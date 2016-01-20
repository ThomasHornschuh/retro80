; PS2 Keyboard decoder
; (c) 2016 Thomas Hornschuh


; Data

lastcode: dw 0 ; 16 Bit Scan code in little endian format either 00XX or E0XX for extendented scan codes 
flagBreak: db 0 ; <>0 when last code was a break code 

keyFlags: db 0  ; Flags for status of shift alt  and control keys

; keyFlag Bit positions 
  lShiftKey equ 0
  rShiftKey equ 1
  lCtrlKey  equ 2
  rCtrlKey  equ 3 
  lAltKey   equ 4
  rAltKey   equ 5 ; "AltGr"
  
; Masks for testing left and right key together 
  shiftMask equ     011B
  ctrlMask  equ   01100B
  altMask   equ 0110000B

lockFlags: db 0 ; Flags for Caps and Numlock Status

; lockFlags bit positions

  capsLock equ 0 
  numLock  equ 1 
  
  capsMask equ 01B
  numMask  equ 10B 

converted: db 0 ; Result of key processing - converted ASCII code   
  
 
; State engine

   sstart equ 0 ; Start state
   code   equ 1 ; complete scan  code (8 or 16 Bit ) received   
   ext    equ 2 ; First byte of extended scan code received

mstate: db sstart; State engine status register    
    
ps2start:   in a,(PS2_DATA) ; clear  ps/2 controller    
ps2loop:    ld c, xdos_flag_wait
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
            

compareCode:  ; Compares scancode in HL with scancode in DE
              ; set Z when equal
              ; destroys add
            ld a,l 
            cp e
            ret nz
            ld a,h
            cp d
            ret             

cpi16 macro immed
            ld de, immed
            call compareCode
      endm       


toggleLockBit:  ; Reg C contains mask of bit to toggle, destroys a,d,e  
            ld a,(lockFlags)
 comment #
            ld d,a ; save in D
            ld a,c 
            cpl ; invert mask
            and d ; a:= ~mask and lockFlags   
            ld e,a ; save in e                         
            ld a,d             
            and c ; mask bit
#            
            xor c ; invert bit 
;            or e  ; mix in the other bits  
            ld (lockFlags),a 
            ret 
            
codeReceived:
            if DEBUG            
            call codePrint
            endif 
            call codeDecode
            if DEBUG 
            ld a,(converted)
            or a ; set flags 
            jr z, cdr1 
            push af 
            ld a,'[';
            call bdoscon
            pop af
            cp ' ' ; check if printable     
            push af            
            call nc, bdoscon ; write ASCII char
            ld a,' '
            call bdoscon             
            pop af 
            call outcharhex ; print hex code 
            ld a,']'
            call bdoscon 
            ld a,' '
            call bdoscon
            
            endif 
cdr1:       call writeStatusline
            ret 

          
codeDecode:  ; The scancode decoder ....          
            ld hl,(lastCode)            
            ld iy, keyFlags
            ld a,(flagBreak)
            or a ; set flags
            jr nz, doBreak 
doMake:                 
            cpi16 12H ; Left shift
            jr nz, make1
            set lShiftKey,(iy+0)
            ret
make1:      cpi16 59H ; Right shift
            jr nz,make2
            set rShiftKey,(iy+0)
            ret
make2:      cpi16 14H ; left Control
            jr nz,make3
            set lCtrlKey,(iy+0)
            ret
make3:      cpi16 0E014H ; right Control
            jr nz,make4
            set rCtrlKey,(iy+0)
            ret     
make4:      cpi16 11H ; left Alt
            jr nz,make5    
            set lAltKey,(iy+0)
            ret 
make5:      cpi16 0E011H
            jr nz,make6
            set rAltKey,(iy+0)
            ret
make6:                  
            cpi16 58H ; Caps Lock 
            jr nz,make7 
            ld c,capsMask
            call toggleLockBit
            
make7:      cpi16 77H ; Num Lock 
            jr nz, make8
            ld c,numMask
            call toggleLockBit
make8:      ; TODO: Handle all other keys          
            
            ld a,h
            or a ; set flags 
            push af
            call z, convStandard ; convert standard keycodes 
            pop af 
            call nz, convExtended ; convert extented keycodes             
            ret 


doBreak:    cpi16 12H ; Left shift
            jr nz, break1
            res lShiftKey,(iy+0)
            ret
break1:      cpi16 59H ; Right shift
            jr nz,break2
            res rShiftKey,(iy+0)
            ret
break2:      cpi16 14H ; left Control
            jr nz,break3
            res lCtrlKey,(iy+0)
            ret
break3:      cpi16 0E014H ; right Control
            jr nz,break4
            res rCtrlKey,(iy+0)
            ret     
break4:      cpi16 11H ; left Alt
            jr nz,break5    
            res lAltKey,(iy+0)
            ret 
break5:      cpi16 0E011H
            jr nz,break6
            res rAltKey,(iy+0)
            ret
break6:      ; TODO: Handle all other keys
            ld a,0     
            ld (converted),a              
            ret             

            
convExtended: 
            ; TODO : Implement
            ld a,0
            ld (converted),a 
            ret 

convStandard:   ; Handle standard keycodes - 
                ;on entry l will contain lower byte of scan code             
             ld a,0 
             ld (converted),a         
             ld a,l ; get scancode              
             cp lookupMax+1 ; range check 
             ret nc ;  return if we are out of range 
             ld hl,lookup1 ; Base of lookup table 
             ld e,a 
             ld d,0 
             add hl,de ; HL is now index into table 
             ld a,(hl)
             or a ; set flags 
             ret z ; ignore empty positions (should not happen....)              
             ld b,a ; now reg b contains the "neutral" ASCII code of the pressed key 
             ld a,(keyFlags)
             ld c,a ; save 
             and shiftMask 
             jr nz, cnvShifted
             ld a,c
             and ctrlMask
             jr nz, cnvCtrl 
             bit rAltKey,c ; "AltGr" ?
             jr nz, cnvAltGr 
             ; else 
             ld a,b 
cnvRet:      ld (converted),a ; result 
             ret              

cnvShifted:
            ld a,b  
            cp 'a' 
            jr c, noLetter
            cp 'z'+1 
            jr nc, noLetter
            sub 'a'-'A' ; convert to Upper case 
            jr cnvRet  
            
noLetter:   jr cnvRet ; TODO : implement           

cnvCtrl:    ; TODO : implement
            ret  

cnvAltGr:             
            ; TODO : implement
            ret 
            
codePrint: 
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
           cpi16 0E02FH
           jp z, 0 ; Terminate when menu key pressed 
           ret 
writeBlank:
           ld hl,msgBlank           
writeKeyStat: ; calls writestrxy but preserves BC,DE,HL ; adds msgLength+1 to c before exit          
           push hl 
           push bc
           push de
           call writestrxy
           pop de
           pop bc
           pop hl
           ld a,c 
           add msgLength+1 
           ld c,a 
           ret 

writeStatusline:  ; Write Keyboard status to status line 
           ldxy bc, 2, physlines-1 
           ld ix,scrpb0
           ld a,(keyFlags)
           ld e,a ; save 
           and shiftMask
           push af 
           call z,writeBlank 
           pop af 
           jr z,wstat1
           ld hl,msgShift
           call writeKeyStat
wstat1:    ld a,e 
           and ctrlMask
           push af 
           call z,writeBlank
           pop af
           jr z,wstat2 
           ld hl,msgCtrl
           call writeKeyStat
wstat2:    ld a,e 
           and altMask
           push af
           call z,writeBlank
           pop af
           jr z,wstat3 
           ld hl,msgAlt
           call writeKeyStat
wstat3:    ld a,(lockFlags)
           ld e,a  
           bit capsLock,e  
           push af
           call z,writeBlank
           pop af
           jr z,wstat4
           ld hl,msgCapsL
           call writeKeyStat
wstat4:    bit numLock,e
           push af
           call z,writeBlank
           pop af
           ret z
           ld hl,msgNumL
           call writeKeyStat
           ret            
           
            
            

           
           

msgAlt:     db 'ALT  ',0
msgCtrl:    db 'CTRL ',0
msgShift:   db 'SHIFT',0
msgNumL:    db 'NUM  ',0 
msgCapsL:   DB 'CAPS ',0 
msgBlank:   DB '     ',0 
msgLength equ 5            


; Keyboard conversion tables


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

           
            
 