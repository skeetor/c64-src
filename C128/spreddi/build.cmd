@echo off

if not exist "obj" mkdir obj
if not exist "bin" mkdir bin

set SYSTEM_CONFIG="c128-asm.cfg"
set SYSTEM_DEFINE=C128

set C1541_PATH=e:\Programme\VICE-Win-3.1-x64\
set PROJECT_NAME=spreddi
set DISK_NAME=%PROJECT_NAME%

del /F /Q obj\*.*

echo System: %SYSTEM_DEFINE%
echo=
echo Building %PROJECT_NAME%.s
ca65 -I ..\..\include -I ..\..\include\c128 -W1 -g -l obj\%PROJECT_NAME%.lst -mm near -t c64 -D %SYSTEM_DEFINE% -o obj\%PROJECT_NAME%.o %PROJECT_NAME%.s
rem echo Building scankeys.s
rem ca65 -I ..\..\include -W1 -g -l obj\scankeys.lst -mm near -t c64 -D %SYSTEM_DEFINE% -o obj\scankeys.o scankeys.s

echo Done. Running linker
echo=
rem ld65 -C %SYSTEM_CONFIG% -Ln obj\%PROJECT_NAME%.vice -vm -m obj\%PROJECT_NAME%.map --dbgfile obj\%PROJECT_NAME%.dbg -o bin\%PROJECT_NAME%.prg obj\%PROJECT_NAME%.o obj\scankeys.o
ld65 -C %SYSTEM_CONFIG% -Ln obj\%PROJECT_NAME%.vice -vm -m obj\%PROJECT_NAME%.map --dbgfile obj\%PROJECT_NAME%.dbg -o bin\%PROJECT_NAME%.prg obj\%PROJECT_NAME%.o
copy /Y obj\*.vice bin 2>NUL: >NUL:
%C1541_PATH%c1541.exe -format "develop,00" d64 bin\%DISK_NAME%.d64 -write "bin\%PROJECT_NAME%.prg" "%PROJECT_NAME%" -write "bin\spritedata.seq" "spritedata,s"
