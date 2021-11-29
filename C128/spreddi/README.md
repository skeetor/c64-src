# Sprite, character and screen editor for the C128

When the editor asks you to enter a value, you can always cancel the operation by pressing RUN/STOP to return to the editor
<br>
<br>
<br>
<b>Keys (* = not implemented)</b>

### <u><b>Common editor keys</b></u><br><br>

These keys work in all editor modes<br><br>
<b>*F1</b> - Sprite editor mode<br>
<b>*F3</b> - Character editor mode<br>
<b>*F5</b> - Screen editor mode<br>

### <u><b>Sprite editor</b></u><br>

<b>C</b> - Copy from frame N to current<br>
<b>D</b> - Delete current frame<br>
<b>*SHIFT D</b> - Delete frame N..M<br>
<b>*E</b> - Export as BASIC DATA program (Linenr, Step, Pretty/Compressed - Max. Line: 63999)<br>
<b>I</b> - Invert edit matrix<br>
<b>G</b> - Goto frame<br>
<b>*H</b> - Help screen<br>
<b>L</b> - Load file<br>
<b>N</b> - New empty frame at end<br>
<b>SHIFT N</b> - Append current frame at end (Copy)<br>
<b>*COMMODORE N/INS</b> - New empty frame at current position (Insert)<br>
<b>*CONTROL N</b> - Insert copy of current frame at current position (Insert copy)<br>
<b>S</b> - Save File<br>
<b>M</b> - Multicolor<br>
<b>U</b> - Undo changes by restoring the current frame<br>
<b>X</b> - Toggle Width<br>
<b>Y</b> - Toggle Heigth<br>
<b>SPC</b> - Toggle bit<br>
<b>,</b> - Previous frame<br>
<b>.</b> - Next frame<br>
<b>SHIFT EXT CRSR Left/Right</b> - next/previous frame<br>

    Alternative is to use ',' for previous and '.' for next frame, because on the Commodore keyboard SHIFT-CRSR-Left is already needed for regular cursor left movement and the C128 cursor keys are not conveniently placed.

<b>CRSR Left/Right/Up/Down</b> - Move cursor in edit grid<br>
<b>HOME</b> - Cursor to top first pixel
<b>DEL</b> - Clear grid<br>
<b>1</b> - Cycle Spritecolor 1<br>
<b>2</b> - Cycle Spritecolor 2 &lt;Multicolor&gt;<br>
<b>3</b> - Cycle Spritecolor 3 &lt;Multicolor&gt;<br>

### <u><b>Character editor</b></u><br><br>

* Save font
* Load font
* Rotate 90 (left/right)

### <u><b>Screen editor</b></u><br><br>

