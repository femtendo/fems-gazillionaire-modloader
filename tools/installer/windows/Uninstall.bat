@echo off
REM Reverts Install.bat: restores your original Gazillionaire.swf.

NET SESSION >nul 2>&1
if %errorLevel% == 0 goto :run

echo Requesting administrator privileges (needed to write into Program Files)...
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b

:run
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%tools\installer\install.ps1" restore
echo.
echo Done.
pause
