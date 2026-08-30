call d:\devprg\hb64\hb64msys.bat
call c:\devprg\hb64\hb64msys_c.bat
HB_USER_CFLAGS=-DHB_SQLT3_MAP_DECLARED_EMULATED
hbmk2.exe teste.prg \develop\harbour\diversos\objmgw\xhberr_mode.prg sddsqlt3.hbc hbsqlit3.hbc xhb.hbc rddsql.hbc -otesteset -cflag="-DHB_SQLT3_MAP_DECLARED_EMULATED" -m -n -w0 -es2 -ge1
hbmk2.exe struct.prg \develop\harbour\diversos\objmgw\xhberr_mode.prg sddsqlt3.hbc hbsqlit3.hbc xhb.hbc rddsql.hbc -cflag="-DHB_SQLT3_MAP_DECLARED_EMULATED" -m -n -w0 -es2 -ge1
