TOP              := tb
DOTF             := tb.f

.PHONY: clean all

all: tb

SYNTH_CMD += read_verilog $(addprefix -I,$(shell listfiles -rf flati $(DOTF))) $(shell listfiles -r $(DOTF));
SYNTH_CMD += hierarchy -top $(TOP);
SYNTH_CMD += write_cxxrtl dut.cpp

dut.cpp: $(shell listfiles $(DOTF))
	yosys -p "$(SYNTH_CMD)" 2>&1 > cxxrtl.log

clean::
	rm -f dut.cpp cxxrtl.log tb

tb: dut.cpp tb.cpp
	clang++ -O3 -std=c++14 $(addprefix -D,$(CDEFINES)) -I $(shell yosys-config --datdir)/include tb.cpp -o tb
