@echo off

if not exist "obj" mkdir obj
if not exist "bin" mkdir bin

if "%1" == "" goto no_params
set SYSTEM=%1
goto main

:no_params
set SYSTEM=c64

:main
if "%SYSTEM%" == "vc20" (
set SYSTEM_CONFIG="vic20-asm.cfg"
set SYSTEM_DEFINE=VC20
)

if "%SYSTEM%" == "c64" (
set SYSTEM_CONFIG="c64-asm.cfg"
set SYSTEM_DEFINE=C64
)

del /F /Q obj\*.*

echo System: %SYSTEM_DEFINE%
echo Running assembler
echo=
ca65 -I ..\include -W1 -g -l obj\hello_world.lst -mm near -t c64 -D %SYSTEM_DEFINE% -o obj\hello_world.o hello_world.s

echo=
echo Done. Running linker
echo=
ld65 -C %SYSTEM_CONFIG% -Ln obj\hello_world.vice -vm -m obj\hello_world.map --dbgfile obj\hello_world.dbg -o bin\helloworld-%SYSTEM%.prg obj\hello_world.o
