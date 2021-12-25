APPNAME  := bootloader
SRCS     := ../../src/boot_init.S ../../src/boot_main.c
INCDIRS  := ../../include
LDSCRIPT := ../../scripts/memmap_boot.ld
MARCH    := rv32ima

CROSS_PREFIX=riscv32-unknown-elf-
CC=$(CROSS_PREFIX)gcc
OBJCOPY=$(CROSS_PREFIX)objcopy
OBJDUMP=$(CROSS_PREFIX)objdump

CCFLAGS ?= -Os

# Provider our own (tiny) startup routine, and forbid some dumb things like
# pulling in memcpy for a single clearing loop. No need for stdlibs.
override CCFLAGS+=-nostartfiles -ffreestanding

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
	$(OBJCOPY) -O binary	 $< $@

%8.hex: %.elf
	$(OBJCOPY) -O verilog $< $@

%32.hex: %8.hex
	$(SCRIPTS)/vhexwidth -w 32 $< -o $@

$(APPNAME).dis: $(APPNAME).elf
	@echo ">>>>>>>>> Memory map:" > $(APPNAME).dis
	$(OBJDUMP) -h $(APPNAME).elf >> $(APPNAME).dis
	@echo >> $(APPNAME).dis
	@echo ">>>>>>>>> Disassembly:" >> $(APPNAME).dis
	$(OBJDUMP) -D $(APPNAME).elf >> $(APPNAME).dis


compile:: $(APPNAME)32.hex $(APPNAME).dis

clean::
	rm -f $(APPNAME).elf $(APPNAME)32.hex $(APPNAME)8.hex $(APPNAME).dis $(APPNAME).bin $(OBJS)
