# Robust Teams Adaptive Card Notification (Azure + AWS + AI)
# Reads multiple possible outputs from your workflow (minimal changes to other components)

$webhook = $env:TEAMS_WEBHOOK_URL

function Read-JsonIfExists($path) {
    if (Test-Path $path) {
        try {
            return Get-Content $path -Raw | ConvertFrom-Json
        } catch {
            Write-Host "WARN: Failed to parse JSON at $path"
            return $null
        }
    }
    return $null
}

function Safe($obj, $key, $default) {
    if ($obj -and $obj.PSObject.Properties[$key]) {
        return $obj.$key
    }
    return $default
}

# ---- Utility: parse conftest_output.log to get FAIL / WARN counts if JSON not present ----
function Parse-ConftestLog($logPath) {
    $res = @{ fail_count = 0; warn_count = 0; drift_type = "none" }
    if (Test-Path $logPath) {
        $txt = Get-Content $logPath -Raw
        $fail = ([regex]::Matches($txt, "(?i)\bFAIL\b|❌")).Count
        $warn = ([regex]::Matches($txt, "(?i)\bWARN\b|⚠")).Count
        $res.fail_count = $fail
        $res.warn_count = $warn
        if ($fail -gt 0) { $res.drift_type = "unsafe" }
        elseif ($warn -gt 0) { $res.drift_type = "safe" }
        return $res
    }
    return $null
}

# ---- Utility: try a bunch of possible drift JSON filenames for a cloud ----
function Get-CloudDrift($cloudDir) {
    # candidate file list (in order)
    $candidates = @(
        "$cloudDir/terraform-drift.json",
        "$cloudDir/drift_results.json",
        "$cloudDir/drift_results.json",   # duplicate intentionally harmless
        "$cloudDir/resource_changes.json",
        "$cloudDir/tfplan.json",
        "$cloudDir/conftest_output.log"
    )

    foreach ($p in $candidates) {
        if (Test-Path $p) {
            if ($p -like "*.log") {
                $parsed = Parse-ConftestLog $p
                if ($parsed) { return $parsed }
            } elseif ($p -like "*.json") {
                $j = Read-JsonIfExists $p
                if ($j -ne $null) {
                    # If this JSON already contains fail_count / warn_count keys use them
                    if ($j.PSObject.Properties.Name -contains "fail_count" -or $j.PSObject.Properties.Name -contains "warn_count") {
                        return @{
                            drift_type = Safe $j "drift_type" "none"
                            severity   = Safe $j "severity"   "none"
                            fail_count = [int](Safe $j "fail_count" 0)
                            warn_count = [int](Safe $j "warn_count" 0)
                        }
                    }

                    # If it's terraform-drift like structure (array or object), try heuristics:
                    if ($j -is [System.Array]) {
                        $count = $j.Length
                        return @{
                            drift_type = (if ($count -gt 0) { "update" } else { "none" })
                            severity   = (if ($count -gt 0) { "low" } else { "none" })
                            fail_count = $count
                            warn_count = 0
                        }
                    } elseif ($j -is [PSCustomObject]) {
                        # try common fields
                        $rc = 0
                        if ($j.PSObject.Properties.Name -contains "resource_changes") {
                            $rc = ( ($j.resource_changes) -as [array] ).Length
                        } elseif ($j.PSObject.Properties.Name -contains "changes") {
                            $rc = ( ($j.changes) -as [array] ).Length
                        } elseif ($j.PSObject.Properties.Name -contains "failed_resources") {
                            # failed_resources possibly array or json-string
                            $fr = $j.failed_resources
                            if ($fr -is [string]) {
                                try { $arr = ConvertFrom-Json $fr; $rc = $arr.Length } catch { $rc = 0 }
                            } elseif ($fr -is [array]) { $rc = $fr.Length }
                        }

                        # If we detected some resources changed, treat as low/high
                        if ($rc -gt 0) {
                            return @{
                                drift_type = Safe $j "drift_type" "update"
                                severity   = Safe $j "severity" "low"
                                fail_count = $rc
                                warn_count = Safe $j "warn_count" 0
                            }
                        }

                        # Fallback: if object empty => return null to continue searching
                        if ($j.PSObject.Properties.Count -eq 0) { return $null }

                        # As last resort, attempt to read keys generically
                        return @{
                            drift_type = Safe $j "drift_type" "none"
                            severity   = Safe $j "severity" "none"
                            fail_count = [int](Safe $j "fail_count" 0)
                            warn_count = [int](Safe $j "warn_count" 0)
                        }
                    }
                }
            } # json/log end
        } # if exists
    } # loop candidates

    # No useful files found → return defaults
    return @{
        drift_type = "none"
        severity   = "none"
        fail_count = 0
        warn_count = 0
    }
}

# ---- AI risk extraction: look for ai_results.json OR drift_predictions.csv ----
function Get-AIRisk() {
    $aiCandidates = @(
        "data/ai_results.json",
        "data/drift_results.json",
        "data/ai_results.json",
        "data/drift_predictions.csv",
        "data/drift_features.csv"
    )

    foreach ($p in $aiCandidates) {
        if (Test-Path $p) {
            if ($p -like "*.json") {
                $j = Read-JsonIfExists $p
                if ($j -ne $null) {
                    return @{
                        drift_type = Safe $j "drift_type" "none"
                        severity   = Safe $j "severity" "none"
                        fail_count = [int](Safe $j "fail_count" 0)
                    }
                }
            } elseif ($p -like "*.csv") {
                try {
                    $csv = Import-Csv -Path $p -ErrorAction Stop
                    if ($csv -and $csv.Count -gt 0) {
                        # look for predicted_risk column or risk/confidence
                        if ($csv.PSObject.Properties.Name -contains "predicted_risk") {
                            $high = ($csv | Where-Object { $_.predicted_risk -match "(?i)high" }).Count
                            if ($high -gt 0) {
                                return @{ drift_type="ai"; severity="high"; fail_count=$high }
                            } else {
                                return @{ drift_type="ai"; severity="low"; fail_count=0 }
                            }
                        } elseif ($csv.PSObject.Properties.Name -contains "predicted") {
                            $high = ($csv | Where-Object { $_.predicted -match "(?i)high" }).Count
                            if ($high -gt 0) { return @{ drift_type="ai"; severity="high"; fail_count=$high } }
                            else { return @{ drift_type="ai"; severity="low"; fail_count=0 } }
                        } else {
                            # generic: if rows exist, mark low
                            return @{ drift_type="ai"; severity="low"; fail_count=0 }
                        }
                    }
                } catch {
                    Write-Host "WARN: Could not import CSV $p - $_"
                }
            }
        }
    }

    return @{ drift_type="none"; severity="none"; fail_count=0 }
}

# -----------------------
# Gather per-cloud data
# -----------------------
$azureDrift = Get-CloudDrift "azure/data"
$awsDrift   = Get-CloudDrift "aws/data"
$aiInfo     = Get-AIRisk

# Prepare $az, $aw, $ai objects for card (consistent shape)
$az = @{
    drift_type = $azureDrift.drift_type
    severity   = (if ($azureDrift.severity) { $azureDrift.severity } else { "none" })
    fail_count = [int]($azureDrift.fail_count)
    warn_count = [int]($azureDrift.warn_count)
}

$aw = @{
    drift_type = $awsDrift.drift_type
    severity   = (if ($awsDrift.severity) { $awsDrift.severity } else { "none" })
    fail_count = [int]($awsDrift.fail_count)
    warn_count = [int]($awsDrift.warn_count)
}

$ai = @{
    drift_type = $aiInfo.drift_type
    severity   = $aiInfo.severity
    fail_count = [int]($aiInfo.fail_count)
}

# Total summary
$totalFails = $az.fail_count + $aw.fail_count + $ai.fail_count
$totalWarn  = $az.warn_count + $aw.warn_count

if ($totalFails -gt 0)  { $severity = "❌ UNSAFE" }
elseif ($totalWarn -gt 0) { $severity = "⚠ SAFE" }
else { $severity = "✅ CLEAN (No drift)" }

$runUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# -------------------------
# Adaptive Card Payload (keeps your original look)
# -------------------------
$card = @{
    "`$schema" = "http://adaptivecards.io/schemas/adaptive-card.json"
    type = "AdaptiveCard"
    version = "1.4"
    body = @(
        @{
            type="TextBlock"
            size="Large"
            weight="Bolder"
            text="🌐 Multi-Cloud Drift Summary"
        },
        @{
            type="TextBlock"
            text="**Overall Status:** $severity"
            wrap=$true
        },
        @{
            type="FactSet"
            facts=@(
                @{ title="Azure:"; value="Type: $($az.drift_type), Fails: $($az.fail_count), Warns: $($az.warn_count)" }
                @{ title="AWS:";   value="Type: $($aw.drift_type), Fails: $($aw.fail_count), Warns: $($aw.warn_count)" }
                @{ title="AI Risk:"; value="Type: $($ai.drift_type), Severity: $($ai.severity)" }
            )
        }
    )
    actions=@(
        @{
            type="Action.OpenUrl"
            title="🔍 View Run Logs / Artifacts"
            url=$runUrl
        }
    )
}

$payload = @{
    type="message"
    attachments = @(
        @{
            contentType="application/vnd.microsoft.card.adaptive"
            content = $card
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri $webhook -Body $payload -ContentType "application/json"
Write-Host "Teams notification sent."
