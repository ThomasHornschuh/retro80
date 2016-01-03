; Console Input Process and Queues

; XDOS functions 

	makeque 	equ 	134
	readque 	equ 	137
	creadque	equ     138
	writeque 	equ 	139
	cndwrque    equ 	140
	createproc 	equ 	144
	getprocd	equ 	09CH
	
	charESC equ 27 	; ASCII Code for ESC
	
; Keyboard decoder states (to decode ALT+F1..F2)

	kbdstart 	equ 0 ; Neutral
	kbdEsc	 	equ charESC ; ESC Received
	
	
	kbdstatus: db  kbdstart
 	
	writeuqcb: dw c0inwqcb
    rawMode: db 0; Flag: bit 7=1 -> Raw mode active 	
	
; Status messages
    msgesc:  db "ESC",0
    msgblnk: db "   ",0  	
	msgRaw:  db "RAW",0 
	
	
; Escape sequences:
; Console 0: ESC 1
; Console 1: ESC 2 
	
   kbdqlen equ 8 

; Console 0 Input process
	
	c0inpd: dw 0 ; Link to next process	
			db 0  ; status
			db 32 ; prio
			dw c0stktop ; SP
			db 'c0in    ' ; name
			db 0 ; console
			db 0ffh; memseg
			ds 36
			
			dw 0c7c7h,0c7c7h,0c7c7h; Stack
			dw 0c7c7h,0c7c7h,0c7c7h; Stack
			dw 0c7c7h,0c7c7h,0c7c7h; Stack
  c0stktop:	dw c0inentry ; Entry point
  
  
  
  
  ; Queue for console 0 
  c0inq: 	dw 0 ; Link
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
  c0inwqcb:  	dw c0inq
				dw ch0write ; msg adr
  ch0write:   	db 0 		
  
  
   ; Queue for console 1 
  c1inq: 	dw 0 ; Link
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
  c1inwqcb:  	dw c1inq
				dw ch0write ; !! Both queues share the same message buffer 
 	
 
  
  ;; c0in Process - this is a sepate process to be started 
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
			
 c0inread:	ld a,(kbdstatus)
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
            
 c0inl3:	in a, (UART0_DATA)
            ld hl,rawMode ; check rawMode flag 
			bit 7,(hl)
			jr nz, c0inl2 ; if set -> no ESC processing 
            cp charESC ; ESC Char ?
			jr nz, c0inl2 ; no
            call updkbdstatus ; store ESC char in kbdstatus, update status line 			
			jr c0inloop; wait for next char...
							
 c0inl2:	ld (ch0write),a 
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
		   ldxy de,77,39 
		   ;ld de, (39 shl 8 ) or 77 ; line 40, colum 78 
		   ld ix,scrpb0
		   call writecharxy	
		   jr c0inloop	
		   	
updkbdstatus: ; Reg A contains kbd status
			  ; Also updates VGA status line 		   
		   ld (kbdstatus),a
		   cp 0 
		   jr nz, uk1
		   ld hl, msgblnk
           jr uk2
  uk1:     ld hl,msgesc
  uk2:     ldxy bc, 73,39
  wrstat:  ld ix,scrpb0	
           call writestrxy
		   ret 	
	

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
	        jr wrstat
			
  
  ; This is an entry point called from BDOS/User program over the conin vector 
  conin0q: ;; XIOS conin reading from queue
			call checkraw  
			ld c,readque
			ld de, c0inrqcb ; Read qcb
			call xdos
			
			ld a,(ch0read)            
			ret 
			
  const0q: ; XIOS constat
			call checkraw 
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
  

;start c0in process

  c0instart: 	ld c, createproc
				ld de, c0inpd
				call xdos
				;ld hl,msg01
				;call strout
				ret
				

;   msg01:    db "crp OK",13,10,0 			
;	msg02:    db "crq OK",13,10,0 
;	msg03:	  db "poll OK",13,10,0 	
	
  
    
			