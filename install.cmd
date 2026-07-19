@echo off
:: ============================================================================
:: install.cmd - double-clickable launcher for install.ps1
:: ============================================================================
:: Why this exists: double-clicking a .ps1 opens it in Notepad (Windows ships
:: that association on purpose, as a security default), and right-click >
:: "Run with PowerShell" doesn't elevate - install.ps1 has
:: #Requires -RunAsAdministrator, so it would just error out.
::
:: This wrapper runs machine setup elevated, then returns to the normal user
:: before installing plugins. Plugin code must never run with Administrator rights.
::
:: %~dp0 = the directory this .cmd lives in, so it works no matter where the
:: repo is cloned or which directory you double-click from.
:: ============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0install.ps1""'; exit $p.ExitCode"
if errorlevel 1 goto :failed

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1"
if errorlevel 1 goto :failed

echo.
echo Setup completed successfully. Press any key to close.
pause >nul
exit /b 0

:failed
echo.
echo Setup failed. Review the errors above, then re-run install.cmd.
pause
exit /b 1
