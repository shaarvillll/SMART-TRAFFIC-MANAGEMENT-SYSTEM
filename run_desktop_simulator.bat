@echo off
setlocal
cd /d "%~dp0traffic_simulation"
call run-map.bat
exit /b %ERRORLEVEL%
