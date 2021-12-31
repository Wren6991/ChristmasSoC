CHIPNAME=fpga_ulx3s
TOP=fpga_ulx3s
DOTF=$(HDL)/fpga/fpga_ulx3s.f
BOOTAPP=bootloader

SYNTH_OPT=-abc9
PNR_OPT=--timing-allow-fail

DEVICE=um5g-85k
PACKAGE=CABGA381

include $(SCRIPTS)/synth_ecp5.mk

# romfiles is a prerequisite for synth
romfiles::
	@echo ">>> Bootcode"
	@echo
	make -C $(SOFTWARE)/apps/$(BOOTAPP) all
	cp $(SOFTWARE)/apps/$(BOOTAPP)/$(BOOTAPP)32.hex bootram_init32.hex

clean::
	make -C $(SOFTWARE)/apps/$(BOOTAPP) clean
	rm -f bootram_init*.hex

prog: bit
	ujprog $(CHIPNAME).bit

flash: bit
	ujprog -j flash $(CHIPNAME).bit
