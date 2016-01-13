program syscopy;
{$V-}

{$IWRITEHEX.INC}

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

    src,dest : byte;


function parseDrive( param: str255;var drive:byte):boolean;
begin
  if (length(param)=2) and (param[1] in ['a','b','A','B']) and (param[2]=':') then begin
    drive:=ord(Upcase(param[1]))-ord('A');
    parseDrive:=true;
  end else
    parseDrive:=false;

end;


procedure doCopy;
var dph : ^tDPH;
    dpb1,dpb2 : ^tDiskParameterBlock;
    t, s : integer;
begin
  dph:=ptr(biosHL(selDsk,dest));
  dpb2:=ptr(dph^.dpblk);
  dph:=ptr(biosHL(selDsk,src));
  dpb1:=ptr(dph^.dpblk);
  if (dpb1^.SPT<>dpb2^.SPT) or (dpb1^.off <>dpb2^.off) then begin
    writeln('Src and Dest disk are not compatible');
    halt;
  end;
  writeln('copy: ',dpb1^.SPT:1,' Sectors ',dpb1^.off:1, ' tracks');

  bios(setdma,addr(sector));
  for t:=0 to dpb1^.off-1 do begin
    bios(settrk,t);
    writeln('Copy of track ',t,' sectors:');
    for s:=0 to dpb1^.SPT-1 do begin
      write(s:3,' ');
      if ((s+1) mod 8) = 0 then writeln;
      bios(setsec,s);
      (*copy *)
      bios(seldsk,src);
      bios(readsec);
      bios(seldsk,dest);
      bios(writesec);
    end;
    writeln;
  end;



end;


begin
  if hi(bdosHL(12))=1 then begin
    writeln('Please use CP/M to run this program');
    halt;
  end;

  if paramCount<>2 then begin
    writeln('Usage: syscopy <src> <dest>, eg syscopy a: b:');
    halt;
  end;
  if parseDrive(paramStr(1),src) and parseDrive(paramStr(2),dest) then
    doCopy
  else
    writeln('Invalid drive specification');
end.
