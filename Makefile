# This Makefile is compatible with both BSD and GNU make

ASM?= avra
SHELL = /bin/bash

.SUFFIXES: .inc .hex

ALL_TARGETS = afro.hex afro2.hex afro_hv.hex afro_nfet.hex arctictiger.hex birdie70a.hex blueesc.hex bs_nfet.hex bs.hex bs40a.hex dlu40a.hex dlux.hex dys_nfet.hex hk200a.hex hm135a.hex hxt200a.hex jrhdrone.hex kda.hex kda_8khz.hex kda_nfet.hex kda_nfet_ni.hex mkblctrl1.hex rb50a.hex rb70a.hex rb70a2.hex rct50a.hex tbs.hex tbs_hv.hex tp.hex tp_8khz.hex tp_i2c.hex tp_nfet.hex tp70a.hex tgy6a.hex tgy_8mhz.hex tgy.hex
AUX_TARGETS = afro_pr0.hex afro_pr1.hex diy0.hex

MOTOR_ID?= 0	# MK-style I2C motor ID, or UART motor number

all: $(ALL_TARGETS)

$(ALL_TARGETS): tgy.asm boot.inc
$(AUX_TARGETS): tgy.asm boot.inc

.inc.hex:
	@test -e $*.asm || ln -s tgy.asm $*.asm
	@echo "$(ASM) -fI -o $@ -D $*_esc -D MOTOR_ID=$(MOTOR_ID) -e $*.eeprom -d $*.obj $*.asm"
	@set -o pipefail; $(ASM) -fI -o $@ -D $*_esc -D MOTOR_ID=$(MOTOR_ID) -e $*.eeprom -d $*.obj $*.asm 2>&1 | sed '/PRAGMA directives currently ignored/d'
	@test -L $*.asm && rm -f $*.asm || true

test: all

clean_solo:
	-rm -f $(ALL_TARGETS) *.cof *.obj *.eep.hex *.eeprom

clean: clean_solo
	-rm -f *.hex.*

binary_zip: $(ALL_TARGETS)
	TARGET="tgy_`date '+%Y-%m-%d'`_`git rev-parse --verify --short HEAD`"; \
	mkdir "$$TARGET" && \
	cp $(ALL_TARGETS) "$$TARGET" && \
	git archive -9 --prefix="$$TARGET/" -o "$$TARGET".zip HEAD && \
	zip -9 "$$TARGET".zip "$$TARGET"/*.hex && ls -l "$$TARGET".zip; \
	rm -f "$$TARGET"/*.hex; \
	rmdir "$$TARGET"

program_tgy_%: %.hex
	avrdude -c stk500v2 -b 9600 -P /dev/ttyUSB0 -u -p m8 -U flash:w:$<:i

program_usbasp_%: %.hex
	avrdude -c usbasp -B.5 -p m8 -U flash:w:$<:i

program_avrisp2_%: %.hex
	avrdude -c avrisp2 -p m8 -U flash:w:$<:i

program_jtag3isp_%: %.hex
	avrdude -c jtag3isp -p m8 -U flash:w:$<:i

program_dragon_%: %.hex
	avrdude -c dragon_isp -p m8 -P usb -U flash:w:$<:i

program_dapa_%: %.hex
	avrdude -c dapa -p m8 -U flash:w:$<:i

program_uisp_%: %.hex
	uisp -dprog=dapa --erase --upload --verify -v if=$<

bootload_usbasp:
	avrdude -c usbasp -u -p m8 -U hfuse:w:`avrdude -c usbasp -u -p m8 -U hfuse:r:-:h | sed -n '/^0x/{s/.$$/a/;p}'`:m

read: read_tgy

read_tgy:
	avrdude -c stk500v2 -b 9600 -P /dev/ttyUSB0 -u -p m8 -U flash:r:flash.hex:i -U eeprom:r:eeprom.hex:i

read_usbasp:
	avrdude -c usbasp -u -p m8 -U flash:r:flash.hex:i -U eeprom:r:eeprom.hex:i

read_avrisp2:
	avrdude -c avrisp2 -p m8 -P usb -v -U flash:r:flash.hex:i -U eeprom:r:eeprom.hex:i

read_jtag3isp:
	avrdude -c jtag3isp -p m8 -P usb -v -U flash:r:flash.hex:i -U eeprom:r:eeprom.hex:i

read_dragon:
	avrdude -c dragon_isp -p m8 -P usb -v -U flash:r:flash.hex:i -U eeprom:r:eeprom.hex:i

read_dapa:
	avrdude -c dapa -p m8 -v -U flash:r:flash.hex:i -U eeprom:r:eeprom.hex:i

read_uisp:
	uisp -dprog=dapa --download -v of=flash.hex

build_8:
	for MOTOR_ID in 0 1 2 3 4 5 6 7; do \
		make clean_solo; \
		export MOTOR_ID; \
		make all || exit -1; \
		for target in $(ALL_TARGETS); do \
			mv "$$target" "$$target".$$MOTOR_ID || exit -1; \
		done; \
	done
