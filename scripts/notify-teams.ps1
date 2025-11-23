# ===============================
# FINAL FIXED TEAMS NOTIFICATION
# AUTO-DETECTS PATHS BASED ON YOUR WORKSPACE TREE
# ===============================

$webhook = $env:TEAMS_WEBHOOK_URL

function Find-JsonFile($cloud) {
    $candidates = @(
        "data/$cloud/drift_results.json",      # artifacts download location
        "$cloud/data/drift_results.json"       # fallback (if ever created by drift-check.sh)
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Read-JsonSafe($cloud) {
    $path = Find-JsonFile $cloud
    if (-not $path) {
        Write-Host "WARN: No JSON found for $cloud — using defaults."
        return $null
    }

    try {
        return Get-Content $path -Raw | ConvertFrom-Json
    } catch {
        Write-Host "WARN: Failed to parse JSON for $cloud at $path"
        return $null
    }
}

# -------------------------
# Read JSON (auto-detected paths)
# -------------------------
$azure = Read-JsonSafe "azure"
$aws   = Read-JsonSafe "aws"
$aiRisk = Read-JsonSafe "ai"   # optional

# -------------------------
# Safe defaults
# -------------------------
function Safe($obj) {
    return @{
        drift_type    = $obj?.drift_type    ?? "none"
        fail_count    = $obj?.fail_count    ?? 0
        warn_count    = $obj?.warn_count    ?? 0
        severity      = $obj?.severity      ?? "none"
        resource_count = $obj?.resource_count ?? 0
        action        = $obj?.action        ?? "none"
    }
}

$az = Safe $azure
$aw = Safe $aws
$ai = Safe $aiRisk

# -------------------------
# Severity Logic
# -------------------------
$totalFails = $az.fail_count + $aw.fail_count + $ai.fail_count
$totalWarn  = $az.warn_count + $aw.warn_count + $ai.warn_count

if ($totalFails -gt 0) { $severity = "❌ UNSAFE DRIFT" }
elseif ($totalWarn -gt 0) { $severity = "⚠ SAFE DRIFT" }
else { $severity = "✅ CLEAN — No Drift" }

# -------------------------
# GitHub Run Link
# -------------------------
$runUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# -------------------------
# Adaptive Card
# -------------------------
$card = @{
    "`$schema" = "http://adaptivecards.io/schemas/adaptive-card.json"
    type       = "AdaptiveCard"
    version    = "1.4"
    body       = @(
        @{
            type="TextBlock"; size="Large"; weight="Bolder";
            text="🌐 Multi-Cloud Drift Summary"
        },
        @{
            type="TextBlock"; wrap=$true;
            text="**Overall Status:** $severity"
        },
        @{
            type="FactSet"
            facts = @(
                @{ title="Azure:"; value="Type: $($az.drift_type), Fails: $($az.fail_count), Warns: $($az.warn_count)" }
                @{ title="AWS:"; value="Type: $($aw.drift_type), Fails: $($aw.fail_count), Warns: $($aw.warn_count)" }
                @{ title="AI Risk:"; value="Severity: $($ai.severity)" }
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

# -------------------------
# Send to Teams
# -------------------------
$payload = @{
    type="message"
    attachments = @(
        @{
            contentType="application/vnd.microsoft.card.adaptive"
            content = $card
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $webhook -Method POST -Body $payload -ContentType "application/json"

Write-Host "Teams notification sent successfully."
