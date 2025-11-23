$clouds = @("azure","aws")
$allDrifts = @()

foreach ($c in $clouds) {
    $file = "data/$c/drift_results.json"
    if (Test-Path $file) {
        try {
            $json = Get-Content $file | ConvertFrom-Json
            $allDrifts += $json
        } catch {
            Write-Warning "⚠ Could not parse $file"
        }
    }
}

# Build Teams card payload
$card = @{
    title = "Cloud Drift Report"
    text = ($allDrifts | ConvertTo-Json -Depth 5)
}

Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK -Method Post -Body ($card | ConvertTo-Json) -ContentType 'application/json'
Write-Host "✅ Teams notification sent."
