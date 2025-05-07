@echo off
setlocal enabledelayedexpansion

for /f "tokens=2 delims==" %%I in ('"wmic os get LocalDateTime /value"') do set datetime=%%I
set year=%datetime:~0,4%
set month=%datetime:~4,2%
set day=%datetime:~6,2%
set today=%year%-%month%-%day%

set rootdir=%~dp0
set notesdir=%rootdir%daily-notes\%year%\%month%
set templatepath=%rootdir%daily-notes\templates\daily-note-template.md
set notepath=%notesdir%\%today%.md

if not exist "%notesdir%" (
    mkdir "%notesdir%"
)

powershell -ExecutionPolicy Bypass -File "%rootdir%merge-incomplete-tasks.ps1" -NotesDir "%notesdir%" -Today "%today%" -Template "%templatepath%"