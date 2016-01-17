; Test Program for Keyboard driver
; (c) 2016 Thomas Hornschuh

.z80

PS2_CONTROL              equ 040H ; PS2 Control and status Port
PS2_DATA                 equ 041H ; PS2 Data Port 

; XDOS function numbers
xdos_terminate equ 0
xdos_poll      equ 131
xdos_flag_wait equ 132
xdos_flag_set  equ 133

xdos equ 5H

; flag numbers (1, 2 are already taken by the os)
; documentation recommends using interrupts for input only

flag_ps2       equ 10 ; TH PS2 Data ready flag 



  org 100H
  
  start: jp ps2loop 
  
         ret
  



  include ps2kbd.asm   
  
  
  .end start
