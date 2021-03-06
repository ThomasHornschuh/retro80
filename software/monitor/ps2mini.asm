;----------------------------------------------------------------------------------
;--+ RETRO80
;--+ An 8-Bit Retro Computer running Digital Research MP/M II and CP/M. 
;--+ Based on Will Sowerbutts  SOCZ80 Project:
;--+ http://sowerbutts.com/
;--+ RETRO80 extensions (c) 2015-2016 by Thomas Hornschuh
;--+ This project is licensed under the GPLV3: https://www.gnu.org/licenses/gpl-3.0.txt

;  Minimal PS2 Keyboard decoder
; (c) 2016 Thomas Hornschuh


; Data


DEBUG equ 0 

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



; ix+lockFlags bit positions

  capsLock equ 0 
  numLock  equ 1 
  
  capsMask equ 01B
  numMask  equ 10B 
  
 
; State engine

   sstart equ 0 ; Start state
   code   equ 1 ; complete scan  code (8 or 16 Bit ) received   
   ext    equ 2 ; First byte of extended scan code received


    
ps2start:   ld a, 01000000B ; PS/2 Controller reset (clears FIFO and pending IRQs) 
            out (PS2_CONTROL),a 
            ld (ix+mstate),sstart
            ld a,0             
            ld (ix+lockFlags),a
            ld (ix+keyFlags),a 
            ld (ix+convValid),a 
            ret              


;----------------------------------------------
; subprogramm ps2do 
;----------------------------------------------            
ps2do:      in a,(PS2_CONTROL)
            and 01H ; check status bit 
            jr nz,ps2read ; -> data available 
            ; Else wait for next interrupt 
        if MPM ; conditional compile - if we use MP/M than wait for Interrupt 
            ld c, xdos_flag_wait
            ld e, flag_ps2
            call xdos ; wait 
        endif     
            jr ps2do 
                       
ps2read:    in a,(PS2_DATA)
            cp 0F0H
            jr z, setBreak
            cp 0E0H
            jr z, setExt
            ld l,a ; save code 
            ld a,(ix+mstate)
            cp ext
            jr nz, ps2l1 ; mstate <> ext ->     
            ; if state ext only update lower byte of lastcode            
            ld a,l
            ld (ix+lastcode),a
            jr ps2l2             
ps2l1:      ld h,0 
            ld (ix+lastcode),l
            ld (ix+lastcode+1),h 
ps2l2:      ld a,code
setState:   ld (ix+mstate),a
            cp code ; check status 
            call z, codeReceived    
            ld a,0
            ld (ix+flagbreak),a ; Reset break flag     
            ret 
            
setBreak:   ld (ix+flagbreak),a 
            ret 
            
setExt:     ld (ix+lastcode+1),a 
            ld a,ext
            jr setState

;------------------------------------------------------
; end ps2do 
;------------------------------------------------------            

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


toggleLockBit:  ; Reg C contains mask of bit to toggle
            ld a,(ix+lockFlags)         
            xor c ; invert bit 
            ld (ix+lockFlags),a 
            ret 
            
codeReceived:
            if DEBUG            
            call codePrint
            endif 
            
            call codeDecode
            
            if DEBUG 
            ld a,(ix+converted)
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

; -----------------------------------------------------
; begin Subprogram codeDecode 
; The scancode decoder .... 
; Takes lastCode and does
;    - handling of shift, alt, ctrl, Lock keys to update (ix+KeyFlags) and (ix+lockFlags)
;    - convert all the other keys to their ASCII and control chars and updates
;      the memory location <converted> with the resulting char  

            
codeDecode:           
            ld l,(ix+lastcode)            
            ld h,(ix+lastcode+1)
            
            ld a,(ix+flagbreak)
            or a ; set flags
            jr nz, doBreak 
doMake:                 
            cpi16 12H ; Left shift
            jr nz, make1
            set lShiftKey,(ix+keyFlags)
            ret
make1:      cpi16 59H ; Right shift
            jr nz,make2
            set rShiftKey,(ix+keyFlags)
            ret
make2:      cpi16 14H ; left Control
            jr nz,make3
            set lCtrlKey,(ix+keyFlags)
            ret
make3:      cpi16 0E014H ; right Control
            jr nz,make4
            set rCtrlKey,(ix+keyFlags)
            ret     
make4:      cpi16 11H ; left Alt
            jr nz,make5    
            set lAltKey,(ix+keyFlags)
            ret 
make5:      cpi16 0E011H
            jr nz,make6
            set rAltKey,(ix+keyFlags)
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
            res lShiftKey,(ix+keyFlags)
            ret
break1:      cpi16 59H ; Right shift
            jr nz,break2
            res rShiftKey,(ix+keyFlags)
            ret
break2:      cpi16 14H ; left Control
            jr nz,break3
            res lCtrlKey,(ix+keyFlags)
            ret
break3:      cpi16 0E014H ; right Control
            jr nz,break4
            res rCtrlKey,(ix+keyFlags)
            ret     
break4:      cpi16 11H ; left Alt
            jr nz,break5    
            res lAltKey,(ix+keyFlags)
            ret 
break5:      cpi16 0E011H
            jr nz,break6
            res rAltKey,(ix+keyFlags)
            ret
break6:                 
            ret          
            
; end Subprogram codeDecode 
;-------------------------------------------------------  

            
convExtended: 
            
            ld a,l   
            ld hl,extMap
            ld b, extMapLen            
            call searchMap  
cnve3:      ld (ix+convValid),a
            or a ; set flags 
            jr z,cnve1             
            ld a,b  
cnve1:      ld (ix+converted),a 
            ret 
            
;------------------------------------------------------- 
; begin Subprogram convStandard           
            
convStandard:   ; Handle standard keycodes - 
                ;on entry hl will contain  scan code             
             ld a,0 
             ld (ix+converted),a
             ld (ix+convValid),a     

             ld a,(ix+lockFlags)
             and numMask ; Check for Num Lock 
             jr nz, cnvs1 ; yes ->
             ld a,l 
             call cnvCursorBlock
             or a; set flags , a contains ff if key was a cursor key
             jr nz, cnvRetB ; -> finish b contains ASCII code              
             ld l,(ix+lastcode)  ; refresh HL 
             ld h,(ix+lastcode+1)
             ; fall through 
cnvs1:       ld a,l ; get scancode              
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
             ld a,(ix+keyFlags)             
             ld c,a ; save
             bit rAltKey,c ; "AltGr" ?
             call nz, cnvAltGr ; handle AltGr - on return b contains ASCII 
             ld a,c
             and ctrlMask
             push af 
             call nz,applyCtrl ; Apply ctrl key - on return b contains ASCII 
             pop af 
             jr nz, cnvRetB ; when control is pressed ignore shift    
             ld a,c    
             and shiftMask 
             jr nz, cnvShifted      
             ld a,(ix+lockFlags)
             and capsMask ; Check CAPS Lock
             ld a,b              
             jr z,cnvRetA 
             call ps2toUpper
             ld b,a ; faster and smaller than jr cnvRetA              
             ; fall through 
cnvRetB:     ld a,b ; restore              
cnvRetA:      
             ld (ix+converted),a ; result 
             ld a,1 
             ld (ix+convValid),a ; flag 
             ret              

cnvShifted:
            ld a,b  
            cp 'a' 
            jr c, noLetter
            cp 'z'+1 
            jr nc, noLetter
            sub 'a'-'A' ; convert to Upper case 
            jr cnvRetA  
            
noLetter:   ld a,(ix+lastcode)
            cp 69H ; check if scan code is from num block
            jr nc, cnvRetB ; Don't apply shiftmap to mum block keys
            ld a,b 
            ld hl,shiftMap
            ld b,shiftMapLen
            call searchMap
            jr cnvRetB 

            

 
; End subprogram convStandard  
;------------------------------------------------------- 

; sub program toUpper
; converts char in a to upper case  
ps2toUpper:
            cp 'a' 
            ret c
            cp 'z'+1 
            ret nc 
            sub 'a'-'A' ; convert to Upper case 
            ret 
            
;-------------------------------------------------------
;sub program cnvAltGr takes ASCII char in reg b
; and looks up altGrMap if there is a mapping 
; if yes modifies char
; in in case the result char is returned in b 
; a is 0FF when search was succesfull, 0 otherwise 


cnvAltGr:   ld a,b ; restore 
            ld hl,altGrMap
            ld b, altGrMapLen
            ; fall through 
searchMap:  cp (hl)
            jr z, cnv1 ; found 
            inc hl 
            inc hl ;hl+=2 
            djnz searchMap
            ; nothing in map -> then use unmodified char 
            ld b,a 
            ld a,0 
            ret          
cnv1:       inc hl ; modified char is at next address 
            ld b,(hl)
            ld a,0ffH 
            ret 

; Entry point cnvCursorBlock - expects scancode in a             
cnvCursorBlock:
           ld hl, cursorMap
           ld b, cursMapLen   
           jr searchMap      

;-------------------------------------------------------
;sub program applyCtrl takes ASCII char in reg b 
           
applyCtrl:  ld a,b
            call ps2toUpper              
            ; Check range 
            cp '@'        
            ret c 
            cp ']'+1 
            ret nc 
            sub 40H ; Ctrl is just offset char with -40H  
            ld b,a 
            ret              
            
if DEBUG             
codePrint: 
           ld hl,(ix+lastcode)
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
           
endif            
           
writeBlank:
           ld hl,msgBlank           
writeKeyStat: ; calls writestrxy but preserves BC,DE ; adds msgLength+1 to c before exit          
           push bc
           push de
           call writestrxy
           pop de
           pop bc
           ld a,c 
           add msgLength+1 
           ld c,a 
           ret 

writeStatusline:  ; Write Keyboard status to status line  
           ld bc, ((physlines-1) shl 8 ) or 2 
           ld a,(ix+keyFlags)
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
wstat3:    ld a,(ix+lockFlags)
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




           
            
 