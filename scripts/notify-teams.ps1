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
            if ($json) { $allDrifts += $json }
        } catch {
            Write-Warning "⚠ Could not parse $file. $_"
        }
    } else {
        Write-Warning "⚠ File not found: $file"
    }
}

# Default message if no drift
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

# Build a summary array
$summaryObjects = @()
foreach ($d in $allDrifts) {
    $summaryObjects += [PSCustomObject]@{
        cloud = $d.cloud
        drift_type = $d.drift_type
        severity = $d.severity
        action = $d.action
        resources = $d.resource_count
        fail = $d.fail_count
        warn = $d.warn_count
    }
}

# Prepare payload for Power Automate
$payload = @{
    summary = "Cloud Drift Report"
    drifts = $summaryObjects
} | ConvertTo-Json -Depth 10

# Send to Power Automate flow
try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body $payload -ContentType 'application/json'
    Write-Host "✅ Drift summary sent to Power Automate successfully."
} catch {
    Write-Host "❌ Failed to send to Power Automate: $_"
}
