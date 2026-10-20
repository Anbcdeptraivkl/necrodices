@echo off
rem Runs the game windowed (540x960) with the console build. Extra args go to Godot.
call "%~dp0_find_godot.cmd"
if errorlevel 1 exit /b 1
cd /d "%~dp0.."
"%GODOT_EXE%" --path . %*
