@echo off

if not exist "obj" mkdir obj
if not exist "bin" mkdir bin

set SYSTEM_CONFIG="c128-asm.cfg"
set SYSTEM_DEFINE=C128

set PROJECT_NAME=keyscan

del /F /Q obj\*.*

echo System: %SYSTEM_DEFINE%
echo=
echo Running assembler
ca65 -I ..\..\include -W1 -g -l obj\%PROJECT_NAME%.lst -mm near -t c64 -D %SYSTEM_DEFINE% -o obj\%PROJECT_NAME%.o %PROJECT_NAME%.s

echo Done. Running linker
echo=
ld65 -C %SYSTEM_CONFIG% -Ln obj\%PROJECT_NAME%.vice -vm -m obj\%PROJECT_NAME%.map --dbgfile obj\%PROJECT_NAME%.dbg -o bin\%PROJECT_NAME%.prg obj\%PROJECT_NAME%.o
copy /Y obj\*.vice bin 2>NUL:
