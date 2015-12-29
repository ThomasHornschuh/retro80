; program vgaecho

	org 100H
	
start:
		ld a, 04H
        ld (mapPage),a
        call initvga

mloop:		
		ld c,1 ; BDOS Console Input
		call 5
		ld c,a
		ld ix,scrpb0
		call vgaconout
		jr mloop
		
	include vgabasic.asm
	
	
	.end start 