<#
.SYNOPSIS
    Imports Spaarke icons into a Dataverse environment as web resources
    and associates them with their respective entities.

.DESCRIPTION
    This script reads icon-manifest.json and performs:
    1. Creates web resources for each SVG icon
    2. Associates entity icons with their Dataverse entities
    3. Publishes customizations

    Requires: PowerShell 7+ with MSAL.PS module, pac CLI recommended

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://org.crm.dynamics.com)

.PARAMETER SolutionUniqueName
    The solution to add web resources to (default: SpaarkeCore)

.PARAMETER IconsPath
    Path to the icons directory (default: ../icons relative to this script)

.PARAMETER ManifestPath
    Path to icon-manifest.json (default: ../icon-manifest.json relative to this script)

.PARAMETER WhatIf
    Preview changes without executing them

.EXAMPLE
    pwsh ./Import-SpaarkeIcons.ps1 -EnvironmentUrl "https://orgname.crm.dynamics.com"

.EXAMPLE
    pwsh ./Import-SpaarkeIcons.ps1 -EnvironmentUrl "https://orgname.crm.dynamics.com" -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentUrl,

    [Parameter()]
    [string]$SolutionUniqueName = "SpaarkeCore",

    [Parameter()]
    [string]$IconsPath,

    [Parameter()]
    [string]$ManifestPath
)

$ErrorActionPreference = "Stop"

# Resolve paths relative to script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $IconsPath) { $IconsPath = Join-Path $ScriptDir "..\icons" }
if (-not $ManifestPath) { $ManifestPath = Join-Path $ScriptDir "..\icon-manifest.json" }

# ── Load manifest ──────────────────────────────────────────────────────
Write-Host "`n=== Spaarke Icon Deployment ===" -ForegroundColor Cyan
Write-Host "Environment: $EnvironmentUrl"
Write-Host "Solution:    $SolutionUniqueName"
Write-Host "Icons path:  $IconsPath"
Write-Host "Manifest:    $ManifestPath`n"

if (-not (Test-Path $ManifestPath)) {
    Write-Error "Manifest not found at $ManifestPath"
    exit 1
}

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$icons = $manifest.icons
Write-Host "Loaded $($icons.Count) icons from manifest" -ForegroundColor Green

# ── Acquire OAuth2 Access Token ──────────────────────────────────────
Write-Host "`n── Authenticating via OAuth2 ──" -ForegroundColor Yellow

# Ensure MSAL.PS is available
if (-not (Get-Module -ListAvailable MSAL.PS)) {
    Write-Host "Installing MSAL.PS module..." -ForegroundColor Yellow
    Install-Module MSAL.PS -Scope CurrentUser -Force -AcceptLicense
}
Import-Module MSAL.PS

# Well-known Azure AD client ID for Dataverse tooling (public client)
$clientId = "51f81489-12ee-4a9e-aaae-a2591f45987d"
$resource = "$EnvironmentUrl/.default"

try {
    Write-Host "Device code authentication — follow the instructions below.`n" -ForegroundColor Yellow
    $tokenResult = Get-MsalToken -ClientId $clientId -Scopes $resource -DeviceCode
    $accessToken = $tokenResult.AccessToken
    Write-Host "`nAuthenticated as: $($tokenResult.Account.Username)" -ForegroundColor Green
}
catch {
    Write-Error "OAuth2 authentication failed: $($_.Exception.Message)"
    exit 1
}

# Build common headers
$authHeaders = @{
    "Authorization" = "Bearer $accessToken"
    "OData-MaxVersion" = "4.0"
    "OData-Version" = "4.0"
    "Accept" = "application/json"
}

# ── Helper: Convert SVG to Base64 ─────────────────────────────────────
function Get-SvgBase64 {
    param([string]$SvgPath)
    if (-not (Test-Path $SvgPath)) {
        Write-Warning "SVG not found: $SvgPath"
        return $null
    }
    $bytes = [System.IO.File]::ReadAllBytes($SvgPath)
    return [Convert]::ToBase64String($bytes)
}

# ── Helper: Resolve local SVG path from manifest entry ─────────────────
function Get-LocalSvgPath {
    param($Icon)
    # manifest localPath is like "icons/nav/home.svg"
    return Join-Path (Split-Path $IconsPath -Parent) $Icon.localPath
}

# ── Step 1: Create Web Resources ──────────────────────────────────────
Write-Host "`n── Step 1: Web Resources ──" -ForegroundColor Yellow

$webResourcePayloads = @()
$categoryStats = @{}

foreach ($icon in $icons) {
    $svgPath = Get-LocalSvgPath $icon
    $base64 = Get-SvgBase64 $svgPath

    if (-not $base64) {
        Write-Warning "Skipping $($icon.id): SVG not found at $svgPath"
        continue
    }

    $category = $icon.category
    if (-not $categoryStats.ContainsKey($category)) { $categoryStats[$category] = 0 }
    $categoryStats[$category]++

    $payload = @{
        name               = $icon.webResourceName
        displayname        = "$($icon.name) Icon"
        description        = "Fluent UI icon: $($icon.fluentComponent) - $($icon.description)"
        webresourcetype    = 11  # SVG
        content            = $base64
        isenabledformobileclient = $true
        introducedversion  = "1.0.0.0"
    }

    $webResourcePayloads += @{
        Icon    = $icon
        Payload = $payload
    }
}

Write-Host "Prepared $($webResourcePayloads.Count) web resources:"
foreach ($cat in $categoryStats.Keys | Sort-Object) {
    Write-Host "  $cat`: $($categoryStats[$cat])" -ForegroundColor Gray
}

# ── Step 2: Create Entity Icon Associations ───────────────────────────
Write-Host "`n── Step 2: Entity Icon Associations ──" -ForegroundColor Yellow

$entityIcons = $icons | Where-Object {
    $_.usageType -eq "entity" -and $_.entityLogicalName
}

Write-Host "Found $($entityIcons.Count) entity-icon associations to create"

$entityPayloads = @()
foreach ($icon in $entityIcons) {
    $entityPayloads += @{
        EntityLogicalName = $icon.entityLogicalName
        WebResourceName   = $icon.webResourceName
        IconName          = $icon.name
        FluentComponent   = $icon.fluentComponent
    }
    Write-Host "  $($icon.entityLogicalName) -> $($icon.webResourceName)" -ForegroundColor Gray
}

# ── Step 3: Navigation / Sitemap References ───────────────────────────
Write-Host "`n── Step 3: Sitemap Navigation Icons ──" -ForegroundColor Yellow

$navIcons = $icons | Where-Object { $_.usageType -eq "navigation" }
Write-Host "Found $($navIcons.Count) navigation icon references"

foreach ($icon in $navIcons) {
    Write-Host "  $($icon.name) -> `$webresource:$($icon.webResourceName)" -ForegroundColor Gray
}

# ── Execute or Preview ────────────────────────────────────────────────
if ($WhatIf -or -not $PSCmdlet.ShouldProcess("Dataverse environment $EnvironmentUrl", "Import $($webResourcePayloads.Count) web resources")) {
    Write-Host "`n── WhatIf Mode: No changes made ──" -ForegroundColor Magenta
    Write-Host "Would create $($webResourcePayloads.Count) web resources"
    Write-Host "Would associate $($entityPayloads.Count) entity icons"
    Write-Host "Would reference $($navIcons.Count) navigation icons in sitemap"
    Write-Host "`nTo execute, run without -WhatIf flag."
    exit 0
}

# ── Create web resources via Web API ──────────────────────────────────
Write-Host "`n── Creating Web Resources ──" -ForegroundColor Yellow
$apiBase = "$EnvironmentUrl/api/data/v9.2"
$created = 0
$updated = 0
$failed = 0

foreach ($item in $webResourcePayloads) {
    $icon = $item.Icon
    $payload = $item.Payload
    $jsonBody = $payload | ConvertTo-Json -Depth 5

    try {
        # Check if web resource already exists
        $filter = "name eq '$($payload.name)'"
        $existing = Invoke-RestMethod -Uri "$apiBase/webresourceset?`$filter=$filter&`$select=webresourceid" `
            -Method Get -Headers $authHeaders -ContentType "application/json"

        if ($existing.value.Count -gt 0) {
            # Update existing
            $wrId = $existing.value[0].webresourceid
            Invoke-RestMethod -Uri "$apiBase/webresourceset($wrId)" `
                -Method Patch -Body $jsonBody -Headers $authHeaders -ContentType "application/json"
            $updated++
            Write-Host "  Updated: $($icon.webResourceName)" -ForegroundColor DarkGreen
        }
        else {
            # Create new
            Invoke-RestMethod -Uri "$apiBase/webresourceset" `
                -Method Post -Body $jsonBody -Headers $authHeaders -ContentType "application/json"
            $created++
            Write-Host "  Created: $($icon.webResourceName)" -ForegroundColor Green
        }
    }
    catch {
        $failed++
        Write-Warning "  Failed: $($icon.webResourceName) - $($_.Exception.Message)"
    }
}

Write-Host "`nWeb Resources: $created created, $updated updated, $failed failed" -ForegroundColor Cyan

# ── Associate entity icons ────────────────────────────────────────────
Write-Host "`n── Associating Entity Icons ──" -ForegroundColor Yellow

foreach ($ep in $entityPayloads) {
    try {
        # Update entity metadata to set icon — requires @odata.type and MergeLabels header
        $entityMetadata = @{
            "@odata.type"  = "Microsoft.Dynamics.CRM.EntityMetadata"
            IconSmallName  = $ep.WebResourceName
            IconMediumName = $ep.WebResourceName
            IconLargeName  = $ep.WebResourceName
            IconVectorName = $ep.WebResourceName
        } | ConvertTo-Json

        $metadataHeaders = @{} + $authHeaders
        $metadataHeaders["MSCRM.MergeLabels"] = "true"

        Invoke-RestMethod -Uri "$apiBase/EntityDefinitions(LogicalName='$($ep.EntityLogicalName)')" `
            -Method Put -Body $entityMetadata -Headers $metadataHeaders -ContentType "application/json"

        Write-Host "  Associated: $($ep.EntityLogicalName) -> $($ep.IconName)" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Failed to associate $($ep.EntityLogicalName): $($_.Exception.Message)"
    }
}

# ── Publish customizations ────────────────────────────────────────────
Write-Host "`n── Publishing Customizations ──" -ForegroundColor Yellow

try {
    Invoke-RestMethod -Uri "$apiBase/PublishAllXml" `
        -Method Post -Headers $authHeaders -ContentType "application/json"

    Write-Host "Customizations published successfully" -ForegroundColor Green
}
catch {
    Write-Warning "Publish failed: $($_.Exception.Message)"
    Write-Host "You may need to publish manually from the Power Platform admin center."
}

# ── Summary ───────────────────────────────────────────────────────────
Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Web Resources:    $created created, $updated updated, $failed failed"
Write-Host "Entity Icons:     $($entityPayloads.Count) associations"
Write-Host "Navigation Icons: $($navIcons.Count) sitemap references (update sitemap XML manually)"
Write-Host "`nNote: Sitemap navigation icons must be updated in the sitemap editor"
Write-Host "or by modifying the sitemap XML in your solution. See deploy/sitemap-icons.xml"
Write-Host "for the SubArea definitions to use.`n"
