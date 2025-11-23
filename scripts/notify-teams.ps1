$clouds = @("azure","aws")
$allDrifts = @()

foreach ($c in $clouds) {
    $file = "data/$c/drift_results.json"
    if (Test-Path $file) {
        try {
            $json = Get-Content $file -Raw | ConvertFrom-Json
            $allDrifts += $json
        } catch {
            Write-Warning "⚠ Could not parse $file: $_"
        }
    } else {
        Write-Warning "⚠ Drift results not found for $c: $file"
    }
}

if ($allDrifts.Count -eq 0) {
    $cardText = "ℹ No drift results available for any cloud."
} else {
    $cardText = ($allDrifts | ConvertTo-Json -Depth 5)
}

$card = @{
    title = "Cloud Drift Report"
    text  = $cardText
}

try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK -Method Post -Body ($card | ConvertTo-Json) -ContentType 'application/json'
    Write-Host "✅ Teams notification sent."
} catch {
    Write-Warning "⚠ Failed to send Teams notification: $_"
}
