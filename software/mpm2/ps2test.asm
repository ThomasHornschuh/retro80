; Test Program for Keyboard driver
; (c) 2016 Thomas Hornschuh

.z80

DEBUG equ 1 ; enable Debug output 

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
  
  
  
  
  start:    ld ix, scrpb0
            ld hl,PhysScreenPage        
            call initscrpb
            ld a,08H 
            ld (mapPage),a ; Map frame buffer to 8000H             
            jp ps2start   
            ret
  
  vgastatusline equ 1  
  include vgabasic.asm  
  
  ;defscrpb 0 ; Define screen control block 

  l_german equ 1 ; Keyboard layout german 
  
; Test Output helpers 

 
  


; print the byte in A as two hex nibbles
outcharhex:
            push bc
            push af  ; save value
            ; print the top nibble
            rra
            rra
            rra
            rra
            call outnibble
            ; print the bottom nibble
            pop af 
            call outnibble
            pop bc
            ret

; print the nibble in the low four bits of A
outnibble:
            and 0x0f ; mask off low four bits
            cp 10
            jr c, numeral ; less than 10?
            add 0x07 ; start at 'A' (10+7+0x30=0x41='A')
numeral:    add 0x30 ; start at '0' (0x30='0')
            ;; Entry point to write character in a to console  
bdoscon:    ld e, a
            ld c,2 ; BDOS Console out 
            call 5H ; call BDOS 
            ret
            
            
  
  
  
  include ps2kbd.asm   
   if l_german 
    include lger.asm 
  endif   
  
  .end start
