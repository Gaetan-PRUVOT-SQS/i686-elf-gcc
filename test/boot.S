#define MB_MAGIC 0x1BADB002
#define MB_FLAGS 0x3

.section .multiboot, "a"
.align 4
.long MB_MAGIC
.long MB_FLAGS
.long -(MB_MAGIC + MB_FLAGS)

.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

.section .text
.global _start
.type _start, @function
_start:
	mov $stack_top, %esp
	push %ebx
	push %eax
	call kmain
	cli
1:	hlt
	jmp 1b

.section .note.GNU-stack, "", @progbits
