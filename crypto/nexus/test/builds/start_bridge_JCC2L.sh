#!/bin/bash

### Set the voltage of your device
vccint=0.85
vccbram=0.85
vcchbm=1.18
### Set Device type:
### Forest Kitten 33 = fk33
### JCC2L-33 = jcc2l_33
### JCC2L-35 = jcc2l_35
### JCC4p_35 = jcc4p_35
devicetype=jcc2l_35

### Uncomment and set the IPs for your ethernet connected JCC2L Device if needed
jcips=192.168.128.2
#,192.168.128.3,192.168.128.4,192.168.128.5

### If running on a Raspberry Pi 32bit please uncomment
# rpi=arm
### If running on a Raspberry Pi 64bit please uncomment
# rpi=arm_64


#############################################################################################
###################### Generated code below no need to modify ###############################
if lsmod | grep "ftdi_sio" &> /dev/null ; then rmmod ftdi_sio; fi
bit_33=NEXUS_FK_550Mhz_WNS-0.198.bit
bit_35=NEXUS_JCC2L_JC35_400Mhz_WNS-0.239.bit
bridge=sqrl_bridge_2.1.4
if [ "$rpi" == "arm" ]; then bridge=sqrl_bridge_2.1.4_pi32; fi
if [ "$rpi" == "arm_64" ]; then bridge=sqrl_bridge_2.1.4_rp64; fi
if [ "$devicetype" == "fk33" ]; then bridgeoptions=$(echo "-u -a -x -g -q -v $vccint -w $vcchbm -y $vccbram -b $bit_33"); fi
if [ "$devicetype" == "jcc2l_33" ]; then bridgeoptions=$(echo "-c $jcips -x -g -q -v $vccint -w $vcchbm -y $vccbram -b $bit_33"); fi
if [ "$devicetype" == "jcc2l_35" ]; then bridgeoptions=$(echo "-c $jcips -g -q -v $vccint -w $vcchbm -y $vccbram -b $bit_35"); fi
if [ "$devicetype" == "jcc4p_35" ]; then bridgeoptions=$(echo "-a -x -g -q -v $vccint -w $vcchbm -y $vccbram -b $bit_35"); fi

### Run Bridge
./$bridge $bridgeoptions
### Pause after bridge stops
read -n 1 -s -r -p "Press any key to continue . . ."