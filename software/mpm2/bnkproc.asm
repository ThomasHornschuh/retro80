; bnkproc.asm contains all XIOS background processes running in banked memory
; include before common base label 

lldxy macro reg, x, y 
  ld reg, (y shl 8) or x 
endm



 if CONFPS2
   DEBUG equ 0 
   include ps2kbd.asm 
   if L_GERMAN 
     include lger.asm 
   endif

   ; PS/2 Keyboard uqcb                 
ps2wuqcb:   dw c1inq ; PS/2 is connected to console 1 
            dw converted ; msg adr -> PS2 converted Char buffer              
   
ps2stkmsg: db 'PANIC: STK Overflow ps2kbd',0    
   
  
ps2proc:   ; PS/2 keyboard handler process 
          in a,(PS2_DATA) ; clear  ps/2 controller 
          
          if Q_INPUT = 0  
            ld c,makeque
            ld de,c1inq
            call xdos           
          endif 
          
          ; main loop...
ps2pl1:   ld a,(ps2stk)
          cp 0c7h ; check for stack possible stack overflow
          jr z, ps2pl2 ; ok...
          or a ; as side effect clears carry 
          ld hl,ps2stk 
          sbc hl, sp ; sp should be greater then HL
          jr c, ps2pl2 ; if yes ok 
          ; else panic           
          ld hl, ps2stkmsg
          jp panic 
          
ps2pl2:   call ps2do  ; wait for input and process it 
          ld a,(convValid) ; check if we have a converted ASCII code  
          or a; set flags 
          jr z, ps2pl1 ; no .. loop again
          ; else write char to queue
          ld a,0
          ld (convValid),a ; clear semaphore 
                    
          ld c, writeque
          ld de, ps2wuqcb
          call xdos                    
          jr ps2pl1    
          
 endif
 
 
 if Q_INPUT 
 
   charESC equ 27   ; ASCII Code for ESC
    
; Keyboard decoder states 

    kbdstart    equ 0 ; Neutral
    kbdEsc      equ charESC ; ESC Received
    
    kbdstatus db kbdstart ; global Variable holding kbdstatus    
    
    writeuqcb: dw c0inwqcb ; Pointer to uqcb for active console 
    
; Status messages
    msgesc:  db "ESC",0
    
; Escape sequences:
; Console 0: ESC 1
; Console 1: ESC 2 

;; c0in Process - Console input 

  c0inentry:  ;; Entry point of process c0in

            ld c,makeque
            ld de,c0inq
            call xdos
            ld c,makeque
            ld de,c1inq
            call xdos 
            
  c0inloop:             
            in a, (UART0_STATUS)
            bit 7, a
            jr nz, c0inread
            ; When no wating char in UART wait for interrupt 
            ld c, xdos_flag_wait
            ld e, flag_uart0in         
            call xdos
            jr c0inloop
            
 c0inread:  ld a,(kbdstatus)
            or a  ;Set flags                          
            jr z, c0inl3 ; When kbstatus was zero -> normal processing 
            ; ESC handling
            ld a,0
            call updkbdstatus ; Reset kbd Status
            in a,(UART0_DATA) 
            cp '1' ; F1 pressed 
            jr z, c0f1
            cp '2' ; F2 pressed 
            jr z, c0f2 
            cp charESC; ; double ESC will be sent as ESC 
            jr z, c0inl2
            ; else 
            push af ; save current char
            ; write ESC 
            ld a,charESC
            ld (ch0write),a 
            ;ld c,cndwrque
            ld c, writeque
            ld de,(writeuqcb)
            call xdos
            pop af ; continue with current char 
            jr c0inl2
            
 c0inl3:    in a, (UART0_DATA)
            IF  CONINSWITCH
                ld hl,rawMode ; check rawMode flag 
                bit 7,(hl)
                jr nz, c0inl2 ; if set -> no ESC processing 
                cp charESC ; ESC Char ?
                jr nz, c0inl2 ; no
                call updkbdstatus ; store ESC char in kbdstatus, update status line             
                jr c0inloop; wait for next char...
            ENDIF                 
 c0inl2:    ld (ch0write),a 
            ;ld c,cndwrque
            ld c, writeque
            ld de, (writeuqcb) ; Output QCB
            call xdos           
            jr c0inloop

 c0f2:     ld hl,c1inwqcb
           
           jr c0inl4    
 c0f1:     ld hl,c0inwqcb
 c0inl4:   ld (writeuqcb),hl ; switch write queue 
           ; Update status line 
           ld c,a ; a still contains console select char '1' or '2' 
           lldxy de,77,39 
           ;ld de, (39 shl 8 ) or 77 ; line 40, colum 78 
           ld ix,scrpb0
           call writecharxy 
           jr c0inloop  
           
; Helper code for console input            
            
updkbdstatus: ; Reg A contains kbd status
              ; Also updates VGA status line           
           ld (kbdstatus),a
           cp 0 
           jr nz, uk1
           ld hl, msgblnk
           jr uk2
  uk1:     ld hl,msgesc
  uk2:     lldxy bc, 73,39
  wrstat:  ld ix,scrpb0 
           di
           call writestrxy
           ei 
           ret  
                
 endif          