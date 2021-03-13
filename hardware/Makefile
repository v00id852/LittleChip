
VERILOG_SRCS := $(wildcard src/*.v)
VERILOG_SRCS += $(wildcard src/io_circuits/*.v)
VERILOG_SRCS += $(wildcard src/riscv_core/*.v)

VERILOG_SIMS := $(wildcard sim/*.v)

Z1TOP_XPR := z1top_proj/z1top_proj.xpr

tb := assembly_testbench

ifeq ($(tb), assembly_testbench)
sw   = assembly_tests
else ifeq ($(tb), echo_testbench)
sw   = echo
else ifeq ($(tb), c_testbench)
sw = c_test
else ifeq ($(tb), strcmp_testbench)
sw = strcmp
else ifeq ($(tb), isa_testbench)
sw = riscv-isa-tests
test = all
endif

BIOS_MIF := ../software/bios151v3/bios151v3.mif
SW_MIF   := ../software/$(sw)/*.mif
SW_SRCS  := $(wildcard ../software/$(sw)/*.h)
SW_SRCS  += $(wildcard ../software/$(sw)/*.c)
SW_SRCS  += $(wildcard ../software/$(sw)/*.s)
SW_SRCS  += $(wildcard ../software/$(sw)/*.ld)

$(BIOS_MIF):
		cd ../software/bios151v3 && make > /dev/null

$(SW_MIF): $(SW_SRCS)
		cd ../software/$(sw) && make > /dev/null

$(sw): $(SW_MIF)

# iverilog simulation
sim_exec = $(tb).out
sim_vcd  = $(tb).vcd

iverilog-compile $(sim_exec): $(VERILOG_SRCS) $(VERILOG_SIMS)
	iverilog $(VERILOG_SRCS) $(VERILOG_SIMS) -I src/ -I src/riscv_core -I sim/ -s $(tb) -o $(sim_exec)

# Full ISA test suit (exclude fence_i)
isa_tests = \
	addi \
	add \
	andi \
	and \
	auipc \
	beq \
	bge \
	bgeu \
	blt \
	bltu \
	bne \
	jal \
	jalr \
	lb \
	lbu \
	lh \
	lhu \
	lui \
	lw \
	ori \
	or \
	sb \
	sh \
	simple \
	slli \
	sll \
	slti \
	sltiu \
	slt \
	sltu \
	srai \
	sra \
	srli \
	srl \
	sub \
	sw \
	xori \
	xor \

iverilog-sim $(sim_vcd): $(sim_exec) $(BIOS_MIF)
	cp $(BIOS_MIF) ./
	if [ "$(sw)" != "" ] ; then \
		cp $(SW_MIF) ./ ; \
	fi
	if [ "$(tb)" = "isa_testbench" -a "$(test)" = "all" ] ; then \
		for inst in $(isa_tests) ; do \
			./$(sim_exec) +MIF_FILE=$$inst.mif | tee -a output.log ; \
		done ; \
		sed -n '/\[[a-zA-Z]*\]/p' output.log ; \
	else \
		./$(sim_exec) +MIF_FILE=$(test).mif ; \
	fi
	rm -f *.mif

wave: $(sim_vcd)
	gtkwave $(sim_vcd)

# Vivado
$(Z1TOP_XPR): $(VERILOG_SRCS) $(BIOS_MIF)
		vivado -mode batch -source scripts/build_project.tcl

.PHONY: build-project
build-project: $(Z1TOP_XPR)

.PHONY: sim
sim: $(sw) $(BIOS_MIF)
		vivado -mode batch -source scripts/sim.tcl -tclargs $(tb) $(sw) $(test) | tee output.log
		sed -n '/\[[a-zA-Z]*\]/p' output.log ; \

.PHONY: write-bitstream
write-bitstream: $(Z1TOP_XPR)
		vivado -mode batch -source scripts/write_bitstream.tcl

.PHONY: program-fpga
program-fpga:
		vivado -mode batch -source scripts/program_fpga.tcl -tclargs $(bs)

.PHONY: clean
# "make clean" won't remove your project folders
clean:
		rm -rf *.log *.jou *.str *.vcd *.out *.mif
