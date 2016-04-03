function parseCmdLine:boolean;
 label 99; (* Error Handler *)
 var I : integer;
     param : string[80];
     code : integer;
     cons : integer;
     fModeSet : boolean;
     fFileName : boolean;

     function checkAlreadySet:boolean;
     begin
       if fModeSet then begin
         writeln('Only one occurence of /c or /g option allowed');
         checkAlreadySet:=true;
       end else begin
        fModeSet:=true;
        checkAlreadySet:=false;
      end;
    end;


 begin
    fModeSet:=false;
    fFileName:=false;
    for I:=1 to ParamCount do begin
       param:=ParamStr(I);
       if param[1]='/' then (*command line option *)
          case UpCase(param[2]) of
            'C': begin
                   if checkAlreadySet then begin
                     parseCmdLine:=false;
                     goto 99;
                   end;
                   if osver<>mpm then begin
                      writeln('/C option only allowed with MP/M');
                      parseCmdLine:=false;
                      goto 99;
                   end;
                   cons:= -1;
                   Val(copy(param,4,80),cons,code);
                   if (code<>0) or (param[3]<>':') or (cons<0) or (cons>15) then begin
                      writeln('Error in /c option. Usage /c:nn nn = 0..15');
                      parseCmdLine:=false;
                      goto 99;
                   end;
                   if cons=bdos(xdos_getconsole) then
                      OperatingMode:=mpmdefcons
                   else
                     OperatingMode:=mpmcons;
                   xm_console:=cons;
                 end;
            'G': begin
                   if checkAlreadySet then begin
                     parseCmdLine:=false;
                     goto 99;
                   end;
                   OperatingMode:=generic;
                 end;
            'T': trace:=true;
          end (*case *)
        else  (* param does not start with a / - assume filename *)
          if fFileName then begin  (* already set *)
            writeln('Only one filename parameter allowed');
            parseCmdLine:=false;
            goto 99;
          end else begin
            fFileName:=true;
            filename:=copy(paramStr(I),1,15);
         end;
    end;  (* for *)

    if not fFileName then begin
      writeln('Filename missing');
      parseCmdLine:=false;
      goto 99;
    end;
    if not fModeSet then (*If no mode option set then set default behaviour *)
      case (osver) of
        mpm: begin
              xm_console:=bdos(xdos_getconsole);
              OperatingMode:=mpmdefcons;
             end;
        cpm2: OperatingMode:=cpmtty;
        cpm3: OperatingMode:=generic;
      end;
    parseCmdLine:=true;
 99:
 end;