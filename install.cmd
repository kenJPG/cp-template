@echo off
:: ============================================================================
:: install.cmd - double-clickable launcher for install.ps1
:: ============================================================================
:: Why this exists: double-clicking a .ps1 opens it in Notepad (Windows ships
:: that association on purpose, as a security default), and right-click >
:: "Run with PowerShell" doesn't elevate - install.ps1 has
:: #Requires -RunAsAdministrator, so it would just error out.
::
:: This wrapper re-launches install.ps1 in an elevated PowerShell (you'll get
:: the normal UAC prompt) and keeps that window open afterwards (-NoExit) so
:: you can read the install log.
::
:: %~dp0 = the directory this .cmd lives in, so it works no matter where the
:: repo is cloned or which directory you double-click from.
:: ============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File ""%~dp0install.ps1""'"
