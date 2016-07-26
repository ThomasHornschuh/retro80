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

##  Quick start guide ##

### Prerequsities ###
As minimum you will need the Papillio Pro itself, with this it is possible to use the serial console (which can be used with any terminal emulator like putty).
Also the Papillio Loader tools need to be installed.

When you want to use the VGA PS/2 you need in addtion:

* The Arcade Megewing attached to your Pro
* A PS/2 Keyboard (usuallly you need a "true" PS/2 keyboard, most USB to PS/2 adapters only work with older USB keyboards which have an internal PS/2 fallback. PS/2 Keyboards are sold a lot on ebay for a few dollar or Euro. I have one from HP, it is really good quality
* A Display with a VGA connector, currently the RETRO80 is working only with standard VGA Resolution 640x480. The screen looks better on classic 4:3 displays then on Widescreen 16:9, but technically both work. I have not tested yet with other displays than mine, so if you have problems, please let me know. 
* A VGA cable of course




The "Serialboot" https://bitbucket.org/thornschuh/retro80/downloads/retro80Serialboot20160604.bit  bitfile contains the orginal ROM Monitor from Will which interacts with the serial console (**the baud rate is 115200 bit/sec fixed)**. The video RAM is initalized with a test pattern (with initalizing the Block RAM by VHDL code), so it is easy to check if VGA is working.



The "consoleboot" https://bitbucket.org/thornschuh/retro80/downloads/retro80consoleboot20160620.bit bitfile contains a ROM Monitor which uses the VGA Port and the PS/2 "A" port of the arcade megawing as conole. Unfortunately the keyboard layout is german at the moment...

Having a boot image https://bitbucket.org/thornschuh/retro80/downloads/retro80_200.image  is much more usefull. To get the boot image onto the system you can either use the method described in Wills readme.txt, or as fast alternative merge it at address 0x200000 to the bitfile and upload it.

For merging bitfiles there are different tools, I used papillo-prog.

The command is

```
#!


papilio-prog.exe -v  -f retro80Serialboot20160604.bit -b ..\bscan_spi_xc6slx9.bit -a 200000:retro80_200.image
```

Of course you must adjust the pathes to the structure on your system. My example was from a start directly in the directory where papilio-prog resides after intallationof the Papilio tools.
When everything is loaded to the Papillio Pros flash chip and you restart the board (best with power cycling) you should see the boot monitor prompt either on your terminal emulator or the VGA display.
Then you enter


```


rread 200 200

rboot 200
```

Now CP/M is booted, the provided image will always boot CP/M on the serial console. On this console you can enter "MPMLDR", this will fire up MP/M II running console 0 on PS/2 / VGA, console 1 on serial port.

The disk image contains a lot, e.g. Turbo Pascal and Wordstar. Please note that all this programs are patched for using the ADM3A screen sequences of the VGA console. So they will not work with the usual VT100 emulation of e.g. putty or TerraTerm. There is a turbovt.com which can be used with VT100.

On user 6 there is an adapted versio of the startrek game.

You can start it with:


```
user 6
startrek 
 
```


If you want also the CP/M part work in VGA/PS/2 you can patch the disk image:

First reset the computer with the reset button on the Arcade MegaWing (this will only reset the CPU/board not reload the bitfile and will therefore not harm the DRAM contents)

Boot CP/M

Enter


```
#!

sysload bootvga.bin a:
```

press "C" to continue (the sysload program is missing a message saying this ....)

Reset the system again. 
```
#!

rboot 200 
```
should now boot to the VGA PS/2 console.

To make the change permnent you need to enter 


```
#!

rwrite 200 200 
```

in the ROM Monitor.