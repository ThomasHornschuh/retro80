{$R-}
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

     tError = (success,chkfail,abort,xEof);

var  logfile,tracefile : text;
     blockfile : file;


Function UpdateCRC16(CRC       : Integer;      { CRC-16 to update  }
                      data     : byte
                    ) : Integer;
    Var Bit          : Integer;
        Carry                   : Boolean;      { catch overflow    }
    begin
        For Bit := 7 downto 0 do begin          { 8 bits per Byte   }
            Carry := CRC and $8000 <> 0;        { shift overlow?    }
            CRC := CRC SHL 1 or data  SHR Bit and 1;
            if Carry then CRC := CRC xor $1021; { apply polynomial  }
        end; { For Bit & ByteCount }            { all Bytes & bits  }
    UpdateCRC16 := CRC;                         { updated CRC-16    }
 end {UpdateCRC16};


function xmodem_recv(var f:text;var buffer:tblock;var len:integer;var blocknum:byte;useCRC:boolean):tError;
label 99;

var c,c2,h1,h2: char;
    x1k : boolean;
    i : integer;
    checksum : byte;
    crc16 : integer;
    err : boolean;

begin
  (* Wait for block begin marker *)
  repeat
    read(f,c);
    case ord(c) of
      soh : x1k := false;
      stx : x1k := true;
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
    else
        writeln(logfile,'Invalid char: ',c);
    end;
  until ord(c) in [soh,stx];
  read(f,h1,h2);
  blocknum:=ord(h1);

  if x1k then
    len:=1024
  else
    len:=128;

  if trace then writeln(tracefile,'Block header: ',ord(c):4,ord(h1):4,ord(h2):4,' Length:',len:5);
  checksum:=0;
  crc16:=0;
  for i:=1 to len do begin
    read(f,c);
    if trace then write(tracefile,c);
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


procedure doReceive;
var len : integer;
    buff : tBlock;
    status : tError;
    blocknum,lastnum : byte;

begin
  lastnum :=0;
  repeat
    status:=xmodem_recv(kbd,buff,len,blocknum,false);
    case status of
      success,
      chkfail: begin
                 write(logfile,'Block ',blocknum:1,' received ',len:1,' Bytes');
                 if status=chkfail then begin
                   write(logfile,' chksum/crc error');
                   write(con,chr(nack));
                   writeln(logfile);
                 end else begin
                   writeln(logfile);
                   if blocknum<>lastnum then
                     writeBuffer(buff,len)
                   else
                     writeln(logfile,'Duplicate block ', blocknum:4,' ignored');
                   lastnum:=blocknum;
                   write(con,chr(ack));
                 end;
               end;
      xeof:  begin
               writeln(logfile,'Transfer completed');
               write(con,chr(ack));
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




begin
  if ParamCount<>1 then begin
    writeln('Usage: xmodem <filename>');
    halt;
  end;

  assign(blockfile,ParamStr(1));
  rewrite(blockfile);



  assign(logfile,'xmodem.log');

  rewrite(logfile);
  if trace then begin
    assign(tracefile,'xmodem.trc');
    rewrite(tracefile);
  end;
  writeln('Start transfer...');
  repeat
    bdos(141,62); (* Wait 62 Ticks ~ 1 Second *)
    write(con,chr(nack));
    bdos(141,2); (* Wait 2 tick ~ 32ms *)
  until keypressed; (*Because we receive over console "keypressed" means a byte was received *)
  doReceive;
  close(logfile);
  if trace then close(tracefile);
end.
