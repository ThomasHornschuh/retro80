program mpmcli;

const xdos_cli = 150;
      xdos_assign_console = 149;
      xdos_getconsole = 153;
      xdos_attachconsole = 146;
      xdos_setpriority = 145;

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

begin

  repeat
    write('Command: ');
    readln(cmd);
    if cmd='.' then exit;
    bdos(xdos_setpriority,190); (*Increase to be higher then MPM TMP process *)
    ca.console_number :=bdos(xdos_getconsole);
    writeln(ca.console_number);
    writeln('...');

    ca.process_name := 'cli     ';
    ca.match:=0;
    res:=bdos(xdos_assign_console,addr(ca));

    with cmdblk do begin
      dsk_user_byte := 0;
      console_number:=ca.console_number;
      for i:=1 to length(cmd) do cmd_line[i]:=cmd[i];
      cmd_line[length(cmd)+1]:=chr(0);
    end;
    bdos(xdos_cli,addr(cmdblk));

    bdos(xdos_attachconsole);
    writeln;
    bdos(xdos_setpriority,200); (* change prio back  *)
  until false;


end.
