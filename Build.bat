@echo off
title Leonida - Game Builder
rem Double-click to build. Finds your copy of the game, checks what's installed, and builds into
rem Documents\Leonida. Extra options pass through, e.g.  Build.bat --out D:\Games\Leonida
setlocal
cd /d "%~dp0"
echo.
echo  ==========================================
echo       L E O N I D A  -  Game Builder
echo  ==========================================
echo.
set "PY="
for %%V in (3.14 3.13 3.12 3) do (
  if not defined PY (
    py -%%V -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)" >nul 2>nul && set "PY=py -%%V"
  )
)
if not defined PY (
  where python >nul 2>nul && (
    python -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)" >nul 2>nul && set "PY=python"
  )
)
if not defined PY (
  echo Python 3.12 or newer is needed: https://www.python.org/downloads/
  echo Tick "Add python.exe to PATH" during setup, then run Build.bat again.
  pause
  exit /b 1
)
%PY% -I "%~dp0make_game.py" %*
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (echo Done.) else (echo The build stopped. Read the message above.)
pause
exit /b %RC%
