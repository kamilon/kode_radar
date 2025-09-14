@echo off
REM Windows build script to process Runner.rc template with environment variables
REM Usage: configure_windows_build.bat

setlocal EnableDelayedExpansion

REM Get environment variables with defaults
if "%APP_COMPANY%"=="" (
    set "APP_COMPANY=com.example"
    echo APP_COMPANY not set, using default: !APP_COMPANY!
) else (
    echo Using APP_COMPANY: %APP_COMPANY%
)

REM Set file paths
set "TEMPLATE_PATH=%~dp0Runner.rc.template"
set "OUTPUT_PATH=%~dp0Runner.rc"

REM Check if template exists
if not exist "%TEMPLATE_PATH%" (
    echo Error: Template file not found: %TEMPLATE_PATH%
    exit /b 1
)

echo Processing template: %TEMPLATE_PATH%

REM Process template and replace placeholders
powershell -Command "(Get-Content '%TEMPLATE_PATH%' -Raw) -replace '\$\{APP_COMPANY\}', '%APP_COMPANY%' | Set-Content '%OUTPUT_PATH%' -NoNewline"

if %ERRORLEVEL% neq 0 (
    echo Error: Failed to process template
    exit /b 1
)

echo Generated: %OUTPUT_PATH%
echo Windows resource file configured with:
echo   APP_COMPANY: %APP_COMPANY%
