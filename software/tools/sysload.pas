program sysload;
{$V-}


const seldsk = 8;
      settrk = 9;
      setsec = 10;
      setdma = 11;
      readsec = 12;
      writesec = 13;


type address = ^byte;


     tDiskParameterBlock = record
       SPT : integer; (* Sectors per track *)
       bsh, blm, exm : byte;
       dsm, drm  : integer;
       al0,al1 : byte;
       chks : integer;
       off : integer; (* Number of system tracks*)
     end;

     tDPH = record
       r1,r2,r3,r4 : integer;
       dirbuff, dpblk,chk0,alv0 : integer;
     end;



     str255 = string[255];



var sector : array [0..127] of byte;

    dest : byte;

    image : file;
    simul : boolean;


procedure writeHex(x:integer;len:integer);
var i : integer;
    nibble : byte;

begin
  for i:=(len-1) downto 0 do begin
   nibble := x shr (i*4) and $0f;
   if nibble<=9 then
     write(chr(nibble+ord('0')))
   else
     write(chr(nibble-10+ord('A')));
  end;

end;



function parseDrive( param: str255;var drive:byte):boolean;
begin
  if (length(param)=2) and (param[1] in ['a','b','A','B']) and (param[2]=':') then begin
    drive:=ord(Upcase(param[1]))-ord('A');
    parseDrive:=true;
  end else
    parseDrive:=false;

end;


procedure dumpsector(num:integer);
var col,ofs : integer;
begin
  ofs:=0;
  while ofs<128 do begin

    writehex(num*128+ofs,4);write(' ');
    for col:=1 to 16 do begin
      writehex(sector[ofs],2);write(' ');
      ofs:=ofs+1;
    end;
    writeln;
  end;

end;


procedure doCopy;
var dph : ^tDPH;
    dpb2 : ^tDiskParameterBlock;
    t, s,c : integer;
begin
  dph:=ptr(biosHL(selDsk,dest));
  dpb2:=ptr(dph^.dpblk);


  writeln('copy: ',dpb2^.SPT:1,' Sectors ',dpb2^.off:1, ' tracks');

  c:=0;
  for t:=0 to dpb2^.off-1 do begin

    writeln('Copy of track ',t,' sectors:');
    for s:=0 to dpb2^.SPT-1 do begin
    (*  write(s:3,' ');
      if ((s+1) mod 8) = 0 then writeln; *)
      (* read *)
      writeln('Read...');
      blockread(image,sector,1);
      dumpsector(c);
      writeln('write...'); 
      if not simul then begin
        bios(seldsk,dest);       
        bios(setdma,addr(sector));       
        bios(settrk,t);
	bios(setsec,s);
        bios(writesec);       
      end;
      c:=c+1;
    end;
    writeln;
  end;
end;


begin
  if hi(bdosHL(12))=1 then begin
    writeln('Please use CP/M to run this program');
    simul:=true;
  end else
    simul:=false;

  if paramCount<>2 then begin
    writeln('Usage: sysload <srcfile> <destdrive>, eg sysload xx.bin b:');
    halt;
  end;
  assign(image,paramstr(1));
  {$I-}
  reset(image);
  if ioresult<>0 then begin
    writeln('Image File cannot be opened');
    halt;
  end;
  {$I+}

  if parseDrive(paramStr(2),dest) then
    doCopy
  else
    writeln('Invalid drive specification');
end.
