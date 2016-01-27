; stage1 is in the ROM; it loads the first 4096 bytes from the disk into RAM
; from 0x1000 upwards, then jumps to 0x1000, with the first physical page of 
; the boot disk in HL.

;-----------------------------------------------------------
; TH: conditional defines 
;-----------------------------------------------------------
MPM         equ 0 ; This is not a MP/M BIOS 
VGACONS     equ 1 ; Enable VGA and PS/2 Console 
RUNTPA      equ 0 ; Test RUN from CP/M TPA 

;-----------------------------------------------------------
; end conditional defines 
;-----------------------------------------------------------

;-----------------------------------------------------------
                       ; TH: Boot parameters
bios        equ 0F500H ; Change this ot the org of the cbios  
bootpgs     equ 03H    ; Number of 4K Pages to boot 
loadbase    equ 0D000H ; Boot load base address 
mybase      equ 1000H
   
                 
;-----------------------------------------------------------


UART0_STATUS  equ 0x0000 ; [7: RX READY] [6: TX BUSY] [6 unused bits]
UART0_DATA    equ 0x0001
MMU_PAGESEL   equ 0xF8
MMU_PERM      equ 0xFB
MMU_FRAMEHI   equ 0xFC
MMU_FRAMELO   equ 0xFD

; Page mapping of frame buffer 
CRTPAGE equ 03H ; 

           
            
            if RUNTPA
              org 100H   
              ; Simulate transfer from boot stage 1 
              ld hl,400H
            endif   
            
             org mybase ; load address
start:       ; stash the boot disk first physical page address
            ld (diskpage), hl

            if VGACONS   
              call crtinit 
            endif 


             ; unmap the ROM and replace it with RAM
            ld a, 0xf
            out (MMU_PAGESEL), a
            out (MMU_FRAMELO), a
            xor a
            out (MMU_FRAMEHI), a
            ; ROM has left the building

           
            ; move our stack
            ld hl, stackptr
            ld sp, hl
                     
            ; say hello
            ld hl, loadmsg
            call strout
            ld hl, (loadaddr)
            call outwordhex
            ld hl, frommsg
            call strout

            ; recover disk address
            ld hl, (diskpage)

nextpage:   inc hl                  ; OS image starts as diskpage+1
            call outwordhex         ; print page number
            ld c, 0x20              ; print space
            call conout
            ld a, 0x2               ; map disk page at 0x2000
            out (MMU_PAGESEL), a
            ld a, h
            out (MMU_FRAMEHI), a
            ld a, l
            out (MMU_FRAMELO), a
            push hl                 ; save page number
            ld de, (loadaddr)       ; retrieve target address
            ld hl, 0x2000           ; source address
            ld bc, 0x1000           ; transfer 4KB
            ldir                    ; copy copy copy
            ld (loadaddr), de       ; save target address
            pop hl                  ; restore page number
            ; more, sir?
            ld a, (pagecount)
            dec a
            ld (pagecount), a
            jr nz, nextpage

            ; map back RAM
            ld a, 0x2
            ld a, 0x2
            out (MMU_PAGESEL), a
            out (MMU_FRAMELO), a
            xor a
            out (MMU_FRAMEHI), a

            ; announce jump
            ld hl, jmpmsg
            call strout

            ; read the boot vector (written into the last four bytes of our 4K boot sector)
            
            ld hl, (bootvector)
            call outwordhex
            ld hl, excited
            call strout
            ld hl, (diskpage) ; tell the OS where to find the boot disk
            ld a, (iobyte)    ; tell OS where to output console 
            ld ix, (bootvector)
            jp (ix) ; boot

; functions

;-----------------------------------------------------
; TH: conout either runs on VGA or on 

if VGACONS

; Because the CP/M BIOS is not doing any multitasking and bank switching we don't need
; any special critical section handling when tampering with the MMU
; so we can define the mmuEnter and mmuLeave Marcos  empty 

mmuEnter macro
endm

mmuLeave macro     
endm
  vgastatusline equ 1  

 include ../mpm2/vgabasic.asm 
 
 
 
  crtinit: 
       ld a, CRTPAGE 
       ld (mapPage),a
       call initvga  
       ret 
 
  conout: ; conout for VGA or serial port 
       ld a,(iobyte) ; Check iobyte 
       or a 
       jr z, uconout ; 0 -> UART  
       push hl 
       push bc
       push de 
       ld ix,scrpb0        
       call vgaconout
       pop de 
       pop bc 
       pop hl 
       ret 
else
 conout: ; identically to uconout below     
endif

 uconout:     ; write chracter from C to console
            in a, (UART0_STATUS)
            bit 6, a
            jr nz, conout ; loop again if transmitter is busy
            ld a, c
            out (UART0_DATA), a ; transmit character
            ret  


strout:     ; print string pointed to by HL
            ld a, (hl)
            cp 0
            ret z
            ld c, a          
            call conout           
            inc hl
            jr strout

outwordhex: ; print the word in HL as a four-char hex value
            ld a, h
            call outcharhex
            ld a, l
            call outcharhex
            ret

outcharhex: ; print byte in A as two-char hex value
            ld d, a ; copy
            rra
            rra
            rra
            rra
            call outnibble
            ld a, d
            call outnibble
            ret

outnibble:  and 0x0f
            cp 10
            jr c, numeral
            add 0x07
numeral:    add 0x30
            ld c, a
            call conout
            ret

        
            
; data
diskpage:   dw 0
loadmsg:    db "RAM disk bootstrap loading to ", 0 
frommsg:    db " from pages ", 0
jmpmsg:     db "... jump to ", 0
excited:    db "!",0DH,0AH, 0

iobyte:     db 1 ; 0 -> UART(tty), 1 -> vga (crt)

; pad to 4KB
pad:        ds start+0x1000-$-10

stackptr:   ; put our stack below config

; configuration -- can be overridden easily since it's at the end of the sector.
; if you add more variables, add them here (ie maintain addresses of existing stuff) and adjust padding.
loadaddr:   dw loadbase  ; address to start loading, must be a multiple of 0x1000 (pad the start of your payload if you need otherwise)
pagecount:  db bootpgs      ; number of 4KB pages to read
            db 0x00         ; ignored, must be zero (high byte for future 16-bit page count)
bootvector: dw bios         ; virtual address to jump to (org of cbios.asm )
bootstrap:  db 0xba, 0xbe   ; ROM checks for this code to indicate bootability
myorg:      dw mybase       ; ROM will load our 4K page to this address in memory
