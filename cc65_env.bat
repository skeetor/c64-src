@echo off

set CC65_HOME=%~dp0

if exist %CC65_HOME%cc65_env_user.bat (
   call %CC65_HOME%cc65_env_user.bat
) else (
    echo cc65_env_user.bat not found in local or parent director!
    exit /B 1
)

set PATH=%PATH%;%CC65_HOME%\bin

echo Home: %CC65_HOME%
