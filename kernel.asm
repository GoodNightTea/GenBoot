[BITS 16]
[ORG 0x1000]

kernel_start:
	mov si, kernel_msg
	call print_string

	mov ah, 0x00
	mov al, 0x03
	int 0x10

	mov si, fancy_msg
	call print_string

.kernel_loop:
	hlt
	jmp .kernel_loop

print_string:
	pusha

.loop:
	lodsb
	cmp al, 0
	je .done
	mov ah, 0x0E
	mov bh, 0x00
	mov bl, 0x0F
	int 0x10
	jmp .loop

.done:
	popa
	ret
kernel_msg  db 'GenBoot Kernel v3.2 loaded successfully!', 13, 10, 0
fancy_msg   db 13, 10
            db '    ____            ____              __ ', 13, 10
            db '   / ___| ___ _ __ | __ )  ___   ___ | |_ ', 13, 10
            db '  | |  _ / _ \ ',' _ \|  _ \ / _ \ / _ \| __|', 13, 10
            db '  | |_| |  __/ | | | |_) | (_) | (_) | |_ ', 13, 10
            db '   \____|\___|_| |_|____/ \___/ \___/ \__|', 13, 10
            db 13, 10
            db 'Welcome to Genesis Custom Kernel!', 13, 10
            db 'GenFS filesystem loaded successfully.', 13, 10, 0

times 512-($-$$) db 0
