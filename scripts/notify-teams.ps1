# Exit if webhook is missing
if (-not $env:TEAMS_WEBHOOK_URL) {
    Write-Host "❌ TEAMS_WEBHOOK_URL not set. Skipping notification."
    exit 0
}

$clouds = @("azure","aws")
$allDrifts = @()

foreach ($c in $clouds) {
    $file = "data/$c/drift_results.json"
    if (Test-Path $file) {
        try {
            $json = Get-Content $file | ConvertFrom-Json
            if ($json -ne $null) { $allDrifts += $json }
        } catch { Write-Warning "⚠ Could not parse $file" }
    }
}

# Default if empty
if (-not $allDrifts -or $allDrifts.Count -eq 0) {
    $allDrifts = @(@{ cloud="none"; drift_type="none"; message="No drifts detected"; severity="none"; action="none" })
}

# Build readable summary
$textLines = @()
foreach ($d in $allDrifts) {
    $cloud = $d.cloud
    $type  = $d.drift_type
    $severity = $d.severity
    $action   = $d.action
    $resources = if ($d.resource_count) { $d.resource_count } else { 0 }
    $fails     = if ($d.fail_count) { $d.fail_count } else { 0 }
    $warns     = if ($d.warn_count) { $d.warn_count } else { 0 }

    $textLines += "Cloud: $cloud`nType: $type`nSeverity: $severity`nAction: $action`nResources: $resources | Fail: $fails | Warn: $warns`n"
}

$text = $textLines -join "`n---`n"

# Minimal valid MessageCard
$card = @{
    "@type"    = "MessageCard"
    "@context" = "https://schema.org/extensions"
    "summary"  = "Cloud Drift Report"
    "themeColor" = "0076D7"
    "title"    = "☁️ Cloud Drift Report"
    "text"     = $text
}

try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body ($card | ConvertTo-Json -Depth 10) -ContentType 'application/json'
    Write-Host "✅ Teams notification sent successfully."
} catch {
    Write-Host "❌ Failed to send Teams notification: $_"
}
