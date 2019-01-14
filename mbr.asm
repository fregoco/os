SectorCount equ 01h
LBA equ 02h
LoaderAddr equ 0900h;Address for loading kernel.

org 07c00h
;Initialization segment register.
mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax

;Set sector count read.
mov al, SectorCount
mov dx, 01f2h;Port number which exceeds a byte will be truncted.
out dx, al

;Set LBA
;Low 8 bits of lba
mov al, LBA & 0xff
mov dx, 01f3h
out dx, al
;Middle 8 bits of lba
mov al, (LBA >> 8 ) & 0xff
mov dx,01f4h
out dx, al
;High 8 bits of lba
mov al, (LBA >> 16) & 0xff
mov dx, 01f5h
out dx, al
;Set device register for lba highest 4 bits, lba mod  bit and master disk bit.
mov al, (LBA >> 24) & 0x0f
or al, 11100000b
mov dx, 01f6h
out dx, al

CheckBusy:
	mov dx, 01f7h
	in al, dx
	mov bl, al
	and al, 10000000b
	cmp al, 10000000b
	jz CheckBusy

CheckError:
	mov al, bl
	and bl, 01b
	cmp bl, 01b
	jnz CheckCommandReady
	mov dx, 0x1f1
	in al, dx
	jmp $


CheckCommandReady:
	;mov dx, 01f7h
	;in al, dx;Obtain status
	and al, 01000000b;Only check the 6th bit which implies whether command is ready for 1, or not for 0.
	cmp al, 01000000b;
	jnz CheckBusy

;Write command.
mov al, 0x20;Read disk command.
mov dx, 01f7h
out dx, al

;Check status for whether data is ready.
;Firstly check whether IO  is busy.
CheckBusy1:
	mov dx, 01f7h
	in al, dx
	mov bl, al
	and al, 10000000b
	cmp al, 10000000b
	jz CheckBusy1

CheckError1:
	mov al, bl
	and bl, 01b
	cmp bl, 01b
	jnz CheckDataReady
	mov dx, 0x1f1
	in al, dx
	jmp $

CheckDataReady:		
	mov dx, 01f7h;Data ready port
	in al, dx
	and al, 00001000b;3th bit is for data ready.
	cmp al, 01000b
	jnz CheckDataReady

	;Read out data from 01f0h port.
	mov ax, SectorCount
	mov dx, 256;Reading times per sector, since data port is 16 bits.
	mul dx
	mov ecx, eax
	;movzx ecx, cx
	mov bx, LoaderAddr
	mov dx, 01f0h	
ReadData:
	in ax, dx
	mov word [bx], ax
	add bx, 2
	loop ReadData

jmp LoaderAddr

times 510 - ($-$$) db 0
db 0x55, 0xaa







