@echo off

if not exist "obj" mkdir obj

del /F /Q obj\*.*

ca65 -W1 -g -l obj\hello_world.lst -mm near -t c64 -o obj\hello_world.o hello_world.s
ld65 -C c64-asm.cfg -Ln obj\hello_world.vice -vm -m obj\hello_world.map --dbgfile obj\hello_world.dbg -S "$C000" obj\hello_world.o -o obj\hello_world.prg
