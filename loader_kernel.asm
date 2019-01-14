%include "pm.inc"

org 0900h

jmp REAL_CODE

[SECTION .gdt]
LABEL_GDT: Descriptor 0, 0, 0
LABEL_CODE32: Descriptor 0, CODE32_LEN - 1, DA_CR|DA_32
LABEIL_DESC_PAGE: Descriptor 0, 0fffffh, DA_DRW|DA_LIMIT_4K;A descriptor holds all the memory.
;LABEIL_DESC_PAGE1: Descriptor 0, 0ffffffh - 1, DA_DRW
LABEL_DESC_KERNEL: Descriptor 0xc0000000, 0x40000, DA_CR|DA_LIMIT_4K|DA_32;A descriptor of 3~4G.
LABEL_DESC_DATA: Descriptor 0, 0xfffff, DA_DRW
LABEL_DESC_STACK: Descriptor 0, StackTop - 1, DA_DRW
LABEL_VEDIO: Descriptor 0B8000h, 0ffffh, DA_DRW

GDT_LEN equ $ - LABEL_GDT
GDTPtr dw GDT_LEN - 1
dd 0

;Selctor
SelectorCode32 equ LABEL_CODE32 - LABEL_GDT
SelectorPage equ LABEIL_DESC_PAGE - LABEL_GDT
SelectorKernel equ LABEL_DESC_KERNEL - LABEL_GDT
SelectorData equ LABEL_DESC_DATA - LABEL_GDT
SelectorStack equ LABEL_DESC_STACK - LABEL_GDT
SelectorVedio equ LABEL_VEDIO - LABEL_GDT


[SECTION .data]
LABEL_DATA:
	ProtectStr: db "In protect mod now!", 0
	ProtectStrLen equ $ - ProtectStr - 1
	VirtualModStr: db "Paging complete.", 0
	VirtualModStrOffset equ VirtualModStr - LABEL_DATA
	VirtualModStrLen equ $ - VirtualModStr
DATA_LEN equ $ - LABEL_DATA

[SECTION .stack]
LABEL_STACK:
	times 100 dd 0
	StackTop equ $ - LABEL_STACK
TOPOFSTACK:

[SECTION .code16]
[BITS 16]
REAL_CODE:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0100h

	;Set base address for 32 bits code descriptor.
	xor eax, eax
	mov ax, cs
	shl eax, 4
	add eax, CODE32
	mov	word [LABEL_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_CODE32 + 4], al
	mov	byte [LABEL_CODE32 + 7], ah

	;Set base address for Data descriptor
	xor eax, eax
	mov ax, ds
	shl eax, 4
	add eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	;Set base address for stack descriptor.
	xor eax, eax
	mov ax, ds
	shl eax, 4
	add eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah

	;Load GDTR
	xor eax, eax
	mov ax, cs
	shl eax, 4
	add eax, LABEL_GDT
	mov dword [GDTPtr + 2], eax
	lgdt [GDTPtr]

	;Close real mod interrupt
	cli

	;Open A20
	in al, 092h
	or al, 000010h
	out 092h, al

	;Set the protect bit of cr0 to 1
	mov eax, cr0
	or eax, 1
	mov cr0, eax

	;Jump to protect mod code
	jmp dword SelectorCode32:0

[SECTION .code32]
ALIGN 32
[BITS 32]
CODE32:
	mov ax, SelectorVedio
	mov gs, ax
	mov ax, SelectorData
	mov ds, ax
	mov ax, SelectorStack
	mov ss, ax
	mov sp, StackTop

	;Display string:"In protect mod now!".
	mov ecx, ProtectStrLen
	mov ebx, 0;Offset from data section of the string.
	mov edx, ((80*11) + 40)*2
	call DispStr

	call Paging

	;Open memory paging
	mov eax, PageDirectory
	mov cr3, eax
	mov eax, cr0
	or eax, 080000000h
	mov cr0, eax

	;Display string:"Paging complete."
	mov ax ,SelectorData
	mov ds, ax
	mov ecx, VirtualModStrLen
	mov ebx, VirtualModStrOffset
	mov edx, ((80*12) + 40)*2
	call DispStr

	mov cx, 200;Sector number.Remember to modify it when kernel becomes bigger.
	mov ebx, 9;Sector LBA.
	Kernel_Buff_Addr equ 0x7000
	mov eax, Kernel_Buff_Addr
	call Read_Disk



	jmp $
DispStr:
	mov ah, 0ch
	mov al, byte [ebx] 
	mov [gs:edx], ax
	inc ebx
	add edx, 2
	loop DispStr
	ret

Paging:
	;Properties of page directory entry and page table.
	P equ 1B
	NP equ 0B
	RW_W equ 10B
	RW_R equ 00B
	US_U equ 100B
	US_S equ 000B

	;Address of page directory and page table.
	PageDirectory equ 0100000h;01000000h is the physical address of page directory.
							  ;Kernel is localed at the top 1M of virtual memory space.
							  ;Kernel will be mapped to the bottom 1M of physical memory space.

	PageTable equ 0101000h;Page table address should be aligned by 4k.

	;Protect ds
	mov ax, ds 
	push ax

	mov ax, SelectorPage
	mov ds, ax

	;Clear page directory and page table
	mov ecx, 4096
	mov eax, PageDirectory
	clear:
		mov byte [eax], 0
		inc eax
		loop clear

	mov eax, PageDirectory
	;mov dword [eax], 00000000h
	;mov dword [eax + 0xc00], 00000000h
	mov ebx, PageTable
	or ebx, P|RW_W|US_U;Page directory entry with properties of presention, writeable and readable and user privilege.
	mov [eax], ebx
	;mov [eax+0xc00], ebx
	mov [eax+768*4], ebx;Virtual address 3G is the 768th entries of page directory.
	;After set the page direction,mapping from 0~1M of virtuanl space to 0~1M of physical space completes.
	;The first level page table only contains 0,pointed to the 0 address of physical space.But a page table only contains
	;4k space.We need 1M space.So we need to create another 255 page table entries.
	;Maybe should assign some properties for page table.
	;Create page table entry for 0~1M physical space.
	mov ecx, 256;1M contains 256 page table entries.
	mov eax, PageTable
	mov ebx, 0
	xor esi, esi
	pte:
		or ebx, P|RW_W|US_U
		mov dword [eax + esi], ebx
		add ebx, 4096
		add esi, 4
		loop pte

	;Kernel virtual space should be set in advance so that all processes can share it.
	;Create page directory entries for the remain kernel space undering that two entries haven been assigned ,one for 3~3.004G,another for 3.996~4G.
	mov ecx, 254
	mov eax, PageTable
	add eax, 4096;The second page table address.
	mov ebx, PageDirectory
	add ebx, 769*4;The second page directory entry of 3~4G is 769th of the whole entries.
	;xor esi, esi
	kernel_pde:
		mov dword [ebx], eax
		;mov dword [ebx + esi*4], eax
		;inc esi
		add ebx, 4
		add eax, 4096
		loop kernel_pde

	;Map the last entry of virtual space to the address of page directory.
	mov eax, PageDirectory
	mov ebx, PageDirectory
	mov esi, 1023
	mov [eax + esi*4], ebx

	;Restore ds 
	pop ax
	mov ds, ax
	ret

Read_Disk:
	push eax

	;Set sector number.
	mov dx, 0x1f2
	mov al, cl
	out dx, al

	;Set LBA
	;Low 8 bits of lba
	mov dx, 0x1f3
	mov al, bl
	out dx, al

	;Middle 8 bit of lba
	mov dx, 0x1f4
	mov al, bh
	out dx, al

	;High 8 bits of lba
	mov dx, 0x1f5
	shr ebx, 16
	mov al, bl
	out dx, al

	;The last 4bits of lba, and set the 6th bits of this register to open lba mode.
	mov dx, 0x1f6
	shr ebx, 8
	mov al, bl
	or al, 01000000b
	out dx, al

	mov dx, 0x1f7
Check_Busy:
	in al, dx
	mov ah, al
	and ah, 10000000b
	cmp ah, 10000000b
	jz Check_Busy

Check_Error:
	mov ah, al
	and ah, 01b
	cmp ah, 01b
	jnz Check_Command
	jmp $

Check_Command:
	in al, dx
	;mov ah, al
	and al, 01000000b
	cmp al, 01000000b
	jnz Check_Command

	;Set command
	mov al, 0x20
	out dx, al

	;
Check_Busy1:
	in al, dx
	mov ah, al
	and ah, 10000000b
	cmp ah, 10000000b
	jz Check_Busy1

Check_Error1:
	mov ah, al
	and ah, 01b
	cmp ah, 01b
	jnz Check_Data_Ready
	jmp $

Check_Data_Ready:
	in al, dx
	and al, 00001000b
	cmp al, 00001000b
	jnz Check_Data_Ready

	;Read data from 0x1f0
	mov ax, 256
	;movzx cx, cl 
	mul cx
	mov ecx, eax

	pop eax
	mov ebx, eax
	mov dx, 0x01f0
Read_Date:
	in ax, dx
	mov [ebx], ax
	add ebx, 2
	loop Read_Date

	ret

	CODE32_LEN equ $ - CODE32



