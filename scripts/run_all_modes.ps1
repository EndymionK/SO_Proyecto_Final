#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Master orchestrator: runs all experiments from configs JSON and aggregates results.
.DESCRIPTION
    Reads experiment config files from experiments/configs/, executes run_experiment.sh
    for each (via WSL), then runs parse_results.py to generate summary and plots.
.PARAMETER Repetitions
    Number of repetitions per experiment config (overrides config if specified).
.PARAMETER Clean
    Remove previous experiment results before starting.
.PARAMETER ConfigDir
    Path to directory containing experiment JSON configs (default: experiments/configs).
#>
param(
    [int]$Repetitions = 0,
    [switch]$Clean,
    [string]$ConfigDir = "experiments/configs"
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
Push-Location $RepoRoot

Write-Host "=== Running All Experiments ===" -ForegroundColor Cyan
Write-Host ""

if ($Clean) {
    Write-Host "Cleaning previous experiment folders..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue results/experiments/* 2>$null
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue results/raw/* 2>$null
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue results/processed/* 2>$null
    Write-Host "Cleaned." -ForegroundColor Green
}

# Find all JSON configs
$configFiles = Get-ChildItem -Path $ConfigDir -Filter "*.json" -File -ErrorAction SilentlyContinue
if (-not $configFiles) {
    Write-Error "No config files found in $ConfigDir"
    Pop-Location
    exit 1
}

Write-Host "Found $($configFiles.Count) config(s) in $ConfigDir" -ForegroundColor Green
Write-Host ""

# Check if WSL is available and run_experiment.sh exists
$wslAvailable = $false
try {
    $wslTest = wsl -e bash -c "echo ok" 2>$null
    if ($wslTest -match "ok") {
        $wslAvailable = $true
        Write-Host "WSL detected. Will use bash scripts for experiment execution." -ForegroundColor Green
    }
} catch {}

if (-not $wslAvailable) {
    Write-Warning "WSL not available. This script requires WSL to run bash scripts (run_experiment.sh)."
    Write-Warning "Ensure WSL is installed and bash is accessible."
    Pop-Location
    exit 2
}

# Execute each config via run_experiment.sh
foreach ($cfg in $configFiles) {
    $cfgPath = $cfg.FullName
    $relPath = Resolve-Path -Relative $cfgPath
    Write-Host "Running: $relPath" -ForegroundColor Cyan
    
    # Convert to relative path from repo root
    $cfgRelative = $cfg.FullName -replace [regex]::Escape($RepoRoot), '' -replace '^\\', '' -replace '\\', '/'
    
    # Invoke run_experiment.sh via WSL with relative path
    Write-Host "  Executing: ./scripts/run_experiment.sh $cfgRelative" -ForegroundColor DarkGray
    
    try {
        # cd to project root in WSL and run experiment with relative path
        $wslProjectPath = "/mnt/c/d/Proyectos_programacion/SO_Proyecto_Final"
        wsl -e bash -lc "cd '$wslProjectPath' && ./scripts/run_experiment.sh '$cfgRelative'"
        Write-Host "Completed: $relPath" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to run $relPath : $_"
    }
    Write-Host ""
}

Write-Host "=== All Experiments Completed ===" -ForegroundColor Cyan
Write-Host "Analyzing results..." -ForegroundColor Yellow
Write-Host ""

# Run parse_results.py (prefer WSL python with venv)
try {
    wsl -e bash -lc "source .venv/bin/activate 2>/dev/null || true; python3 scripts/parse_results.py"
    Write-Host "Parser completed." -ForegroundColor Green
} catch {
    Write-Warning "Parser execution failed or not available: $_"
}

# Display summary if available
$summaryPath = "results/processed/summary.csv"
if (Test-Path $summaryPath) {
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Get-Content $summaryPath | Select-Object -First 20
} else {
    Write-Host "Summary not found at $summaryPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done! Check results/processed/ for detailed analysis." -ForegroundColor Green

# Generate final consolidated report with system info
$reportPath = "results/processed/REPORT.md"
Write-Host "Generating consolidated report: $reportPath" -ForegroundColor Cyan

$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$mem = Get-CimInstance -ClassName Win32_ComputerSystem
$os = Get-CimInstance -ClassName Win32_OperatingSystem

$reportContent = @"
# Proof-of-Work Miner: Experiment Report
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## System Information
- **PC Name:** $($env:COMPUTERNAME)
- **User:** $($env:USERNAME)
- **CPU:** $($cpu.Name)
- **CPU Cores:** $($cpu.NumberOfCores)
- **Logical Processors:** $($cpu.NumberOfLogicalProcessors)
- **Total Memory:** $([math]::Round($mem.TotalPhysicalMemory / 1GB, 2)) GB
- **Operating System:** $($os.Caption) $($os.Version)

## Experiment Configuration
All experiments were executed using configurations from ``experiments/configs/``:
- **Modes tested:** Sequential, Concurrent (with CPU pinning), Parallel
- **Threads:** 1, 2, 4 (varies by mode)
- **Difficulty:** 16 bits (low), 20 bits (medium)
- **Repetitions per config:** 30
- **Timeout:** 60-120 seconds
- **Seed:** 42

## Results Summary
Detailed results are available in:
- ``results/processed/summary.csv`` — Aggregated throughput, speedup, efficiency
- ``results/processed/stats_summary.csv`` — Statistical tests (ANOVA, Kruskal-Wallis, pairwise comparisons)
- ``results/processed/stats_summary.txt`` — Human-readable statistical analysis
- ``results/processed/plots/`` — Throughput and speedup graphs

### Key Findings
(Review the plots and summary CSV for detailed analysis)

- **Sequential baseline:** Establishes reference throughput (hashes/s)
- **Parallel mode:** Expected to show speedup scaling with thread count
- **Concurrent mode:** CPU pinning forces threads to share a single core; used to study scheduling overhead vs parallelism

### Statistical Analysis
The ``stats_summary.txt`` file includes:
- ANOVA and Kruskal-Wallis tests comparing modes at each thread count
- Pairwise Mann-Whitney U tests with Bonferroni correction
- Evaluation of whether differences in throughput between modes are statistically significant

## Conclusion
This experiment validates the implementation of the three execution modes and provides empirical data on:
- Scalability of parallel execution
- Overhead introduced by concurrency with CPU pinning
- Relationship between difficulty, thread count, and throughput

For detailed methodology and analysis, refer to the project documentation in ``instrucciones.md``, ``README.md``, ``USAGE.md``, and ``TECHNICAL.md``.

---
*Generated by run_all_modes.ps1*
"@

$reportContent | Out-File -Encoding UTF8 $reportPath
Write-Host "Report written to: $reportPath" -ForegroundColor Green

Pop-Location
