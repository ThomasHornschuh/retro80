;----------------------------------------------------------------------------------
;--+ RETRO80
;--+ An 8-Bit Retro Computer running Digital Research MP/M II and CP/M. 
;--+ Based on Will Sowerbutts  SOCZ80 Project:
;--+ http://sowerbutts.com/
;--+ RETRO80 extensions (c) 2015-2016 by Thomas Hornschuh
;--+ This project is licensed under the GPLV3: https://www.gnu.org/licenses/gpl-3.0.txt

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
  
 
  
    
   ; Queue for Console 0 
   ; For historical reasons it is labled console 1 throughout the XIOS
   ; But at least the queue name is corrected now. 
  c1inq:    dw 0 ; Link
            db 'con0inq ' ; name
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
                

    
  
    
            