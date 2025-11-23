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
    $allDrifts = @(@{ message = "No drifts detected" })
}

# Build human-readable text for Teams
$textArray = $allDrifts | ForEach-Object {
    $_ | ConvertTo-Json -Depth 5 -Compress
}
$text = $textArray -join "`n`n"

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
Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body ($card | ConvertTo-Json -Depth 5) -ContentType 'application/json'

Write-Host "✅ Teams notification sent with drift values."
