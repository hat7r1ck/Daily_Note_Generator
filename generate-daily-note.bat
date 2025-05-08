@ECHO OFF
SETLOCAL

REM Get the directory where this batch file is located
SET "BATCH_SCRIPT_DIR=%~dp0"

REM Define the name of the PowerShell script
SET "POWERSHELL_SCRIPT_NAME=Run-DailyNotes.ps1"
SET "POWERSHELL_SCRIPT_PATH=%BATCH_SCRIPT_DIR%%POWERSHELL_SCRIPT_NAME%"

ECHO Attempting to run PowerShell script:
ECHO "%POWERSHELL_SCRIPT_PATH%"
ECHO.

REM Call the PowerShell script.
REM The PowerShell script itself handles all path and date determination.
REM No arguments are passed from batch to the PS script, avoiding parsing issues.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%POWERSHELL_SCRIPT_PATH%"

REM The PAUSE below will be hit if PowerShell.exe fails to launch the script.
REM If the PowerShell script runs, its own ReadKey() at the end will keep its window open.
PAUSE
ENDLOCAL
