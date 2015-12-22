(*Include File for MPM Time of Day Function *)


const XDOSgetTOD=$9B;

type tTOD= record
       date : integer; (* Number of days since 01.01.1978 *)
       hour,minute, second : byte;
     end;

     str2 = string[2];


procedure getTOD(var tod:tTOD);
begin
  bdos(XDOSgetTOD,addr(tod));
end;


function BCDtoInt(bv:byte):integer;
begin
  BCDtoInt:= ((bv and $f0) shr 4)*10 + (bv and $0f);

end;


function BCDToString(bv:byte):str2;
var s: str2;
begin
  s[0]:=chr(2); (*Length *)
  s[1]:= chr((bv and $f0) shr 4 + ord('0'));
  s[2]:= chr((bv and $0f)  + ord('0'));
  BCDToString:=s;

end;


function timeDiff(var tod1:tTOD;var tod2:tTOD):real;
var d1,d2: real;
    days : integer;

  function calcSeconds(var tod:tTOD):real;
  begin
    with tod do
      calcSeconds:= BCDToInt(hour)*3600.0 + BCDToInt(minute)*60.0 + BCDToInt(second);
  end;


begin
  d1:=calcSeconds(tod1);
  d2:=calcSeconds(tod2);

  if tod1.date=tod2.date then (*Values are on the same day *)
    timeDiff:=d1-d2
  else  begin
    days := tod1.date - tod2.date;
    timediff := d1 - d2 + days*86400.0;
  end;


end;

procedure printTime(var f:text;var tod:tTOD);
begin
  with tod do
    write(f,BCDToString(hour):2,':',BCDToString(minute):2,':',BCDToString(second):2);

end;

