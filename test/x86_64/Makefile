CROSS   ?= x86_64-elf-
CC      = $(CROSS)gcc
NM      = $(CROSS)nm

CFLAGS  = -std=gnu11 -ffreestanding -fno-stack-protector -fno-pic -mno-red-zone \
          -mcmodel=kernel -mgeneral-regs-only -O2 -g -Wall -Wextra -Werror
LDFLAGS = -T linker.ld -ffreestanding -nostdlib -O2 -mno-red-zone -mcmodel=kernel \
          -Wl,-z,max-page-size=0x1000 -Wl,-z,noexecstack -Wl,--trace

all: kernel.elf

kernel.elf: kernel.o linker.ld
	$(CC) $(LDFLAGS) -o $@ kernel.o -lgcc > lien.txt

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

check: kernel.elf
	LC_ALL=C $(CROSS)readelf -h kernel.elf | grep -q 'ELF64' && echo "ELF64 OK"
	$(CC) -print-multi-lib | grep -q '^no-red-zone;' && echo "multilib no-red-zone OK"
	grep -q 'no-red-zone/libgcc.a' lien.txt && echo "libgcc sans red zone liée OK"
	$(NM) kernel.elf | grep -q '__udivti3' && echo "libgcc OK"
	$(NM) kernel.elf | grep -q '^ffffffff80' && echo "higher half OK"

clean:
	rm -f kernel.o kernel.elf lien.txt

.PHONY: all check clean
