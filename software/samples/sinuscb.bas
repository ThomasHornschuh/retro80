REM Sinus Test Program in CBASIC

    REM Televideo clear screen Ctrl-Z
    PRINT CHR$(26)

    PI=3.1415927
    SCALE=1.0/37.0*PI*2

    FOR I%=1 TO 37
      X%=35+SIN(FLOAT(I%)*SCALE)*35
      REM Telvideo set cursor ESC = R C
      C$=CHR$(27)+"="+CHR$(I%+32)+CHR$(X%+32)
      PRINT C$+"*"
    NEXT I%

    REM Cursor Home
    PRINT CHR$(27)+"=  "