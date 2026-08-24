<#
  run.ps1
  Automates cloning (or updating) the repository and running a .NET project inside it.

  Usage examples:
    # Clone into default destination and run the first found .csproj
    .\run.ps1

    # Specify destination and project (csproj path or directory containing csproj)
    .\run.ps1 -Destination "C:\me\repos\vscode-dotnet-runtime" -Project "C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital"

    # Specify a csproj file directly
    .\run.ps1 -Project "src/ExampleProject/ExampleProject.csproj"
#>

param(
    [string]$Destination = "$env:USERPROFILE\source\repos\vscode-dotnet-runtime",
    # Pre-filled with the project path you provided. You can override with -Project.
    [string]$Project = 'C:\AIBAK-SMART-HOSPITAL\ayback_10bed_surgery_hospital'
)

$repoUrl = 'https://github.com/mamonaminyar1998/vscode-dotnet-runtime.git'

Write-Host "Destination: $Destination" -ForegroundColor Cyan

if (-not (Test-Path $Destination)) {
    Write-Host "Cloning repository to $Destination..." -ForegroundColor Green
    git clone $repoUrl $Destination
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git clone failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} else {
    Write-Host "Repository already exists at $Destination. Fetching latest changes..." -ForegroundColor Yellow
    try {
        Push-Location $Destination
        git fetch --all
        git pull --rebase
        Pop-Location
    } catch {
        Write-Warning "Failed to update repository: $_"
    }
}

Set-Location $Destination

function Find-CsProj {
    param([string]$path)

    if ([string]::IsNullOrWhiteSpace($path)) {
        # find first csproj in the repo
        $cs = Get-ChildItem -Path . -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
        return $cs
    }

    # If user provided a path
    if (Test-Path $path) {
        $full = Resolve-Path -Path $path
        if ((Get-Item $full).PSIsContainer) {
            # search for csproj inside directory
            $cs = Get-ChildItem -Path $full -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
            return $cs
        } else {
            # assume it's a file
            if ($full -like "*.csproj") {
                return Get-Item $full
            } else {
                Write-Warning "Specified file exists but is not a .csproj: $full"
                return $null
            }
        }
    } else {
        Write-Warning "Specified project path not found: $path"
        return $null
    }
}

$csproj = Find-CsProj -path $Project

if ($null -ne $csproj) {
    $csprojPath = $csproj.FullName
    Write-Host "Found project: $csprojPath" -ForegroundColor Green
    Write-Host "Running: dotnet run --project `"$csprojPath`"" -ForegroundColor Cyan
    dotnet run --project "$csprojPath"
    exit $LASTEXITCODE
} else {
    Write-Warning "No .csproj found. Listing top-level .csproj files to help you choose..."
    Get-ChildItem -Path . -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
    Write-Host "\nIf this repository is a VS Code extension (Node/TS), you can instead run the Node build steps:" -ForegroundColor Yellow
    Write-Host "  npm ci`n  npm run compile`n  code . (then use Run Extension debug target)"
    exit 1
}
