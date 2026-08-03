@echo off
setlocal
set "CP_TEMPLATE_LANGUAGE=java"
set "CP_TEMPLATE_TOOL_NAME=templatejava"
set "template_cli=%~dp0commands\template_cli.py"
if not exist "%template_cli%" set "template_cli=%~dp0..\commands\template_cli.py"
python "%template_cli%" %*
set "exit_code=%ERRORLEVEL%"
endlocal & exit /b %exit_code%
