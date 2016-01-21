;scheisse.asm

 extern enterMMU
 extern leaveMMU 

mmuEnter macro 
        call enterMMU
endm
        
mmuLeave macro
        call leaveMMU
endm

test:
       mmuEnter
       mmuLeave
       ret
       
 .end test        

