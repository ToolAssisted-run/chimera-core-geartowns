; towns-ipl.asm - a free FM Towns boot program for the core's media tests.
;
; Copyright 2026 Sergio Martin and the chimera-core-geartowns contributors.
; MIT licence, as the rest of this repository's own code (LICENSE).
;
; An FM Towns system ROM boots a disk by reading its first sector to
; B000:0000 and, when it starts with "IPL4", calling B000:0004 with the
; kind of drive in BL (2 a floppy, 8 the CD) and the unit in BH. This is
; such a sector: make-media.py writes it to the start of a floppy image and
; of a CD image. The test scripts boot it with the Free FM Towns Project's
; compatible system ROM, built from its source, so the floppy and CD paths
; of the emulator (drive, controller, DMA and the ROM's disk BIOS) run with
; nothing that is Fujitsu's.
;
; It notes where it booted from at 0000:0600 ('BOOT', the drive kind, the
; unit and the disk's number, which make-media.py writes at DISK_ID), then
; every frame waits for the vertical retrace, counts it, reads game port A
; and moves a square with the pad's directions.
;
; Assemble: nasm -f bin -o towns-ipl.bin towns-ipl.asm (1024 bytes)

	bits 16
	cpu 386
	org 0

V_MAGIC		equ 0600h	; dword 'BOOT'
V_KIND		equ 0604h	; byte: BL at entry
V_UNIT		equ 0605h	; byte: BH at entry
V_DISK		equ 0606h	; byte: the disk's number
V_FRAME		equ 0608h	; dword: frames
V_PAD		equ 060Ch	; byte: game port A
V_X		equ 060Eh	; word: the square's column in bytes
V_Y		equ 0610h	; word: its line

	db 'IPL4'
entry:					; B000:0004
	cli
	cld
	xor ax, ax
	mov ds, ax
	mov ss, ax
	mov sp, 7000h
	mov dword [V_MAGIC], 'BOOT'
	mov [V_KIND], bl
	mov [V_UNIT], bh
	mov al, [cs:disk_id]
	mov [V_DISK], al
	mov dword [V_FRAME], 0
	mov word [V_X], 38
	mov word [V_Y], 192

	mov dx, 0404h			; the FM-R screen at C0000h
	xor al, al
	out dx, al
	mov dx, 0FF81h			; write every plane
	mov al, 0Fh
	out dx, al
	mov ax, 0C000h
	mov es, ax
	xor di, di
	xor ax, ax
	mov cx, 80 * 400 / 2
	rep stosw

frame:
	mov dx, 0FDA0h			; wait for the next vertical retrace
	mov ecx, 400000h
.in:	in al, dx
	test al, 1
	jz .wait
	dec ecx
	jnz .in
.wait:	in al, dx
	test al, 1
	jnz .counted
	dec ecx
	jnz .wait
.counted:
	inc dword [V_FRAME]

	call square_address		; erase the square
	mov dx, 0FF81h
	mov al, 0Fh
	out dx, al
	xor ax, ax
	call fill

	mov dx, 04D0h			; game port A, active low
	in al, dx
	mov [V_PAD], al
	not al
	test al, 01h
	jz .no_up
	cmp word [V_Y], 4
	jb .no_up
	sub word [V_Y], 4
.no_up:	test al, 02h
	jz .no_down
	cmp word [V_Y], 380
	ja .no_down
	add word [V_Y], 4
.no_down:
	test al, 04h
	jz .no_left
	cmp word [V_X], 0
	je .no_left
	dec word [V_X]
.no_left:
	test al, 08h
	jz .no_right
	cmp word [V_X], 78
	jae .no_right
	inc word [V_X]
.no_right:

	call square_address		; draw it, coloured by the disk and the drive
	mov al, [V_DISK]
	add al, [V_KIND]
	or al, 08h
	and al, 0Fh
	mov dx, 0FF81h
	out dx, al
	mov ax, 0FFFFh
	call fill

	mov al, [V_FRAME]		; and the frame count along the top
	mov dx, 0FF81h
	push ax
	mov al, 0Fh
	out dx, al
	pop ax
	xor di, di
	mov cx, 8
.top:	mov [es:di], al
	add di, 80
	loop .top
	jmp frame

square_address:
	mov ax, 0C000h
	mov es, ax
	mov ax, [V_Y]
	mov dx, 80
	mul dx
	add ax, [V_X]
	mov di, ax
	ret

fill:					; 16 lines of AX at ES:DI
	mov cx, 16
.line:	mov [es:di], ax
	add di, 80
	loop .line
	ret

	times 1020 - ($ - $$) db 0
disk_id:
	db 1				; make-media.py writes the disk's number here
	db 0, 0, 0
