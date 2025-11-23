# Ensure the webhook URL is set
if (-Not $env:TEAMS_WEBHOOK_URL) {
    Write-Host "❌ TEAMS_WEBHOOK_URL not set in environment variables."
    exit 1
}

# Build a sample payload from collected drift logs
$payload = @{
    summary = "Cloud Drift Notification"
    drifts = @()
}

# Try to read Azure drift results
$azureFile = "data/azure/terraform-drift.json"
if (Test-Path $azureFile) {
    $azureDrift = Get-Content $azureFile -Raw | ConvertFrom-Json
    $payload.drifts += @{
        cloud      = "azure"
        drift_type = if ($azureDrift.unsafe_count -gt 0) { "unsafe" } else { "safe" }
        severity   = if ($azureDrift.unsafe_count -gt 0) { "high" } else { "low" }
        action     = "remediate"
        resources  = $azureDrift.total_resources
        fail       = $azureDrift.fail_count
        warn       = $azureDrift.warn_count
    }
}

# Try to read AWS drift results
$awsFile = "data/aws/terraform-drift.json"
if (Test-Path $awsFile) {
    $awsDrift = Get-Content $awsFile -Raw | ConvertFrom-Json
    $payload.drifts += @{
        cloud      = "aws"
        drift_type = if ($awsDrift.unsafe_count -gt 0) { "unsafe" } else { "safe" }
        severity   = if ($awsDrift.unsafe_count -gt 0) { "high" } else { "low" }
        action     = "remediate"
        resources  = $awsDrift.total_resources
        fail       = $awsDrift.fail_count
        warn       = $awsDrift.warn_count
    }
}

# Convert payload to JSON
$body = $payload | ConvertTo-Json -Depth 5

# Send POST request
try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body $body -ContentType 'application/json'
    Write-Host "✅ Drift summary sent to Power Automate successfully."
} catch {
    Write-Host "❌ Failed to send Teams notification."
    Write-Host $_.Exception.Message
}
