const xdosGetPD = $9C;

type word = integer;
     address = ^byte;

     str255 = string[255];

     pPD = ^processDescriptor;

     processDescriptor = record
        link : pPD;
        status : byte;
        priority : byte;
        stkptr : address;
        name : array[1..8] of byte;
        cons_list : byte;
        memseg : byte;
        dparam : address;
        thread : address;
        dma : address;
        dsksel : byte;
        dcnt : address;
        srchl : byte;
        srcha : address;
        pd : word;
        reg : record
          XHL,XDE,XBC,XAF,IY,IX,HL,DE,BC,AF : word;
        end;
        ext : word;
     end;


