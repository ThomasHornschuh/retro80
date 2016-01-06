program mpmcli;

const xdos_cli = 150;
      xdos_assign_console = 149;
      xdos_getconsole = 153;
      xdos_attachconsole = 146;
      xdos_setpriority = 145;
      xdos_delay = 141;

type clicmd = record
        dsk_user_byte : byte;
        console_number : byte;
        cmd_line : array [1..129] of char;
     end;

     abp = record
       console_number : byte;
       process_name : array [0..7] of char;
       match : byte;
     end;




var cmdblk : clicmd;
    ca : abp;
    cmd : string[128];
    i : integer;
    res : byte;
    runOnce: boolean;
    repMode : boolean;

procedure parsecmdline;
var buffer: string[16];
    i : integer;

begin
  cmd:='';
  repMode:=false;
  for i:=1 to ParamCount do begin
    buffer:=ParamStr(i);
    if buffer[1]='/' then begin
      if buffer[2] in ['r','R'] then
        RepMode:=true
      else
        writeln('Unknown option /',buffer[2]);
    end else
      cmd := cmd + buffer + ' ';
  end;

end;



begin

  repeat
    runOnce:=ParamCount>=1;
    if runOnce then begin
      parsecmdline;
      writeln('Excecuting: ',cmd);
    end else begin
      write('Command: ');
      readln(cmd);
    end;
    if cmd='.' then exit;

    ca.console_number :=bdos(xdos_getconsole);
    ca.process_name := 'cli     ';
    ca.match:=0;

    with cmdblk do begin
      dsk_user_byte := 0;
      console_number:=ca.console_number;
      for i:=1 to length(cmd) do cmd_line[i]:=cmd[i];
      cmd_line[length(cmd)+1]:=chr(0);
    end;

    bdos(xdos_setpriority,190); (*Increase to be higher then MPM TMP process *)
    repeat
      res:=bdos(xdos_assign_console,addr(ca));
      bdos(xdos_cli,addr(cmdblk));
      bdos(xdos_attachconsole);
      writeln;
      if repMode then bdos(xdos_delay,61); (*~1 Seconds *)
    until keypressed or not repMode;

    bdos(xdos_setpriority,200); (* change prio back  *)
  until runOnce;


end.
