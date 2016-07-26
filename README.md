# RETRO80 - A retro Microcomputer running on Papillio Pro FPGA Board #

This project is based on the work of http://sowerbutts.com/socz80/ First I will say, that Will's  has done the "hard" part of the work, my addtions are quite small. 

For operation of the whole system, especially how to use the Monitor please refer to Wills excelent readme.txt :http://sowerbutts.com/socz80/README.txt

## Features added by me  ##

- Integration of a text mode video controller from open cores http://opencores.org/project,interface_vga80x40
- PS/2 keyboard
- Adapted to use the Arcade Megawing for PS/2, VGA, GPIO LEDs, reset button
- Extended CP/M 2.2 BIOS and MPM XIOS to support PS/2 and VGA.
- ROM Monitor and boot loaders that can be used with VGA/PS/2 - so my extended version can be used as real stand-alone Computer when connected to power suplly, monitor and keyboard
- The simulated terminal supports ADM3A/TVI950 escape sequences instead of VT100. They are easier/smaller to implement and many CP/M programs have difficulty to generate VT100 seqeunces. The disadvantage is that the local console is incompatible with the serial console, because I'm not aware of any Windows Terminal Emulator supporting ADM3A
- The keyboard supports Wordstar compaitble Control characters for cursor keys. 
- For MP/M Console 0 is the Serial UART and Console 1 PS/2 / VGA. 

Other hardware / Software extensions:

- Added support to Interrupt Mode 2 to the hardware and adapted MP/M XIOS to it (this allows the use of normal CP/M debuggers under MP/M without crashing the systems because the XIOS is no longer using RST7 for interrupts)
- Fixed a bug in BIOS/XIOS with not taking into account that a CP/M DMA buffer can cross a 4K boundary. This occaisonally lead to data corruption e.g. when copying a file with CP/M PIP.COM

Software:

I also wrote a xmodem receive program in Turbo Pascal which makes transfering files a bit more easier.
I collected a lot of old Software like Wordstar, Mutiplan, CBASIC, MBASIC, Turbo Pascal, Microsoft Fortran etc. and configured it to run with the Video Terminal. 
I created some example programs in Turbo Pascal, MBASIC, CBASIC and even Fortran (it was the first Fortran program in my life -really fun :-) ).
I also collected things like Eliza and Startrek. I also adpated the MBASIC Startrek to compiled CBASIC. 



[##  Quick start guide ##](https://bitbucket.org/thornschuh/retro80/wiki/Quick%20Start%20Guide%20)
