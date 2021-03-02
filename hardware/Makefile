
VERILOG_SRCS := $(wildcard src/*.v)
VERILOG_SRCS += $(wildcard src/io_circuits/*.v)
VERILOG_SRCS += $(wildcard src/riscv_core/*.v)

Z1TOP_XPR := z1top_proj/z1top_proj.xpr

tb := assembly_testbench

ifeq ($(tb), assembly_testbench)
sw   = assembly_tests
test = assembly_tests
else ifeq ($(tb), echo_testbench)
sw   = echo
test = echo
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

$(Z1TOP_XPR): $(VERILOG_SRCS) $(BIOS_MIF)
		vivado -mode batch -source scripts/build_project.tcl

.PHONY: build-project
build-project: $(Z1TOP_XPR)

.PHONY: sim
sim: $(sw) $(BIOS_MIF)
		vivado -mode batch -source scripts/sim.tcl -tclargs $(tb) $(sw) $(test)

.PHONY: write-bitstream
write-bitstream: $(Z1TOP_XPR)
		vivado -mode batch -source scripts/write_bitstream.tcl

.PHONY: program-fpga
program-fpga:
		vivado -mode batch -source scripts/program_fpga.tcl -tclargs $(bs)

.PHONY: clean
# "make clean" won't remove your project folders
clean:
		rm -rf *.log *.jou *.str vcd_files
