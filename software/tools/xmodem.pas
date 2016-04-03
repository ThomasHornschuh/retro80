program xmodem;

(* xmodem Receive program  (c) 2015/2016 Thomas Hornschuh

   command line options:

   /c:n  - set channel for xmodem transfer

           MP/M: use console number n for xmodem in/out
           if not specified the current console is used

   /g    "generic" Mode. Just use the Turbo Pascal standard console/kbd device for transfering of data,
         with CP/M only generic mode is supported

   /t   write detailed trace info

*)

{$R-,C-,B-}

{$IXDOS.INC}
{$IXMIO.INC}

const soh=$01;
      stx=$02;
      ack=$06;
      nack=$15;
      eot=$04;
      sub=$1A;
      etx=$03; (*Ctrl-C*)


      trace : boolean = false;

type tblock = array [1..1024] of byte;
     bPointer = ^tblock;

     tError = (success,chkfail,abort,xEof,sequenceError);
   
var  logfile,tracefile : text;
     filename : string[15];
     blockfile : file;
     osver : tOS;

{$IXMPARSE.INC}     
     
function xmodem_recv(var f:text;var buffer:tblock;var len:integer;
                     var blocknum:byte;useCRC:boolean):tError;
label 99;

var c,c2,h1,h2: char;

    i : integer;
    checksum : byte;
    crc16 : integer;
    err : boolean;

 {$ICRC16.INC}   

    procedure traceMarker(c:char);
    begin
      if trace then
         case ord(c) of
              soh : writeln(tracefile,'[SOH] (128 Byte block)');
              stx : writeln(tracefile,'[STX] (1024 Byte block)');
              etx : writeln(tracefile,'[ETX] (abort)');
              eot : writeln(tracefile,'[EOT] (end of file )');
         else;
        end;
    end;


begin
  (* Wait for block begin marker *)
  repeat
    read(f,c);
    traceMarker(c);
    case ord(c) of
      soh : len := 128;
      stx : len := 1024; (*xmodem 1K*)
      etx : begin
              len:=0;
              blocknum:=$FF;
              xmodem_recv:=abort;
              goto 99;
            end;
      eot : begin (*end of file *)
             len:=0;
             blocknum:=$FF;
             xmodem_recv:=xEof;
             goto 99;
           end;
    end;
  until ord(c) in [soh,stx];
  read(f,h1,h2);

   if trace then
    writeln(tracefile,'Block sequence: ',
            ord(h1):4,ord(h2):4,' Length:',len:5);

  blocknum:=ord(h1);
  if blocknum<> ord(h2) xor $ff then begin
    xmodem_recv:= sequenceError;
    goto 99;
  end;

  checksum:=0;
  crc16:=0;
  for i:=1 to len do begin
    read(f,c);
    if trace then
      if (c>=' ') and (c<=chr(127)) then
        write(tracefile,c)
      else
        write(tracefile,'.');

    buffer[i]:=ord(c);
    checksum:=checksum+ord(c);
    crc16:=updateCRC16(crc16,ord(c));
  end;
  if trace then writeln(tracefile);
  read(f,c); (*checksum 1*)
  if useCRC then begin
    read(f,c2); (* checksum 2 *)
    i:= ord(c2) shl 8 + ord(c); (*16 Bit CRC *)
    if trace then writeln(tracefile,'CRC: ',i:6,crc16:6);
    err := i <> crc16;
  end else begin
    if trace then writeln(tracefile,'Checksum: ',ord(c):4,checksum:4);
    err := ord(c) <> checksum;
  end;
  if err then
    xmodem_recv:=chkfail
  else
   xmodem_recv:=success;


  99: (* Error exit *)
end;


procedure writeBuffer(buff:tBlock;len:integer);
var blocks : integer;
begin

  if len>0 then begin
    blocks := len div 128;
    if (len mod 128) <>0 then blocks:=blocks+1;
    BlockWrite(blockfile,buff,blocks);
  end;

end;


procedure doReceive(var infile:text;var out:text);
const timeout = 1500; (* 60 seconds / 40 ms   *)
      sendinterval = 50; (*2000ms / 40 ms *)

var len : integer;
    buff : tBlock;
    status : tError;
    blocknum,lastnum : byte;
    waitcounter : integer;
    inStat : boolean;
    
begin
  lastnum :=0;
  writeln(out ,'Start file tranfer in your terminal program');
  bdos(141,50); (* Wait one second *)
  (* Sync at start *)
  waitcounter:= 0;
  repeat
    if (waitcounter mod sendinterval) = 0 then begin
      if trace then write(tracefile,'->[NACK]');
      if OperatingMode=mpmcons then write(con,'.');
      write(out,chr(nack));
    
    end;
    waitcounter:=waitcounter+1;
    inStat:=xmInStat; 
    if not inStat then bdos(141,2); (* when no char received  Wait 2 tick ~ 40ms *)
  until inStat;

  repeat
    status:=xmodem_recv(infile,buff,len,blocknum,false);
    case status of
      success,
      chkfail: begin
                 write(logfile,'Block ',blocknum:1,' received ',
                       len:1,' Bytes');
                 if status=chkfail then begin
                   write(logfile,' chksum/crc error');
                   write(out,chr(nack));
                   writeln(logfile);
                 end else begin
                   writeln(logfile);
                   if blocknum<>lastnum then
                     writeBuffer(buff,len)
                   else
                     writeln(logfile,'Duplicate block ',
                             blocknum:4,' ignored');
                   lastnum:=blocknum;
                   write(out,chr(ack));
                 end;
               end;
      sequenceError: begin
                       writeln(logfile,
                       'Sequence number check fail:',blocknum:4 );
                       write(out,chr(nack));
                     end;
      xeof:  begin
               writeln(logfile,'Transfer completed');
               write(out,chr(ack));
               bdos(141,62); (* Wait 62 Ticks ~ 1 Second *)
               writeln('Transfer completed');
               close(blockfile);
             end;
      abort: begin
               writeln(logfile,'Transfer aborted');
               writeln('Transfer aborted');
               close(blockfile);
               erase(blockfile);
             end;
    end;

  until (len=0) or (status=abort);

end;

{
procedure setRawMode;
const msgRaw : string[60] = 'Set console to raw mode';

var pd : pPD;
begin
  writeln(msgRaw);
  writeln(logfile,msgRaw);
  pd:=ptr(bdoshl(xdosGetPD));
  if pd<>nil then begin
    pd^.name[1]:=pd^.name[1] or $80; (* Set High order bit *)
  end else begin
    writeln(logfile,'Warning: Raw mode could not be set');
  end;
end;

}

procedure main;
begin
  assign(logfile,'xmodem.log');
  rewrite(logfile);
  if trace then begin
{    if OperatingMode=mpmcons then
      assign(tracefile,'con:')
    else }
      assign(tracefile,'xmodem.trc');
    rewrite(tracefile);
  end;

  writeln('Creating ',Filename);
  assign(blockfile,Filename);
  rewrite(blockfile);

  case OperatingMode of
    generic,cpmtty: doReceive(kbd,con);
    cpmaux: doReceive(aux,aux);
    mpmcons,mpmdefcons:
      begin
       bdos(xdos_setpriority,190); (*Increase prio over TMP process *)
       setupMPMIO;
       doReceive(usr,usr);
       bdos(xdos_setpriority,200); (*Restore prio *)
      end;
  end;

  close(logfile);
  if trace then close(tracefile);

end;


begin
  osver:=getOS;
  if osver=mpm then begin
    io_console:=bdos(xdos_getconsole);
    current_console:=io_console;
  end;
  if parseCmdLine then begin
    writeln('XMODEM receive of file ',filename);
    write('Operating Mode: ');
    case OperatingMode of
      generic: writeln('Use TP kbd/con without any specical settings');
      cpmtty:  writeln('Use CP/M CONSOLE set to tty (uses TP kbd/con), set IOBYTE to 0');
      cpmaux:  writeln('Use CP/M RDR/PUN device, (TP AUX device) - not yet supported');
      mpmcons: writeln('Use MP/M console number ',xm_console:2,' mapped to TP USR device');
      mpmdefcons: writeln('Use MP/M  default console: ',xm_console:2,' mapped to TP USR device');
    end;
    main;
   end else
     writeln('Usage: xmodem <filename> [c:nn] / [g]  [/t]');

end.
