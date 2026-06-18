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
	bl write_string

	bl paint_framebuffer

	mov r0, r4
	ldr r1, =done_message
	bl write_string

pause_loop:
	mov r7, #29
	svc #0
	b pause_loop

write_string:
	ldr r2, [r1]
	add r1, r1, #4
	mov r7, #4
	svc #0
	bx lr

paint_framebuffer:
	push {lr}

	ldr r0, =fb0_path
	mov r1, #1
	mov r2, #0
	mov r7, #5
	svc #0

	cmp r0, #0
	bge framebuffer_opened

	ldr r0, =graphics_fb0_path
	mov r1, #1
	mov r2, #0
	mov r7, #5
	svc #0

	cmp r0, #0
	bge framebuffer_opened

	mov r0, r4
	ldr r1, =fb_fail_message
	bl write_string
	pop {pc}

framebuffer_opened:
	mov r5, r0

	ldr r0, =fb_buffer
	ldr r1, =1024
	ldr r2, =0x07e007e0
fill_fb_buffer:
	str r2, [r0], #4
	subs r1, r1, #1
	bne fill_fb_buffer

	ldr r6, =225
write_fb_buffer:
	mov r0, r5
	ldr r1, =fb_buffer
	ldr r2, =4096
	mov r7, #4
	svc #0

	cmp r0, #0
	ble framebuffer_write_failed

	subs r6, r6, #1
	bne write_fb_buffer

	mov r0, r4
	ldr r1, =fb_ok_message
	bl write_string
	pop {pc}

framebuffer_write_failed:
	mov r0, r4
	ldr r1, =fb_fail_message
	bl write_string
	pop {pc}

	.section .rodata
console_path:
	.asciz "/dev/console"
fb0_path:
	.asciz "/dev/fb0"
graphics_fb0_path:
	.asciz "/dev/graphics/fb0"
	.align 2
boot_message:
	.word boot_message_end - boot_message_text
boot_message_text:
	.ascii "is01 phase1 mininit: booted from custom initramfs\n"
boot_message_end:
	.align 2
fb_ok_message:
	.word fb_ok_message_end - fb_ok_message_text
fb_ok_message_text:
	.ascii "is01 phase1 mininit: framebuffer painted green\n"
fb_ok_message_end:
	.align 2
fb_fail_message:
	.word fb_fail_message_end - fb_fail_message_text
fb_fail_message_text:
	.ascii "is01 phase1 mininit: framebuffer paint failed\n"
fb_fail_message_end:
	.align 2
done_message:
	.word done_message_end - done_message_text
done_message_text:
	.ascii "is01 phase1 mininit: waiting forever\n"
done_message_end:

	.section .bss
	.align 4
fb_buffer:
	.space 4096
