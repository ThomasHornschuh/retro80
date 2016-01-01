var dbp: integer;


procedure writeHex(x:integer);
var i : integer;
    nibble : byte;

begin
  for i:=3 downto 0 do begin
   nibble := x shr (i*4) and $0f;
   if nibble<=9 then
     write(chr(nibble+ord('0')))
   else
     write(chr(nibble-10+ord('A')));
  end;

end;



begin
  dbp:=bdoshl(31);
  writeHex(dbp);


end.
