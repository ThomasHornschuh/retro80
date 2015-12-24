(*Waring: Compile with start address 4000 in Compiler options *)

const mmu_page_reg = $f8;
      mmu_map_h = $fc;
      mmu_map_l  = $fd;

      Test : string[128] = 'The Quick brown fox jumps over the lazy dog';


type  str128 = string[128];

var i : integer;
    video : array [0..4095] of byte absolute $3000;
    svh,svl : byte;
    buffer : array [0..255] of byte;


    procedure writestring(x,y:integer;var s:str128);

    var adr,i : integer;

    begin
      adr:= y*80 + x;

      i:=1;
      while i<=length(s) do begin
        if (adr>=0) and (adr<=4095) then begin
          video[adr]:=byte(s[i]);
        end;
        i:=succ(i);
        adr:=succ(adr);
      end;

    end;

begin




  (* Test Pattern in "normal" Memory *)

  for i:=0 to 4095 do video[i]:=ord('#');

  for i:=0 to 255 do write(chr(video[i]));
  writeln;writeln;

  inline($f3); (* Disable interrupts *)

  port[mmu_page_reg]:=$03;

  svh:=port[mmu_map_h];
  svl:=port[mmu_map_l];


  port[mmu_map_h]:=$20;
  port[mmu_map_l]:=$02;

  for I:=0 to 4095 do video[i]:=32; (* blank *)
  writestring(0,0,Test);
  writestring(0,39,Test);

  port[mmu_map_h]:=svh;
  port[mmu_map_l]:=svl;


  inline($fb); (* ei *)

  writeln('save: ',svh:3,svl:3);

  (*Check if memory is remapped correctly and not corrupted *)
  for i:=0 to 255 do write(chr(video[i]));
  writeln;
end.
