<#
  run.ps1
  Local-first script to run a .NET project with optional npm steps, background execution, and timestamped log rotation.

  Changes made:
  - Default to LocalOnly mode (do not clone the remote repo by default)
  - Default Destination and Project set to your project folder
  - Timestamped log rotation: existing run.log is archived to run-YYYYMMDD-HHMMSS.log at start
  - Retains npm, background, and logging features

  Usage examples (all copy/paste):
    # Default (local-only): run project in C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital
    .\run.ps1

    # Explicit local-only with csproj file
    .\run.ps1 -LocalOnly -Project "C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital\YourApp\YourApp.csproj"

    # Run npm install + build then run dotnet in foreground
    .\run.ps1 -RunNpm -NpmInstall -NpmBuild "npm run compile"

    # Run dotnet in background and enable logging (log will rotate with timestamp)
    .\run.ps1 -Background -EnableLogging

    # Check rotated logs: Get-ChildItem -Path "C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital\run-*.log"
#>

param(
    [string]$Destination = 'C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital',
    [string]$Project = 'C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital',
    [switch]$SkipClone,
    [switch]$LocalOnly = $true,
    [switch]$EnableLogging,
    [switch]$Background,
    [switch]$RunNpm,
    [switch]$NpmInstall,
    [string]$NpmBuild = 'npm run compile'
)

$repoUrl = 'https://github.com/mamonaminyar1998/vscode-dotnet-runtime.git'
$logFile = Join-Path -Path $Destination -ChildPath 'run.log'

function Log {
    param([string]$message)
    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$time] $message"
    if ($EnableLogging) {
        try {
            $dir = Split-Path -Path $logFile -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Add-Content -Path $logFile -Value $line
        } catch {
            Write-Warning "Failed to write log: $_"
        }
    }
    Write-Host $line
}

function Rotate-Log {
    param([string]$filePath)
    if (-not (Test-Path $filePath)) { return }
    try {
        $info = Get-Item $filePath
        if ($info.Length -gt 0) {
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            $archived = Join-Path -Path ($info.DirectoryName) -ChildPath ("run-$ts.log")
            Move-Item -Path $filePath -Destination $archived -Force
            Write-Host "Rotated log to $archived"
        } else {
            # empty file => just remove it
            Remove-Item -Path $filePath -Force
        }
    } catch {
        Write-Warning "Log rotation failed: $_"
    }
}

Log "Starting run.ps1 (LocalOnly=$LocalOnly, Project=$Project, Destination=$Destination)"

if ($EnableLogging) {
    Rotate-Log -filePath $logFile
}

if (-not $LocalOnly) {
    if (-not $SkipClone) {
        if (-not (Test-Path $Destination)) {
            Log "Cloning repository to $Destination..."
            git clone $repoUrl $Destination
            if ($LASTEXITCODE -ne 0) {
                Log "git clone failed with exit code $LASTEXITCODE"
                exit $LASTEXITCODE
            }
        } else {
            Log "Repository exists at $Destination. Fetching latest changes..."
            try {
                Push-Location $Destination
                git fetch --all
                git pull --rebase
                Pop-Location
            } catch {
                Log "Failed to update repository: $_"
            }
        }
    } else {
        Log "Skipping clone/update as requested (SkipClone)."
    }

    Set-Location $Destination
} else {
    # LocalOnly: run directly against the Project path
    if (-not (Test-Path $Project)) {
        Log "LocalOnly mode but specified project path not found: $Project"
        exit 1
    }
    # If Project is a file, set location to its parent; if directory use it
    $projItem = Get-Item $Project
    if ($projItem.PSIsContainer) {
        Set-Location $projItem.FullName
    } else {
        Set-Location (Split-Path -Path $projItem.FullName -Parent)
    }
    Log "LocalOnly mode: working directory set to $(Get-Location)"
}

function Find-CsProj {
    param([string]$path)

    if ([string]::IsNullOrWhiteSpace($path)) {
        $cs = Get-ChildItem -Path . -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
        return $cs
    }

    if (Test-Path $path) {
        $full = Resolve-Path -Path $path
        $item = Get-Item $full
        if ($item.PSIsContainer) {
            $cs = Get-ChildItem -Path $item.FullName -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
            return $cs
        } else {
            if ($full -like "*.csproj") {
                return Get-Item $full
            } else {
                Log "Specified file exists but is not a .csproj: $full"
                return $null
            }
        }
    } else {
        Log "Specified project path not found: $path"
        return $null
    }
}

$csproj = Find-CsProj -path $Project

if ($null -eq $csproj) {
    Log "No .csproj found for path: $Project"
    Log "Listing candidate .csproj files to help you choose..."
    Get-ChildItem -Path . -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
    Log "If this repository is a VS Code extension (Node/TypeScript), you can run npm steps instead."
    exit 1
}

$csprojPath = $csproj.FullName
Log "Found project: $csprojPath"

# Optionally run npm steps before dotnet
if ($RunNpm) {
    $npmDir = Split-Path -Path $csprojPath -Parent
    if (-not (Test-Path (Join-Path $npmDir 'package.json'))) {
        $npmDir = Get-Location
    }

    Push-Location $npmDir
    Log "Running npm steps in $npmDir"
    if ($NpmInstall) {
        Log "Running npm ci..."
        npm ci
        if ($LASTEXITCODE -ne 0) { Log "npm ci failed with code $LASTEXITCODE"; Pop-Location; exit $LASTEXITCODE }
    }

    if (-not [string]::IsNullOrWhiteSpace($NpmBuild)) {
        Log "Running build command: $NpmBuild"
        $buildParts = $NpmBuild -split ' '
        $cmd = $buildParts[0]
        $args = $buildParts[1..($buildParts.Length-1)] -join ' '
        if ($cmd -eq 'npm') {
            npm $args
            if ($LASTEXITCODE -ne 0) { Log "npm build failed with code $LASTEXITCODE"; Pop-Location; exit $LASTEXITCODE }
        } else {
            & $cmd $args
            if ($LASTEXITCODE -ne 0) { Log "build command failed with code $LASTEXITCODE"; Pop-Location; exit $LASTEXITCODE }
        }
    }
    Pop-Location
}

# Run dotnet either foreground or background
$dotnetArgs = "run --project `"$csprojPath`""
if ($Background) {
    Log "Starting dotnet in background: dotnet $dotnetArgs"
    $proc = Start-Process -FilePath 'dotnet' -ArgumentList $dotnetArgs -PassThru -WindowStyle Hidden
    Log "Background process started. PID: $($proc.Id)"
    if ($EnableLogging) { Log "Background process logging to $logFile" }
    exit 0
} else {
    Log "Running foreground: dotnet $dotnetArgs"
    & dotnet run --project "$csprojPath"
    $rc = $LASTEXITCODE
    Log "dotnet finished with exit code $rc"
    exit $rc
}
