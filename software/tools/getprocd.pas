program getprocd;

(*Read and display MP/M process descriptor *)


{$Iwritehex.inc}
{$V-}

const xdosGetPD = $9C;

type word = integer;
     address = ^byte;

     str255 = string[255];

     pPD = ^processDescriptor;

     processDescriptor = record
        link : pPD;
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
          HL,DE,BC,AF,IY,IX,XHL,XDE,XBC,XAF : word;
        end;
        ext : word;
     end;


var pd :pPD;
    i : integer;


procedure wra(s:str255;v:address;newline:boolean);
begin
  write(s,': ');writehex(ord(v));
  if newline then writeln;

end;


begin
  pd:=ptr(bdoshl(xdosGetPD));
  if pd<> nil then begin
    wra('PD Address: ',ptr(ord(pd)),true);

    with pd^ do begin
      wra('Link: ',ptr(ord(link)),true);
      write('Name: ');
      for i:=1 to 8 do write(chr((name[i]) and $7F));
      writeln;
      wra('SP',stkptr,true);
    end;

  end;

end.
