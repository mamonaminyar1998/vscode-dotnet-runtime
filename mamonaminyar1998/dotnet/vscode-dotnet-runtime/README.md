# vscode-dotnet-runtime

TL;DR: VS Code helper repository for acquiring and managing .NET runtimes and SDKs. This README explains how to clone, run, and test the project from your account using PowerShell (ps).

## Problem
This repository provides logic and VS Code extensions to automate .NET runtime and SDK acquisition so other extensions and tools can reliably get the correct .NET environment.

## Run on your account (PowerShell)
These steps assume you're on Windows and using PowerShell (pwsh or Windows PowerShell). They also work on macOS/Linux if you run the Bash variants shown later.

1. Open PowerShell.
2. Clone the repository into your account's workspace:

```powershell
# replace <your-folder> with where you want the repo
git clone https://github.com/mamonaminyar1998/vscode-dotnet-runtime.git "C:\Users\$env:USERNAME\source\repos\vscode-dotnet-runtime"
cd "C:\Users\$env:USERNAME\source\repos\vscode-dotnet-runtime"
```

3. If the project contains a sample .NET project, run it with dotnet (PowerShell):

```powershell
# Example: run a sample project located at src/ExampleProject
dotnet run --project src/ExampleProject
```

4. If the repository is the VS Code extension (Node/TypeScript based) and you need to build and run the extension locally:

```powershell
# from repo root
# install dependencies
npm ci
# compile TypeScript (if present)
npm run compile
# open in VS Code and run the "Launch Extension" debug target
code .
```

5. To run tests (PowerShell):

```powershell
# unit tests (example path)
cd vscode-dotnet-runtime-library
npm ci
npm run unit-test
```

## Run using PowerShell Core (cross-platform)
If you use PowerShell Core (pwsh) on macOS/Linux, use the same commands after installing Git and the .NET SDK.

## Bash (Linux/macOS) equivalent
```bash
git clone https://github.com/mamonaminyar1998/vscode-dotnet-runtime.git
cd vscode-dotnet-runtime
# run a sample dotnet project
dotnet run --project src/ExampleProject
```

## Notes
- Replace `src/ExampleProject` with the actual path to a runnable .NET project in this repository. If you're not sure which folder contains a .NET project, search for a `*.csproj` file.
- Ensure you have the .NET SDK installed that matches the project's TargetFramework. Use `dotnet --list-sdks` to check installed SDKs.
- If you want me to add a specific PowerShell script (e.g., `run.ps1`) to automate these steps in the repo, say "add run.ps1" and I'll create it and commit it for you.

---

If this is what you meant, I've added this README at `mamonaminyar1998/dotnet/vscode-dotnet-runtime/README.md` in your repository to describe how to run the project from your account using PowerShell. If you'd like me to also add a `run.ps1` script that automates cloning and running the sample, I can create it next.
