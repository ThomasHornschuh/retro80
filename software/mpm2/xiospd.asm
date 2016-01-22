; XIOS  Process descriptor and Queues
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
  
 
  
    
   ; Queue for console 1 
  c1inq:    dw 0 ; Link
            db 'con1inq ' ; name
            dw 1 ; msglen
            dw kbdqlen ; nmbmsgs
            ds 8 
  c1msg:    dw 0 ; msg count
            ds kbdqlen ; buffer
            
  ; Input qcb (for reader)          
  c1inrqcb:  dw c1inq
             dw ch1read ; msg adr
  ch1read:   db 0       

            
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

  endif 
  
  
;start process

  c0instart:    
           if   CONFPS2
                ld c, createproc
                ld de, ps2pd
                call xdos     
           endif                 
                ret
                

    
  
    
            