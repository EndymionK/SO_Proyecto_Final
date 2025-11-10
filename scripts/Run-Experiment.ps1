param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 2
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ResultsRaw = Join-Path $RepoRoot "results\raw"
$ResultsMeta = Join-Path $RepoRoot "results\meta"
$MinerExe = Join-Path $RepoRoot "build\miner.exe"
$CollectorScript = Join-Path $ScriptDir "Collect-ProcessMetrics.ps1"

if (-not (Test-Path $MinerExe)) {
    Write-Error "Miner executable not found: $MinerExe"
    exit 1
}

New-Item -ItemType Directory -Force -Path $ResultsRaw | Out-Null
New-Item -ItemType Directory -Force -Path $ResultsMeta | Out-Null

$config = Get-Content -Raw $ConfigPath | ConvertFrom-Json

$expId = $config.id
$mode = $config.mode
$difficulty = $config.difficulty
$threads = $config.threads
$affinity = $config.affinity
$reps = $config.repetitions
$timeout = $config.timeout
$seed = $config.seed

Write-Host "Running experiment: $expId" -ForegroundColor Cyan
Write-Host "  Mode: $mode, Difficulty: $difficulty, Threads: $threads, Reps: $reps" -ForegroundColor Gray

$env:PATH = "C:\msys64\mingw64\bin;$env:PATH"

for ($i = 1; $i -le $reps; $i++) {
    $timestamp = Get-Date -Format "yyyyMMddTHHmmssZ"
    $runId = "${expId}_run_${timestamp}_rep${i}"
    $outCsv = Join-Path $ResultsRaw "${runId}.csv"
    $outMeta = Join-Path $ResultsMeta "${runId}.meta.json"
    
    Write-Host "  Run $i/$reps -> $runId" -ForegroundColor Yellow
    
    $metaData = @{
        run_id = $runId
        experiment_id = $expId
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        system = @{
            hostname = $env:COMPUTERNAME
            user = $env:USERNAME
            os = (Get-CimInstance Win32_OperatingSystem).Caption
            cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
            cores = (Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfCores
            logical_processors = (Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfLogicalProcessors
            total_memory_gb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        }
        config = @{
            mode = $mode
            difficulty = $difficulty
            threads = $threads
            affinity = $affinity
            timeout = $timeout
            seed = $seed
        }
    }
    
    try {
        $gitCommit = git rev-parse --short HEAD 2>$null
        if ($gitCommit) {
            $metaData.git_commit = $gitCommit
        }
    } catch {}
    
    $metaData | ConvertTo-Json -Depth 10 | Out-File -FilePath $outMeta -Encoding UTF8
    
    $minerArgs = @(
        "--mode", $mode,
        "--difficulty", $difficulty,
        "--threads", $threads,
        "--seed", $seed,
        "--timeout", $timeout,
        "--metrics-out", $outCsv
    )
    
    if ($affinity -eq $true -or $affinity -eq "true") {
        $minerArgs += "--affinity", "true"
    }
    
    $minerProcess = Start-Process -FilePath $MinerExe -ArgumentList $minerArgs -NoNewWindow -PassThru
    $minerId = $minerProcess.Id
    
    $collectPrefix = Join-Path $ResultsRaw "${runId}.proc"
    
    $collectorJob = Start-Job -ScriptBlock {
        param($script, $processId, $prefix, $interval)
        & $script -ProcessId $processId -OutputPrefix $prefix -IntervalSeconds $interval
    } -ArgumentList $CollectorScript, $minerId, $collectPrefix, 1
    
    $minerProcess.WaitForExit()
    
    Start-Sleep -Milliseconds 500
    
    if ($collectorJob.State -eq 'Running') {
        Stop-Job -Job $collectorJob | Out-Null
    }
    Remove-Job -Job $collectorJob -Force | Out-Null
    
    $updatedMeta = Get-Content -Raw $outMeta | ConvertFrom-Json
    $updatedMeta | Add-Member -NotePropertyName "miner_pid" -NotePropertyValue $minerId -Force
    $updatedMeta | Add-Member -NotePropertyName "collect_prefix" -NotePropertyValue $collectPrefix -Force
    $updatedMeta | ConvertTo-Json -Depth 10 | Out-File -FilePath $outMeta -Encoding UTF8
    
    Start-Sleep -Seconds 1
}

Write-Host "Experiment $expId completed" -ForegroundColor Green
