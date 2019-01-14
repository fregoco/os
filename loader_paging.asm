%include "pm.inc"

org 0900h

jmp REAL_CODE

[SECTION .gdt]
LABEL_GDT: Descriptor 0, 0, 0
LABEL_CODE32: Descriptor 0, CODE32_LEN - 1, DA_CR|DA_32
LABEIL_DESC_PAGE: Descriptor 0, 0fffffh, DA_DRW|DA_LIMIT_4K;A deccriptor holds all the memory.
;LABEIL_DESC_PAGE1: Descriptor 0, 0ffffffh - 1, DA_DRW
LABEL_DESC_DATA: Descriptor 0, DATA_LEN - 1, DA_DR
LABEL_VEDIO: Descriptor 0B8000h, 0ffffh, DA_DRW

GDT_LEN equ $ - LABEL_GDT

;Selctor
SelectorCode32 equ LABEL_CODE32 - LABEL_GDT
SelectorData equ LABEL_DESC_DATA - LABEL_GDT
SelectorPage equ LABEIL_DESC_PAGE - LABEL_GDT
SelectorVedio equ LABEL_VEDIO - LABEL_GDT


[SECTION .data]
LABEL_DATA:
	ProtectStr: db "In protect mod now!", 0
	ProtectStrLen equ $ - ProtectStr - 1
	VirtualModStr: db "Paging complete.", 0
	VirtualModStrOffset equ VirtualModStr - LABEL_DATA
	VirtualModStrLen equ $ - VirtualModStr
	GDTPtr: dw GDT_LEN - 1
	dd 0
DATA_LEN equ $ - LABEL_DATA

[SECTION .code16]
[BITS 16]
REAL_CODE:
	;xchg bx, bx
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0100h

	;32 bits code
	xor eax, eax
	mov ax, cs
	shl eax, 4
	add eax, CODE32
	mov	word [LABEL_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_CODE32 + 4], al
	mov	byte [LABEL_CODE32 + 7], ah

	;Data descriptor
	xor eax, eax
	mov ax, ds
	shl eax, 4
	add eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

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

	;Change the base address of vedio descriptor to virtual space of kernel.
	mov ax, SelectorPage
	mov ds, ax
	mov eax ,0x900;Base address of loader.
	add eax, LABEL_VEDIO;Address of vedio descriptor.
	;Only chang the four highest bits of base address of vedio descriptor.
	mov ebx, [eax+16]
	or ebx, 0xc000
	mov [eax+16], ebx

	;Move top of stack to virtual space.
	add esp, 0xc0000000

	;Move GDTPtr to virtual space.
	mov eax, [GDTPtr+2]
	add eax, 0xc0000000
	mov [GDTPtr+2], eax

	lgdt [GDTPtr]



	;or qword [eax], 0xc0000000

	;Test
	mov ax, SelectorVedio
	mov gs, ax
	mov ah, 0ch
	mov al, 'V'
	mov edx, ((80*13) + 40)*2
	mov [gs:edx], ax




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

	ret

	CODE32_LEN equ $ - CODE32



