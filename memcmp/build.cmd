@echo off

set PRJ_NAME=memcmp

if not exist "obj" mkdir obj
if not exist "bin" mkdir bin

set SYSTEM_CONFIG="c64-asm.cfg"
set SYSTEM_DEFINE=C64

del /F /Q obj\*.*

echo System: %SYSTEM_DEFINE%
echo Building %PRJ_NAME%

ca65 -I ..\include -W1 -g -l obj\%PRJ_NAME%.lst -mm near -t c64 -D %SYSTEM_DEFINE% -o obj\%PRJ_NAME%.o %PRJ_NAME%.s
ld65 -C %SYSTEM_CONFIG% -Ln obj\%PRJ_NAME%.vice -vm -m obj\%PRJ_NAME%.map -S 49152 --dbgfile obj\%PRJ_NAME%.dbg -o bin\%PRJ_NAME%.prg obj\%PRJ_NAME%.o

echo Done.
