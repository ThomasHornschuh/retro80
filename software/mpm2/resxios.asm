; SOCZ80 MP/M 2.1 XIOS
; 2013-11-19 Will Sowerbutts
; use zmac --rel to assemble this, then use link-80 under CP/M 2.2 to produce a .SPR file
;   LINK RESXIOS [OS]

; handy cmdline for testing cycle: ./build && ( echo "rboot 200"; sleep 0.1; ~/projects/socz80/software/cpm2.2/receive/sendmany ./zout/resxios.rel ; sleep 0.1; echo "link resxios [os]"; sleep 0.2; echo "era bnkxios.spr"; sleep 0.1; echo "ren bnkxios.spr=resxios.spr"; sleep 0.1; echo "gensys \$a" ; sleep 0.5; echo "mpmldr" ) > /dev/ttyUSB1

    public commonbase


.z80        ; tell zmac to prefer z80 mnemonics
startlabel: ; important that this assembles to offset 0 (or the linker will add a jump)

; Conditional defines 

Q_INPUT       equ 0 ;   Queued input for UART0 
CONINSWITCH   equ 1 ;   Enable  Console switch funktion for UART0  
CONFPS2       equ 1 ;   PS/2 Keyboard support
L_GERMAN      equ 1 ;   German Layout  
MMU_SECTION   equ 1 ;   Enable MMU critical section handling 
MPM           equ 1 ;   we are MP/M   
DISKDEBUG     equ 0 ; 


if MMU_SECTION 

mmuEnter macro owner
        ld a,owner 
        call enterMMU
endm
        
mmuLeave macro
        call leaveMMU
endm

else

mmuEnter macro 
endm

mmuLeave macro
endm 
endif  
 
; IO Ports 

UART0_STATUS   equ 0x00   ; [7: RX READY] [6: TX BUSY] [6 unused bits]
UART0_DATA     equ 0x01

UART1_STATUS   equ 0x28   ; [7: RX READY] [6: TX BUSY] [6 unused bits]
UART1_DATA     equ 0x29

MMU_PAGESEL    equ 0xF8
MMU_PERM       equ 0xFB
MMU_FRAMEHI    equ 0xFC
MMU_FRAMELO    equ 0xFD
GPIO_INPUT     equ 0x20
GPIO_OUTPUT    equ 0x21

TIMER_STATUS            equ 0x10
TIMER_COMMAND           equ 0x11
TIMER_VAL0              equ 0x14
TIMER_VAL1              equ 0x15
TIMER_VAL2              equ 0x16
TIMER_VAL3              equ 0x17

TIMCMD_INTACK           equ 0x00
TIMCMD_UPRESET          equ 0x01
TIMCMD_UPLATCH          equ 0x02
TIMCMD_DOWNRESET        equ 0x03
TIMCMD_SEL_UPVAL        equ 0x10
TIMCMD_SEL_UPLATCH      equ 0x11
TIMCMD_SEL_DOWNVAL      equ 0x12
TIMCMD_SEL_DOWNRESET    equ 0x13

PS2_CONTROL              equ 040H ; PS2 Control and status Port
PS2_DATA                 equ 041H ; PS2 Data Port 

; XDOS function numbers
xdos_terminate equ 0
xdos_poll      equ 131
xdos_flag_wait equ 132
xdos_flag_set  equ 133

; device numbers (come back, enum, all is forgiven!)
; it seems we can use any numbers/mapping we like here
poll_uart0out  equ 0
poll_uart1out  equ 1
poll_uart0in   equ 2
poll_uart1in   equ 3

; flag numbers (1, 2 are already taken by the os)
; documentation recommends using interrupts for input only
flag_uart0in   equ 6
flag_uart1in   equ 7
flag_uart0out  equ 8
flag_uart1out  equ 9
flag_ps2       equ 10 ; TH PS2 Data ready flag 

            ; BIOS vectors (largely CP/M compatible)
            jp commonbase   ; terminate process
            jp wboot        ; warm boot (terminate process)
            jp const        ; console status
            jp conin        ; console character in
            jp conout       ; console character out
            jp list         ; list character out
            jp unimplemented; not used by MPM/2
            jp unimplemented; not used by MPM/2
            jp home         ; move disk head to home position
            jp seldsk       ; select disk
            jp seltrk       ; set track number
            jp setsec       ; set setor number
            jp setdma       ; set DMA address
            jp read         ; read disk
            jp write        ; write disk
            jp listst       ; return list status
            jp sectran      ; sector translate
            ; XIOS vectors (for MP/M)
            jp selmemory    ; select memory
            jp polldevice   ; poll device
            jp startclock   ; start clock tick
            jp stopclock    ; stop clock tick
            jp exitregion   ; leave critical region
            jp maxconsole   ; get maximum console number
            jp systeminit   ; initialise system
            ; idle procedure is either a jump to our idle routine, or three 0 bytes
            ; db 0, 0, 0      ; uncomment this if mp/m should poll devices when idling
            jp idle         ; custom idle procedure (optional)

            include bnkproc.asm ; XIOS Background processes running in banked memory 
            include banked.asm ; Banked parts of the XIOS... 
  

bankedsize  equ $-startlabel  
           
            ds 256- (bankedsize mod 256) ; padding to page boundary
            
            ; gensys locates the 256 byte page with the commonbase always completly in common
            ; memory. The padding above enforces starting a new page here
            ; so everything from here on will be on a 256 byte page boundary in common area
            ; e.g. address C000
            
intvector:  dw interrupt_handler; Z80 IM Mode 2 Interrupt table            
            
; everything AFTER the "commonbase" label is located in "common memory".
; everything BEFORE this is in banked memory
commonbase: jp wboot
swtuser:    jp $-$          ; vector computed by GENSYS.COM; restore user memory bank
swtsys:     jp $-$          ; vector computed by GENSYS.COM; restore BNKBDOS memory bank
pdisp:      jp $-$          ; vector computed by GENSYS.COM; calls dispatcher (scheduler)
xdos:       jp $-$          ; vector computed by GENSYS.COM; make XDOS function call
sysdat:     dw $-$          ; value computed by GENSYS.COM; address of system data page

        
ndisks      equ 3           ; number of disks we defined
nconsoles   equ 2           ; number of consoles we support

; disk parameter block (can be shared by all disks with same configuration)
; my RAM disks are each 2MB in size;
;     track is 16384 bytes (128 x 128 sectors per track)
;     there are 128 tracks (128 x 128 x 128 = 2MB)
;     track 0 is reserved for the operating system, so there are 2048-16 = 2032 user sectors, and 16KB reserved for OS boot storage (which is plenty)
; using 1K sectors here resulted in problems. don't do that! with 4K sectors it seems much happier.
dpblk:
            dw 128          ; SPT: number of 128 byte sectors per track
            db 5            ; BSH: block shift factor (see manual for table)
            db 31           ; BLM: block mask (see manual for table)
            db 1            ; EXM: extent mask (see manual for table, using entries marked N/A turns out to be a bad idea!)
            dw 508          ; DSM: (disk bytes / block bytes) - 1, change alv00/01 etc if you change this; this is the number of the last sector on the disk, excluding system tracks (ie more system tracks -> this gets smaller)
            dw 511          ; DRM: directory max entries - 1
            db 0xf0         ; AL0: directory sector allocation bitmask byte 0
            db 0x00         ; AL1: directory sector allocation bitmask byte 1
            dw 0            ; CKS: check size (change chk00/01 etc if you change this)
            dw 1            ; OFF: track offset (number of system tracks)

; XIOS functions follow
wboot:      ; request XDOS terminate this process
            ld c, xdos_terminate
            jp xdos

ptbljmp:    ; look up procedure address in table following CALL, jump to it
            ; console number is in D; take care not to destroy C
            mov a, d
            cp nconsoles
            jr c, tbljmp
            pop af ; throw away table (return) address
            xor a  ; with return A=0 ("not ready")
            ret
tbljmp:     add a  ; *2
            pop hl ; retrieve table address (it's the return address)
            ld e, a
            ld d, 0
            add hl, de
            ld e, (hl) ; get procedure address low byte
            inc hl
            ld d, (hl) ; get procedure address high byte
            ex de, hl
            jp (hl)    ; jump to procedure

; ---[ console demux ]---------------------------------

const:     
            call ptbljmp
        if Q_INPUT
            dw const0q
            dw const1q 
        else
            dw uart0pollin
            if CONFPS2
              dw const1q
            else  
              dw uart1pollin
            endif   
        endif 
           

conin:      
            call ptbljmp
        if Q_INPUT  
            dw conin0q ; Queued input 
            dw conin1q
        else
            dw uart0in
            if CONFPS2
              dw conin1q 
            else   
              dw uart1in
            endif   
        endif       
            

conout:    
            call ptbljmp
            dw uart0out
            dw vconout 
            

; ---[ UART status ]--------------------------------
; Not really needed in the future ....
uart0pollin:
            in a, (UART0_STATUS)
            bit 7, a
            jr z, notready
            jr ready

uart1pollin:
            in a, (UART1_STATUS)
            bit 7, a
            jr z, notready
            jr ready

uart0pollout:
            in a, (UART0_STATUS)
            bit 6, a
            jr nz, notready
            jr ready

uart1pollout:
            in a, (UART1_STATUS)
            bit 6, a
            jr nz, notready
            jr ready

notready:   xor a
            ret
ready:      ld a, 0xff
            ret

; ---[ UART read ]----------------------------------

if Q_INPUT = 0 
uart0in:    call uart0pollin
            or a ; test result
            jr nz, uart0read
            ;; ; not ready -- get XDOS to poll us
            ;; ld c, xdos_poll
            ;; ld e, poll_uart0in
            ;; call xdos
            ; not ready -- wait for interrupt
            ld c, xdos_flag_wait
            ld e, flag_uart0in
            call xdos
            jr uart0in
uart0read:  in a, (UART0_DATA)
            jr input_fixup
endif           

if CONFPS2 = 0 
uart1in:    call uart1pollin
            or a ; test result
            jr nz, uart1read
            ;; ; not ready -- get XDOS to poll us
            ;; ld c, xdos_poll
            ;; ld e, poll_uart1in
            ;; call xdos
            ; not ready -- wait for interrupt
            ld c, xdos_flag_wait
            ld e, flag_uart1in
            call xdos
            jr uart1in
uart1read:  in a, (UART1_DATA)
            jr input_fixup

endif 
            
input_fixup: ; fix up data read from UARTs in A; for now we just replace backspace with Ctrl-H
            ;cp 0x7f ; backspace?
            ;ret nz
            ;ld a, 8 ; ctrl-h
            ret

; ---[ UART write ]---------------------------------

uart0out:   call uart0pollout
            or a ; test result
            jr nz, uart0write
            ; not ready -- get XDOS to poll us
            push bc ; stash character to write (in register C)
            ;;ld c, xdos_poll
            ;;ld e, poll_uart0out
            ;;call xdos
            ld c, xdos_flag_wait
            ld e, flag_uart0out
            call xdos
            pop bc ; recover C register contents
            jr uart0out
uart0write: ld a, c
            out (UART0_DATA), a ; transmit character
            ret

if CONFPS2 = 0 
uart1out:   call uart1pollout
            or a ; test result
            jr nz, uart1write
            ; not ready -- get XDOS to poll us
            push bc ; stash character to write (in register C)
            ;; ld c, xdos_poll
            ;; ld e, poll_uart1out
            ;; call xdos
            ld c, xdos_flag_wait
            ld e, flag_uart1out
            call xdos
            pop bc ; recover C register contents
            jr uart1out
uart1write: ld a, c
            out (UART1_DATA), a ; transmit character
            ret
endif 
; ---[ list device ]--------------------------------

listst:     ; return list device status
            xor a       ; 0 = not ready
            ; fall through to list
list:       ; write character to listing device (we don't have one!)
            ; fall through to unimplemented
returnzero:
unimplemented:
            xor a
            ret
            
            
; MMU critical section handling 

enterMMU: 
          push hl 
          di ; disable interrupts 
          ld hl, mmuSema
          bit 0, (hl) ; Check if semaphore is set 
          jr nz, enter01
          ; if not 
          set 0,(hl) ; set it 
          inc hl 
          ld (hl),a ; set MMU owner 
          pop hl
          ret 
enter01:  
          ; output on MMU panic 
          ; 
          call outcharhex ; write new owner in a 
          ld c,' '
          call dbgout
          ld a,(mmuOwner)          
          call outcharhex ; old owner 
          ld c,' '
          call dbgout
          
          inc sp 
          inc sp ; jump over pushed hl 
          ld hl,0
          add hl,sp 
          ld b, 16 ; 16 stack entries max            
dumpStack:          
          ld c,(hl) ; low byte
          inc hl 
          ld a,(hl)  ; high byte 
          inc hl 
          call outcharhex
          ld a,c 
          call outcharhex 
          ld c,' '
          call dbgout 
          djnz dumpStack 
          ld hl, mmuPanic
          jp panic 

leaveMMU:
          ld a,0
          ld (mmuSema),a 
          ld (mmuOwner),a 
          ld a, (preempted)
          or a ; set flags 
          ret nz
          ei ; enable interrupts 
          ret             
          
                    
            

; ---[ RAM disk driver ]----------------------------

; partly moved to banked.asm 

read:       ; read from our RAM disk
        if DISKDEBUG
            ld iy, readmsg
            call printdisk
         endif  
            call swtuser  ; bank switch to user segment
            
            call mapmmu
            ; HL now points to the location where our data is stored
            ; DE now points at the DMA buffer
docopy:     ld bc, 0x80 ; transfer 128 bytes
            ldir ; copy copy copy!
            call unmapmmu ; put MMU back as it was
            call swtsys   ; bank switch back to system segment
            xor a ; A=0: success
            ret

write:      ; write to our RAM disk
         if DISKDEBUG
            ld iy, writemsg
            call printdisk
          endif
            call swtuser
            call mapmmu
            ; HL now points to the location where our data is stored
            ; DE points to the DMA buffer
            ex de, hl ; swap HL/DE
            jr docopy

mapmmu:     ; use MMU to map the physical page corresponding to the drive data
            ;
            ; CPM address = drive number / 7 bit track / 7 bit sector / 7 bits byte offset
            ; Physical address:
            ;   bits 22-21: drive number+1 (2 bits)
            ;   bits 20-14: track number (7 bits)
            ;   bits 13-7:  sector number (7 bits)
            ;   bits 6-0:   byte offset (7 bits)
            ; CPM:   DDTTTTTTTSSSSSSSOOOOOOO  (2 bit drive, 7 bit track, 7 bit sector, 7 bit offset)
            ; Phys:  PPPPPPPPPPPOOOOOOOOOOOO  (11 bit page frame number, 12 bit page offset)
            ; MMU:   HHHLLLLLLLL              (3 bit hi, 8 bit low, low 12 bits come from logical address accessed)

            ; start by picking where in our address space to map the disk memory
            ; we know PC is in Cxxx (!!) so we can't use that
            ; we have to avoid SP and the target DMA address
            ; SP >= 0x8000 -> use 0x2000 unless DMA is in 0x2000 in which case use 0x4000
            ; SP  < 0x8000 -> use 0xA000 unless DMA is in 0xA000 in which case use 0x8000
            
           
            
            mmuEnter 0FFH ; "Owner" Disk system             
            ; turn on disk access LED
            in a, (GPIO_OUTPUT)
            set 3, a
            out (GPIO_OUTPUT), a
            
            ; TH: Additional check because DMA buffer can cross a page boundary 
            ; CP/M allow the DMA buffer to be at any possible memory address  
            ld hl,(curdmaaddr)
            ld a,h 
            and 0F0H 
            ld d,a ; Store start page of current DMA in d             
            ld bc,128 
            add hl,bc ; Calculate End of DMA buffer 
            ld a,h 
            and 0F0H 
            ld e,a ; store end page of current DMA in e 
                        
            ld hl, 0    ; you can't read sp ...
            add hl, sp  ; but you can add it to hl!                                                 
            ld a, h     ; test top bit of SP
            and 0x80
            jr z, use_a0   ; top bit of SP is not set, SP is in low 32K
            ; top bit of SP is set, SP is in high 32K
            ld a, d ; check conflict with DMA start 
            cp 0x20
            jr z, use_40
            ld a, e  ; check conflict with DMA end 
            cp 0x20 
            jr z, use_40 
            ld a, 0x2
            jr foundframe
            
use_40:     ld a, 0x4
            jr foundframe
            
use_a0:     ld a, d ; check conflict with DMA start 
            cp 0xa0
            jr z, use_80
            ld a, e  ; check conflict with DMA end 
            cp 0xa0 
            jr z, use_80
            ld a, 0xa         
            jr foundframe
use_80:     ld a, 0x8 ; TH change from 0xC to 0x8 for MP/M 
            ; fall through to foundframe
foundframe: ; selected frame in register a
        if DISKDEBUG
            push af 
            call outcharhex
            call crlf
            pop af 
         endif 
         
            out (MMU_PAGESEL), a ; select page frame
            and a ; clear carry flag (for rla)
            rla   ; shift left four bits
            rla
            rla
            rla
            ld h, a              ; set the top four bits of h
            ; store current MMU state
            in a, (MMU_PERM)
            ld (mmutemp0), a
            in a, (MMU_FRAMEHI)
            ld (mmutemp1), a
            in a, (MMU_FRAMELO)
            ld (mmutemp2), a
            ; now compute MMU_FRAMEHI value (physical address of RAM disk sector)
            ld a, (curdisk)
            inc a             ; we use disk+1 so first disk starts at physical address 2MB
            sla a             ; shift A left one position, load 0 into bit 0
            ld b, a
            ld a, (curtrack)
            and 0x40          ; test top bit of 7-bit track number
            jr z, framehiready
            inc b             ; load top bit of track into B
framehiready:
            ld a, b
            out (MMU_FRAMEHI), a
            ; now compute MMU_FRAMELO value (physical address of RAM disk sector)
            ld a, (curtrack)
            sla a
            sla a
            ld b, a         ; the bottom 6 bits of the track number are now in the top 6 bits of B, with 00 in the low two bits
            ld a, (cursector) ; we only want the top two bits of this 7-bit number
            srl a
            srl a
            srl a
            srl a
            srl a
            and 0x03 ; mask off the low two bits (potentially cursector had the top bit set I suppose?)
            or b     ; merge in the 6 bits of track number
            out (MMU_FRAMELO), a
            ; brilliant, now it's mapped! finally compute HL to point to the start of the data buffer
            ld l, 0
            ld a, (cursector)
            srl a            ; shift A right one bit, bottom bit goes into carry flag
            jr nc, lready    ; test carry flag and ...
            ld l, 0x80       ; ... bump up L to the next sector if it was 1
lready:     and 0x0f         ; we only want four bits
            or h             ; merge in the frame number computed earlier
            ld h, a          ; store it in H
            ld de, (curdmaaddr) ; load DE with source/target address
            ret

unmapmmu:   ; put MMU mapping for frame back as it was
            ld a, (mmutemp0)
            out (MMU_PERM), a
            ld a, (mmutemp1)
            out (MMU_FRAMEHI), a
            ld a, (mmutemp2)
            out (MMU_FRAMELO), a
        
            mmuLeave
            ; turn off disk access LED
            in a, (GPIO_OUTPUT)
            res 3, a
            out (GPIO_OUTPUT), a
                      
            ret

; -- Additional XIOS functions (not used in CP/M) below

; ---[ banked memory ]------------------------------

BANKED_PAGES equ 12   ; 0xc0 / 0x10 = 12 pages banked

selmemory:  ; select memory bank pointed to by BC
            ; BC+0 - base
            ; BC+1 - size
            ; BC+2 - attributes
            ; BC+3 - bank number  <-- this is the useful info
            inc bc               ; advance BC three bytes
            inc bc
            inc bc
            ld a, (bc)           ; load memory bank number
            and 0x07             ; just in case
doselmemory: ; systeminit will jump here with bank in A
            ld l, a              ; stash page number
            ld a, (curbank)      ; load current bank number
            cp l                 ; compare to desired bank number
            ret z                ; fastpath if it's what we've already got paged in

            in a, (GPIO_OUTPUT)  ; load GPIO outputs
            and 0xf8             ; mask off low 3 bits (LEDs)
            or l                 ; put stashed bank number on low 3 bits
            out (GPIO_OUTPUT), a ; output to LEDs
            ; compute base page, we use pages 0x00 through 0x63 ie 400KB total, 64K+7*48K
            ; l contains page number, we can do this with just 8 bits
            ld a, l   ; *1
            ld (curbank), a      ; update current bank number
            add a     ; *2
            add a     ; *4
            ld l, a   ; store copy ie L=bank*4
            add a     ; *8
            add l     ; *12 (*4+*8)
            ld l, a   ; L=bank*12
            ld h, 0   ; HL=bank*12
            ; all the banks are 48K except bank 0 which is 64K, adjust for that
            cp 0      ; A=L already
            jr z, bankmmu
            ; we're in banks 1 or above
            add 4
            ld l, a   ; adjust upwards
bankmmu:    ; now we program the MMU!
           
            ld b, BANKED_PAGES
            ld c, 0
nextpage:   ld a, c
            out (MMU_PAGESEL), a
            ld a, h
            out (MMU_FRAMEHI), a
            ld a, l
            out (MMU_FRAMELO), a
            inc c
            inc hl
            djnz nextpage
            ret

; ---[ timer tick ]---------------------------------
startclock:
            ld a, 0xff
            ld (ticking), a
            ret

stopclock:
            xor a
            ld (ticking), a
            ret

; ---[ console and polling ]------------------------
maxconsole: ; return number of supported consoles in A register
            ld a, nconsoles
            ret

polldevice: ; poll device - device number is in C register
            ;        push bc
            ;        ld a, c
            ;        add 48
            ;        ld c, a
            ;        call dbgout
            ;        pop bc
            ld a, c
            cp numdevices
            jr c, deviceok
            jp returnzero    ; bad device? return zero.
deviceok:   call tbljmp      ; perform table lookup
tblstart:   dw uart0pollout  ; device number 0: poll_uart0out
            dw uart1pollout  ; device number 1: poll_uart1out
            dw uart0pollin   ; device number 2: poll_uart0in
            dw uart1pollin   ; device number 3: poll_uart1in
numdevices  equ ($-tblstart)/2 ; compute table size used in range check above

; ---[ initialisation common part  ]-----------------------------



sysinitc:   ; Part of sysinit that must reside in common memory because it does bank switching      
            
            ; now copy system vectors etc into our buffer, then copy them to the other banks
            ld hl, 0
            ld de, sysvectors
            ld bc, VECTOR_LENGTH
            ldir ; copy
            ; initialise each bank
            ld b, 7
nextbank:   push bc ; save bank number
            ld a, b
            call doselmemory ; select it
            ld hl, sysvectors
            ld de, 0
            ld bc, VECTOR_LENGTH ; docs say we should copy lower 256 bytes but 64 seems to be quite adequate.
            ldir ; copy
            pop bc ; restore bank number
            djnz nextbank ; copy banks 7 ... 1
            ld a, 0
            call doselmemory ; restore bank 0
            ret

; ---[ interrupt handling ]-------------------------
exitregion:
            ; re-enable interrupts (iff the preempted flag is zero)
            ld a, (preempted)
            or a
            ret nz ; non zero? leave interrupts disabled
            ; enable interrupts and return
            ei
            ret

interrupt_handler:
            ; switch stacks, then save CPU state on our interrupt stack
            ld (saved_stackptr), sp
            ld sp, interrupt_stack
            push af
            push hl
            push de
            push bc
            push ix
            push iy

            ; set preempted flag (so exitregion won't re-enable interrupts until we're done)
            ld a, 0xff
            ld (preempted), a

            ; test if the timer triggered this interrupt
            in a, (TIMER_STATUS)
            and 0x80
            jr z, timerdone

            ; timer has generated an interrupt, ack it.
            xor a  ; cmd 0 = interrupt acknowledge
            out (TIMER_COMMAND), a
        
            ; decrement our tick counter 
inth1:      ld hl, tickcount
            dec (hl)
            
                        
            jr nz, not1second

            ; 1 second has passed
            ld (hl), tickspersec ; reset counter
            ; set 1 second flag
            ld c, xdos_flag_set
            ld e, 2 ; flag 2 is the 1 second flag
            call xdos

not1second: ld a, (ticking) ; test if system tick should be running
            or a
            jr z, timerdone
            ; set timer flag #1
            ld c, xdos_flag_set
            ld e, 1 ; flag 1 is the timer tick flag
            call xdos
timerdone:


            ; test UART0
            in a, (UART0_STATUS)
            ld b, a
            ; test interrupt bits
            and 0x03
            jr z, uart0done
            ; ack interrupts
            ld a, b
            and 0xfc
            out (UART0_STATUS), a

            ; test receive bit
            bit 1, b
            jr z, uart0tx
            ; bit 1 is set -- receive complete
            ld c, xdos_flag_set
            ld e, flag_uart0in
            push bc
            call xdos
            pop bc
uart0tx:    ; test transmit bit
            bit 0, b
            jr z, uart0done
            ; bit 0 is set -- transmit complete
            ld c, xdos_flag_set
            ld e, flag_uart0out
            call xdos
uart0done:
        

            ; test UART1
            in a, (UART1_STATUS)
            ld b, a
            ; test interrupt bits
            and 0x03
            jr z, uart1done
            ; ack interrupts
            ld a, b
            and 0xfc
            out (UART1_STATUS), a

            ; test receive bit
            bit 1, b
            jr z, uart1tx
            ; bit 1 is set -- receive complete
            ld c, xdos_flag_set
            ld e, flag_uart1in
            push bc
            call xdos
            pop bc
uart1tx:    ; test transmit bit
            bit 0, b
            jr z, uart1done
            ; bit 0 is set -- transmit complete
            ld c, xdos_flag_set
            ld e, flag_uart1out
            call xdos
uart1done:
    if CONFPS2
           in a,(PS2_CONTROL)
           and 01H ; Check PS2 Status bit 
           jr z,intdone 
           ld a,82H ; Bit 7 int Ack, bit 1 enable interrupts 
           out (PS2_CONTROL),a ; INT Acknowledge
           ld c,xdos_flag_set
           ld e,flag_ps2
           call xdos
    endif 
        
intdone:    ; tidy up from interrupts, return via the dispatcher
            ; clear preempted flag
            xor a
            ld (preempted), a
            ; restore CPU state
            pop iy
            pop ix
            pop bc
            pop de
            pop hl
            pop af
            ld sp, (saved_stackptr)
            jp pdisp ; run the MP/M dispatcher

idle:       halt
            ret

   vgastatusline equ 1 ; Enable line 40 as status line - not acccesiable to normal console out          
            
; !! Bug in zasm: include is not allowed to be in column 1
  include   vgabasic.asm

  vconout: push ix ; some CP/M programs may not expect BIOS to change Z80 regs.
           ld ix,scrpb0
           call vgaconout 
           pop ix 
           ret 
                



if Q_INPUT
  include qinput.asm
else 
  include xiospd.asm   
endif 
    
mmuPanic:  db ' MMU hazard',0;                
                
;---------------------------------------------------------------------------------------------------------------
; this string must be AT LEAST 64 bytes since we use it as a copy buffer inside systeminit, and
; then used again as the stack during interrupts
sysvectors:  
initmsg:    db 13, 10
initmsg1:   db  "Z80 MP/M-II Banked XIOS (Will Sowerbutts, [TH 20160502,vga,ps2])", 0 ; MP/M print a CRLF for us
          if ($ - sysvectors) < VECTOR_LENGTH
            ds (VECTOR_LENGTH - ($ - sysvectors))  ; fill up to 64 Bytes if needed 
          endif   

            .assert ($-sysvectors >= VECTOR_LENGTH) ; safety check
interrupt_stack:
saved_stackptr: dw 0

;---------------------------------------------------------------------------------------------------------------
; debug functions (ideally to be removed in final version, if we ever get that far!)

strout:     ; print string pointed to by HL
            ld a, (hl)
            cp 0
            ret z
            ld c, a
            call dbgout
            inc hl
            jr strout       

dbgout:     ; wait tx idle
            in a, (UART0_STATUS)
            bit 6, a
            jr nz, dbgout
            ; GO GO
            ld a, c
            out (UART0_DATA), a
dbgwait:    ; wait tx idle again
            in a, (UART0_STATUS)
            bit 6, a
            jr nz, dbgwait
            ret

panic:      call strout
            hlt     
            

cstrout:   ; like strout but using XIOS conout, D points to console number
            ld a, (hl)
            cp 0
            ret z
            ld c, a
            push de
            push hl
            call conout
            pop hl 
            pop de 
            inc hl
            jr cstrout 
            

            
debugc equ 1 

if debugc
           
; print the byte in A as two hex nibbles
outcharhex:
            push bc
            ld b, a  ; copy value
            ; print the top nibble
            rra
            rra
            rra
            rra
            call outnibble
            ; print the bottom nibble
            ld a, b
            call outnibble
            pop bc
            ret

; print the nibble in the low four bits of A
outnibble:
            and 0x0f ; mask off low four bits
            cp 10
            jr c, numeral ; less than 10?
            add 0x07 ; start at 'A' (10+7+0x30=0x41='A')
numeral:    add 0x30 ; start at '0' (0x30='0')
            ld c, a
            call dbgout
            ret
            
        

endif            

if DISKDEBUG            
     dbgconout equ dbgout ; Alias 
            
dbgstrout:  ; print string pointed to by IY
            ld a, (iy+0)
            cp 0
            ret z
            ld c, a          
            call dbgconout             
            inc iy 
            jr dbgstrout    

crlf:
            ld c, 0x0d
            call dbgconout
            ld c, 0x0a
            call dbgconout
            ret

outhexblank: 
            call outcharhex            
outblank:   ld c, ' '
            jp dbgconout 
            ; dbgconout will return             
                        
printdisk:   
            call dbgstrout ; Print message passed in IY 
            ld a,(curdisk)
            call outhexblank
            ld a,(curtrack)
            call outhexblank
            ld a,(cursector)
            call outhexblank
            ld a,(curdmaaddr+1)
            call outcharhex
            ld a,(curdmaaddr)
            call outhexblank                        
            ret 
            
            
readmsg:    db "[RD ", 0
writemsg:   db "[WR ", 0   

endif             

;---------------------------------------------------------------------------------------------------------------

; scratch RAM used by BIOS
curdisk:    db 0x11
curtrack:   db 0x22
cursector:  db 0x33
curdmaaddr: dw 0x4444
mmutemp0:   db 0x55
mmutemp1:   db 0x66
mmutemp2:   db 0x77
tickspersec equ 50
tickcount:  db tickspersec  ; count down ticks to measure one second
ticking:    db 0    ; bool: system timer ticking?
preempted:  db 1    ; bool: pre-empted? clear after in XIOS init !!!
curbank:    db 0

mmuSema:    db 0 
mmuOwner:   db 0 




; scratch RAM used by BDOS/MPMLDR
dirbf:      ds 128           ; directory scratch area
alv00:      ds 64            ; allocation vector for disk 0, must be (DSM/8)+1 bytes
alv01:      ds 64            ; allocation vector for disk 1, must be (DSM/8)+1 bytes
alv02:      ds 64            ; allocation vector for disk 2, must be (DSM/8)+1 bytes
chk00:      ds 0             ; check vector for disk 0 (must be CKS bytes long)
chk01:      ds 0             ; check vector for disk 1 (must be CKS bytes long)
chk02:      ds 0             ; check vector for disk 1 (must be CKS bytes long)

                             ; obsolete !!! space for interrupt vector table

 ;           ds 256           ; "waste" space to make sure that final code size will above a page boundary
            
;lastpage:                    ; Dummy label marking end of BIOS - upper 8 Bits will be the last 256 Byte page            
            
    

; zmac will complain about a missing "end label" statement unless you add one. If the (non-optional)
; start vector is to anywhere other than the first byte, the linker adds a jump instruction which
; results in our jump table offsets being all out of whack.
            .end startlabel
