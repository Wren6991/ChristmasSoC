APPNAME  := hellow
SRCS     := ../../src/init.S ../../src/$(APPNAME).c
INCDIRS  := ../../include
LDSCRIPT := ../../scripts/memmap_sdram.ld
MARCH    := rv32ima

CROSS_PREFIX=riscv32-unknown-elf-
CC=$(CROSS_PREFIX)gcc
OBJCOPY=$(CROSS_PREFIX)objcopy
OBJDUMP=$(CROSS_PREFIX)objdump

CCFLAGS ?= -Os -g

override CCFLAGS+=-march=$(MARCH) $(addprefix -I ,$(INCDIRS))
override CCFLAGS+=-Wall -Wextra
override CCFLAGS+=-T $(LDSCRIPT)

.SUFFIXES:
.SECONDARY:
.PHONY: all clean
all: compile

$(APPNAME).elf: $(SRCS)
	$(CC) $(CCFLAGS) $(SRCS) -o $(APPNAME).elf

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%_flash.bin: %.bin
	../../scripts/mkflashbin $< $@

$(APPNAME).dis: $(APPNAME).elf
	@echo ">>>>>>>>> Memory map:" > $(APPNAME).dis
	$(OBJDUMP) -h $(APPNAME).elf >> $(APPNAME).dis
	@echo >> $(APPNAME).dis
	@echo ">>>>>>>>> Disassembly:" >> $(APPNAME).dis
	$(OBJDUMP) -D $(APPNAME).elf >> $(APPNAME).dis


compile:: $(APPNAME).bin $(APPNAME)_flash.bin $(APPNAME).dis

clean::
	rm -f $(APPNAME).elf $(APPNAME)32.hex $(APPNAME)8.hex $(APPNAME).dis $(APPNAME).bin $(OBJS)
