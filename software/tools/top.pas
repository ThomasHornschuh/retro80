program top; (* Process monitor for MP/M, like UNIX top  *)

{$IXDOS.INC}
{$IWRITEHEX.INC}

const maxProcesses=40; (*Max number of displayable processes *)


var ProcTable : array [1..maxProcesses] of pxdos_PD;
    maxIndex : integer;
    xdosDS : address;
    I : integer;



procedure writeEntry(pd:pxdos_PD);

const StatDisplay : array [0..14] of string[3] =

 (
  'RUN',
  'DEQ',
  'ENQ',
  'POL',
  'FLG',
  'DLY',
  '',
  'TRM',
  'PRI',
  'DIS',
  'DET',
  '',
  '',
  '',
  ''

 );


(*     0 - process is ready to run
       1 - process is dequeueing
       2 - process is enqueueing
       3- process is polling
       4 - process is waiting for a flag
       5 - process is on delay list
       6 - not implemented under MP/M II
       7 - terminate process
       8 - set process priority
       9 - Dispatch
       10 - Attach console
       11 - Detach console
       12 - Set console
       13 - Attach list
       14 - Detach list

*)

var procName : array [1..8] of char;
    I : 1..8;

begin

  writehex(ord(pd));
  with pd^ do begin
    for I:=1 to 8 do procName[I]:=chr(name[I] and $7F);

    writeln(' ',procName:9,'[',(cons_list and $0F):1,'] ',
            status:2,' ',statDisplay[status] );

{    write(' ',status:3,priority:3,procName:9,'[',(cons_list and $0F):1,']',
          memseg:3);  }
  end;

end;



procedure getAllProcesses;


  procedure traverseItems(pd:pxdos_PD);
  begin
    while pd<>nil do begin
      writeEntry(pd);
      ProcTable[maxIndex]:=pd;
      maxIndex:=maxIndex+1;
      pd:=pd^.link;
    end;
  end;



  procedure processList(dsOffset:integer);
  var pd  : pxdos_PD;
      ppd : ^pxdos_PD;

  begin
    ppd:=ptr(ord(xdosDS)+dsOffset); (* Get Pointer to list head pointer *)
    if ppd<>nil then begin
      pd:=ppd^;
      traverseItems(pd);
    end;
  end;


  procedure processQueueList;
  var pqd : pxdos_QD;
      ppqd : ^pxdos_QD;

  begin
    ppqd:=ptr(ord(xdosDS)+osq1r);
    if ppqd<>nil then begin
      pqd:=ppqd^;
      while pqd<>nil do begin
        with pqd^ do begin
          traverseItems(dqph);
          traverseItems(nqph);
        end;
        pqd:=pqd^.link;
      end;
    end;
  end;


  procedure processPDArray(offset:integer;length:integer);
  var pFlagArray : pxdos_flagArray;
      I : integer;
      pd : pxdos_PD;

  begin
    pFlagArray:=ptr(ord(xdosDS)+offset);
    for I:=1 to length do begin
      pd:=pFlagArray^[I];
      if (pd<>nil) and ((ord(pd) and $FFFE) <> $FFFE) then begin
        writeEntry(pd);
        ProcTable[maxIndex]:=pd;
        maxIndex:=maxIndex+1;
      end;
    end;
  end;





begin
  maxIndex:=1;
  writeln('Ready list');
  processList(osr1r);  (* Ready list *)
  writeln('delay list');
  processList(osd1r);  (* delay list *)
  writeln('poll list');
  processList(osp1r);  (* poll  list *)
  writeln('Flag waiting');
  processPDArray(ossysfla,numFlags);
  writeln('Detached');
  processPDArray(oscnsque,16);
  writeln('queue list');
  processQueueList;  (* queue list *)

end;



begin
  xdosDS:=getXDOSDataSegment;
  writehex(ord(xdosDS));writeln;
  if xdosDS=nil then begin
    writeln('Cannot get XDOS Data Segment, Abort');
    halt;
  end;
  getAllProcesses;

(* Test Output *)

 writeln('*********');
 for I:=1 to maxIndex-1 do writeEntry(ProcTable[I]);

end.
