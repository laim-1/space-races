@echo off
setlocal

:: ── Space Races – Setup Script ──────────────────────────────────────────────
:: Double-click this file to clone the repo, check out the dev branch,
:: and open the Godot 4 project automatically.
:: ─────────────────────────────────────────────────────────────────────────────

set REPO_URL=https://github.com/laim-1/space-races.git
set BRANCH=claude/space-racers-development-wEyD0
set CLONE_DIR=%USERPROFILE%\Desktop\space-races

echo.
echo  ====================================
echo   SPACE RACES — Project Setup
echo  ====================================
echo.

:: ── 1. Check git is installed ────────────────────────────────────────────────
where git >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Git is not installed or not in PATH.
    echo  Download it from: https://git-scm.com/download/win
    pause
    exit /b 1
)

:: ── 2. Clone (skip if folder already exists) ─────────────────────────────────
if exist "%CLONE_DIR%\" (
    echo  Folder already exists: %CLONE_DIR%
    echo  Skipping clone — pulling latest changes instead...
    git -C "%CLONE_DIR%" fetch origin
) else (
    echo  Cloning repo to %CLONE_DIR% ...
    git clone "%REPO_URL%" "%CLONE_DIR%"
    if errorlevel 1 (
        echo  [ERROR] Clone failed. Check your internet connection.
        pause
        exit /b 1
    )
)

:: ── 3. Check out the dev branch ───────────────────────────────────────────────
echo  Checking out branch: %BRANCH%
git -C "%CLONE_DIR%" checkout "%BRANCH%"
if errorlevel 1 (
    echo  [ERROR] Could not check out branch %BRANCH%.
    pause
    exit /b 1
)

:: ── 4. Find Godot 4 and open the project ─────────────────────────────────────
echo.
echo  Looking for Godot 4...

:: Common install locations
set GODOT_EXE=
for %%P in (
    "%LOCALAPPDATA%\Programs\Godot\Godot_v4*.exe"
    "%PROGRAMFILES%\Godot\Godot_v4*.exe"
    "%PROGRAMFILES(X86)%\Godot\Godot_v4*.exe"
    "%USERPROFILE%\Downloads\Godot_v4*.exe"
    "%USERPROFILE%\Desktop\Godot_v4*.exe"
    "C:\Godot\Godot_v4*.exe"
) do (
    if not defined GODOT_EXE (
        for %%F in (%%P) do (
            if exist "%%F" set GODOT_EXE=%%F
        )
    )
)

if defined GODOT_EXE (
    echo  Found Godot: %GODOT_EXE%
    echo  Opening project...
    start "" "%GODOT_EXE%" --path "%CLONE_DIR%\godot"
) else (
    echo.
    echo  [WARNING] Could not find Godot 4 automatically.
    echo  Please open Godot manually and load the project from:
    echo    %CLONE_DIR%\godot
    echo.
    echo  Download Godot 4 from: https://godotengine.org/download
    explorer "%CLONE_DIR%\godot"
)

echo.
echo  Done! Project is at: %CLONE_DIR%\godot
echo.
pause
endlocal
