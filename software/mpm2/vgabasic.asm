; BASIC Video Output Routines and data
; to be included in e.g. XIOS

; VGA Video output handling

; IO Registers

CursorXReg	equ 38H ; 1..80 !!
CursorYReg	equ 39H ; 0..39 
VgaCtrlReg	equ 3AH	

vMMUPageSel equ 0F8H
vMMUFrameH	equ 0FCH
vMMUFrameL  equ 0FDH

; Phyiscal Page address of screen buffer

PhysScreenPage equ 2002H


defscrpb macro n

; Screen parameter block macro
scrpb`n`:
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


writechar:  ; Reg C contains char -- IX contains scrpb
            ; The critical part of the code (where the video buffer is mapped into virtual address space) does not use the stack
			; and runs with interrupts disabled. This will avoid any interferences between SP and video mapping

			
			ld a,(ix+cursY)
			call mult80 ; hl = a*80
			ld e,(ix+cursX)
			ld d,0
			add hl,de ; hl is now cursY*80 + cursX
			ld a, (mapPage)				
			ld d,a
			;; Shift mapPage 4 bit left to calc virtual adress
			ld b,4
wcl1:       sla d
			djnz wcl1 	
			ld e,0
			add hl,de ; now HL contains the virtual address of cursX,cursY
						
			di ; disable interrupts 
			mapVPage
			ld (hl),c ; finally output :-)
			unmapVPage
			ei  			
            ret 			
			


			
mult80:    ; Mutiply a with 80 return result in hl, will destroy b and de
           ;  hl = a*64 + a*16

		ld b,6  
		ld e,a 
        ld d,0 		
mlp1:	sla e
        rl d
		djnz mlp1 
        ld l,a 
		ld h,0 
        ld b,4
mlp2:	sla l
		rl h
		djnz mlp2
		add hl,de
		ret
		
		
vgaconout:  ; Basic conout procedure  Reg C contains char -- IX contains scrpb
		call writechar
		ld a,(ix+cursX)
		inc a
		cp 80
	    jp nz, vco1 ; no end of line - just update cursX
		; "Line wrap"
		ld a,(ix+cursY) ; process Y
		inc a
		cp 40
		jp nz, vco2
		; for the moment we just start over at the beginning of the screen - no scrolling
		xor a ; a:=0 
vco2:   ld (ix+cursY),a
		xor a ; after changing Y x will always be 0 
vco1:   ld (ix+cursX),a	

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
		ld a,1
		out (cursorXReg),a 
		ld a,0
		out (cursorYReg),a
		ld a, 0F2H
		out (VgaCtrlReg),a
		ret
		
		
		

; Variables for VGA video controller

defscrpb 0 ; Allocate one parameter block for physical screen buffer 
           ; Callers can allocate more block for virtual screen buffers (in mein memory)
		   
mapPage db 0FH ; Virtual Page to map screen buffer to - can be changed 
FrameSaveL ds 1  ; Locations to save orginal mapping of mapPage 
FrameSaveH ds 1  ; 