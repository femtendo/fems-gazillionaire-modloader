@echo off
REM Double-click installer: patches your local Steam copy of Gazillionaire.
REM Plain batch + PowerShell, no compiled binary - unlike a packaged .exe,
REM this has nothing for antivirus/Drive heuristics to flag as a false
REM positive. See ../install.ps1 for the actual install/restore logic.

NET SESSION >nul 2>&1
if %errorLevel% == 0 goto :run

echo Requesting administrator privileges (needed to write into Program Files)...
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b

:run
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%tools\installer\install.ps1" install
echo.
echo Done. Launch Gazillionaire from Steam and look for the blue "Play Online"
echo button in the top-left corner to host or join a networked game.
pause
