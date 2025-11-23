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
            $json = Get-Content -Raw $file | ConvertFrom-Json
            if ($json -and $json.Count -gt 0) { $allDrifts += $json }
        } catch {
            Write-Warning "⚠ Could not parse $file. $_"
        }
    } else {
        Write-Warning "⚠ File not found: $file"
    }
}

# If no drifts found, create default message
if (-not $allDrifts -or $allDrifts.Count -eq 0) {
    $allDrifts = @(@{ 
        cloud="none"; 
        drift_type="none"; 
        message="No drifts detected"; 
        severity="none"; 
        action="none"; 
        resource_count=0; 
        fail_count=0; 
        warn_count=0 
    })
}

# Build summary
$summaryLines = @()
foreach ($d in $allDrifts) {
    $summaryLines += @"
☁️ Cloud: $($d.cloud)
Drift Type: $($d.drift_type)
Severity: $($d.severity)
Action: $($d.action)
Resources: $($d.resource_count) | Fail: $($d.fail_count) | Warn: $($d.warn_count)
---
"@
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

# Send the notification (always tries, even if empty)
try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body ($card | ConvertTo-Json -Depth 10 -Compress) -ContentType 'application/json'
    Write-Host "✅ Teams notification sent successfully."
} catch {
    Write-Host "❌ Failed to send Teams notification: $_"
}
