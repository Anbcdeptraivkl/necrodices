@echo off
rem Runs the headless test suites (tests\test_*.gd) in one process through tests\_run.gd,
rem printing PASS / FAIL per case with its time.
rem Usage: tools\test.cmd                            re-import, then every suite
rem        tools\test.cmd --changed                  suites covering files changed against HEAD
rem        tools\test.cmd --since=main               ... or changed since a ref
rem        tools\test.cmd battle_sim unit_anim:smear  chosen suites, or cases by name part
rem        tools\test.cmd --list [suites]            list suites and cases, run nothing
rem        add --import to any of these to re-import first (new class_name, new or edited assets)
rem A run fails on a failed case or on a SCRIPT ERROR in the log.
setlocal EnableDelayedExpansion
call "%~dp0_find_godot.cmd"
if errorlevel 1 exit /b 1
cd /d "%~dp0.."
set "LOG=%TEMP%\necrodices_test_%RANDOM%.log"
set "ARGS="
set "IMPORT=0"
if "%~1"=="" set "IMPORT=1"
for %%A in (%*) do (
  if /I "%%~A"=="--import" (set "IMPORT=1") else (set "ARGS=!ARGS! %%~A")
)
if %IMPORT%==1 (
  echo == import
  "%GODOT_EXE%" --headless --path . --import > "%LOG%" 2>&1
  if errorlevel 1 (
    type "%LOG%"
    echo IMPORT FAILED
    exit /b 1
  )
)
"%GODOT_EXE%" --headless --path . --script res://tests/_run.gd -- %ARGS% > "%LOG%" 2>&1
set CODE=%ERRORLEVEL%
findstr /V /B /C:"Godot Engine" "%LOG%"
findstr /C:"SCRIPT ERROR" "%LOG%" >nul
if not errorlevel 1 set CODE=1
del "%LOG%" 2>nul
if not %CODE%==0 (
  echo TESTS FAILED
  exit /b 1
)
echo TESTS PASSED
exit /b 0
