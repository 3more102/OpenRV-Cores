PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
RTL := rtl/rv32_core.sv rtl/rv32_soc.sv
TB := tb/tb_rv32_soc.sv
PROGRAMS := smoke branches memory alu branch_matrix illegal misaligned ecall misaligned_jump invalid_shift

.PHONY: generate test check clean
generate:
	$(PYTHON) scripts/gen_programs.py

build/sim.vvp: $(RTL) $(TB)
	mkdir -p build
	$(IVERILOG) -g2012 -s tb_rv32_soc -o $@ $(RTL) $(TB)

test: generate build/sim.vvp
	@set -e; i=0; for program in $(PROGRAMS); do \
	  i=$$((i+1)); \
	  $(VVP) build/sim.vvp +PROGRAM=tests/$$program.hex +TEST=$$i; \
	done

check: generate
	$(PYTHON) -m compileall -q scripts
	$(PYTHON) scripts/check_hex.py

clean:
	rm -rf build
