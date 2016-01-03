    .z80
    org 100H
    
    vgastatusline equ 1


start:          
            ld a, 04H
            ld (mapPage),a
            call initvga
                        
            call wait2
            ld ix,scrpb0
            ld b,5
loop:       push bc
            ld hl,msg
            call strout
             
            pop bc
            djnz loop
            ;; Fill last line 
            ld (ix+cursX),0
            ld (ix+cursY),39
            ld hl,msg
            call strout
            
            call wait2
            
            ld b,5
loop2:      push bc
            ld hl,msg2
            call strout 
            call wait2
            pop bc
            djnz loop2  
            
            jp 0 ; Go back to cp/m
            

wait2:      ld c,8dh  ; XDOS Delay function
            ld de, 62*2 ; ~ 2 Seconds
            call 5H ; Call BDOS
            ret 
            
  include VGABASIC.ASM         

strout:     ; print string pointed to by HL
            
            ld a, (hl)
            cp 0
            ret z
            ld c,a
            push hl
            call vgaconout
            pop hl
            inc hl
            jr strout
            
            
msg:        db "The quick brown fox jumps over the lazy dog ",0DH,0AH,0
msg2:       db "Lore ipsum blablabla",0DH,0AH,0  

    .end start  