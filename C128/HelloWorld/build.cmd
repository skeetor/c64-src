@echo off

if not exist "obj" mkdir obj
if not exist "bin" mkdir bin

set SYSTEM_CONFIG="c128-asm.cfg"
set SYSTEM_DEFINE=C128

del /F /Q obj\*.*

echo System: %SYSTEM_DEFINE%
echo=
echo Running assembler
ca65 -I ..\..\include -W1 -g -l obj\HelloWorld.lst -mm near -t c64 -D %SYSTEM_DEFINE% -o obj\HelloWorld.o HelloWorld.s

echo Done. Running linker
echo=
ld65 -C %SYSTEM_CONFIG% -Ln obj\HelloWorld.vice -vm -m obj\HelloWorld.map --dbgfile obj\HelloWorld.dbg -o bin\helloworld-%SYSTEM%.prg obj\HelloWorld.o
