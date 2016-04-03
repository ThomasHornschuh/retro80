
 type tOperatingMode = (
           generic, (* use TP kbd/con without any specical settings *)
           cpmtty,  (* Use CP/M CON set to tty (uses TP kbd/con), set IOBYTE to 0 *)
           cpmaux,  (* Use CP/M RDR/PUN device, (TP AUX device) - not yet supported  *)
           mpmcons, (* Uses a specific console channel with MP/M, mapped to TP USR device *)
           mpmdefcons (*Uses default console channel with MP/M, mapped to TP USR device *)
     );



var 
 
     OperatingMode : tOperatingMode;
     xm_console : byte; (*MP/M only, console number used for xmodem transfer*)
     io_console : byte; (*MP/M only, console number to be used for User I/O *)

     current_console: byte; (* console set by last set console call *)


 procedure setConsole(cons:byte);
 begin
   if cons<>current_console then begin
     bdos(xdos_setconsole,cons);
     current_console:=cons;
   end;
 end;


(* I/O  Drivers for Turbo Pascal*)

procedure UsrOut(ch: char);
begin
   setConsole(xm_console);
   bdos(bdos_rawOutput,byte(ch));
end;


function UsrIn:char;
begin
  setConsole(xm_console);
  UsrIn:=chr(bdos(bdos_rawInput));
end;

procedure ConOut(ch: char);
begin
   setConsole(io_console);
   bdos(bdos_conout,byte(ch));
end;


function ConIn:char;
begin
  setConsole(io_console);
  UsrIn:=chr(bdos(bdos_conin));
end;

function ConStat:boolean;
begin
  setConsole(io_console);
  ConStat:=bdos(bdos_constat )<>0;
end;

procedure setDrivers;
begin
  ConStPtr:=addr(Constat);
  ConInPtr:=addr(ConIn);
  ConOutPtr:=addr(ConOut);
  UsrOutPtr:=addr(UsrOut);
  UsrInPtr:=addr(UsrIn);

end;

function xmInStat:boolean;
begin
  case OperatingMode of
    generic,cpmtty: xmInStat:=keypressed;
    cpmaux: xmInStat:=true; (* there is no CP/M API for this... *)
   else begin
     setConsole(xm_console);
     xmInStat:=bdos(bdos_constat )<>0;
     end;
  end; (*case *)
end;

procedure setupMPMIO;
 var ac : xdos_abp;
     ppd : pxdos_PD;
     I : integer;
 begin
   setDrivers;
   if io_console<>xm_console then begin
     (* Assign the xm_console also to our process *)
     ppd:=ptr(bdosHL(xdos_GetPD));
     ac.console_number:=xm_console;
     ac.match:=0;
     for I:=1 to 8 do ac.process_name[I]:=ppd^.name[I] and $7F;
     bdos(xdos_assign_console,addr(ac));
   end;
 end;

 