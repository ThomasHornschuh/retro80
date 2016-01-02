; Console Input Process and Queues

; XDOS functions 

	makeque 	equ 	134
	readque 	equ 	137
	creadque	equ     138
	writeque 	equ 	139
	cndwrque    equ 	140
	createproc 	equ 	144
	
	charESC equ 27 	; ASCII Code for ESC
	
; Keyboard decoder states (to decode ALT+F1..F2)

	kbdstart 	equ 0 ; Neutral
	kbdEsc	 	equ charESC ; ESC Received
	
	
	kbdstatus: db  kbdstart
 	
	writeuqcb: dw c0inwqcb   
	
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
            ld c, xdos_flag_wait
            ld e, flag_uart0in		   
            call xdos
 c0inread:	ld a,(kbdstatus)
			or a  ;Set flags              
            in a, (UART0_DATA)
            jr z, c0inl3 ; When kbstatus was zero -> normal processing 
			; ESC handling
			ld hl,kbdstatus
			ld (hl),0 ; Reset kbd Status 
			cp '1' ; F1 pressed 
			jr z, c0f1
			cp '2' ; F2 pressed 
			jr z, c0f2 
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
            
 c0inl3:	cp charESC ; ESC Char ?
			jr nz, c0inl2 ; no 
			ld (kbdstatus),a ; store ESC char in kbdstatus 
			jr c0inloop; 
							
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
		   jr c0inloop	
		   	
				
  
  ; This is an entry point called from BDOS/User program over the conin vector 
  conin0q: ;; XIOS conin reading from queue
			  
			ld c,readque
			ld de, c0inrqcb ; Read qcb
			call xdos
			
			ld a,(ch0read)            
			ret 
			
  const0q: ; XIOS constat 
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
				ld hl,msg01
				call strout
				ret
				

    msg01:    db "crp OK",13,10,0 			
	msg02:    db "crq OK",13,10,0 
	msg03:	  db "poll OK",13,10,0 	
	
  
    
			