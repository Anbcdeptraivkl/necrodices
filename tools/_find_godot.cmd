@echo off
rem Sets GODOT_EXE to the Godot console binary this project targets (docs/tech.md).
rem Override: set GODOT=C:\path\to\Godot_v4.6.3-stable_win64_console.exe
set "GODOT_EXE="
set "GODOT_NAME=Godot_v4.6.3-stable_win64_console.exe"
if defined GODOT (
  if exist "%GODOT%" (
    set "GODOT_EXE=%GODOT%"
    goto :eof
  )
)
for %%D in ("%USERPROFILE%\Tools\Godot_v4.6.3-stable_win64" "%USERPROFILE%\Tools\Godot" "%LOCALAPPDATA%\Programs\Godot" "%ProgramFiles%\Godot" "C:\Godot") do (
  if not defined GODOT_EXE if exist "%%~D\%GODOT_NAME%" set "GODOT_EXE=%%~D\%GODOT_NAME%"
)
if defined GODOT_EXE goto :eof
for %%F in (%GODOT_NAME%) do set "GODOT_EXE=%%~$PATH:F"
if defined GODOT_EXE goto :eof
echo %GODOT_NAME% not found. Install it or set GODOT to its full path. 1>&2
exit /b 1
