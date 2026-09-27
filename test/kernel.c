#include <stdint.h>
#include <stddef.h>

#define COM1 0x3F8

static inline void outb(uint16_t port, uint8_t val)
{
	__asm__ volatile("outb %0, %1" : : "a"(val), "Nd"(port) : "memory");
}

static inline uint8_t inb(uint16_t port)
{
	uint8_t ret;

	__asm__ volatile("inb %1, %0" : "=a"(ret) : "Nd"(port) : "memory");
	return ret;
}

static void serial_init(void)
{
	outb(COM1 + 1, 0x00);	/* pas d'interruptions */
	outb(COM1 + 3, 0x80);	/* DLAB pour régler la vitesse */
	outb(COM1 + 0, 0x03);	/* 38400 bauds */
	outb(COM1 + 1, 0x00);
	outb(COM1 + 3, 0x03);	/* 8 bits, pas de parité, 1 stop */
	outb(COM1 + 2, 0xC7);	/* FIFO */
}

static void serial_puts(const char *s)
{
	while (*s)
	{
		while ((inb(COM1 + 5) & 0x20) == 0)
			;
		outb(COM1, (uint8_t)*s++);
	}
}

/* Division 64 bits : en 32 bits, gcc appelle __udivdi3 de libgcc. */
static int libgcc_ok(void)
{
	volatile uint64_t a = 10000000000ULL;
	volatile uint64_t b = 3;

	return a / b == 3333333333ULL && a % b == 1;
}

void kmain(uint32_t magic, uint32_t info)
{
	volatile uint16_t *vga = (volatile uint16_t *)0xB8000;
	const char *msg = "OK";

	(void)info;
	serial_init();
	if (magic != 0x2BADB002)
	{
		serial_puts("mauvais magic multiboot\n");
		return;
	}
	if (!libgcc_ok())
	{
		serial_puts("division 64 bits fausse\n");
		return;
	}
	for (size_t i = 0; msg[i]; i++)
		vga[i] = (uint16_t)(0x0F00 | (uint8_t)msg[i]);
	serial_puts("kmain OK\n");
}
