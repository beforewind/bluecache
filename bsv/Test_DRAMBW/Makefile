SRC_BSV=/home/shuotao/bluecache_old/bsv
CONNECTALDIR?=~/tools/connectal/
S2H_INTERFACES = BluecacheRequest:Bluecache.request
H2S_INTERFACES = Bluecache:BluecacheIndication:host
# MEM_READ_INTERFACES = lBluecache.dmaReadClient
# MEM_WRITE_INTERFACES = lBluecache.dmaWriteClient

BSVFILES = Bluecache.bsv #Top.bsv
CPPFILES=testbluecache.cpp testbluecache.h

MIGDIR = /home/shuotao/bluecache_old/xilinx/ddr3_v2_0


BSVDIR= $(SRC_BSV):$(SRC_BSV)/../lib/:$(SRC_BSV)/hardware_controller/dram_test/any_64:$(MIGDIR)

#$(SRC_BSV)/hardware_controller/dram_sim:$(SRC_BSV)/hardware_controller/dram/any_64:$(MIGDIR)

#DATA_BUS_WIDTH=128
#NUMBER_OF_MASTERS=1

PIN_TYPE=Top_Pins
PIN_TYPE_INCLUDE=TopPins
AUTOTOP = --interface pins:Bluecache.pins

CONNECTALFLAGS += -D IMPORT_HOSTIF -D XILINX_SYS_CLK

CONNECTALFLAGS += --bsvpath=$(BSVDIR) --cflags " -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux" -D DataBusWidth=128 -D Debug --clib rt --bscflags "-u -suppress-warnings G0024: -steps-max-intervals 200000 -D DataBusWidth=128 -D Debug -D NodeCountLog=2 -D RequestRouteType=0 +RTS -K100M -RTS"


ifeq ($(BOARD), bluesim)
CONNECTALFLAGS += --bsvpath=$(BSVDIR) --cflags " -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux -D BSIM" -D DataBusWidth=128 -D Debug --clib rt --bscflags "-u -suppress-warnings G0024: -steps-max-intervals 200000 -D DataBusWidth=128 -D Debug -D NodeCountLog=2 -D RequestRouteType=0 +RTS -K100M -RTS -D BSIM"
else
CONNECTALFLAGS += --bsvpath=$(BSVDIR) --cflags " -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/ -I/usr/lib/jvm/java-1.7.0-openjdk-amd64/include/linux" -D DataBusWidth=128 -D Debug --clib rt --bscflags "-u -suppress-warnings G0024: -steps-max-intervals 200000 -D DataBusWidth=128 -D Debug -D NodeCountLog=2 -D RequestRouteType=0 +RTS -K100M -RTS"
endif

#--constraint ~/bluecache_old/xilinx/constraints/clocks.xdc \
#--constraint $(MIGDIR)/ddr3_v2_0.xdc \
#--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc \
#-C ../../xilinx/aurora_64b66b/aurora_64b66b_exdes_119.xdc

ifeq ($(BOARD), vc707)

CONNECTALFLAGS += 	--implconstraint ~/bluecache_old/xilinx/constraints/clocks.xdc \
			--verilog $(MIGDIR)/ddr3_wrapper.v \
			--xci $(CONNECTALDIR)/out/$(BOARD)/ddr3_v2_0/ddr3_v2_0.xci \
			--implconstraint $(MIGDIR)/ddr3_v2_0.xdc

DDR3_V = $(CONNECTALDIR)/out/$(BOARD)/ddr3_v2_0/ddr3_v2_0_stub.v

prebuild:: $(DDR3_V)

$(DDR3_V): $(MIGDIR)/synth-ip.tcl
	(cd $(BOARD); vivado -mode batch -source $(MIGDIR)/synth-ip.tcl)

endif



include $(CONNECTALDIR)/Makefile.connectal

