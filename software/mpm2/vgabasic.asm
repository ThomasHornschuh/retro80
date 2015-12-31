; BASIC Video Output Routines and data
; to be included in e.g. XIOS

; VGA Video output handling


; 

; IO Registers

CursorXReg  equ 38H ; 1..80 !!
CursorYReg  equ 39H ; 0..39 
VgaCtrlReg  equ 3AH 

vMMUPageSel equ 0F8H
vMMUFrameH  equ 0FCH
vMMUFrameL  equ 0FDH

; Phyiscal Page address of screen buffer

PhysScreenPage equ 2002H

columns    equ 80
physlines  equ 40

 if vgastatusline
  lines      equ physlines-1   
 else
  lines equ physlines
 endif   
screensize equ columns*lines
physsize equ columns*physlines


defscrpb macro n

; Screen parameter block macro
scrpb&n:
            DB 0  ; X Cursor Position 0..79
            DB 0  ; Y Cursor Position 0..39 
            DW 0  ; Physical Page number of video buffer
            DB 0  ; <>0 => spb points to real vga frame buffer - update cursor registers...
endm
            
;Offsets into screen parameter block            
cursX  equ  0
cursY  equ  cursX+1
screenPage equ cursY+1
screenPageL equ screenPage
screenPageH equ screenPageL+1
physFlag    equ ScreenPageH+1


mapVPage macro 
        ld a, (mapPage)
        out (vMMUPageSel),a
        in a,(vMMUFrameL)
        ld (FrameSaveL),a
        in a,(vMMUFrameH)
        ld (FrameSaveH),a
        ld a,(ix+ScreenPageL)
        out (vMMUFrameL),a
        ld a,(ix+ScreenPageH)
        out (vMMUFrameH),a
endm

unmapVPage macro
        ld a, (mapPage)
        out (vMMUPageSel),a
        ld a,(FrameSaveL)
        out (vMMUFrameL),a
        ld a,(FrameSaveH)
        out (vMMUFrameH),a
endm        

getmapva:   ; Calculate virtual address of mapPage
            ld a, (mapPage)             
            ;; Shift mapPage 4 bit left to calc virtual address
            add a,a
            add a,a
            add a,a
            add a,a           
            ret


		
writechar:  ; Reg C contains char -- IX contains scrpb
            ; The critical part of the code (where the video buffer is mapped into virtual address space) does not use the stack
            ; and runs with interrupts disabled. This will avoid any interferences between SP and video mapping

            
            ld a,(ix+cursY)
            call mult80 ; hl = a*80
            ld e,(ix+cursX)
            ld d,0
            add hl,de ; hl is now cursY*80 + cursX
            call getmapva ; get virtual address of screen map 
            or h ; Merge  with high order byte of screen offest
            ld h,a 
                        
            di ; disable interrupts 
            mapVPage
            ld (hl),c ; finally output :-)
            unmapVPage
            ei              
            ret             
            
clrscr:     ; Clears the screen (fill with blank), IX ontains scrpb. Again code runs with interrupts disabled and without stack usage
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
clrall:		ld de, physsize
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
			call getmapva
			ld (scratch),a ; Save ...
			or h ; Merge map Page into H
			ld d,a ; Move result to DE
			ld e,l 
			
			pop hl 
			; Now HL contains ptr to string and DE contains ptr to screen buffer
			mapVPage 
wxy0:		ld a, (hl)
            cp 0
            jr z, wxy1 ; finish 
            ldi  ; (DE)<-(HL), increment ptrs 
			; The following code ensures that DE is not leaving the 4K Page boundary
			ld a,d
			and 0FH 
			ld d,a 	
			ld a,(scratch)
			or d 
			ld d,a 
            jr wxy0 
wxy1:		unmapVPage		
			ret 	
			
			
			
			
scroll:     ; Scrolls screen 1 line (append empty line at end ), ix points to scrpb
            call getmapva
            ld d,a
            ld e,0
            ld h,a
            ld l,columns 
            ld bc, columns*(lines-1)
            di
            mapVPage
            ldir
			; clear bottom line
			ex de,hl ; de points to begin of last line -> HL
			ld b,columns
scrl1:		ld (hl),' '
			inc hl
			djnz scrl1				
            unmapVPage
            ei
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
        ld a,c
		cp 0dh ; CR ?
		jr z, vccr
		cp 0ah ; LF ?
		jr z, vcolf 
		cp 08h ; backspace
		jr z, vcobackspace 
		; no regognized control chars -> output 
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
        

        
        
initscrpb: ; IX = Address of scrpb HL=ScreenPage
        
        ld (ix+ScreenPageL),l
        ld (ix+ScreenPageH),h
        ld (ix+cursX),0
        ld (ix+cursY),0
        ld (ix+physFlag),1
        ret
        
initvga:   ; Initalize lib and Hardware
        ld ix,scrpb0
        ld hl,PhysScreenPage        
        call initscrpb
		ld c,1 ; clear including status line 
        call clrscr
        ld a,1
        out (cursorXReg),a 
        ld a,0
        out (cursorYReg),a
        ld a, 0F2H
        out (VgaCtrlReg),a
        ret
        
        
        

; Variables for VGA video controller

defscrpb 0  ; Allocate one parameter block for physical screen buffer 
           ; Callers can allocate more block for virtual screen buffers (in main memory)
           
mapPage:    db 0FH ; Virtual Page to map screen buffer to - can be changed 
FrameSaveL: ds 1  ; Locations to save orginal mapping of mapPage 
FrameSaveH: ds 1  ; 
scratch: ds 2 ; Scratch area 