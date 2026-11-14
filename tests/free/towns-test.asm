; towns-test.asm - a free FM Towns test program for the core's test scripts.
;
; Copyright 2026 Sergio Martin and the chimera-core-geartowns contributors.
; MIT licence, as the rest of this repository's own code (LICENSE).
;
; It is built as a 256 KB system ROM (FMT_SYS.ROM), so it runs from the
; moment the processor resets and needs no Fujitsu firmware and no disk:
; the test scripts give it to the machine in place of the real system ROM,
; with blank OS, font and dictionary ROMs beside it. It stays in real mode
; and uses only what every FM Towns model has, so the same file runs on
; all fourteen models the emulator knows.
;
; Every frame it waits for the vertical retrace, then:
;   - reads game port A (a pad) and game port B (as a mouse), except on
;     every sixteenth frame, which it leaves unread (a lag frame);
;   - reads every byte the keyboard has sent;
;   - moves a 16x16 square with the pad's directions, coloured by the
;     buttons, on the 640x400 FM-R compatible screen;
;   - draws its frame counter, the keyboard's checksum and the mouse's
;     position as bit patterns along the top of the screen;
;   - plays a note on the FM sound chip while button A is held, its pitch
;     chosen by the other buttons, and a short click every 32 frames;
;   - reads floppy drive 1's status (its motor is turned on at the start):
;     whether a disk is in and spun up, and whether it is write-protected.
;
; Its state lives at 0000:0600 in main RAM, where the test scripts' memory
; comparisons see it.
;
; Assemble: nasm -f bin -o FMT_SYS.ROM towns-test.asm

	bits 16
	cpu 386

ROM_SIZE	equ 40000h	; 256 KB
TOP_SIZE	equ 10000h	; the last 64 KB, where the processor starts

; state in main RAM (DS = 0)
V_FRAME		equ 0600h	; dword: frames seen
V_PAD		equ 0604h	; byte: last read of game port A
V_KEYSUM	equ 0606h	; word: sum of every keyboard byte
V_KEYLAST	equ 0608h	; byte: last keyboard byte
V_X		equ 060Ah	; word: square's column, in bytes (0..78)
V_Y		equ 060Ch	; word: square's line (0..384)
V_MX		equ 0610h	; word: mouse X, summed
V_MY		equ 0612h	; word: mouse Y, summed
V_MBTN		equ 0614h	; byte: last mouse buttons
V_READS		equ 0616h	; dword: frames the controls were read
V_NOTE		equ 061Ah	; byte: nonzero while a note is keyed on
V_MAGIC		equ 061Ch	; dword: 'TOWN' once set up
V_FDD		equ 0620h	; byte: floppy drive status (0208h)
V_FDC		equ 0621h	; byte: floppy controller status (0200h)

	times ROM_SIZE - TOP_SIZE db 0FFh

	; The last 64 KB. The processor starts at its offset 0FFF0h with
	; CS's base at the top of the address space, so every jump in here is
	; near and nothing loads CS: no interrupts, no far calls.
top:
start:
	cli
	cld
	xor ax, ax
	mov ss, ax
	mov sp, 7000h
	mov ds, ax

	; the C0000h-EFFFFh window shows the FM-R compatible VRAM
	mov dx, 0404h
	xor al, al
	out dx, al

	; keyboard reset
	mov dx, 0602h
	mov al, 0A1h
	out dx, al

	call init_crtc
	call init_palette
	call clear_screen
	call init_sound

	; floppy drive 1 selected, its motor on
	mov dx, 020Ch
	mov al, 51h
	out dx, al
	mov dx, 0208h
	mov al, 12h
	out dx, al

	; game port output: both TRIG lines high, COM low
	mov dx, 04D6h
	mov al, 0Fh
	out dx, al

	; state
	xor eax, eax
	mov [V_FRAME], eax
	mov [V_READS], eax
	mov [V_KEYSUM], ax
	mov [V_KEYLAST], al
	mov [V_MX], ax
	mov [V_MY], ax
	mov [V_MBTN], al
	mov [V_NOTE], al
	mov byte [V_PAD], 3Fh
	mov word [V_X], 38
	mov word [V_Y], 192
	mov dword [V_MAGIC], 'TOWN'

main_loop:
	call wait_vsync
	inc dword [V_FRAME]

	; leave every sixteenth frame unread
	mov al, [V_FRAME]
	and al, 0Fh
	cmp al, 0Fh
	je .no_input
	call read_pad
	call read_mouse
	call read_keyboard
	inc dword [V_READS]
.no_input:
	call read_floppy
	call erase_square
	call move_square
	call draw_square
	call draw_status
	call update_sound
	jmp main_loop

;---------------------------------------------------------------------

; Wait for the start of the next vertical retrace (FDA0h bit 0).
; Bounded, so a machine whose display is off still goes round.
wait_vsync:
	mov dx, 0FDA0h
	mov ecx, 400000h
.while_in:
	in al, dx
	test al, 1
	jz .wait_start
	dec ecx
	jnz .while_in
	ret
.wait_start:
	in al, dx
	test al, 1
	jnz .done
	dec ecx
	jnz .wait_start
.done:
	ret

;---------------------------------------------------------------------

init_crtc:
	mov dx, 0FDA0h
	xor al, al
	out dx, al

	mov si, crtc_table
	xor bl, bl
.loop:
	mov dx, 0440h
	mov al, bl
	out dx, al
	cs lodsw
	mov dx, 0442h
	out dx, ax
	inc bl
	cmp bl, 32
	jb .loop

	mov dx, 0448h
	xor al, al
	out dx, al
	mov dx, 044Ah
	mov al, 15h
	out dx, al
	mov dx, 0448h
	mov al, 1
	out dx, al
	mov dx, 044Ah
	mov al, 8
	out dx, al

	mov dx, 0FDA0h
	mov al, 8
	out dx, al

	mov dx, 0FF81h		; write every plane
	mov al, 0Fh
	out dx, al
	mov dx, 0FF82h		; show every plane
	mov al, 67h
	out dx, al
	mov dx, 0FF83h		; read plane 0
	xor al, al
	out dx, al
	ret

; 640x400, the FM-R compatible mode (the register values Fujitsu's
; and the compatible ROMs' boot code program)
crtc_table:
	dw 0040h, 0320h, 0000h, 0000h, 035Fh, 0000h, 0010h, 0000h
	dw 036Fh, 009Ch, 031Ch, 009Ch, 031Ch, 0040h, 0360h, 0040h
	dw 0360h, 0000h, 009Ch, 0000h, 0050h, 0000h, 009Ch, 0000h
	dw 0050h, 004Ah, 0001h, 0000h, 803Fh, 0003h, 0000h, 0150h

init_palette:
	mov si, palette
	xor bl, bl
.loop:
	mov dx, 0FD90h
	mov al, bl
	out dx, al
	cs lodsb
	mov dx, 0FD92h		; blue
	out dx, al
	cs lodsb
	mov dx, 0FD94h		; red
	out dx, al
	cs lodsb
	mov dx, 0FD96h		; green
	out dx, al
	inc bl
	cmp bl, 16
	jb .loop
	ret

palette:			; blue, red, green
	db 00h,00h,00h, 80h,00h,00h, 00h,80h,00h, 80h,80h,00h
	db 00h,00h,80h, 80h,00h,80h, 00h,80h,80h, 80h,80h,80h
	db 40h,40h,40h, 0FFh,00h,00h, 00h,0FFh,00h, 0FFh,0FFh,00h
	db 00h,00h,0FFh, 0FFh,00h,0FFh, 00h,0FFh,0FFh, 0FFh,0FFh,0FFh

clear_screen:
	push es
	mov ax, 0C000h
	mov es, ax
	mov dx, 0FF81h
	mov al, 0Fh
	out dx, al
	xor di, di
	xor ax, ax
	mov cx, 80 * 400 / 2
	rep stosw
	pop es
	ret

;---------------------------------------------------------------------

read_pad:
	mov dx, 04D0h
	in al, dx
	mov [V_PAD], al
	ret

; Game port B as a mouse: four COM edges, a nibble after each
; (X high, X low, Y high, Y low). A pad there reads as buttons, which is
; summed all the same.
read_mouse:
	mov dx, 04D6h
	mov al, 2Fh		; COM B high
	out dx, al
	mov dx, 04D2h
	in al, dx
	mov bh, al		; X high, and the buttons
	mov dx, 04D6h
	mov al, 0Fh		; COM B low
	out dx, al
	mov dx, 04D2h
	in al, dx
	mov bl, al		; X low
	mov dx, 04D6h
	mov al, 2Fh
	out dx, al
	mov dx, 04D2h
	in al, dx
	mov ch, al		; Y high
	mov dx, 04D6h
	mov al, 0Fh
	out dx, al
	mov dx, 04D2h
	in al, dx
	mov cl, al		; Y low

	mov al, bh
	and al, 30h
	mov [V_MBTN], al

	mov al, bh
	shl al, 4
	and bl, 0Fh
	or al, bl
	cbw
	add [V_MX], ax
	mov al, ch
	shl al, 4
	and cl, 0Fh
	or al, cl
	cbw
	add [V_MY], ax
	ret

; every byte the keyboard has queued, at most 16 a frame
read_keyboard:
	mov cx, 16
.loop:
	mov dx, 0602h
	in al, dx
	test al, 1
	jz .done
	mov dx, 0600h
	in al, dx
	mov [V_KEYLAST], al
	xor ah, ah
	add [V_KEYSUM], ax
	rol word [V_KEYSUM], 3
	loop .loop
.done:
	ret

read_floppy:
	mov dx, 0208h
	in al, dx
	mov [V_FDD], al
	mov dx, 0200h
	in al, dx
	and al, 0C0h		; not ready, write-protected
	mov [V_FDC], al
	ret

;---------------------------------------------------------------------

; ES:DI = the square's first byte
square_address:
	mov ax, 0C000h
	mov es, ax
	mov ax, [V_Y]
	mov dx, 80
	mul dx
	add ax, [V_X]
	mov di, ax
	ret

erase_square:
	push es
	call square_address
	mov dx, 0FF81h
	mov al, 0Fh
	out dx, al
	xor ax, ax
	mov cx, 16
.loop:
	mov [es:di], ax
	add di, 80
	loop .loop
	pop es
	ret

; the pad's lines are active low: bit 0 up, 1 down, 2 left, 3 right
; (up and down together is SELECT, left and right together is RUN)
move_square:
	mov bl, [V_PAD]
	not bl
	mov al, bl
	and al, 03h
	cmp al, 03h
	je .horizontal
	test bl, 01h
	jz .not_up
	cmp word [V_Y], 4
	jb .not_up
	sub word [V_Y], 4
.not_up:
	test bl, 02h
	jz .horizontal
	cmp word [V_Y], 380
	ja .horizontal
	add word [V_Y], 4
.horizontal:
	mov al, bl
	and al, 0Ch
	cmp al, 0Ch
	je .done
	test bl, 04h
	jz .not_left
	cmp word [V_X], 0
	je .not_left
	dec word [V_X]
.not_left:
	test bl, 08h
	jz .done
	cmp word [V_X], 78
	jae .done
	inc word [V_X]
.done:
	ret

draw_square:
	push es
	call square_address
	; colour: 8 + A, B and the frame's high bits, never black
	mov al, [V_PAD]
	not al
	shr al, 4
	and al, 03h
	mov ah, [V_FRAME]
	shr ah, 3
	and ah, 04h
	or al, ah
	or al, 08h
	mov dx, 0FF81h
	out dx, al
	mov ax, 0FFFFh
	mov cx, 16
.loop:
	mov [es:di], ax
	add di, 80
	loop .loop
	pop es
	ret

; one byte drawn as 8 lines of bits at column BX, in colour AH
draw_byte:
	push ax
	mov dx, 0FF81h
	mov al, 0Fh
	out dx, al
	mov di, bx
	xor al, al
	mov cx, 8
.clear:
	mov [es:di], al
	add di, 80
	loop .clear
	pop ax
	push ax
	mov dx, 0FF81h
	mov al, ah
	out dx, al
	pop ax
	mov di, bx
	mov cx, 8
.draw:
	mov [es:di], al
	add di, 80
	loop .draw
	ret

draw_status:
	push es
	mov ax, 0C000h
	mov es, ax
	mov si, V_FRAME
	mov bx, 0
	mov ah, 0Fh
.frame:
	mov al, [si]
	push ax
	call draw_byte
	pop ax
	inc si
	inc bx
	cmp bx, 4
	jb .frame

	mov al, [V_KEYSUM]
	mov ah, 0Ah
	mov bx, 8
	call draw_byte
	mov al, [V_KEYSUM + 1]
	mov ah, 0Ah
	mov bx, 9
	call draw_byte
	mov al, [V_KEYLAST]
	mov ah, 0Eh
	mov bx, 10
	call draw_byte

	mov al, [V_MX]
	mov ah, 0Ch
	mov bx, 12
	call draw_byte
	mov al, [V_MY]
	mov ah, 0Ch
	mov bx, 13
	call draw_byte
	mov al, [V_MBTN]
	mov ah, 0Dh
	mov bx, 14
	call draw_byte

	mov al, [V_FDD]
	mov ah, 0Bh
	mov bx, 16
	call draw_byte
	mov al, [V_FDC]
	mov ah, 0Bh
	mov bx, 17
	call draw_byte
	pop es
	ret

;---------------------------------------------------------------------

; YM3438 register AL = data AH (bank 0)
ym_write:
	push dx
	mov dx, 04D8h
	out dx, al
	mov dx, 04DAh
	mov al, ah
	out dx, al
	pop dx
	ret

init_sound:
	mov dx, 04ECh		; final output on
	mov al, 40h
	out dx, al
	mov dx, 04D5h		; FM through
	mov al, 02h
	out dx, al

	mov si, ym_init
.loop:
	cs lodsw
	cmp al, 0FFh
	je .done
	call ym_write
	jmp .loop
.done:
	ret

ym_init:			; register, value; channel 1, algorithm 7
	db 22h, 00h, 27h, 00h, 28h, 00h
	db 30h, 01h, 34h, 01h, 38h, 01h, 3Ch, 01h
	db 40h, 7Fh, 44h, 7Fh, 48h, 7Fh, 4Ch, 00h
	db 50h, 1Fh, 54h, 1Fh, 58h, 1Fh, 5Ch, 1Fh
	db 60h, 00h, 64h, 00h, 68h, 00h, 6Ch, 00h
	db 70h, 00h, 74h, 00h, 78h, 00h, 7Ch, 00h
	db 80h, 0Fh, 84h, 0Fh, 88h, 0Fh, 8Ch, 0Fh
	db 0B0h, 07h, 0B4h, 0C0h
	db 0A4h, 22h, 0A0h, 69h
	db 0FFh, 0FFh

; A held: a note whose block comes from B and the directions; else a
; click on every 32nd frame
update_sound:
	mov bl, [V_PAD]
	not bl
	test bl, 10h
	jnz .note
	mov al, [V_FRAME]
	and al, 1Fh
	jnz .off
	mov ah, 1Ah
	jmp .key_on
.note:
	mov ah, bl
	and ah, 2Fh
	shr ah, 1
	and ah, 17h
	or ah, 08h
.key_on:
	mov al, 0A4h
	call ym_write
	mov al, 0A0h
	mov ah, 69h
	call ym_write
	mov al, 28h
	mov ah, 0F0h
	call ym_write
	mov byte [V_NOTE], 1
	ret
.off:
	cmp byte [V_NOTE], 0
	je .quiet
	mov al, 28h
	xor ah, ah
	call ym_write
	mov byte [V_NOTE], 0
.quiet:
	ret

;---------------------------------------------------------------------

	times TOP_SIZE - 10h - ($ - top) db 0FFh
reset:
	jmp near start		; offset 0FFF0h
	times TOP_SIZE - ($ - top) db 0FFh
