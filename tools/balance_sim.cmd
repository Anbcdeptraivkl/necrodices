@echo off
rem Headless balance simulation. Usage:
rem   tools\balance_sim.cmd --mode=baseline --trials=20000
rem   tools\balance_sim.cmd --mode=runs --trials=1000
call "%~dp0_find_godot.cmd"
if errorlevel 1 exit /b 1
cd /d "%~dp0.."
"%GODOT_EXE%" --headless --path . --script res://tools/balance_sim.gd -- %*
