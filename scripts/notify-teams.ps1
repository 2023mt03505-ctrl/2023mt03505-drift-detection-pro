# Exit early if webhook secret is missing
if (-not $env:TEAMS_WEBHOOK_URL) {
    Write-Host "❌ TEAMS_WEBHOOK_URL not set. Skipping notification."
    exit 0
}

# List of clouds
$clouds = @("azure","aws")
$allDrifts = @()

foreach ($c in $clouds) {
    $file = "data/$c/drift_results.json"
    if (Test-Path $file) {
        try {
            $json = Get-Content $file | ConvertFrom-Json
            if ($json -ne $null -and $json.Count -gt 0) {
                $allDrifts += $json
            }
        } catch {
            Write-Warning "⚠ Could not parse $file"
        }
    }
}

# Handle empty drift
if (-not $allDrifts -or $allDrifts.Count -eq 0) {
    $allDrifts = @(@{ cloud = "none"; drift_type = "none"; message = "No drifts detected" })
}

# Build human-readable summary text
$text = ""
foreach ($d in $allDrifts) {
    $cloud = $d.cloud
    $type  = $d.drift_type
    $severity = $d.severity
    $action   = $d.action
    $resource_count = $d.resource_count
    $fail_count     = $d.fail_count
    $warn_count     = $d.warn_count

    $text += "☁️ **Cloud:** $cloud`n"
    $text += "Drift Type: $type`nSeverity: $severity`nAction: $action`n"
    $text += "Resources: $resource_count | Fail: $fail_count | Warn: $warn_count`n`n"
}

# Build Teams MessageCard payload
$card = @{
    "@type"    = "MessageCard"
    "@context" = "https://schema.org/extensions"
    "summary"  = "Cloud Drift Report"
    "themeColor" = "0076D7"
    "title"    = "☁️ Cloud Drift Report"
    "text"     = $text
}

# Send the Teams notification
try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body ($card | ConvertTo-Json -Depth 5) -ContentType 'application/json'
    Write-Host "✅ Teams notification sent successfully."
} catch {
    Write-Host "❌ Failed to send Teams notification: $_"
}
