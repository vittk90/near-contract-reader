@echo off
rem usage: read-contract.bat <contract.near> [pages]
setlocal
set C=%1
set P=%2
if "%C%"=="" (
  echo usage: read-contract.bat ^<contract.near^> [pages]
  exit /b 1
)
if "%P%"=="" set P=2
powershell -ExecutionPolicy Bypass -File "%~dp0near-contract-reader.ps1" -Contract %C% -Pages %P%
