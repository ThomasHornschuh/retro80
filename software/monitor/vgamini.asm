; Minimal Video Output Routines and data
; to be included in e.g. ROM Monitor 

; VGA Video output handling

;-----------------------------------------------------------
; TH: conditional defines 
;-----------------------------------------------------------
MAPALWAYS equ 1 ; Map Video RAM Always into memory 
;-----------------------------------------------------------
; end conditional defines 
;-----------------------------------------------------------

; 

; IO Registers

CursorXReg  equ 38H ; 1..80 !!
CursorYReg  equ 39H ; 0..39 
VgaCtrlReg  equ 3AH 

vMMUPageSel equ 0F8H
vMMUFrameH  equ 0FCH
vMMUFrameL  equ 0FDH

ASCII_ESC   equ 27

; Phyiscal Page address of screen buffer

PhysScreenPage equ 2002H

if LOADTPA
  mapPage equ  08H
else   
  mapPage  equ 0EH  ; Virtual Page to map screen buffer to - can be changed 
endif   

columns    equ 80
physlines  equ 40

 
lines      equ physlines-1   
    
screensize equ columns*lines
physsize equ columns*physlines


defscrpb macro n

; Screen parameter block macro
scrpb&n:
            DB 0  ; X Cursor Position 0..79
            DB 0  ; Y Cursor Position 0..39 
            DW 0  ; Physical Page number of video buffer
            DB 0  ; <>0 => spb points to real vga frame buffer - update cursor registers...
            DW 0  ; frame save area     
                        
endm


ldxy macro reg, x, y 
  ld reg, (y shl 8) or x 
endm
            
;Offsets into screen parameter block            
cursX  equ  0
cursY  equ  cursX+1
screenPage equ cursY+1
screenPageL equ screenPage
screenPageH equ screenPageL+1
physFlag    equ ScreenPageH+1
FrameSaveL  equ physFlag+1;
FrameSaveH   equ FrameSaveL+1 
mstate       equ FrameSaveH+1 
; Data fields for PS/2 keyboard 
lastcode     equ mstate+1 ; offest of Last Keyboard Scancode (16Bit)
flagbreak   equ lastcode+2;<>0 when last code was a break code 
converted  equ flagbreak+1 ; Result of key processing - converted ASCII code   
convValid  equ converted+1  ; <> 0 : converted is valid 
keyFlags   equ convValid+1
lockFlags  equ keyFlags+1 

scpbsize equ keyFlags+1 


if MAPALWAYS 

mapVPage macro
endm

unmapVPage macro 
endm 

else 

mapVPage macro 
     
        ld a, mapPage
        out (vMMUPageSel),a
        in a,(vMMUFrameL)
        ld (ix+FrameSaveL),a
        in a,(vMMUFrameH)
        ld (ix+FrameSaveH),a
        ld a,(ix+ScreenPageL)
        out (vMMUFrameL),a
        ld a,(ix+ScreenPageH)
        out (vMMUFrameH),a        
endm

unmapVPage macro            
        ld a, mapPage
        out (vMMUPageSel),a
        ld a,(ix+FrameSaveL)
        out (vMMUFrameL),a
        ld a,(ix+FrameSaveH)
        out (vMMUFrameH),a
       
endm        

endif 

getmapva:   ; Calculate virtual address of mapPage
            ld a, mapPage shl 4              
                      
            ret


           
;writecharxy:  ; Write a charater at position x,y. 
              ; Registers: C = char to output, D=y, E=x, IX=scrpb 

;            push de
;            ld a,d
;            call mult80 
;            pop de
;            jr wrch1 ; continue below 
             
                
        
writechar:  ; Write char at current cursor positon of scrpb 
            ; Reg C contains char -- IX contains scrpb
            ; The critical part of the code (where the video buffer is mapped into virtual address space) does not use the stack
            ; and runs with interrupts disabled. This will avoid any interferences between SP and video mapping

            
            ld a,(ix+cursY)
            call mult80 ; hl = a*80
            ld e,(ix+cursX)
 wrch1:     ld d,0
            add hl,de ; hl is now cursY*80 + cursX
            call getmapva ; get virtual address of screen map 
            or h ; Merge  with high order byte of screen offest
            ld h,a 
                                    
            mapVPage
            ld (hl),c ; finally output :-)
            unmapVPage                  
            ret             
            
clrscr:     ; Clears the screen (fill with blank), IX ontains scrpb. 
            ; C contains flag c=0: Clear only screen without status line, c=1: clear including status lines 
            ; Will not change interrupt enable - so make sure that no MMU changes are done while this code is running 
            call getmapva
            ld h,a
            ld l,0
            ld a,c ; Check clr size flag 
            or a ; Set Flags 
            jr nz, clrall
            ld de, screensize
            jr clrs00
clrall:     ld de, physsize
clrs00:                 
            ld c, ' '
           
            mapVPage            
clrs01:     ld (hl),c
            inc hl
            ld a,l 
            cp e ; low byte of screen size 
            jr nz, clrs01
            ld a,h
            and 0fh
            cp d ; high byte of screen size 
            jr nz, clrs01
            unmapVPage
            ret


writestrxy: ; Write a string at position x,y  HL : ptr to null terminated string, B: Y C: x, IX: ptr to scrpb   
            ; Does not scroll, does not update the HW cursor  
            ; Will not change interrupt enable - so make sure that no MMU changes are done while this code is running 
            push hl; save ptr 
            ld a,b
            push bc
            call mult80
            pop bc
            ld b,0 ; clear high order byte
            add hl,bc ; HL = B*80 + C 
            ld a, mapPage shl 4 
            or h ; Merge map Page into H
            ld d,a ; Move result to DE
            ld e,l 
            
            pop hl 
            ; Now HL contains ptr to string and DE contains ptr to screen buffer
            mapVPage 
wxy0:       ld a, (hl)
            cp 0
            jr z, wxy1 ; finish 
            ldi  ; (DE)<-(HL), increment ptrs 
            ; The following code ensures that DE is not leaving the 4K Page boundary
            ld a,d
            and 0FH ; mask higher 4 bits 
            or  mapPage shl 4 ; set them  to mapPage            
            ld d,a   
            jr wxy0 
wxy1:       unmapVPage      
            ret     
            
            
scroll:     ; Scrolls screen 1 line (append empty line at end ), ix points to scrpb
            call getmapva
            ld d,a
            ld e,0
            ld h,a
            ld l,columns 
            ld bc, columns*(lines-1)
 doscroll:  
            mapVPage
            ld a,b  
            or c ; check if BC = 0
            jr z, scrl2 ; -> yes: skip 
            ldir            
scrl2:      ; clear bottom line       
            ex de,hl ; de points to begin of last line -> HL
clrl:       ld b,columns
scrl1:      ld (hl),' '
            inc hl
            djnz scrl1              
            unmapVPage            
            ret
            
            
                                    
mult80:    ; Mutiply a with 80 return result in hl, will destroy b and de
           ;  hl = a*64 + a*16

        ld b,6  
        ld e,a 
        ld d,0      
mlp1:   sla e
        rl d
        djnz mlp1 
        ld l,a 
        ld h,0 
        ld b,4
mlp2:   sla l
        rl h
        djnz mlp2
        add hl,de
        ret

        
vgaconout:  ; Basic conout procedure  Reg C contains char -- IX contains scrpb
        ;ld a,(ix+escIndex)
        ;cp 0ffh
        ;jr nz,tviesc ; when in ESC sequence continue processing sequence 
        ; else output processing 
        ld a,c
        cp 0dh ; CR ?
        jr z, vccr
        cp 0ah ; LF ?
        jr z, vcolf 
        cp 08h ; backspace
        jr z, vcobackspace
        cp 1AH ; Ctrl-Z
        jr z, vcoctrlz      
        ;cp ASCII_ESC
        ;jr z, startesc      
        cp 32
        ret m ; no regognized control chars -> ignore 
        call writechar
        ; advance cursor....
        ld a,(ix+cursX)
        inc a
        cp columns
        jr nz, vco1 ; no at last column - just update cursX
        ; else go to first column of next line 
        xor a 
        ld (ix+cursX),a
        jr vcolf 
        
vco1:   ld (ix+cursX),a 
        jr sethwcursor

vcoctrlz: ; process Ctrl-Z (clear screen)   
        ld c,0 
        ;di 
        call clrscr
        ;ei 
        ld (ix+cursX),0
        ld (ix+cursY),0 
        jr sethwcursor
        
        ; process a cr 
vccr:   xor a
        jr vco1 
        
vcolf:  ; "Line feed"
        ld a,(ix+cursY) ; process Y
        inc a
        cp lines
        jr nz, vco2
        ; scroll ...
        call scroll
        ld a, lines-1 ; set line back to 39  
vco2:   ld (ix+cursY),a
        jr sethwcursor
        
vcobackspace:
        ld a,(ix+cursX)
        dec a
        cp 0
        ret m ; ignore when <0
        ld (ix+cursX),a         
;; fall through 

sethwcursor: 
        ld a,(ix+physFlag)
        cp 0
        ret z ; Dont update hw cursor on a virtual screen       
        ld a,(ix+cursX)
        inc a ; HW cursor column is 1 based
        out (CursorXReg),a
        ld a,(ix+cursY)
        out (CursorYReg),a                
        ret 
                
; end of vgaconout         
        
; Helper subroutines 
        
        
        
initscrpb: ; IX = Address of scrpb HL=ScreenPage
        
        ld (ix+ScreenPageL),l
        ld (ix+ScreenPageH),h
        ld (ix+cursX),0
        ld (ix+cursY),0
        ld (ix+physFlag),1       
        ret
        
initvga:   ; Initalize lib and Hardware
        
        ld ix,SCPB 
        ld hl,PhysScreenPage        
        call initscrpb
if MAPALWAYS
        ld a, mapPage
        out (vMMUPageSel),a
        in a,(vMMUFrameL)
        ld (ix+FrameSaveL),a
        in a,(vMMUFrameH)
        ld (ix+FrameSaveH),a
        ld a,(ix+ScreenPageL)
        out (vMMUFrameL),a
        ld a,(ix+ScreenPageH)
        out (vMMUFrameH),a  
endif             
        ld c,1 ; clear including status line 
        call clrscr
        ld a,1
        out (cursorXReg),a 
        ld a,0
        out (cursorYReg),a
        ld a, 0F2H
        out (VgaCtrlReg),a
    
        ret
        

unmapvga:  
        push ix   
        ld ix,SCPB      
        ld a, mapPage
        out (vMMUPageSel),a
        ld a,(ix+FrameSaveL)
        out (vMMUFrameL),a
        ld a,(ix+FrameSaveH)
        out (vMMUFrameH),a
        pop ix 
        ret 



