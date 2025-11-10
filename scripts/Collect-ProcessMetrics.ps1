param(
    [Parameter(Mandatory=$true)]
    [int]$ProcessId,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPrefix,
    
    [int]$IntervalSeconds = 1
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-CpuTemperature {
    try {
        $temps = Get-WmiObject -Namespace "root\wmi" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($temps) {
            return ($temps | ForEach-Object { ($_.CurrentTemperature - 2732) / 10.0 } | Measure-Object -Average).Average
        }
    } catch {}
    return $null
}

function Get-ProcessSnapshot {
    param([int]$pid)
    try {
        $proc = Get-Process -Id $pid -ErrorAction Stop
        return @{
            CPU = $proc.CPU
            WorkingSet = $proc.WorkingSet64
            PrivateMemory = $proc.PrivateMemorySize64
            ThreadCount = $proc.Threads.Count
            HandleCount = $proc.HandleCount
        }
    } catch {
        return $null
    }
}

while ($true) {
    $alive = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $alive) {
        break
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $snapshot = Get-ProcessSnapshot -pid $ProcessId
    
    if ($snapshot) {
        $csvPath = "${OutputPrefix}.${timestamp}.proc.csv"
        $csvData = @"
timestamp,cpu_time_s,working_set_mb,private_mb,threads,handles
${timestamp},$($snapshot.CPU),$([math]::Round($snapshot.WorkingSet/1MB, 2)),$([math]::Round($snapshot.PrivateMemory/1MB, 2)),$($snapshot.ThreadCount),$($snapshot.HandleCount)
"@
        $csvData | Out-File -FilePath $csvPath -Encoding UTF8
        
        $temp = Get-CpuTemperature
        if ($temp) {
            $tempPath = "${OutputPrefix}.${timestamp}.temp.csv"
            $tempData = @"
timestamp,temp_C
${timestamp},$temp
"@
            $tempData | Out-File -FilePath $tempPath -Encoding UTF8
        }
    }
    
    Start-Sleep -Seconds $IntervalSeconds
}
