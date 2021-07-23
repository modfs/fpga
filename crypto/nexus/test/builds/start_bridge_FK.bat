@echo off

REM ### Set the voltage of your device
set vccint=0.90
set vccbram=0.85
set vcchbm=1.22
REM ### Set Device type:
REM ### Forest Kitten 33 = fk33
REM ### JCC2L_33 = jcc2l_33
REM ### JCC2L_35 = jcc2l_35
REM ### JCC4p_35 = jcc4p_35
set devicetype=fk33

REM ### Uncomment and set the IPs for your ethernet connected JCC2L Device if needed
REM set jcips=192.168.1.20,192.168.1.21

REM #############################################################################################
REM ###################### Generated code below no need to modify ###############################
set bit_33=NEXUS_FK_550Mhz_WNS-0.198.bit
set bit_35=sq35_eth_rc25_w10f_ndh_2200_hotter.bit
set bridge=sqrl_bridge_2.1.4.exe
REM ### Set bridgeoptions
if [%devicetype%] EQU [fk33] set bridgeoptions=-u -t -a  -g -q -b %bit_33%
if [%devicetype%] EQU [jcc2l_33] set bridgeoptions=-c %jcips% -x -g -q -v %vccint% -w %vcchbm% -y %vccbram% -b %bit_33%
if [%devicetype%] EQU [jcc2l_35] set bridgeoptions=-c %jcips% -x -g -q -v %vccint% -w %vcchbm% -y %vccbram% -b %bit_35%
if [%devicetype%] EQU [jcc4p_35] set bridgeoptions=-a -x -g -q -v %vccint% -w %vcchbm% -y %vccbram% -b %bit_35%
REM ### Run Bridge
%bridge% %bridgeoptions%
REM ### Pause after bridge stops
pause