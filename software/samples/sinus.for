C Fortran version of SINUS.BAS. Will output a sinus curve
C of 37 Lines on the text screen
C Uses TVI 910 cursor move command ESC=<row><col> to position cursor


      SUBROUTINE OUT(X,Y)
        INTEGER X
        INTEGER Y

        LOGICAL ROW,COL,ESC

        ESC = 27

        ROW = Y + 32
        COL = X + 32

        WRITE(1,10) ESC,ROW,COL
10      FORMAT('+',A1,'=',2A1,'*',/)
        RETURN
      END

C  Global Vars

      REAL SCALE
      LOGICAL CTRL
      INTEGER X,Y

C  Clear screen (write Ctrl-Z)

      CTRL = 26
      WRITE(1,20) CTRL
20    FORMAT('+',A1,/)


C  Main loop

      SCALE = 1/37.0*3.1415927*2.0
      DO 100 Y=1, 37
        X = 35+SIN(Y*SCALE)*35
        CALL OUT(X,Y)
100   CONTINUE


C  Set Cursor to home position
      CTRL = 27
      WRITE(1,30) CTRL
30    FORMAT('+',A1,'=  ',/)
      END

