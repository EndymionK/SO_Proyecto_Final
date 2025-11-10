#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Removes old experiment results and optionally archives them.
.PARAMETER Archive
    Create a timestamped ZIP archive before deletion.
.PARAMETER RemoveRaw
    Remove raw CSV files under results/raw/ (default: true).
.PARAMETER RemoveProcessed
    Remove processed outputs under results/processed/ (default: false).
.PARAMETER RemoveExperiments
    Remove experiment folders under results/experiments/ (default: true).
.PARAMETER Force
    Skip interactive confirmation prompt.
#>
param(
    [switch]$Archive,
    [switch]$RemoveRaw = $true,
    [switch]$RemoveProcessed = $false,
    [switch]$RemoveExperiments = $true,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Resolve-Path (Join-Path $ScriptDir '..')

$rawDir = Join-Path $RepoRoot 'results\raw'
$metaDir = Join-Path $RepoRoot 'results\meta'
$processedDir = Join-Path $RepoRoot 'results\processed'
$exptsDir = Join-Path $RepoRoot 'results\experiments'
$archiveRoot = Join-Path $RepoRoot 'archive'

function Confirm-Or-Exit($msg) {
    if ($Force) { return }
    Write-Host $msg -ForegroundColor Yellow
    $ans = Read-Host "Proceed? (Y/N)"
    if ($ans -notin @('Y','y')) { 
        Write-Host 'Aborted by user.' -ForegroundColor Red
        exit 0 
    }
}

# Build list of targets
$toRemove = @()
if ($RemoveRaw -and (Test-Path $rawDir)) {
    # Remover TODOS los archivos en raw/ (CSVs, .proc.status, .cpu.stat, etc.)
    $rawFiles = Get-ChildItem -Path $rawDir -File -Recurse -ErrorAction SilentlyContinue
    if ($rawFiles) { $toRemove += $rawFiles }
}
if ($RemoveRaw -and (Test-Path $metaDir)) {
    # Remover archivos JSON de metadata
    $metaFiles = Get-ChildItem -Path $metaDir -File -Recurse -ErrorAction SilentlyContinue
    if ($metaFiles) { $toRemove += $metaFiles }
}
if ($RemoveProcessed -and (Test-Path $processedDir)) {
    $procFiles = Get-ChildItem -Path $processedDir -File -Recurse -ErrorAction SilentlyContinue
    if ($procFiles) { $toRemove += $procFiles }
}
if ($RemoveExperiments -and (Test-Path $exptsDir)) {
    $expItems = Get-ChildItem -Path $exptsDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($expItems) { $toRemove += $expItems }
}

if (-not $toRemove) {
    Write-Host 'Nothing to remove (no matching files).' -ForegroundColor Green
    exit 0
}

Write-Host "Files/items to be removed (count: $($toRemove.Count)):" -ForegroundColor Cyan
$toRemove | ForEach-Object { Write-Host "  - $($_.FullName)" }

if ($Archive) {
    New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null
    $ts = (Get-Date).ToString('yyyyMMddTHHmmssZ')
    $archivePath = Join-Path $archiveRoot "results_archive_$ts.zip"
    Write-Host "Creating archive: $archivePath" -ForegroundColor Yellow
    $paths = $toRemove | Select-Object -ExpandProperty FullName
    try {
        Compress-Archive -Path $paths -DestinationPath $archivePath -Force
        Write-Host "Archive created: $archivePath" -ForegroundColor Green
    } catch {
        Write-Warning "Archive creation failed: $_"
    }
}

Confirm-Or-Exit "About to delete the listed items."

# Perform removals
$removed = 0
foreach ($item in $toRemove) {
    try {
        Remove-Item -LiteralPath $item.FullName -Force -Recurse -ErrorAction Stop
        Write-Host "Removed: $($item.FullName)" -ForegroundColor DarkGray
        $removed++
    } catch {
        Write-Warning "Failed to remove: $($item.FullName) => $($_.Exception.Message)"
    }
}

# Attempt to remove empty experiment directories
if ((Test-Path $exptsDir)) {
    Get-ChildItem -Path $exptsDir -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
        (Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0
    } | ForEach-Object {
        try { 
            Remove-Item -LiteralPath $_.FullName -Force -Recurse
            Write-Host "Removed empty dir: $($_.FullName)" -ForegroundColor DarkGray
        } catch { }
    }
}

Write-Host "Cleanup complete. Removed $removed items." -ForegroundColor Green
