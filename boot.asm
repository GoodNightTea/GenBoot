[BITS 16]
[ORG 0x7C00]

start:
    ; Setup
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Self-check FIRST (before we rely on any data)
    call self_check
    jc corruption_detected

    ; Store boot drive (passed by BIOS in DL)
    mov [boot_drive], dl

    ; Load sector 2 directly
    mov si, loading_msg
    call print_string
    
    mov ax, 2               ; Sector 2
    mov bx, 0x1000          ; Load address  
    call read_sector
    jc disk_error
    
    ; Success!
    mov si, success_msg
    call print_string
    jmp 0x1000

corruption_detected:
    mov si, corruption_msg
    call print_string
    jmp halt

disk_error:
    mov si, error_msg
    call print_string
    jmp halt

halt:
    hlt
    jmp halt

; Self-check function
; Returns: Carry flag set if corrupted
self_check:
    pusha
    
    ; DEBUG: Show what we're checking
    mov si, debug_checksum_msg
    call print_string
    
    ; Calculate checksum of bootloader (excluding our checksum bytes)
    mov si, 0x7C00          ; Start of bootloader
    mov cx, 508             ; Check first 508 bytes (not checksum or signature)
    xor ax, ax              ; Checksum accumulator (USE FULL AX, not just AL!)
    
.checksum_loop:
    xor bx, bx              ; Clear BX to use as temporary
    mov bl, [si]            ; Load byte into BL (BX = 0x00XX)
    add ax, bx              ; Add full word to AX (like Python's sum())
    inc si
    loop .checksum_loop
    
    ; DEBUG: Show calculated checksum
    push ax
    mov si, calc_msg
    call print_string
    pop ax
    push ax
    call print_hex_word
    call print_newline
    
    ; DEBUG: Show stored checksum
    mov si, stored_msg
    call print_string
    mov ax, [0x7C00 + 508]  ; This reads little-endian correctly
    call print_hex_word
    call print_newline
    
    ; Compare with stored checksum at offset 508
    pop ax
    cmp ax, [0x7C00 + 508]  ; Compare with stored checksum
    je .checksum_valid
    
    ; Checksum invalid
    popa
    stc                     ; Set carry flag = error
    ret
    
.checksum_valid:
    mov si, checksum_ok_msg
    call print_string
    popa
    clc                     ; Clear carry flag = success
    ret

print_hex_word:
    push ax
    mov al, ah
    call print_hex_byte
    pop ax
    call print_hex_byte
    ret

print_hex_byte:
    push ax
    shr al, 4
    call print_hex_nibble
    pop ax
    and al, 0x0F
    call print_hex_nibble
    ret

print_hex_nibble:
    cmp al, 10
    jb .digit
    add al, 'A' - 10
    jmp .print
.digit:
    add al, '0'
.print:
    mov ah, 0x0E
    int 0x10
    ret

print_newline:
    mov al, 13
    mov ah, 0x0E
    int 0x10
    mov al, 10
    int 0x10
    ret

; Read sector using CHS
read_sector:
    pusha
    
    ; Convert LBA to CHS
    push bx                 ; Save buffer
    
    xor dx, dx
    mov bx, 18              ; Sectors per track
    div bx                  ; AX = track, DX = sector
    inc dx                  ; Sectors are 1-based (1-18)
    mov cl, dl              ; CL = sector
    
    xor dx, dx  
    mov bx, 2               ; Heads per cylinder
    div bx                  ; AX = cylinder, DX = head
    mov ch, al              ; CH = cylinder
    mov dh, dl              ; DH = head
    
    pop bx                  ; Restore buffer
    
    ; Use the drive we booted from
    mov dl, [boot_drive]
    mov ah, 0x02            ; Read function
    mov al, 1               ; 1 sector
    int 0x13
    
    popa
    ret

print_string:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    popa
    ret

; Data
debug_checksum_msg db 'Self-check running...', 13, 10, 0
calc_msg        db 'Calculated: 0x', 0
stored_msg      db 'Stored: 0x', 0
checksum_ok_msg db 'Checksum OK!', 13, 10, 0
corruption_msg  db 'SECURITY: Bootloader tampered! Halting.', 13, 10, 0
loading_msg     db 'Integrity check passed. Loading kernel...', 13, 10, 0
success_msg     db 'Kernel loaded successfully!', 13, 10, 0
error_msg       db 'Disk read failed!', 13, 10, 0
boot_drive      db 0

; Pad to byte 508, then reserve space for checksum
times 508-($-$$) db 0

; Checksum storage (will be filled by external tool)
stored_checksum dw 0x0000

; Boot signature
dw 0xAA55
