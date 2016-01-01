; Console Input Process and Queues

; XDOS functions 

	makeque 	equ 	134
	readque 	equ 	137
	creadque	equ     138
	writeque 	equ 	139
	createproc 	equ 	144
	

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
  
  ; Queue
  c0inq: 	dw 0 ; Link
			db 'c0inque ' ; name
			dw 1 ; msglen
			dw 4 ; nmbmsgs
			ds 8 
  c0msg:    dw 0 ; msg count
			ds 4 ; buffer
			
  ; Input qcb (for reader)			
  c0inrqcb:  dw c0inq
			 dw ch0read ; msg adr
  ch0read:   db 0 		

; Output QCB (for writer)
  c0inwqcb:  	dw c0inq
				dw ch0write ; msg adr
  ch0write:   	db 0 		
  
 
  
  ;; c0in Process - this is a sepate process to be started 
  c0inentry:  ;; Entry point of process c0in

			ld c,makeque
			ld de,c0inq
			call xdos
			ld hl,msg02
			call strout
			
  c0inloop: 
		    ;   call uart0in ; Wait for Input (in reg A)
     
		    ; Test with XDOS Poll
            ld c, xdos_poll
            ld e, poll_uart0in
            call xdos
			in a, (UART0_DATA)
			ld (ch0write),a 
		  	ld c,writeque
			ld de, c0inwqcb ; Output QCB
			call xdos           
			jr c0inloop
				
  
  ; This is an entry point called from BDOS/User program over the conin vector 
  conin0q: ;; XIOS conin reading from queue
			  
			ld c,readque
			ld de, c0inrqcb ; Read qcb
			call xdos
			
  c0ret:	ld a,(ch0read)            
			ret 
			
  const0q: ; XIOS constat 
            ld a,(c0msg) ; Peek in queue len 
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
	
  
    
			