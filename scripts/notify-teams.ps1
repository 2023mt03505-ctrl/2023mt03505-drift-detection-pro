# ===============================
# AUTO-DETECT JSON PATHS – FINAL FIX
# ===============================

$webhook = $env:TEAMS_WEBHOOK_URL

# STRICT FINAL JSON DETECTOR (only valid artifact JSON)
function Find-JsonFile {
    param($cloud)

    # FINAL FIX — replaces your earlier candidates
    $preferred = "data/$cloud/drift_results.json"

    if (Test-Path $preferred) {
        return $preferred
    }

    Write-Host "WARN: No JSON found for $cloud"
    return $null
}

function Read-JsonSafe($cloud) {
    $path = Find-JsonFile $cloud
    if (-not $path) { return $null }

    try { return Get-Content $path -Raw | ConvertFrom-Json }
    catch {
        Write-Host "WARN: Failed to parse JSON for $cloud at $path"
        return $null
    }
}

# -------------------------
# Read JSON
# -------------------------
$azure = Read-JsonSafe "azure"
$aws   = Read-JsonSafe "aws"
$ai    = Read-JsonSafe "ai"

# -------------------------
# Safe defaults
# -------------------------
function Safe($x) {
    return @{
        drift_type = $x?.drift_type ?? "none"
        fail_count = $x?.fail_count ?? 0
        warn_count = $x?.warn_count ?? 0
        severity   = $x?.severity   ?? "none"
    }
}

$az = Safe $azure
$aw = Safe $aws
$ai = Safe $ai

$totalFails = $az.fail_count + $aw.fail_count
$totalWarns = $az.warn_count + $aw.warn_count

if ($totalFails -gt 0) { $overall = "❌ UNSAFE DRIFT" }
elseif ($totalWarns -gt 0) { $overall = "⚠ SAFE DRIFT" }
else { $overall = "✅ CLEAN — No Drift" }

$runUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"

# -------------------------
# Adaptive card
# -------------------------
$card = @{
    "`$schema"="http://adaptivecards.io/schemas/adaptive-card.json"
    type="AdaptiveCard"
    version="1.4"
    body=@(
        @{ type="TextBlock"; size="Large"; weight="Bolder"; text="🌐 Multi-Cloud Drift Summary" },
        @{ type="TextBlock"; wrap=$t
