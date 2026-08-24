<#
  run.ps1
  Enhanced script to automate cloning/updating the repository and running a .NET project.

  Features added per request:
  - Pre-filled project path
  - Option to skip cloning or run a local project only
  - Optional npm steps (install/build) before running dotnet
  - Optional background execution for dotnet run
  - Enhanced logging to a run.log file

  Usage examples:
    # Default: clone/update repo, find .csproj inside pre-filled project path and run it
    .\run.ps1

    # Run a local project only (no cloning) and run npm steps before dotnet
    .\run.ps1 -LocalOnly -Project "C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital" -RunNpm -NpmInstall -NpmBuild "npm run compile"

    # Clone/update repo but skip cloning step explicitly
    .\run.ps1 -SkipClone

    # Run dotnet in the background
    .\run.ps1 -Background

    # Enable logging to run.log
    .\run.ps1 -EnableLogging

    # Full example: clone, run npm install+build, run dotnet in background and enable logging
    .\run.ps1 -RunNpm -NpmInstall -NpmBuild "npm run compile" -Background -EnableLogging
#>

param(
    [string]$Destination = "$env:USERPROFILE\source\repos\vscode-dotnet-runtime",
    [string]$Project = 'C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital',
    [switch]$SkipClone,
    [switch]$LocalOnly,
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

Log "Starting run.ps1 (Project=$Project, Destination=$Destination)"

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
    if ((Get-Item $Project).PSIsContainer) {
        Set-Location $Project
    } else {
        Set-Location (Split-Path -Path $Project -Parent)
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

# If Project points to a csproj inside the cloned repo, it may be a full path; use it
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
    # Determine npm working directory: prefer the csproj's directory if the node project lives alongside, otherwise repo root
    $npmDir = Split-Path -Path $csprojPath -Parent
    if (-not (Test-Path (Join-Path $npmDir 'package.json'))) {
        # fallback to repo root
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
        # Split the build string to command and args for Start-Process
        $buildParts = $NpmBuild -split ' '
        $cmd = $buildParts[0]
        $args = $buildParts[1..($buildParts.Length-1)] -join ' '
        if ($cmd -eq 'npm') {
            npm $args
            if ($LASTEXITCODE -ne 0) { Log "npm build failed with code $LASTEXITCODE"; Pop-Location; exit $LASTEXITCODE }
        } else {
            # run generic command
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
    exit 0
} else {
    Log "Running foreground: dotnet $dotnetArgs"
    & dotnet run --project "$csprojPath"
    $rc = $LASTEXITCODE
    Log "dotnet finished with exit code $rc"
    exit $rc
}
