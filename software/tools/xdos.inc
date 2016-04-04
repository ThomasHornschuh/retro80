const
     bdos_getVersion = 12;
     bdos_conin = 1;
     bdos_conout = 2;
     bdos_rawInput = 3;
     bdos_rawOutput = 4;
     bdos_constat = 11;

     xdos_cli = 150;
     xdos_assign_console = 149;
     xdos_getconsole = 153;
     xdos_attachconsole = 146;
     xdos_setpriority = 145;
     xdos_setconsole = 148;
     xdos_GetPD = $9C;
     xdos_getSysDataPtr = 154;


(*System page table offets *)

     memTop = 0;
     numConsoles =1;
     BreakRST = 2;
     Banked = 4;
     Z80 = 5;
     XIOSJumpBase = 7;
     MaxMemSeg = 15;
     XDOSEntry = 245;
     XDOSDataSeg =252;

 (* XDOS Data Segment offests (MP/M Programmer Guide chapter 3.6) *)

     osr1r = $5; (* Ready list root *)
     osd1r = $7; (* delay list root *)
     osdrl = $9; (* dispatcher ready list ??*)
     osp1r = $B; (* poll list root *)
     osq1r = $F; (* Queue List root *)
     oscnsque = $34; (*Console attach table *)
     ossysfla = $55;  (*System flag PD array *)
     osmbbsegs = $95; (*Number of memory segments *)
     osmsegtbl = $96; (*Memory segment table *)

     numFlags = 32;


type
     word = integer;
     address = ^byte;

     str255 = string[255];

     pxdos_PD = ^xdos_processDescriptor;
     
     xdos_processDescriptor = record
        link : pxdos_PD;
        status : byte;
        priority : byte;
        stkptr : address;
        name : array[1..8] of byte;
        cons_list : byte;
        memseg : byte;
        dparam : address;
        thread : address;
        dma : address;
        dsksel : byte;
        dcnt : address;
        srchl : byte;
        srcha : address;
        pd : word;
        reg : record
          XHL,XDE,XBC,XAF,IY,IX,HL,DE,BC,AF : word;
        end;
        ext : word;
     end;

     pxdos_QD = ^xdos_queueDescriptor;

     xdos_queueDescriptor = record
       link : pxdos_QD;
        name : array[1..8] of byte;
        msglen,nmbmsgs : integer;
        dqph, nqph : pxdos_PD;
     end;

     (* XDOS hold in its data segment at offset ossysfla an array of pointers
        to the PDs of the processes waiting for a flag.
        An entry contains FFFF when no process_name is waiting for the flag *)

     xdos_flagArray = array [1..numFlags] of pxdos_PD;
     pxdos_flagArray = ^xdos_flagArray;

     tOS = (cpm2,cpm3,mpm);

     xdos_abp = record
       console_number : byte;
       process_name : array [1..7] of byte;
       match : byte;
     end;

    tPage = array [0..255] of byte;




function getOS:tOS;
 var vers : integer;
 begin
   vers:=bdosHL(bdos_getVersion);
   if hi(vers)=1 then
     getOS:=mpm
   else case lo(vers) and $f0 of
     $20: getOS:=cpm2;
     $30: getOS:=cpm3;
     else
          getOS:=cpm2; (* Assume unkown OS version as cpm2 *)
   end;
 end;


 function getXDOSDataSegment:address;
 var pSystemPage : ^tPage;

 begin
   pSystemPage:=ptr(bdosHL(xdos_getSysDataPtr));


   if pSystemPage<>nil then
     getXDOSDataSegment:=
       ptr( pSystemPage^[XDOSDataSeg] or
            (pSystemPage^[XDOSDataSeg+1] shl 8) )
   else
     getXDOSDataSegment:=nil;
 end;
