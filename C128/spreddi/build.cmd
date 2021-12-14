@echo off

if not exist "obj" mkdir obj
if not exist "bin" mkdir bin

set SYSTEM_CONFIG="c128-asm.cfg"
set SYSTEM_DEFINE=c128

@echo on
echo Building %PROJECT_NAME%.s C128
ca65 -I ..\..\include -W1 -g -l obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.lst -mm near -t c64 -D C128 -o obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.o %PROJECT_NAME%.s
echo Done. Running linker
echo=
ld65 -C %SYSTEM_CONFIG% -Ln obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.vice -vm -m obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.map --dbgfile obj\%PROJECT_NAME%-c128.dbg -o bin\%PROJECT_NAME%-%SYSTEM_DEFINE%.prg obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.o

set SYSTEM_CONFIG="c64-asm.cfg"
set SYSTEM_DEFINE=c64

echo Building %PROJECT_NAME%.s C64
ca65 -I ..\..\include -W1 -g -l obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.lst -mm near -t c64 -D C64 -o obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.o %PROJECT_NAME%.s
echo Done. Running linker
echo=
ld65 -C %SYSTEM_CONFIG% -Ln obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.vice -vm -m obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.map --dbgfile obj\%PROJECT_NAME%-c128.dbg -o bin\%PROJECT_NAME%-%SYSTEM_DEFINE%.prg obj\%PROJECT_NAME%-%SYSTEM_DEFINE%.o

copy /Y obj\*.vice bin 2>NUL: >NUL:
%C1541_PATH%c1541.exe -format "develop,00" d64 bin\%DISK_NAME%.d64 -write "bin\%PROJECT_NAME%-c64.prg" "%PROJECT_NAME%-c64" -write "bin\%PROJECT_NAME%-c128.prg" "%PROJECT_NAME%-c128" -write "bin\spritedata.seq" "spritedata,s"
