# Windows build script to process Runner.rc template with environment variables
# Usage: .\configure_windows_build.ps1

$ErrorActionPreference = "Stop"

# Get environment variables with defaults
$APP_COMPANY = $env:APP_COMPANY
if (-not $APP_COMPANY) {
    $APP_COMPANY = "com.example"
    Write-Host "APP_COMPANY not set, using default: $APP_COMPANY"
} else {
    Write-Host "Using APP_COMPANY: $APP_COMPANY"
}

# Read template file
$templatePath = "$PSScriptRoot\Runner.rc.template"
$outputPath = "$PSScriptRoot\Runner.rc"

if (-not (Test-Path $templatePath)) {
    Write-Error "Template file not found: $templatePath"
    exit 1
}

Write-Host "Processing template: $templatePath"
$content = Get-Content $templatePath -Raw

# Replace environment variable placeholders
$content = $content -replace '\$\{APP_COMPANY\}', $APP_COMPANY

# Write the processed content to Runner.rc
$content | Set-Content $outputPath -NoNewline

Write-Host "Generated: $outputPath"
Write-Host "Windows resource file configured with:"
Write-Host "  APP_COMPANY: $APP_COMPANY"
