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
         
  tOS = (cpm2,cpm3,mpm);         
  
    xdos_abp = record
       console_number : byte;
       process_name : array [1..7] of byte;
       match : byte;
     end;

         

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
