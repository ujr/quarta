; *********************************************************************
; *                                                                   *
; *   Q U A R T A                                                     *
; *                                                                   *
; *   Der kompakte Boot-Manager, der inklusive Partitionstabelle      *
; *   in den ersten 512 Bytes der Festplatte platz findet!            *
; *                                                                   *
; *   Copyright (c) 1995 UJR                             30.9.95      *
; *                                                                   *
; *********************************************************************

;
; Translation: tasm QUARTA.ASM <��
;              tlink QUARTA.OBJ <��
;              exe2bin QUARTA.EXE QUARTA.BIN <��
;              binobj QUARTA.BIN QUARTA.B2O PARTCODE <��
;
; Information: Diese Software geht davon aus, dass alle verwendeten
;              BIOS-Funktionen sich entsprechend den Angaben im Buch
;              "PC intern 3.0" von M.Tischer verhalten. Das gilt ins-
;              besondere f�r die Erhaltung von Registerinhalten.
;              Die verwendeten BIOS-Funktionen sind:
;              - INT 10h, Fkt 0Ah und Fkt 0Eh  (Video: Zeichenausgabe)
;              - INT 13h, Fkt 00h und Fkt 02h  (Harddisk: Reset und lesen)
;              - INT 16h, Fkt 00h und Fkt 01h  (Tastatur: Zeichen lesen)
;              - INT 18h                       (ROM-BASIC)
;              >>> SIEHE HINWEISE IM INSTALLER QUELLCODE <<<
;

; Vom BIOS an Adresse 0000:7C00 geladen und ausgef�hrt

               P8086
               LOCALS  @@

PartCode       SEGMENT BYTE

               ASSUME  CS:PartCode


;-- Um Platz zu machen f�r den Boot-Sektor, der per Definition ebenfalls
;-- an die Adresse 0000:7C00 geladen werden muss, verschiebt sich der
;-- Partitionscode nach 0000:0600.

               CLI
               XOR     AX,AX
               MOV     SS,AX
               MOV     ES,AX
               MOV     DS,AX
               MOV     SI,7C00h
               MOV     SP,SI
               MOV     DI,0600h
               MOV     CX,0100h
               CLD
               STI
               REPNZ   MOVSW
               DB      0EAh,1Dh,06,00,00    ; JMP 0000:061D


;-- Wir sind nun im verschobenen Code an der Adresse 0000:061D.

;-- Die aktive Partition ist mit 80h gekennzeichnet, die anderen drei mit
;-- 00h. Wird auf der Suche nach der aktiven Partition eine andere Kenn-
;-- zeichnung angetroffen, wird die Tabelle als ung�ltig erachtet und nach
;-- einer Fehlermeldung begibt sich der Code in eine Endlosschleife.

               MOV     BL,04h
               MOV     SI,07BEh
  NextPart:    CMP     BYTE PTR [SI],80h
               JE      Active
               CMP     BYTE PTR [SI],00h
               JNE     Error1
               ADD     SI,0010h
               DEC     BL
               JNE     NextPart
               INT     18h
  Active:      PUSH    SI
  Check:       ADD     SI,0010h
               DEC     BL
               JE      WaitKey
               CMP     BYTE PTR [SI],00h
               JE      Check
  Error1:      MOV     SI,OFFSET ErrMsg1+600h
               JMP     SHORT Error


;-- Die Tabelle war in Ordnung. Nun werden Titel und Copyright ausgegeben.
;-- Danach hat der Anwender etwa 10 Sekunden Zeit, die zu bootende Partition
;-- �ber die Tasten 1..4 auszuw�hlen.

  WaitKey:     MOV     SI,OFFSET Message+600h
               CALL    Print
               MOV     AX,0AB1h
               MOV     BX,0007h
               MOV     CX,0026h
               INT     10h

               ;-- CX und BX sollten nicht ver�ndert worden sein!
  @@1:         MOV     AX,0EDBh
               INT     10h
               MOV     BX,046Ch
               MOV     SI,[BX]              ; remember: DS=0
               ADD     SI,0005h
  @@2:         MOV     AH,01h
               INT     16h
               JNZ     CalcOfs
               CMP     CS:[BX],SI
               JB      @@2
               LOOP    @@1
               JMP     SHORT LoadBoot       ; keine Taste gedr�ckt


;-- Falls eine Taste gedr�ckt wurde, wird diese ausgelesen und in einen
;-- Offset in die Partitionstabelle umgerechnet.

  CalcOfs:     XOR     AH,AH
               INT     16h
               CMP     AL,'s'               ;
               JNE     @@1                  ; remove these lines if
               MOV     DX,0081h             ; support for a second
               MOV     CX,0001h             ; harddrive is not desired
               JMP     SHORT Second         ;
  @@1:         SUB     AL,'1'
               JS      LoadBoot
               CMP     AL,3
               JG      LoadBoot
               XOR     AH,AH
               MOV     CL,4
               SHL     AX,CL                ; AX := AX * 4
               ADD     AX,07BEh
               PUSH    AX


;-- Der Bootsektor der ausgew�hlten oder als aktiv markierten Partition wird
;-- in den Speicher geladen und ausgef�hrt.

  LoadBoot:    POP     SI
               MOV     DX,[SI]              ; Status & Head     ) aus
               MOV     CX,[SI+02]           ; Sector & Cylinder ) Tab.
               MOV     DL,80h               ; BIOS-Nr f�r HD #1
  Second:      MOV     DI,0005h             ; maximal 5 Leseversuche
  ReadSec:     MOV     BX,7C00h             ; ES:BX -> Zielpuffer
               MOV     AX,0201h             ; Fkt 2: 1 Sektor lesen
               PUSH    DI
               INT     13h
               POP     DI
               JNB     Start
               XOR     AX,AX
               INT     13h                  ; Disk-Reset bei Lesefehler
               DEC     DI
               JNE     ReadSec
               MOV     SI,OFFSET ErrMsg2+600h

  Error:       CALL    Print                ; Fehlermeldung in SI
  Endless:     JMP     SHORT Endless        ; Endlosschlaufe (Reset)

  Start:       MOV     SI,OFFSET ErrMsg3+600h
               MOV     DI,7DFEh             ; Letztes Word adressieren
               CMP     WORD PTR [DI],0AA55h ; Ausf�hrbarer Sektor ?
               JNE     Error
               MOV     SI,OFFSET CRLF+600h
               CALL    Print                ; Zwei Zeilen nach unten
               ;-- evtl SI mit Tabellen-Eintrags-Offset laden...??
               DB      0EAh,00,7Ch,00,00    ; JMP 0000:7C00


;-- Schreibt den in SI �bergebenen ASCIIZ-String auf den Bildschirm

  Print:       LODSB
               OR      AL,AL
               JE      @@1
               PUSH    SI
               MOV     AH,0Eh
               MOV     BX,0007h
               INT     10h
               POP     SI
               JMP     SHORT Print
  @@1:         RET


;-- Die drei m�glichen Fehlermeldungen:

  ErrMsg1:     DB      "Invalid partition table",0
  ErrMsg2:     DB      "Error loading boot sector",0
  ErrMsg3:     DB      "No operating system",0


;-- Die folgenden Texte dienen der Bildschirmgestaltung:

  Message:     DB      13,10,10
               DB      "QUARTA - (c) 1995-97 by UJR",13,10,10
               DB      "To boot",13,10
               DB      "  - your active partition hit ESC",13,10
               DB      "  - any other partition hit 1..4",13,10
               DB      "  - from your 2nd harddisk hit s"
  CRLF:        DB      13,10,10,0


;-- Die Partitionstabelle ab Offset 01BEh wird hier nur angedeutet.
;-- Das letzte Word dieses Sektors muss AA55hex sein, damit das BIOS
;-- ihn als ausf�hrbar erkennt!!

               ORG     1BEh                 ; Die Partitionstabelle
               DB      16 DUP (0)           ; 1. Eintrag
               DB      16 DUP (0)           ; 2. Eintrag
               DB      16 DUP (0)           ; 3. Eintrag
               DB      16 DUP (0)           ; 4. Eintrag

               DW      0AA55h               ; Kennzeichen f�r BIOS


PartCode       ENDS
               END
