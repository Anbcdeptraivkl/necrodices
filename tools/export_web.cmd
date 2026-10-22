@echo off
rem Web (HTML5) release export for itch.io (DECISIONS D-A10): single-threaded, Compatibility,
rem index.html at the zip root. Needs the Godot 4.6.3 export templates installed
rem (Editor > Manage Export Templates, or %APPDATA%\Godot\export_templates\4.6.3.stable).
rem Output: build\web\ and build\roll_the_bones_web.zip
setlocal
call "%~dp0_find_godot.cmd"
if errorlevel 1 exit /b 1
cd /d "%~dp0.."
if not exist "%APPDATA%\Godot\export_templates\4.6.3.stable\web_nothreads_release.zip" (
  echo Missing export templates for 4.6.3: install them first. 1>&2
  exit /b 1
)
if exist build\web rmdir /s /q build\web
mkdir build\web
"%GODOT_EXE%" --headless --path . --export-release "Web" build/web/index.html
if errorlevel 1 exit /b 1
powershell -NoProfile -Command "Compress-Archive -Path build/web/* -DestinationPath build/roll_the_bones_web.zip -Force"
echo Exported build\web and build\roll_the_bones_web.zip
