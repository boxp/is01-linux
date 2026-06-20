/*
 * Bare IS01 bootloader handoff probe.
 *
 * The Android boot image loads this blob at 0x20008000 and jumps to it as if it
 * were an ARM Linux zImage. It deliberately does not parse ATAGs/DTB or enter
 * Linux. It only writes a visible RGB565 pattern into the framebuffer region
 * recorded by the Sharp Deckard downstream board file, then spins forever.
 */

.syntax unified
.arch armv7-a
.arm

.global _start
.type _start, %function

.equ IS01_FB_BASE, 0x02b00000
.equ IS01_FB_SIZE, 0x001c2000

_start:
        mrs     r0, cpsr
        orr     r0, r0, #0xc0
        msr     cpsr_c, r0

        ldr     r1, =IS01_FB_BASE
        ldr     r2, =IS01_FB_SIZE
        add     r3, r1, r2
        ldr     r4, =0xf80007e0
        ldr     r5, =0x001fffff
        ldr     r6, =0x07e0f800
        ldr     r7, =0x00000000
        ldr     r9, =0x00080000
        ldr     r10, =0x00100000

1:
        cmp     r1, r3
        bhs     3f
        and     r8, r1, r5
        cmp     r8, r9
        blo     2f
        cmp     r8, r10
        movlo   r0, r6
        movhs   r0, r7
        b       4f
2:
        mov     r0, r4
4:
        str     r0, [r1], #4
        b       1b

3:
        mov     r0, #0
        mcr     p15, 0, r0, c7, c10, 4
        mcr     p15, 0, r0, c7, c10, 5

5:
        b       5b
