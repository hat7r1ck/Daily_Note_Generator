@echo off
setlocal enabledelayedexpansion

REM Date Setup
for /f "tokens=2 delims==" %%I in ('"wmic os get LocalDateTime /value"') do set datetime=%%I
set year=%datetime:~0,4%
set month=%datetime:~4,2%
set day=%datetime:~6,2%
set today=%year%-%month%-%day%

REM Path Setup
set rootdir=%~dp0
set notes_root_dir=%rootdir%daily-notes
set template_path=%rootdir%daily-notes\templates\daily-note-template.md
set powershell_script_path=%rootdir%merge-incomplete-tasks.ps1

REM Ensure today's specific YYYY/MM directory exists (optional, PS script also does this)
if not exist "%notes_root_dir%\%year%\%month%" (
    echo Creating directory: %notes_root_dir%\%year%\%month%
    mkdir "%notes_root_dir%\%year%\%month%"
)

REM Echo Parameters for Debugging (Optional)
echo.
echo Calling PowerShell Script:
echo   Script Path: %powershell_script_path%
echo   Notes Root Dir (for -NotesDir): %notes_root_dir%
echo   Today's Date (for -Today): %today%
echo   Template Path (for -Template): %template_path%
echo.

REM PowerShell Call
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "& { & '%powershell_script_path%' -NotesDir '%notes_root_dir%' -Today '%today%' -Template '%template_path%' }"

PAUSE
