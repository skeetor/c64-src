# KeyScan by Gerhard Gruber<br>sparhawk@gmx.at

This project demonstrates how to read the keyboard directly via the CIA ports on the C128 and C64, including the extended keys.<br>
<br>
The keyboard matrix is shown on screen and shows which keys are pressed. This can also be used to test a keyboard and see if all keys are working, except RESTORE which doesn't use the CIA ports.<br>
<br>
The code will also work on the C64 with the only difference that it doesn't have the extended keys, so this can be skipped if desired.<br>
<br>
The same binary can be run natively on C128 and C64 without any changes or recompiling. However on a C64 it MUST be loaded using LOAD"KEYSCAN",8 and started with RUN. If loaded with LOAD"KEYSCAN",8,1 it will be at the C128 BASIC address, so the SYS 7262 must be entered manually.<br>
It will also detect if it is on a real C64 or on a C128 in C64 mode and shows this accordingly.<br>
<br>
<br>
C128 = Native C128 mode<br>
C64  = Native C64 mode<br>
C128/C64 = Running on C128 in C64 mode.<br>
<br>
