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
    simul,wait : boolean; (* options *)
    diskbyte : byte  absolute $4; (* CP/M Disk/User byte *)


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
  if (length(param)=2) and
     (param[1] in ['a','b','A','B']) and (param[2]=':') then begin
    drive:=ord(Upcase(param[1]))-ord('A');
    parseDrive:=true;
  end else
    parseDrive:=false;

end;


procedure parseOptions(param:str255);
var I : integer;
begin

  for I:=1 to length(param) do
    case param[i] of
      'w','W': wait:=true;
      's','S': simul:=true;
    else
      writeln('Unkown option ',UpCase(param[i]),' ignored');
    end;
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


    procedure doWait;
    var c: char;
    begin
      if wait then begin
        repeat until keypressed;
        read(kbd,c);
        if ord(c)=3 then begin
          write('Warning: Abort of sysload can lead to unbootable disk, are you sure(Y/N)?');
          read(kbd,c);
          if UpCase(c)='Y' then halt;
        end else
          wait:=  UpCase(c)<>'C';
      end;
    end;

begin
  wait:=true;
  if  bdosHL(12)<>$0022 then begin
    dpb2:=ptr(bdosHL(31));
  end else begin
    dph:=ptr(biosHL(selDsk,dest));
    write('dph:');writeHex(ord(dph),4);writeln;
    dpb2:=ptr(dph^.dpblk);
  end;

   write('dpb2:');writeHex(ord(dpb2),4);writeln;
  writeln('copy: ',dpb2^.SPT:1,' Sectors ',dpb2^.off:1, ' tracks');
  doWait;
  c:=0;
  for t:=0 to dpb2^.off-1 do begin

    writeln('Copy of track ',t,' sectors:');
    for s:=0 to dpb2^.SPT-1 do begin
      writeln('Read...');
      bios(seldsk,diskbyte and $0F); (*Set BIOS back to orginal value *)
      blockread(image,sector,1);
      dumpsector(c);
      doWait;
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
  wait:=false;
  simul:=false;

  if not (paramCount in [2,3]) then begin
    writeln('Usage: sysload <srcfile> <destdrive> <s><w>  , eg sysload xx.bin b: w');
    writeln('Options: s = simluate, w=wait after each sector');
    halt;
  end;


  if hi(bdosHL(12))=1 then begin
    writeln('This program cannot write to disk under MP/M');
    writeln('Forciing simul/wait mode ');
    simul:=true;
    wait:=true;
  end else begin
    if paramCount=3 then parseOptions(paramStr(3));
    if simul then writeln('Running in simlation mode');
  end;

  assign(image,paramStr(1));
  {$I-}
  reset(image);
  if ioresult<>0 then begin
    writeln('Image File cannot be opened');
    halt;
  end;
  {$I+}

  if parseDrive(paramStr(2),dest) then begin
    doCopy;
    if not simul then begin
      writeln('Please reboot system with press of reset key');
      repeat until keypressed;
    end;
  end else
    writeln('Invalid drive specification');
end.

