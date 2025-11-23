# Minimal Teams Adaptive Card Notification (Azure + AWS + AI)

$webhook = $env:TEAMS_WEBHOOK_URL

function Read-JsonIfExists($path) {
    if (Test-Path $path) {
        try {
            return Get-Content $path -Raw | ConvertFrom-Json
        } catch {
            Write-Host "WARN: Failed to parse JSON at $path"
        }
    }
    return $null
}

$azure = Read-JsonIfExists "azure/data/drift_results.json"
$aws   = Read-JsonIfExists "aws/data/drift_results.json"
$aiRisk = Read-JsonIfExists "data/drift_results.json"

# --- Default safe values ----
$az = @{
    drift_type = $azure?.drift_type ?? "none"
    fail_count = $azure?.fail_count ?? 0
    warn_count = $azure?.warn_count ?? 0
    severity   = $azure?.severity ?? "none"
}

$aw = @{
    drift_type = $aws?.drift_type ?? "none"
    fail_count = $aws?.fail_count ?? 0
    warn_count = $aws?.warn_count ?? 0
    severity   = $aws?.severity ?? "none"
}

$ai = @{
    drift_type = $aiRisk?.drift_type ?? "none"
    fail_count = $aiRisk?.fail_count ?? 0
    warn_count = $aiRisk?.warn_count ?? 0
    severity   = $aiRisk?.severity ?? "none"
}

# ---------- Summary -------------
$totalFails = $az.fail_count + $aw.fail_count + $ai.fail_count
$totalWarn  = $az.warn_count + $aw.warn_count + $ai.warn_count

if ($totalFails -gt 0) {
    $severity = "❌ UNSAFE"
}
elseif ($totalWarn -gt 0) {
    $severity = "⚠ SAFE"
}
else {
    $severity = "✅ CLEAN (No drift)"
}

$runUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# ---------- Teams Adaptive Card ----------
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
