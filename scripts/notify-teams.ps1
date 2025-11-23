# Ensure the webhook URL is set
if (-Not $env:TEAMS_WEBHOOK_URL) {
    Write-Host "❌ TEAMS_WEBHOOK_URL not set in environment variables."
    exit 1
}

# Initialize the attachments array
$attachments = @()

# Helper function to create an Adaptive Card for a drift entry
function New-DriftAdaptiveCard($cloud, $drift_type, $severity, $action, $resources, $fail, $warn) {
    return @{
        contentType = "application/vnd.microsoft.card.adaptive"
        content = @{
            type = "AdaptiveCard"
            version = "1.2"
            body = @(
                @{
                    type = "TextBlock"
                    text = "$cloud Drift Report"
                    weight = "Bolder"
                    size = "Medium"
                },
                @{
                    type = "FactSet"
                    facts = @(
                        @{ title = "Drift Type:"; value = $drift_type }
                        @{ title = "Severity:"; value = $severity }
                        @{ title = "Action:"; value = $action }
                        @{ title = "Total Resources:"; value = "$resources" }
                        @{ title = "Fail Count:"; value = "$fail" }
                        @{ title = "Warn Count:"; value = "$warn" }
                    )
                }
            )
        }
    }
}

# Read Azure drift results
$azureFile = "data/azure/terraform-drift.json"
if (Test-Path $azureFile) {
    $azureDrift = Get-Content $azureFile -Raw | ConvertFrom-Json
    $attachments += New-DriftAdaptiveCard -cloud "Azure" `
        -drift_type (if ($azureDrift.unsafe_count -gt 0) { "unsafe" } else { "safe" }) `
        -severity (if ($azureDrift.unsafe_count -gt 0) { "high" } else { "low" }) `
        -action "remediate" `
        -resources $azureDrift.total_resources `
        -fail $azureDrift.fail_count `
        -warn $azureDrift.warn_count
}

# Read AWS drift results
$awsFile = "data/aws/terraform-drift.json"
if (Test-Path $awsFile) {
    $awsDrift = Get-Content $awsFile -Raw | ConvertFrom-Json
    $attachments += New-DriftAdaptiveCard -cloud "AWS" `
        -drift_type (if ($awsDrift.unsafe_count -gt 0) { "unsafe" } else { "safe" }) `
        -severity (if ($awsDrift.unsafe_count -gt 0) { "high" } else { "low" }) `
        -action "remediate" `
        -resources $awsDrift.total_resources `
        -fail $awsDrift.fail_count `
        -warn $awsDrift.warn_count
}

# Build final payload
$body = @{ attachments = $attachments } | ConvertTo-Json -Depth 10

# Send POST request
try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body $body -ContentType 'application/json'
    Write-Host "✅ Drift summary sent to Power Automate successfully."
} catch {
    Write-Host "❌ Failed to send Teams notification."
    Write-Host $_.Exception.Message
}
