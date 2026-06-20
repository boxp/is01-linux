/*
 * Bare IS01 bootloader handoff control probe.
 *
 * If this payload is reached, it masks interrupts and spins forever without
 * touching RAM beyond its own instruction fetches.
 */

.syntax unified
.arch armv7-a
.arm

.global _start
.type _start, %function

_start:
        mrs     r0, cpsr
        orr     r0, r0, #0xc0
        msr     cpsr_c, r0

1:
        b       1b
