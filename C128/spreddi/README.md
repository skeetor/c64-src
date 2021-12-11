# Sprite, character and screen editor for the C128<br>
<br>
When the editor asks you to enter a value, you can always cancel the operation by pressing RUN/STOP to return to the editor<br>
<br>
Note! When you enter a value you have to alway press ENTER to accept the value, even for single character input!<br>
<br>
<b>Spreddi V1.0 Release Version on 2021.12.11</b><br>
https://github.com/skeetor/c64-src<br>
<br>
<br>
<b>Keys (* = not implemented)</b><br>
<br>

### <u><b>Common editor keys</b></u><br>
<br>
These keys work in all editor modes<br>
<br>
<b>*F1</b> - Sprite editor mode<br>
<b>*F3</b> - Character editor mode<br>
<b>*F5</b> - Screen editor mode<br>
<br>

### <b><u>Sprite editor</u></b><br>
<br>
<b>C</b> - Copy from frame N to current<br>
<b>D</b> - Delete current frame<br>
<b>*SHIFT D</b> - Delete frame N..M (Make 7 frames, goto fr.5, del 1-1, cursor in wrong place<br>
<b>E</b> - Export as BASIC DATA program (Linenr, Step, Pretty/Compressed - Max. Line: 63999)<br>
<b>I</b> - Invert edit matrix<br>
<b>F</b> - Flip vertically<br>
<b>SHIFT F</b> - Flip horizontally<br>
<b>G</b> - Goto frame<br>
<b>*H</b> - Help screen<br>
<b>L</b> - Load file<br>
<b>N</b> - New empty frame at end<br>
<b>SHIFT N</b> - New empty frame at current position (Insert)<br>
<b>CMDR N</b> - Append current frame at end (Copy)<br>
<b>CTRL N</b> - Insert copy of current frame at current position (Insert copy)<br>
<b>DEL</b> - Delete Column on current line<br>
<b>CMDR DEL</b> - Delete line (INS)<br>
<b>CTRL DEL</b> - Delete columns on all lines<br>
<b>INS</b> - Insert column on current line<br>
<b>CMDR INS</b> - Insert line<br>
<b>CTRL INS</b> - Insert columns on all lines<br>
<b>S</b> - Save File (Ask for overwriting if file exists needs to be done)<br>
<b>M</b> - Multicolor<br>
<b>U</b> - Undo changes by restoring the current frame<br>
<b>X</b> - Toggle Width<br>
<b>Y</b> - Toggle Heigth<br>
<b>SPC</b> - Toggle bit<br>
<b>,</b> - Previous frame<br>
<b>.</b> - Next frame<br>
<b>ENTER</b> - Goto begin of next line<br>
<b>SHIFT EXT CRSR Left/Right</b> - next/previous frame<br>

    Alternative is to use ',' for previous and '.' for next frame, because on the Commodore keyboard SHIFT-CRSR-Left is already needed for regular cursor left movement and the C128 cursor keys are not conveniently placed.

<b>CRSR Left/Right/Up/Down</b> - Move cursor in edit grid<br>
<b>CMDR CRSR Left/Right</b> - Shift grid left/right<br>
<b>CMDR CRSR Up/Down</b> - Shift grid up/down<br>
<b>CMDR W</b> - Shift grid up<br>
<b>CMDR A</b> - Shift grid left<br>
<b>CMDR S</b> - Shift grid down<br>
<b>CMDR D</b> - Shift grid right<br>
<b>HOME</b> - Cursor to top first pixel<br>
<b>CLEAR</b> - Clear grid<br>
<b>1</b> - Cycle Spritecolor 1<br>
<b>2</b> - Cycle Spritecolor 2 &lt;Multicolor&gt;<br>
<b>3</b> - Cycle Spritecolor 3 &lt;Multicolor&gt;<br>
<br>
### <u><b>Character editor</b></u><br>
<br>
* Save font<br>
* Load font<br>
* Rotate 90 (left/right)<br>
<br>

### <u><b>Screen editor</b></u>
<br>
* TBD<br>
<br>
<br>

### <u><b>Possible features and improvments</b></u><br>
<br>

    This section contains features and stuff for improvment. That does not mean that everything will be implemented, but at least I don't want to forget about it, so it is mentioned here until I can investigate it.

    The order doesn't reflect the priority :)
<br>

* Refactor InputNumber to library
* Refactor DrawGridMatrix seperate frameborder<br>
* Port to C64<br>
* Port to MEGA65<br>
* Improve keyhandling by switching directly to map with respective primary modifier SHIFT,CMDR,CTRL, etc.<br>
* Mousesupport<br>
* Discmenu<br>
* Big spritepreview, show 2x2 sprites<br>
* Animation preview (forward/backward/cycle/etc.)<br>
* Use DATA/BSS segments properly<br>

### <u><b>Done</b></u><br>
* <s>Refactor keyboard functions to use Carry mechanism</s><br>
* <s>Use .bss segment to remove uninitialized bytes from binary</s><br>
* <s>NoRepeat keys no longer working</s><br>
