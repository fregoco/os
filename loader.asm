org 0x900
jmp LABEL_BEGIN
[SECTION .data]
LoaderStr db "Load loader complete.", 0
LoaderStrLen equ $ - LoaderStr - 1

;mov ax, cs
;mov es, ax
[SECTION .code]
LABEL_BEGIN:
	mov ecx, LoaderStrLen
	;mov di, ((80*11) + 40)*2
	mov ax, LoaderStr
	mov bp, ax
	DisplayStr:
		mov ax, 0x1301
		mov bx, 0x000c
		mov dl, 0;Register dx content contains the position of cursor.
		int 0x10
		;loop DisplayStr
	jmp $
