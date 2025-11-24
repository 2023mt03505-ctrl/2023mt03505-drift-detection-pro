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

# Function to process drift JSON and calculate counts
function Get-DriftCounts($filePath) {
    if (-Not (Test-Path $filePath)) {
        return @{ total=0; unsafe=0; safe=0 }
    }

    $driftData = Get-Content $filePath -Raw | ConvertFrom-Json

    $total = $driftData.Count
    $unsafe = ($driftData | Where-Object { $_.change.actions -contains "update" }).Count
    $safe = ($driftData | Where-Object { $_.change.actions -contains "no-op" }).Count

    # For simplicity, treat fail as unsafe, warn as safe
    return @{ total=$total; unsafe=$unsafe; safe=$safe }
}

# Azure drift
$azureFile = "data/azure/terraform-drift.json"
$azureCounts = Get-DriftCounts $azureFile
$azureDriftType = if ($azureCounts.unsafe -gt 0) { "unsafe" } else { "safe" }
$azureSeverity = if ($azureCounts.unsafe -gt 0) { "high" } else { "low" }

$attachments += New-DriftAdaptiveCard -cloud "Azure" `
    -drift_type $azureDriftType `
    -severity $azureSeverity `
    -action "remediate" `
    -resources $azureCounts.total `
    -fail $azureCounts.unsafe `
    -warn $azureCounts.safe

# AWS drift
$awsFile = "data/aws/terraform-drift.json"
$awsCounts = Get-DriftCounts $awsFile
$awsDriftType = if ($awsCounts.unsafe -gt 0) { "unsafe" } else { "safe" }
$awsSeverity = if ($awsCounts.unsafe -gt 0) { "high" } else { "low" }

$attachments += New-DriftAdaptiveCard -cloud "AWS" `
    -drift_type $awsDriftType `
    -severity $awsSeverity `
    -action "remediate" `
    -resources $awsCounts.total `
    -fail $awsCounts.unsafe `
    -warn $awsCounts.safe

# Build final payload
$body = @{ attachments = $attachments } | ConvertTo-Json -Depth 10

# Send POST request
try {
    Invoke-RestMethod -Uri $env:TEAMS_WEBHOOK_URL -Method Post -Body $body -ContentType 'application/json'
    Write-Host "✅ Drift summary sent to Teams successfully."
} catch {
    Write-Host "❌ Failed to send Teams notification."
    Write-Host $_.Exception.Message
}
