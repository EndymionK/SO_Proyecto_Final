param(
    [string]$PythonExe = 'python',
    [string]$VenvPath = '.venv',
    [string]$Requirements = 'requirements.txt',
    [switch]$Force
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Resolve-Path (Join-Path $ScriptDir '..')
$VenvFull = Join-Path $RepoRoot $VenvPath
$ReqFull = Join-Path $RepoRoot $Requirements

Write-Host "Using python executable: $PythonExe"

$pythonCmd = Get-Command $PythonExe -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Error "Python executable '$PythonExe' not found in PATH. Install Python or provide path via -PythonExe."
    exit 2
}

if ((Test-Path $VenvFull) -and -not $Force) {
    Write-Host "Virtual environment already exists at $VenvFull. Use -Force to recreate or remove it first." 
    exit 0
}

Write-Host "Creating virtual environment at: $VenvFull"
& $PythonExe -m venv $VenvFull

$venvPython = Join-Path $VenvFull 'Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Error "Failed to create virtual environment or python not found at $venvPython"
    exit 3
}

Write-Host "Upgrading pip in venv"
& $venvPython -m pip install --upgrade pip

if (Test-Path $ReqFull) {
    Write-Host "Installing requirements from $ReqFull"
    & $venvPython -m pip install -r $ReqFull
} else {
    Write-Host "Requirements file not found at $ReqFull. You can create one as 'requirements.txt' at repo root."
}

Write-Host "Environment setup complete. Activate with: .\$VenvPath\Scripts\Activate.ps1"
