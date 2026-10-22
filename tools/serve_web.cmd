@echo off
rem Serves the Web export locally (browsers block fetch() of .wasm/.pck from file://).
rem Usage: tools\serve_web.cmd [port]   -> http://127.0.0.1:8060/  (Ctrl+C to stop)
setlocal
set "PORT=%~1"
if "%PORT%"=="" set "PORT=8060"
cd /d "%~dp0.."
if not exist build\web\index.html (
  echo build\web\index.html not found: run tools\export_web.cmd first. 1>&2
  exit /b 1
)
start "" "http://127.0.0.1:%PORT%/"
python -m http.server %PORT% --bind 127.0.0.1 --directory build\web
