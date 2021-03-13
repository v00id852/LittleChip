
# Some example commands

## Simulation

### IVERILOG

make iverilog-sim tb={testbench_name}

where testbench_name = {
  Riscv151_testbench,
  echo_testbench,
  c_testbench,
  bios_testbench,
  strcmp_testbench,
  assembly_testbench }

isa_testbench needs an extra argument "test" to select which ISA test to simulate

make iverilog-sim tb=isa_testbench test=add
- Run the ISA testbench with test "add" from the RISCV test suite

make iverilog-sim tb=isa_testbench test=add
- Run all the 38 tests from the RISCV test suite 

make wave tb={testbench_name}
- Run the simulation, and open the waveform with GTKWave

make wave tb=isa_testbench test=add
- Run the ISA testbench with test "add", and open the wavefrom with GTKWave

### VIVADO XSIM

make sim tb={testbench_name}
make sim tb=isa_testbench test=add
make sim tb=isa_testbench test=all

## Bitstream Generation

make build-project
make write-bitstream

## Program FPGA

make program-fpga bs=bitstream_files/z1top.bit

