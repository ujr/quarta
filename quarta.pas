{*********************************************************************}
{                                                                     }
{   Q U A R T A    v2.0                                               }
{                                                                     }
{   Installationsprogramm f�r QUARTA, den kompakten Boot-Manager,     }
{   der inklusive Partitionstabelle in den ersten 512 Bytes der       }
{   Festplatte Platz findet!                                          }
{                                                                     }
{   Copyright (c) 1995, 1996, 1997 by UJR                             }
{                                                                     }
{*********************************************************************}

{
  History:     30.09.95  Start of development
               20.11.95  Release of version 1.0
               30.03.97  Major rewrite -> v2.0
  Translation: Compile with Borland Pascal 7.0 (or similar)
  Information: Der Boot-Manager mu�te wirklich sehr simpel gehalten
               werden, um mitsamt der Partitionstabelle in einem Sektor
               Platz zu finden.
               Kommentar im Assembler Source lesen!!!
}

program Quarta;

{ $DEFINE TESTING}     { if defined, this prog won't write into MBR }

const    ERR_READ_MBR: pChar = 'Error reading master boot record';
         ERR_WRITE_MBR: pChar = 'Error writing master boot record';
         ERR_READ_FILE: pChar = 'Error reading file';
         ERR_WRITE_FILE: pChar = 'Error writing file';
         ERR_CHANGED_MIND: pChar = 'You decided not to modify your MBR';

const    SECTOR_SIZE = 512;    { Gr�sse eines Sektors in Bytes }
         MAX_RETRIES = 5;      { Max Anzahl schreib/lese-Versuche }

const    DRIVE_1 = $80;        { BIOS-Nummer f�r erste HD }
         DRIVE_2 = $81;        {                 zweite   }

const    INSTALL_QUARTA = 0;   { Install QUARTA code in MBR }
         READ_MBR = 1;         { MBR auslesen und in Datei sichern }
         WRITE_MBR = 2;        { Dateiinhalt in MBR schreiben }
         WRITE_COMPLETE = 3;   { write code AND table }

type     SECTOR = array[0..SECTOR_SIZE-1] of Byte;

var      Drive: Byte;          { DRIVE_1 or DRIVE_2 }
         Task: Byte;           { INSTALL_MBR, READ_MBR, or WRITE_MBR }
         Filename: String;     { READ_MBR and WRITE_MBR involve a file }
         i: Integer;


procedure PartCode; external; {$L QUARTA.B2O}
{ Herein is the actual boot manager! }

procedure Usage;
begin
  WriteLn('Usage: quarta [-q|r|w|x|?] [-disk] file');
  WriteLn('  -q  install QUARTA code in MBR (default)');
  WriteLn('  -r  read MBR from ''disk'' and store it in ''file''');
  WriteLn('  -w  read ''file'' and store it in MBR of ''disk'' (be careful!)');
  WriteLn('  -x  does the same as -w but also writes the partition table!');
  WriteLn('  -?  get help text on this program');
  WriteLn('  ''disk'' is either 1 or 2 (1st or 2nd harddisk, respectively)');
  WriteLn;
  Halt( 1 );
end;

procedure Help;
begin
  WriteLn('This program may be used to perform three tasks using the');
  WriteLn('three main command line options -r, -w, and -q:');
  WriteLn;
  WriteLn('-r Copy the code in the master boot record (MBR) to a file.');
  WriteLn('   The following syntax example copies the MBR of your first');
  WriteLn('   harddisk into a file called mbr.bak:');
  WriteLn('     quarta -r mbr.bak');
  WriteLn;
  WriteLn('-w Copy a file into the MBR you have previously created as');
  WriteLn('   explained above. BE CAREFUL with this option. If you write');
  WriteLn('   nonsense into your MBR your computer won''t boot any more!');
  WriteLn('   The following example copies the contents of the file mbr.bak');
  WriteLn('   into the MBR of your second harddisk:');
  WriteLn('     quarta -w -2 mbr.bak');
  WriteLn('   (Note: -x also writes the table. BE EXTREMELY CAREFUL!');
  WriteLn;
  WriteLn('-q This options installs the quarta boot manager code into your');
  WriteLn('   MBR. This code will let you choose at startup, which partition');
  WriteLn('   want to boot. Usage: quarta without any parameters.');
  WriteLn;
  WriteLn('Copyright (c) 1995, 1996, 1997 by UJR');
  WriteLn('READ THE DOCUMENTATION THAT CAME WITH THIS PROGRAM FOR MORE INFO!');
  WriteLn;
  Halt;
end;

{$IFDEF TESTING}

function WriteSector( Drive, Head: Byte; SecCyl: Word; var Buf ): Boolean;
var F: File;
    R: Word;
begin
  WriteLn('WriteSector( ', Drive,', ',Head,', ',SecCyl,', Buf )');
  Assign( F, 'dump.mbr');
{$I-}
  Rewrite( F, 1 );
  BlockWrite( F, Buf, sizeof( SECTOR ), R );
  Close( F );
{$I+}
  WriteSector := ( IOResult = 0 ) and ( R = SECTOR_SIZE );
end;

{$ELSE}

function WriteSector( Drive, Head: Byte; SecCyl: Word; var Buf ): Boolean; assembler;
var R: Byte;
asm
        MOV     R,MAX_RETRIES
@@1:    MOV     AX,0301h
        MOV     DL,Drive
        MOV     DH,Head
        MOV     CX,SecCyl
        LES     BX,Buf
        INT     13h
        JC      @@2
        MOV     AL,01h
        JMP     @@3
@@2:    XOR     AX,AX
        INT     13h
        DEC     R
        JNZ     @@1
        XOR     AL,AL
@@3:
end;

{$ENDIF}

function ReadSector( Drive, Head: Byte; SecCyl: Word; var Buf ): Boolean; assembler;
var R: Byte;
asm
        MOV     R,MAX_RETRIES
@@1:    MOV     AX,0201h
        MOV     DL,Drive
        MOV     DH,Head
        MOV     CX,SecCyl
        LES     BX,Buf
        INT     13h
        JC      @@2
        MOV     AL,01h
        JMP     @@3
@@2:    XOR     AX,AX
        INT     13h
        DEC     R
        JNZ     @@1
        XOR     AL,AL
@@3:
end;

procedure Fatal( p: pChar );
begin
  if p <> nil then WriteLn( p );
  WriteLn;
  Halt( 255 );
end;

function Exists( FileName: String ): Boolean;
var F: File;
begin
  Assign( F, FileName );
{$I-}
  Reset( F );
  Close( F );
{$I+}
  Exists := ( IOResult = 0 ) and ( FileName <> '' );
end;

function OverWrite( Filename: String ): Boolean;
var Ch: Char;
begin
  WriteLn( Filename, ' already exists.');
  Write('Do you want to overwrite this file? (y/n) ');
  ReadLn( Ch ); OverWrite := ( Ch = 'Y') or ( Ch = 'y');
end;

function AreYouSure: Boolean;
var Ch: Char;
begin
  Write('Are you sure you want to modify your master boot record? (y/n) ');
  ReadLn( Ch ); AreYouSure := ( Ch = 'Y') or ( Ch = 'y');
end;

function WriteSectorFile( S: String; var Buffer ): Boolean;
var F: File;
    R: Word;
begin
  Assign( F, S );
{$I-}
  Rewrite( F, 1 );
  BlockWrite( F, Buffer, SECTOR_SIZE, R );
  Close( F );
{$I+}
  WriteSectorFile := ( IOResult = 0 ) and ( R = SECTOR_SIZE );
end;

function ReadSectorFile( S: String; var Buffer ): Boolean;
var F: File;
    R: Word;
begin
  Assign( F, S );
{$I-}
  Reset( F, 1 );
  BlockRead( F, Buffer, SECTOR_SIZE, R );
  Close( F );
{$I+}
  ReadSectorFile := ( IOResult = 0 ) and ( R = SECTOR_SIZE );
end;

procedure InstallQuarta( Drive: Byte );
var FBuffer, MBuffer: SECTOR;
begin
  {$IFDEF TESTING}WriteLn('InstallQuarta( ', Drive, ' )');{$ENDIF}
  Move( @PartCode^, FBuffer, 512 );
  if not ReadSector( Drive, 0, 1, MBuffer ) then Fatal( ERR_READ_MBR );
  if not AreYouSure then Fatal( ERR_CHANGED_MIND );
  Move( MBuffer[$1BE], FBuffer[$1BE], 4*16 );
  if not WriteSector( Drive, 0, 1, FBuffer ) then Fatal( ERR_WRITE_MBR );
end;

procedure SaveToFile( Drive: Byte; Filename: String );
var Buffer: SECTOR;
begin
  {$IFDEF TESTING}WriteLn('SaveToFile( ', Drive,', ', Filename,' )');{$ENDIF}
  if not ReadSector( Drive, 0, 1, Buffer ) then Fatal( ERR_READ_MBR );
  if Exists( Filename ) then if not OverWrite( Filename ) then Fatal( nil );
  if WriteSectorFile( Filename, Buffer ) then
    WriteLn('Stored current mbr to file ', Filename )
  else Fatal( ERR_WRITE_FILE );
end;

procedure WriteNewMBR( Drive: Byte; Filename: String );
var FBuffer, MBuffer: SECTOR;
begin
  {$IFDEF TESTING}WriteLn('WriteNewMBR( ', Drive,', ', Filename,' )');{$ENDIF}
  if not ReadSectorFile( Filename, FBuffer ) then Fatal( ERR_READ_FILE );
  if not ReadSector( Drive, 0, 1, MBuffer ) then Fatal( ERR_READ_MBR );
  if not AreYouSure then Fatal( ERR_CHANGED_MIND );
  Move( MBuffer[$1BE], FBuffer[$1BE], 4*16 );
  if not WriteSector( Drive, 0, 1, FBuffer ) then Fatal( ERR_WRITE_MBR );
end;

procedure WriteComplete( Drive: Byte; Filename: String );
var Buffer: SECTOR;
begin
  {$IFDEF TESTING}WriteLn('WriteComplete( ', Drive,', ', Filename,' )');{$ENDIF}
  if not ReadSectorFile( Filename, Buffer ) then Fatal( ERR_READ_FILE );
  if not AreYouSure then Fatal( ERR_CHANGED_MIND );
  if not WriteSector( Drive, 0, 1, Buffer ) then Fatal( ERR_WRITE_MBR );
end;


begin
  Drive := DRIVE_1;                    { default }
  Task := INSTALL_QUARTA;              { default }
  Filename := '';                      { no filename for this task }

  if ParamCount > 0 then
    for i := 1 to ParamCount do
      begin
        if ParamStr( i ) = '-?' then Help
        else if ParamStr( i ) = '-q' then Task := INSTALL_QUARTA
        else if ParamStr( i ) = '-r' then Task := READ_MBR
        else if ParamStr( i ) = '-w' then Task := WRITE_MBR
        else if ParamStr( i ) = '-x' then Task := WRITE_COMPLETE
        else if ParamStr( i ) = '-1' then Drive := $80
        else if ParamStr( i ) = '-2' then Drive := $81
        else Filename := ParamStr( i );
      end;
  if Task = INSTALL_QUARTA then begin
    if Filename <> '' then Usage;
  end else begin
    if Filename = '' then Usage;
  end;

  case Task of
    INSTALL_QUARTA: InstallQuarta( Drive );
    READ_MBR:       SaveToFile( Drive, Filename );
    WRITE_MBR:      WriteNewMBR( Drive, Filename );
    WRITE_COMPLETE: WriteComplete( Drive, Filename );
  end;
end.
