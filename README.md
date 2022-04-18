
# Quarta Bootmanager

Quarta is a boot manager for IBM PC computers.
It is so tiny that it fits into the first sector of any harddisk,
along with the partition table. I wrote quarta a long time ago
because I was in need of a boot manager and because I was curious
about low level programming.
It is now only of historical interest, if it is at all interesting.

## Technical Notes

In the IBM PC world, the first sector of a hard disk is known
as the *Master Boot Record* or MBR for short. It contains
at most 400 bytes of code followed by the partition table
of about 100 bytes at the end of the sector. This table
has four entries and each describes one partition of the disk:
where it starts, where it ends, what type it is, etc.

When the computer is turned on, the BIOS loads the hard disk's
first sector into memory and transfers control to the code
contained in it. This code looks at the partition table and
loads the first sector of the one partition that is marked as
*active* into memory. This sector is known as the *boot sector*.
It contains a small program that loads and launches the operating
system. The quarta boot manager replaces the code in the MBR by
a program that presents a simple user interface that allows the
user to choose which of the (at most) four partitions to start.

## Files

- Read the documentation: [quarta.txt](quarta.txt)
- Download the installer: [quarta.exe](quarta.exe)
- Browse the source code: [quarta.asm](quarta.asm)
  and [quarta.pas](quarta.pas)

## Building

The source code consists of two modules, the boot manager
written in assembler and the installation program, written
mostly in Pascal with some assembler. Both modules are linked
together to build the executable, quarta.exe.
Here is the DOS batch file used to do that:

``` cmd
@echo off
echo This batch file builds the QUARTA boot manager
echo and installation program. The boot manager code
echo will actually be incorporated into the installer.
pause

tasm quarta.asm
tlink quarta.obj
exe2bin quarta.exe quarta.bin
binobj quarta.bin quarta.b2o partcode
bpc quarta.pas
del quarta.obj
del quarta.map
del quarta.bin
del quarta.b2o

echo.
echo Now you should have a newly built QUARTA.EXE; copy it
echo along with QUARTA.TXT to the distribution media.
echo.
echo QUARTA is copyright (c) 1995, 1996, 1997 by UJR
```

Above I used the Borland Pascal tools: **tasm** is the assembler,
**tlink** the linker, **exe2bin** converts an exe file into
a binary file, and **binobj** converts this binary file into
an object code file, which is referred to from the Pascal source
file using the `{$L QUARTA.B2O}` linker directive; finally,
**bpc** compiles the Pascal source code and links it with the
boot manager object code.

## Notes

This README file was extracted from the 2004 [quarta.html](quarta.html) file.

The Master Boot Record (MBR) scheme was introduced by PC DOS
in the early 1980ies. As of 2022 it is being (or mostly has been)
superseded by a new scheme known as GUID Partition Table (GPT),
which is part of UEFI, the successor of good-old BIOS.
