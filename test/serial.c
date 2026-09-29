#include <stdint.h>
#include "serial.h"

#define COM1 0x3F8
#define LSR_THR_VIDE 0x20
#define ATTENTE_MAX 100000

static inline void	outb(uint16_t port, uint8_t val)
{
	__asm__ volatile ("outb %0, %1" : : "a" (val), "Nd" (port) : "memory");
}

static inline uint8_t	inb(uint16_t port)
{
	uint8_t	ret;

	__asm__ volatile ("inb %1, %0" : "=a" (ret) : "Nd" (port) : "memory");
	return (ret);
}

void	serial_init(void)
{
	outb(COM1 + 1, 0x00);
	outb(COM1 + 3, 0x80);
	outb(COM1 + 0, 0x03);
	outb(COM1 + 1, 0x00);
	outb(COM1 + 3, 0x03);
	outb(COM1 + 2, 0xC7);
}

static void	serial_putc(char c)
{
	uint32_t	essais;

	essais = 0;
	while ((inb(COM1 + 5) & LSR_THR_VIDE) == 0 && essais < ATTENTE_MAX)
		essais++;
	outb(COM1, (uint8_t)c);
}

void	serial_puts(const char *s)
{
	while (*s)
	{
		serial_putc(*s);
		s++;
	}
}
