@echo off
setlocal EnableDelayedExpansion

if not exist "obj" mkdir obj
if not exist "bin" mkdir bin

set C1541_PATH=e:\Programme\VICE-Win-3.1-x64\
set "BUILD_128="
set "BUILD_64="
set "BUILD_TARGET="
set PROJECT_NAME=spreddi
set DISK_NAME=%PROJECT_NAME%

del /F /Q obj\*.* > NUL 2>&1
del /F /Q bin\%PROJECT_NAME%*.* > NUL 2>&1

set BUILD_TARGET=%1
if "%1" == "" goto no_params
goto main

:no_params
set BUILD_128=True
set BUILD_64=True
goto build_src

:main 
if "%BUILD_TARGET%" == "c128" (
set BUILD_128=True
set BUILD_64=False
goto build_src
)

if "%BUILD_TARGET%" == "c64" (
set BUILD_128=False
set BUILD_64=True
goto build_src
)

:build_src

if "%BUILD_128%" EQU "True" (
set SYSTEM_CONFIG="%PROJECT_NAME%-c128.cfg"
set SYSTEM_DEFINE=c128

echo Building %PROJECT_NAME%.s !SYSTEM_DEFINE!
ca65 -I ..\..\include -W1 -g -l obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.lst -mm near -t c64 -D C128 -o obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.o %PROJECT_NAME%.s
ld65 -C !SYSTEM_CONFIG! -Ln obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.vice -vm -m obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.map --dbgfile obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.dbg -o bin\%PROJECT_NAME%-!SYSTEM_DEFINE!.prg obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.o
)

if "%BUILD_64%" == "True" (
set SYSTEM_CONFIG="%PROJECT_NAME%-c64.cfg"
set SYSTEM_DEFINE=c64

echo Building %PROJECT_NAME%.s !SYSTEM_DEFINE!
ca65 -I ..\..\include -W1 -g -l obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.lst -mm near -t c64 -D C64 -o obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.o %PROJECT_NAME%.s
ld65 -C !SYSTEM_CONFIG! -Ln obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.vice -vm -m obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.map --dbgfile obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.dbg -o bin\%PROJECT_NAME%-!SYSTEM_DEFINE!.prg obj\%PROJECT_NAME%-!SYSTEM_DEFINE!.o
)

copy /Y obj\*.vice bin 2>NUL: >NUL:
%C1541_PATH%c1541.exe -format "develop,00" d64 bin\%DISK_NAME%.d64
if "%BUILD_128%" == "True" (
%C1541_PATH%c1541.exe -attach bin\%DISK_NAME%.d64 -write "bin\%PROJECT_NAME%-c128.prg" "%PROJECT_NAME%-c128"
)
if "%BUILD_64%" == "True" (
%C1541_PATH%c1541.exe -attach bin\%DISK_NAME%.d64 -write "bin\%PROJECT_NAME%-c64.prg" "%PROJECT_NAME%-c64"
)
%C1541_PATH%c1541.exe -attach bin\%DISK_NAME%.d64 -write "bin\spritedata.seq" "spritedata,s"
