program ps2test;

type digits= 1..4;


var scan : byte;

procedure writeHex(x:integer;length:digits);
var i : integer;
    nibble : byte;

begin
  for i:=length-1 downto 0 do begin
   nibble := x shr (i*4) and $0f;
   if nibble<=9 then
     write(chr(nibble+ord('0')))
   else
     write(chr(nibble-10+ord('A')));
  end;

end;


begin

  repeat
    while not keypressed and (port[$40]=0) do;
    if port[$40]=1 then begin
      scan:=port[$41];
      port[$40]:=$01; (* Clear flag *)
      writeHex(scan,2);
      write(' ');
    end;
    bdos(141,2); (*Wait two ticks to throttle load *)
  until keypressed;
end.
