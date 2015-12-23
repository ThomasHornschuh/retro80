(*Waring: Compile with start address 4000 in Compiler options *)

const mmu_page_reg = $f8;
      mmu_map_h = $fc;
      mmu_map_mh = $fd;
      mmu_map_ml = $fe;
      mmu_map_l  = $ff;

      mmu_data = $fa;

      Test : string[128] = 'The Quick brown fox jumps over the lazy dog';

var i : integer;
    video : array [0..4095] of byte absolute $3000;
    svh,svl : byte;
    buffer : array [0..255] of byte;



begin

  (* Test Pattern in "normal" Memory *)

  for i:=0 to 4095 do video[i]:=ord('#');

  for i:=0 to 255 do write(chr(video[i]));
  writeln;writeln;

  inline($f3); (* Disable interrupts *)

  port[mmu_page_reg]:=$03;

  svh:=port[mmu_map_h];
  svl:=port[mmu_map_mh];


  port[mmu_map_h]:=$20;
  port[mmu_map_mh]:=$02;
  (* port[mmu_map_ml]:=$00;
  port[mmu_map_l]:=$00; *)

  for I:=0 to 4095 do video[i]:=32; (* blank *)
  for I:=1 to length(Test) do video[i-1]:=byte(Test[i]);


  port[mmu_map_h]:=svh;
  port[mmu_map_mh]:=svl;


  inline($fb); (* ei *)

  writeln('save: ',svh:3,svl:3);

  (*Check if memory is remapped correctly and not corrupted *)
  for i:=0 to 255 do write(chr(video[i]));
  writeln;
end.

