#include <stdint.h>

static int	libgcc_ok(void)
{
	volatile unsigned __int128	a;
	volatile unsigned __int128	b;
	unsigned __int128			attendu;

	a = (unsigned __int128)1 << 100;
	b = 3;
	attendu = ((unsigned __int128)1 << 100) / 3;
	return (a / b == attendu && a % b == 1);
}

void	kmain(void)
{
	volatile int	resultat;

	resultat = libgcc_ok();
	(void)resultat;
	while (1)
		__asm__ volatile ("hlt");
}
