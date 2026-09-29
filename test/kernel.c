#include <stdint.h>
#include <stddef.h>
#include "serial.h"

#define MULTIBOOT_MAGIC 0x2BADB002
#define VGA_BLANC 0x0F00

static int	libgcc_ok(void)
{
	volatile uint64_t	a;
	volatile uint64_t	b;

	a = 10000000000ULL;
	b = 3;
	return (a / b == 3333333333ULL && a % b == 1);
}

static void	vga_ecrire(const char *msg)
{
	volatile uint16_t	*vga;
	size_t				i;

	vga = (volatile uint16_t *)0xB8000;
	i = 0;
	while (msg[i])
	{
		vga[i] = (uint16_t)(VGA_BLANC | (uint8_t)msg[i]);
		i++;
	}
}

void	kmain(uint32_t magic, uint32_t info)
{
	(void)info;
	serial_init();
	if (magic != MULTIBOOT_MAGIC)
	{
		serial_puts("mauvais magic multiboot\n");
		return ;
	}
	if (!libgcc_ok())
	{
		serial_puts("division 64 bits fausse\n");
		return ;
	}
	vga_ecrire("OK");
	serial_puts("kmain OK\n");
}
