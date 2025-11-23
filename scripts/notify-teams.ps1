# Exit early if webhook is missing
if (-not $env:TEAMS_WEBHOOK_URL) {
    Write-Host "❌ TEAMS_WEBHOOK_URL not set. Skipping notification."
    exit 0
}

# Collect all drifts from both clouds
$clouds = @("azure","aws")
$allDrifts = @()

foreach ($c in $clouds) {
    $file = "data/$c/drift_results.json"
    if (Test-Path $file) {
        try {
            $json = Get-Content $file | ConvertFrom-Json
            if ($json) { $allDrifts += $json }
        } catch {
            Write-Warning "⚠ Could not parse $file"
        }
    }
}

# Default message if no drift
if (-not $allDrifts -or $allDrifts.Count -eq 0) {
    $allDrifts = @(@{ cloud="none"; drift_type="none"; message="No drifts detected"; severity="none"; action="none" })
}

# Build a readable summary
$summaryLines = @()
foreach ($d in $allDrifts) {
    $summaryLines += "☁️ Cloud: $($d.cloud)`nDrift Type: $($d.drift_type)`nSeverity: $($d.severity)`nAction: $($d.action)`nResources: $($d.resource_count) | Fail: $($d.fail_count) | Warn: $($d.warn_count)`n---"
}

$summaryText = $summaryLines -join "`n"

# Construct Teams MessageCard payload
$card = @{
    "@type"    = "MessageCard"
    "@context" = "https://schema.org/extensions"
    "summary"  = "Cloud Drift Report"
    "themeColor" = "0076D7"
    "title"    = "☁️ Cloud Drift Report"
    "text"     = $summaryText
}

# Send the notification
try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body ($card | ConvertTo-Json -Depth 10) -ContentType 'application/json'
    Write-Host "✅ Teams notification sent successfully."
} catch {
    Write-Host "❌ Failed to send Teams notification: $_"
}
