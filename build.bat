@echo.
@echo This batch file builds the quarta boot manager
@echo and installation program. The boot manager code
@echo will actually be incorporated into the installer.
@pause
@echo off

tasm quarta.asm
tlink quarta.obj
exe2bin quarta.exe quarta.bin
binobj quarta.bin quarta.b2o partcode
bpc quarta.pas
del quarta.obj
del quarta.map
del quarta.bin
del quarta.b2o

@echo.
@echo Now you should have a newly built QUARTA.EXE; copy it
@echo along with QUARTA.TXT to the distribution media.
@echo.
@echo QUARTA is copyright (c) 1995, 1996, 1997 by UJR
