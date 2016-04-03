Function UpdateCRC16(CRC       : Integer;      { CRC-16 to update  }
                      data     : byte
                    ) : Integer;
    Var Bit          : Integer;
        Carry                   : Boolean;      { catch overflow    }
    begin
        For Bit := 7 downto 0 do begin          { 8 bits per Byte   }
            Carry := CRC and $8000 <> 0;        { shift overlow?    }
            CRC := CRC SHL 1 or data  SHR Bit and 1;
            if Carry then CRC := CRC xor $1021; { apply polynomial  }
        end; { For Bit & ByteCount }            { all Bytes & bits  }
    UpdateCRC16 := CRC;                         { updated CRC-16    }
 end {UpdateCRC16};