@echo off
rem Entry point for dsh-whale-persona releases.
rem Bypasses the Windows script execution policy for this one file and forwards all args
rem to release.ps1 (PowerShell 5.1 or PowerShell 7, whichever is installed).
rem
rem Usage:
rem   release.cmd                    repack the current version
rem   release.cmd -Bump patch        bump the version, then repack
rem   release.cmd -GithubUser name   fill in the YOUR_GITHUB_USER placeholder
setlocal
set "PS=powershell"
where pwsh >nul 2>nul && set "PS=pwsh"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0release.ps1" %*
endlocal
