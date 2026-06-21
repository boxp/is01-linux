/*
 * zImage-shaped IS01 proc_comm reset probe.
 *
 * This keeps the ARM zImage magic header shape while using the same
 * display-independent proc_comm reset signal as proc-comm-reset.S.
 */

.syntax unified
.arch armv7-a
.arm

.global _start
.type _start, %function

.equ MSM_SHARED_RAM_PHYS, 0x00100000
.equ MSM_CSR_PHYS,        0xAC100000

.equ APP_COMMAND,         0x00
.equ APP_DATA1,           0x08
.equ APP_DATA2,           0x0C
.equ MDM_STATUS,          0x14

.equ PCOM_READY,          0x00000001
.equ PCOM_RESET_CHIP_IMM, 0x0000002A
.equ A2M_INT_6,           0x00000418

_start:
        .rept   8
        mov     r0, r0
        .endr

        b       signal_start
        .word   0x016f2818
        .word   _start
        .word   _edata

signal_start:
        mrs     r0, cpsr
        orr     r0, r0, #0xc0
        msr     cpsr_c, r0

        ldr     r1, =MSM_SHARED_RAM_PHYS
        ldr     r2, =PCOM_READY
        ldr     r8, =0x01000000

wait_ready:
        ldr     r3, [r1, #MDM_STATUS]
        cmp     r3, r2
        beq     send_reset
        subs    r8, r8, #1
        bne     wait_ready

send_reset:
        mov     r0, #0
        str     r0, [r1, #APP_DATA1]
        str     r0, [r1, #APP_DATA2]
        ldr     r0, =PCOM_RESET_CHIP_IMM
        str     r0, [r1, #APP_COMMAND]

        mov     r0, #0
        mcr     p15, 0, r0, c7, c10, 4
        mcr     p15, 0, r0, c7, c10, 5

        ldr     r4, =MSM_CSR_PHYS
        mov     r5, #1
        str     r5, [r4, #A2M_INT_6]

        mov     r0, #0
        mcr     p15, 0, r0, c7, c10, 4
        mcr     p15, 0, r0, c7, c10, 5

1:
        b       1b

        .ltorg
_edata:
