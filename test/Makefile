# Noyau Multiboot minimal pour vérifier la toolchain.
# CROSS=/chemin/vers/bin/i686-elf- pour tester un préfixe hors du PATH.
CROSS   ?= i686-elf-
CC      = $(CROSS)gcc
NM      = $(CROSS)nm

CFLAGS  = -std=gnu11 -ffreestanding -fno-stack-protector -fno-pic \
          -mno-sse -mno-mmx -mno-80387 -O2 -g -Wall -Wextra -Werror
LDFLAGS = -T linker.ld -ffreestanding -nostdlib -O2 -Wl,-z,noexecstack
LIBS    = -lgcc

OBJ = boot.o kernel.o

all: kernel.elf

kernel.elf: $(OBJ) linker.ld
	$(CC) $(LDFLAGS) -o $@ $(OBJ) $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

# Contrôles : ELF 32 bits, en-tête Multiboot, libgcc liée, boot QEMU sur COM1.
check: kernel.elf
	$(CROSS)readelf -h kernel.elf | grep -q 'ELF32' && echo "ELF32 OK"
	$(NM) kernel.elf | grep -q '__udivdi3' && echo "libgcc OK"
	@if command -v grub-file >/dev/null; then \
		grub-file --is-x86-multiboot kernel.elf && echo "multiboot OK"; \
	else echo "grub-file absent, contrôle multiboot sauté"; fi
	timeout 10 qemu-system-i386 -kernel kernel.elf -display none -serial stdio -no-reboot \
		| grep -q "kmain OK" && echo "boot OK" || (echo "boot KO"; exit 1)

run: kernel.elf
	qemu-system-i386 -kernel kernel.elf -serial stdio -no-reboot -no-shutdown

debug: kernel.elf
	qemu-system-i386 -kernel kernel.elf -serial stdio -no-reboot -s -S &
	gdb -ex 'symbol-file kernel.elf' -ex 'target remote :1234' -ex 'break kmain' -ex 'continue'

clean:
	rm -f $(OBJ) kernel.elf

.PHONY: all check run debug clean
