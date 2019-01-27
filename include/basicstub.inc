; A basic stub which can be included to create a
; BASIC line starting the main program.
;
; Written by Gerhard W. Gruber 27.01.2019

; _EntryPoint must be defined before the file is included
; and set to the function which starts the application.

__basicstub:
.word @nextline
.word 10 ; line number
.byte $9e ; SYS
.byte $20

.byte <(((_EntryPoint / 10000) .mod 10) + $30)
.byte <(((_EntryPoint / 1000)  .mod 10) + $30)
.byte <(((_EntryPoint / 100 )  .mod 10) + $30)
.byte <(((_EntryPoint / 10 )   .mod 10) + $30)
.byte <((_EntryPoint           .mod 10) + $30)
.byte 0 ;end of line

@nextline:
.word 0 ; empty line == end pf BASIC
