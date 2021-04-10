# Master Makefile dependencies
TARGET := lenet
INCLUDE_LIB := true
GCC_OPTS += -O2

include ../Makefile.gcc.in

run: lenet.elf
	../../scripts/hex_to_serial lenet.mif 30000000

