	.section .text
	.global _start

_start:
	ldr r0, =console_path
	mov r1, #1
	mov r2, #0
	mov r7, #5
	svc #0

	cmp r0, #0
	movlt r0, #1
	mov r4, r0

	mov r0, r4
	ldr r1, =boot_message
	ldr r2, =boot_message_end
	ldr r3, =boot_message
	sub r2, r2, r3
	mov r7, #4
	svc #0

pause_loop:
	mov r7, #29
	svc #0
	b pause_loop

	.section .rodata
console_path:
	.asciz "/dev/console"
boot_message:
	.ascii "is01 phase1 mininit: booted from custom initramfs\n"
boot_message_end:
