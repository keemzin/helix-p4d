@echo off
setlocal enableextensions

rem --------------------------------------------------------------------------------
rem Windows build script for the native Ubuntu Perforce Helix P4D server image
rem --------------------------------------------------------------------------------
rem
rem Usage:
rem   build.bat [name:tag]
rem
rem Examples:
rem   build.bat
rem   build.bat helix-p4d:latest
rem   build.bat my-p4d:2025.1
rem

set "tag=%~1"
if "%tag%"=="" set "tag=johnsdoes/helix-p4d:2026.1"

set "platform=linux/amd64"

docker build -t "%tag%" --platform %platform% .

if %errorlevel% equ 0 (
    echo.
    echo Image built: %tag%
) else (
    echo.
    echo Build failed (exit code %errorlevel%)
    exit /b %errorlevel%
)

endlocal
