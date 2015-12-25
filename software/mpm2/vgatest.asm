
   org 100H

  


start:
			call initvga
			ld a, 04H
			ld (mapPage),a
			ld b,5
loop:       push bc
			ld hl,msg
			call strout
			pop bc
            djnz loop
			ret ; Go back to cp/m
			
			
  include vgabasic.asm			

strout:     ; print string pointed to by HL
            
            ld a, (hl)
            cp 0
            ret z
            ld c,a
			ld ix,scrpb0
			push hl
            call vgaconout
			pop hl
            inc hl
            jr strout
			
			
msg:		db "The quick brown fox jumps over the lazy dog ",0

endlabel:			