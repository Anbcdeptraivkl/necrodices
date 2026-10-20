@echo off
rem UI smoke tests in the real game context (autoloads loaded): tests\ui\ui_runner.tscn.
rem Fails on a FAIL line or a SCRIPT ERROR in the log.
setlocal
call "%~dp0_find_godot.cmd"
if errorlevel 1 exit /b 1
cd /d "%~dp0.."
set "LOG=%TEMP%\necrodices_ui_%RANDOM%.log"
"%GODOT_EXE%" --headless --path . res://tests/ui/ui_runner.tscn > "%LOG%" 2>&1
set CODE=%ERRORLEVEL%
findstr /V /B /C:"Godot Engine" "%LOG%"
findstr /C:"SCRIPT ERROR" "%LOG%" >nul
if not errorlevel 1 set CODE=1
del "%LOG%" 2>nul
if not %CODE%==0 (
  echo UI TESTS FAILED
  exit /b 1
)
echo UI TESTS PASSED
exit /b 0
