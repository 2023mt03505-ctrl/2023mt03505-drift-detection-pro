# Minimal Teams Adaptive Card Notification (Azure + AWS + AI)

$webhook = $env:TEAMS_WEBHOOK_URL

function Read-JsonIfExists($path) {
    if (Test-Path $path) {
        return Get-Content $path -Raw | ConvertFrom-Json
    }
    return $null
}

# ------- NEW: Safe accessor to avoid blank output -------
function Safe($obj, $key, $default) {
    if ($obj -and $obj.PSObject.Properties[$key]) { 
        return $obj.$key
    }
    return $default
}

# Load JSON files
$azure = Read-JsonIfExists "azure/data/drift_results.json"
$aws   = Read-JsonIfExists "aws/data/drift_results.json"
$aiRaw = Read-JsonIfExists "data/drift_results.json"

# ------- FIXED: Build structured values with safe defaults -------
$az = @{
    drift_type  = Safe $azure "drift_type" "none"
    severity    = Safe $azure "severity"   "none"
    fail_count  = Safe $azure "fail_count" 0
    warn_count  = Safe $azure "warn_count" 0
}

$aw = @{
    drift_type  = Safe $aws "drift_type" "none"
    severity    = Safe $aws "severity"   "none"
    fail_count  = Safe $aws "fail_count" 0
    warn_count  = Safe $aws "warn_count" 0
}

$ai = @{
    drift_type  = Safe $aiRaw "drift_type" "none"
    severity    = Safe $aiRaw "severity"   "none"
}

# Compute total severity
$totalFails = $az.fail_count + $aw.fail_count + ($ai.fail_count ? $ai.fail_count : 0)
$totalWarn  = $az.warn_count + $aw.warn_count

if ($totalFails -gt 0)  { $severity = "❌ UNSAFE" }
elseif ($totalWarn -gt 0) { $severity = "⚠ SAFE" }
else { $severity = "✅ CLEAN (No drift)" }

$runUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# -------------------------
# Adaptive Card Payload
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
