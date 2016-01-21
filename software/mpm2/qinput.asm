; Console Input Process descriptor and Queues
; required bnkproc.asm to be included before commombase label 

; XDOS functions 

    makeque     equ     134
    readque     equ     137
    creadque    equ     138
    writeque    equ     139
    cndwrque    equ     140
    createproc  equ     144
    getprocd    equ     09CH
    
    
; constants
    kbdqlen equ 8 
   
        
; global Variables/initalized data   
    rawMode: db 0; Flag: bit 7=1 -> Raw mode active     
    
	 msgRaw:  db "RAW",0
     msgblnk: db "   ",0     	 
	 
; Console 0 Input process
    
    c0inpd: 
	    if CONFPS2
	        dw ps2pd ; Link to next process
        else			
			dw 0 ; Link to next process
        endif 			
            db 0  ; status
            db 32 ; prio
            dw c0stktop ; SP
            db 'c0in    ' ; name
            db 0 ; console
            db 0h; memseg -> 0 system bank 
            ds 36
            
            dw 0c7c7h,0c7c7h,0c7c7h; Stack
            dw 0c7c7h,0c7c7h,0c7c7h; Stack
            dw 0c7c7h,0c7c7h,0c7c7h; Stack
  c0stktop: dw c0inentry ; Entry point
  
 if CONFPS2
  
  ps2pd:   dw 0 ; Link to next process 
            db 0  ; status
            db 15 ; prio give high prio to avoid loosing scan codes 
            dw ps2stktop ; SP
            db 'ps2kbd  ' ; name
            db 1 ; console
            db 0h; memseg -> 0 system bank 
            ds 36
            
  ps2stk:   dw 0c7c7h,0c7c7h,0c7c7h; Stack
            dw 0c7c7h,0c7c7h,0c7c7h; Stack
            dw 0c7c7h,0c7c7h,0c7c7h; Stack
            dw 0c7c7h,0c7c7h,0c7c7h; Stack
            dw 0c7c7h,0c7c7h,0c7c7h; Stack
 ps2stktop: dw ps2proc ; Entry point
  
 endif
  
  
  ; Queue for console 0 
  c0inq:    dw 0 ; Link
            db 'c0inque ' ; name
            dw 1 ; msglen
            dw kbdqlen ; nmbmsgs
            ds 8 
  c0msg:    dw 0 ; msg count
            ds kbdqlen ; buffer
            
  ; Input qcb (for reader)          
  c0inrqcb:  dw c0inq
             dw ch0read ; msg adr
  ch0read:   db 0       

; Output QCB (for writer)
  c0inwqcb:     dw c0inq
                dw ch0write ; msg adr
  ch0write:     db 0        
  
  
   ; Queue for console 1 
  c1inq:    dw 0 ; Link
            db 'c1inque ' ; name
            dw 1 ; msglen
            dw kbdqlen ; nmbmsgs
            ds 8 
  c1msg:    dw 0 ; msg count
            ds kbdqlen ; buffer
            
  ; Input qcb (for reader)          
  c1inrqcb:  dw c1inq
             dw ch1read ; msg adr
  ch1read:   db 0       

; Output QCB (for writer)
  c1inwqcb:     dw c1inq
                dw ch0write ; !! Both queues share the same message buffer 
                
  
 
  ; This is an entry point called from BDOS/User program over the conin vector 
  conin0q: ;; XIOS conin reading from queue
            if CONINSWITCH
            call checkraw 
            endif             
            ld c,readque
            ld de, c0inrqcb ; Read qcb
            call xdos
            
            ld a,(ch0read)            
            ret 
            
  const0q: ; XIOS constat
            if CONINSWITCH
            call checkraw 
            endif 
            ld a,(c0msg) ; Peek in queue len 
            or a ; set flags  
            ret z ; When no msg just return with a=0            
            ld a,0ffh               
            ret  
            
  conin1q: ;; XIOS conin reading from queue
              
            ld c,readque
            ld de, c1inrqcb ; Read qcb
            call xdos
            
            ld a,(ch1read)            
            ret 
            
  const1q: ; XIOS constat 
            ld a,(c1msg) ; Peek in queue len 
            or a ; set flags  
            ret z ; When no msg just return with a=0            
            ld a,0ffh               
            ret             


if CONINSWITCH            
; Helpers 
checkraw: ; Checks if raw mode is set in the current process descriptor
            ld c,getprocd
            call xdos
            ld a,h
            or l  ; NULL PTR check
            ret z 
            ld de, 6 ; offset of name field in PD
            add hl,de
            ld a,(hl) ; Check first char of PD - bit 7 will be 1 when raw mode 
            and 80H; Mask all other bits            
            ld hl,rawMode
            cp (hl) ; Check if mode has changed
            ret z ; no -> return
            ld (hl),a ; Set raw mode flag           
            or a ; set flags 
            jr z, noRaw
            ld hl,msgRaw
            jr chkraw1  
  noRaw:    ld hl,msgblnk
  chkraw1:  ldxy bc, 69,39 
            push ix ; for CP/M programs that dont expect the BIOS using Z80 registers
            ld ix,scrpb0 
            di
            call writestrxy
            ei 
            pop ix 
            ret  
ENDIF 

;start c0in process

  c0instart:    ld c, createproc
                ld de, c0inpd
                call xdos               
                ret
                

    
  
    
            