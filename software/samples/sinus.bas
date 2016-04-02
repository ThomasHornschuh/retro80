10 REM Televideo clear screen Ctrl-Z
20 PRINT CHR$(26)
30 PI=3.1415927#
40 '***
50 FOR I=1 TO 37
60   X=35+SIN((I/37)*PI*2)*35
70   REM Telvideo set cursor ESC = R C
80   C$=CHR$(27)+"="+CHR$(I+32)+CHR$(X+32)
90   PRINT C$+"*"
100 NEXT I
110 '***
120 PRINT CHR$(27)+"=  "
