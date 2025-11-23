# ===============================
# AUTO-DETECT JSON PATHS – FINAL FIX
# ===============================

# -------------------------
# ENSURE PARENT FOLDERS EXIST
# -------------------------
if (-not (Test-Path "data/azure")) { New-Item -ItemType Directory -Path "data/azure" | Out-Null }
if (-not (Test-Path "data/aws"))   { New-Item -ItemType Directory -Path "data/aws"   | Out-Null }
if (-not (Test-Path "data/ai"))    { New-Item -ItemType Directory -Path "data/ai"    | Out-Null }

# -------------------------
# CREATE EMPTY JSON FILES IF MISSING
# -------------------------
$azureFile = "data/azure/drift_results.json"
if (-not (Test-Path $azureFile)) { '{}' | Set-Content $azureFile }

$awsFile   = "data/aws/drift_results.json"
if (-not (Test-Path $awsFile))   { '{}' | Set-Content $awsFile }

$aiFile    = "data/ai/drift_results.json"
if (-not (Test-Path $aiFile))    { '{}' | Set-Content $aiFile }

# -------------------------
# TEAMS WEBHOOK
# -------------------------
$webhook = $env:TEAMS_WEBHOOK_URL

# STRICT FINAL JSON DETECTOR (only valid artifact JSON)
function Find-JsonFile {
    param($cloud)
    $preferred = "data/$cloud/drift_results.json"
    if (Test-Path $preferred) { return $preferred }
    Write-Host "WARN: No JSON found for $cloud"
    return $null
}

function Read-JsonSafe($cloud) {
    $path = Find-JsonFile $cloud
    if (-not $path) { return $null }
    try { return Get-Content $path -Raw | ConvertFrom-Json }
    catch {
        Write-Host "WARN: Failed to parse JSON for $cloud at $path"
        return $null
    }
}

# -------------------------
# Read JSON safely
# -------------------------
$azure = Read-JsonSafe "azure"
$aws   = Read-JsonSafe "aws"
$ai    = Read-JsonSafe "ai"

# -------------------------
# Safe defaults
# -------------------------
function Safe($x) {
    return @{
        drift_type = $x?.drift_type ?? "none"
        fail_count = $x?.fail_count ?? 0
        warn_count = $x?.warn_count ?? 0
        severity   = $x?.severity   ?? "none"
    }
}

$az = Safe $azure
$aw = Safe $aws
$ai = Safe $ai

$totalFails = $az.fail_count + $aw.fail_count
$totalWarns = $az.warn_count + $aw.warn_count

if ($totalFails -gt 0) { $overall = "❌ UNSAFE DRIFT" }
elseif ($totalWarns -gt 0) { $overall = "⚠ SAFE DRIFT" }
else { $overall = "✅ CLEAN — No Drift Detected" }

$runUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# -------------------------
# Adaptive Card
# -------------------------
$card = @{
    "`$schema" = "http://adaptivecards.io/schemas/adaptive-card.json"
    type      = "AdaptiveCard"
    version   = "1.4"
    body      = @(
        @{
            type="TextBlock"
            size="Large"
            weight="Bolder"
            text="🌐 Multi-Cloud Drift Summary"
        },
        @{
            type="TextBlock"
            wrap=$true
            text="**Overall Status:** $overall"
        },
        @{
            type="FactSet"
            facts = @(
                @{
                    title="Azure:"
                    value="Type: $($az.drift_type), Fails: $($az.fail_count), Warns: $($az.warn_count)"
                },
                @{
                    title="AWS:"
                    value="Type: $($aw.drift_type), Fails: $($aw.fail_count), Warns: $($aw.warn_count)"
                },
                @{
                    title="AI Risk:"
                    value="Severity: $($ai.severity)"
                }
            )
        }
    )
    actions = @(
        @{
            type="Action.OpenUrl"
            title="🔍 View Logs / Artifacts"
            url=$runUrl
        }
    )
}

$payload = @{
    type="message"
    attachments=@(
        @{
            contentType="application/vnd.microsoft.card.adaptive"
            content=$card
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $webhook -Method POST -Body $payload -ContentType "application/json"

Write-Host "Teams notification sent OK!"
