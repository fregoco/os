SelectorVideo_Ti equ 000b
SelectorVideo_SPL equ 00b
SelectorVideo equ 0x0006<<3|SelectorVideo_Ti|SelectorVideo_SPL
SCREEN_ROW equ 25
SCREEN_COLLUMN equ 80

global put_char
bits 32
put_char:
	pushad
	push ebp
	mov ebp, esp
	;Fetch cursor location high bits
	mov dx, 0x3d4
	mov al,0xe
	out dx, al
	mov dx, 0x3d5
	in al, dx
	mov ah, al;Move high bits to ah

	mov dx, 0x3d4
	mov al, 0xf
	out dx, al
	mov dx, 0x3d5
	in al, dx
	
	mov bx, ax;Use bx to store location of curser
	mov edx, [ebp + 36 + 4];Fetch the character from stack.Don't ignore the return address.
	cmp dl, ' '
	jl .control_char
	or dx, 0x0c00
	movzx ebx, bx
	mov [gs:ebx+ebx], dx
	inc bx
	cmp bx, 2000
	jge .change_page	
	jmp .update_register
.control_char:
	cmp dl, 00001010b
	jz .line_feed
	cmp dl, 00001101b
	jz .return
	cmp dl, 00001000b
	jz .backspace
	jmp $
.line_feed:
	add bx, SCREEN_COLLUMN
	cmp bx, 2000
	jl .update_register
	jmp .change_page
.return:
	xor dx, dx
	mov ax, bx
	mov cx, SCREEN_COLLUMN
	div cx
	sub bx, dx
	jmp .update_register
.backspace:
	movzx ebx, bx
	dec ebx
	mov word [gs:ebx+ebx], 0
	
	jmp .update_register
.change_page:
	sub bx, SCREEN_COLLUMN
	mov ecx, (SCREEN_ROW-1)*SCREEN_COLLUMN
	mov esi, SCREEN_COLLUMN
	mov edi, 0
	;Copy the 2-25 lines content to 1-24 lines content.
	.fresh_page:
		mov ax, [gs:esi+esi]
		mov [gs:edi+edi], ax
		add esi, 1
		add edi, 1
		loop .fresh_page
		;Replace the last line with 0.
		mov ecx, SCREEN_COLLUMN
	.handle_last_line:
		mov word [gs:edi+edi], 0
		loop .handle_last_line
.update_register:
	;Write high bits of cursor to register.
	mov dx, 0x3d4
	mov al, 0xe
	out dx, al
	mov dx, 0x3d5
	mov al, bh
	out dx, al

	;Write low bits of cursor to register.
	mov dx, 0x3d4
	mov al, 0xf
	out dx, al
	mov dx, 0x3d5
	mov al, bl
	out dx, al

	pop ebp
	popad
	ret
