@echo off
rem Captures a preset state to a PNG (scenes\dev\capture.gd PRESETS). Opens a window briefly.
rem Usage: tools\screenshot.cmd <preset> <out.png> [WxH] [--wait=<s>]
rem Extra --key=value arguments go through %* (raw), because cmd splits %1..%9 at '='.
call "%~dp0_find_godot.cmd"
if errorlevel 1 exit /b 1
cd /d "%~dp0.."
set "RES=%~3"
if "%RES%"=="" set "RES=960x540"
"%GODOT_EXE%" --path . --resolution %RES% res://scenes/dev/capture.tscn -- --preset=%~1 --out=%~2 %*
