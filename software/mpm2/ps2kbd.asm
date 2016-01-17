; PS2 Keyboard decoder
; (c) 2016 Thomas Hornschuh


; Data

lastcode: dw 0 ; 16 Bit Scan code in little endian format either 00XX or E0XX for extendented scan codes 
flagBreak: db 0 ; <>0 when last code was a break code 


; State engine

   sstart equ 0 ; Start state
   code   equ 1 ; complete scan  code (8 or 16 Bit ) received   
   ext    equ 2 ; First byte of extended scan code received

mstate: db sstart; State engine status register    
    
ps2loop:    ;in a, (PS2_CONTROL)
            ;and 01H ; check for data
            ;jr nz, ps2read
            ld c, xdos_flag_wait
            ld e, flag_ps2
            call xdos ; wait 
            ;jr ps2loop
            
ps2read:    in a,(PS2_DATA)
            cp 0F0H
            jr z, setBreak
            cp 0E0H
            jr z, setExt
            ld l,a ; save code 
            ld a,(mstate)
            cp ext
            jr nz, ps2l1
            ; if state ext only update lower byte of lastcode
            ld a,l
            ld (lastcode),a
            jr ps2l2             
ps2l1:      ld h,0
            ld (lastcode),hl
ps2l2:      ld a,code
setState:   ld (mstate),a
            cp code ; check status 
            call z, codeReceived    
            ld a,0
            ld (flagBreak),a ; Reset break flag     
            jr ps2loop
            
setBreak:   ld (flagBreak),a 
            jr ps2loop
            
setExt:     ld (lastcode+1),a 
            ld a,ext
            jr setState
            

codeReceived:  
           ld hl,(lastcode)
           ld a,h
           push hl
           call outcharhex
           pop hl
           ld a,l
           push hl 
           call outcharhex
           ld a, ' '
           ld e,a            
           ld c,2 ; BDOS Console out 
           call 5H ; call BDOS 
           pop hl
           ld a,l
           cp 5AH ; enter ...
           jp z, 0 ; Terminate when enter pressed 
           ret 




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
            ld e, a
            ld c,2 ; BDOS Console out 
            call 5H ; call BDOS 
            ret

           
            
 