;----------------------------------------------------------------------------------
;--+ RETRO80
;--+ An 8-Bit Retro Computer running Digital Research MP/M II and CP/M. 
;--+ Based on Will Sowerbutts  SOCZ80 Project:
;--+ http://sowerbutts.com/
;--+ RETRO80 extensions (c) 2015-2016 by Thomas Hornschuh
;--+ This project is licensed under the GPLV3: https://www.gnu.org/licenses/gpl-3.0.txt

; Banked portion of XIOS
; include betweem jump table and commonbase label 




; disk parameter header (16 bytes for each drive), see page 6-28 in CP/M 2.2 operating system manual
dpbase:
            ; disk 0 (A)
            dw 0            ; sector translation table (0 = no translation)
            dw 0            ; must be 0
            dw 0            ; must be 0
            dw 0            ; must be 0
            dw dirbf        ; DIRBUF (address of shared 128 byte scratch pad area)
            dw dpblk        ; DPB (disk parameter block)
            dw chk00        ; CSV (unique scratch pad used to check for changed disks)
            dw alv00        ; ALV (unique scratch pad for allocation information)
            ; end of disk 0

            ; disk 1 (B)
            dw 0            ; sector translation table (0 = no translation)
            dw 0            ; must be 0
            dw 0            ; must be 0
            dw 0            ; must be 0
            dw dirbf        ; DIRBUF (address of shared 128 byte scratch pad area)
            dw dpblk        ; DPB (disk parameter block)
            dw chk01        ; CSV (unique scratch pad used to check for changed disks)
            dw alv01        ; ALV (unique scratch pad for allocation information)
            ; end of disk 1
            
             ; disk 2 (C)
            dw 0            ; sector translation table (0 = no translation)
            dw 0            ; must be 0
            dw 0            ; must be 0
            dw 0            ; must be 0
            dw dirbf        ; DIRBUF (address of shared 128 byte scratch pad area)
            dw dpblk        ; DPB (disk parameter block)
            dw chk02        ; CSV (unique scratch pad used to check for changed disks)
            dw alv02        ; ALV (unique scratch pad for allocation information)
            ; end of disk 2

; Banked Disk routines 

seldsk:     ; select disk indicated by register C
            ld hl, 0    ; return code 0 indicates error
            ld a, c
            cp ndisks
            ret nc      ; return (with error code) if C >= ndisks ie illegal drive
            ld (curdisk), a ; store current disk
            ; compute proper disk parameter header address in HL
            ld l, c
            ld h, 0
            add hl, hl ; *2
            add hl, hl ; *4
            add hl, hl ; *8
            add hl, hl ; *16
            ; now HL = disk number * 16
            ld de, dpbase
            add hl, de ; HL = dpbase + disk number * 16
            ret

home:       ld c, 0
            ; fall through into seltrk
seltrk:     ; set track given by register BC
            ld a, c
            ld (curtrack), a
            ret

setsec:     ; set sector given by register BC
            ld a, c
            ld (cursector), a
            ret

sectran:    ; logical to physical sector translation
            ; HL=BC ie 1:1 mapping (no translation)
            ld h, b
            ld l, c
            ret

setdma:     ; set DMA address given by BC
            ld (curdmaaddr), bc ; may need to xfer to HL first?
            ret
			
            
; ---[ initialisation banked part ]-----------------------------    
   
systeminit: ; initialise system -- info in C, DE, HL.


            ; TH: Init VGA Library 
            ld a, 04H
            ld (mapPage),a
            call initvga
            
            ld hl, initmsg
            call strout
 
            ld ix,scrpb0
            ld hl,initmsg
            ld a,0FFH
            ld (preempted),a ; supress enabling of interrupts in VGA module
prmsg:      ld a,(hl)
            or a
            jr z,sysinit1
            ld c,a
            push hl 
            call vgaconout
            pop hl 
            inc hl 
            jr prmsg
            
                         
sysinit1:   ld (preempted),a ; A will be 0 already          
            ; TH: Prepare Interrupt mode 2 handler
            
			ld hl, intvector
			ld a,l 
			or a ; set flags
            jr nz, intpanic ; Go panic when intvector is not located at a page boundary 			
            ld a,h
            ld i,a  ; Load Z80 Interrupt table register 
            
            ; set up timer hardware to downcount at 50Hz
            ld a, TIMCMD_SEL_DOWNRESET
            out (TIMER_COMMAND), a

            ; (1000000 / 50) - 1 = 0x00004e1f
            ld a, 0x1f
            out (TIMER_VAL0), a
            ld a, 0x4e
            out (TIMER_VAL1), a
            xor a
            out (TIMER_VAL2), a
            out (TIMER_VAL3), a

            ; reset downcounter
            ld a, TIMCMD_DOWNRESET
            out (TIMER_COMMAND), a

            ; program timer control register
            in a, (TIMER_STATUS)
            set 6, a ; enable interrupt generation
            res 7, a ; clear any outstanding interrupt
            out (TIMER_STATUS), a

            ; program UART0 to deliver interrupts for rx, tx
            in a, (UART0_STATUS)
            and 0xf0
            or  0x0c
            out (UART0_STATUS), a

            ; program UART1 to deliver interrupts for rx, tx
            in a, (UART1_STATUS)
            and 0xf0
            or  0x0c
            out (UART1_STATUS), a
    
            ; tell CPU to use interrupt mode 2 (Z80 interrupt vector table )            
            im 2            
            ; note that we don't call ei ourselves, since MP/M-II does this once we return
            ld a,0 
            ld (preempted),a     
   if Q_INPUT or CONFPS2           
            call c0instart ; Start input process 
   endif            
            jp sysinitc ; jump to part in commom memory 
            
intpanic:	ld hl, panic_int
			jp panic             
panic_int:   db "INT CHK HLT",13,10,0 
			
            
            
        