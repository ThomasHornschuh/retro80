; German keyboard layout tables

lookup1:  ; "Neutral" Keyboard lookup, no shift, no ctrl, no alt but assume num lock enabled 
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 09 ; TAB 0DH
 db '^' ;  00EH
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 'q' ;  015H
 db '1' ;  016H
 db 0
 db 0
 db 0
 db 'y' ;  01AH
 db 's' ;  01BH
 db 'a' ;  01CH
 db 'w' ;  01DH
 db '2' ;  01EH
 db 0
 db 0
 db 'c' ;  021H
 db 'x' ;  022H
 db 'd' ;  023H
 db 'e' ;  024H
 db '4' ;  025H
 db '3' ;  026H
 db 0
 db 0
 db ' ' ;  029H
 db 'v' ;  02AH
 db 'f' ;  02BH
 db 't' ;  02CH
 db 'r' ;  02DH
 db '5' ;  02EH
 db 0
 db 0
 db 'n' ;  031H
 db 'b' ;  032H
 db 'h' ;  033H
 db 'g' ;  034H
 db 'z' ;  035H
 db '6' ;  036H
 db 0
 db 0
 db 0
 db 'm' ;  03AH
 db 'j' ;  03BH
 db 'u' ;  03CH
 db '7' ;  03DH
 db '8' ;  03EH
 db 0
 db 0
 db ',' ;  041H
 db 'k' ;  042H
 db 'i' ;  043H
 db 'o' ;  044H
 db '0' ;  045H
 db '9' ;  046H
 db 0
 db 0
 db '.' ;  049H
 db '-' ;  04AH
 db 'l' ;  04BH
 db 0
 db 'p' ;  04DH
 db '\' ;  04EH
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0
 db 0DH ; ENTER 5A 
 db '+' ;  05BH
 db 0
 db '#' ;  05DH
 db 0
 db 0
 db 0
 db '<' ;  061H
 db 0
 db 0
 db 0
 db 0
 db 08H ; 066H
 db 0
 db 0
 db '1' ;  069H
 db 0
 db '4' ;  06BH
 db '7' ;  06CH
 db 0
 db 0
 db 0
 db '0' ;  070H
 db ',' ;  071H
 db '2' ;  072H
 db '5' ;  073H
 db '6' ;  074H
 db '8' ;  075H
 db 1BH ; 066H
 db 0
 db 0
 db '+' ;  079H
 db '3' ;  07AH
 db '-' ;  07BH
 db '*' ;  07CH
 db '9' ;  07DH


lookup_end: 
 

  lookupMax equ (lookup_end-lookup1) ; Max Index - result should be 7D 


