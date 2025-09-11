;after way too long of a debug session:
;BUG FIX: added proper PIC management, finally that was the reason for the triple fault... 
;future me: dont overwrite the IDT pretty please 0.o
;nother bug fix: the timer interrupt handler cant be found, maybe address calc is fucked? idk imma just move it in main
; Initialize VGA system
; Safe VGA Text Mode Driver for GenOS
; Uses parameter-passing only, no global variables to avoid include corruption

; VGA Constants
VGA_BUFFER      equ 0xB8000
VGA_WIDTH       equ 80
VGA_HEIGHT      equ 25
PIC1_COMMAND    equ 0x20
PIC2_COMMAND    equ 0xA0

; Color constants
COLOR_BLACK     equ 0x0
COLOR_BLUE      equ 0x1
COLOR_GREEN     equ 0x2
COLOR_CYAN      equ 0x3
COLOR_RED       equ 0x4
COLOR_MAGENTA   equ 0x5
COLOR_BROWN     equ 0x6
COLOR_LIGHT_GRAY equ 0x7
COLOR_DARK_GRAY equ 0x8
COLOR_LIGHT_BLUE equ 0x9
COLOR_LIGHT_GREEN equ 0xA
COLOR_LIGHT_CYAN equ 0xB
COLOR_LIGHT_RED equ 0xC
COLOR_PINK      equ 0xD
COLOR_YELLOW    equ 0xE
COLOR_WHITE     equ 0xF

; Initialize VGA system with header
vga_init:
    pushad

    ; Draw header
    mov eax, 8                          ; x position
    mov ebx, 0                          ; y position
    mov ecx, welcome_header
    mov edx, 0x1E                       ; blue bg, yellow fg
    call vga_print_string_at

    ; Draw separator
    mov eax, 0
    mov ebx, 1
    mov ecx, separator_line
    mov edx, 0x1F                       ; blue bg, white fg
    call vga_print_string_at

    popad
    ret

; Initialize PICs
init_pics:
    mov al, 0x11
    out PIC1_COMMAND, al
    out PIC2_COMMAND, al

    ; Remap to interrupts 32-47
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    ; Setup cascade
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al

    ; Set mode
    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; Enable only timer
    mov al, 0xFE
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al

    ret

; Print string at specific position
; EAX = x, EBX = y, ECX = string pointer, EDX = color
vga_print_string_at:
    pushad

    ; Calculate starting position
    mov edi, VGA_BUFFER
    imul ebx, VGA_WIDTH * 2
    add edi, ebx
    shl eax, 1
    add edi, eax

    ; Print string
    mov esi, ecx
.loop:
    lodsb
    test al, al
    jz .done

    cmp al, 10                          ; newline?
    je .newline

    mov ah, dl                          ; color
    stosw
    jmp .loop

.newline:
    ; Move to next line, reset to start
    add edi, VGA_WIDTH * 2
    and edi, 0xFFFFF000                 ; Align to start of line
    add edi, VGA_BUFFER
    jmp .loop

.done:
    popad
    ret

; Print string with color combination
; EAX = x, EBX = y, ECX = string, DL = bg color, DH = fg color
vga_print_colored_string:
    pushad

    ; Combine colors
    shl dl, 4
    or dl, dh
    mov dh, 0

    call vga_print_string_at

    popad
    ret

; Write single character at position
; EAX = x, EBX = y, ECX = character, EDX = color
vga_write_char_at:
    pushad

    ; Calculate position
    mov edi, VGA_BUFFER
    imul ebx, VGA_WIDTH * 2
    add edi, ebx
    shl eax, 1
    add edi, eax

    ; Write character
    mov eax, ecx
    mov ah, dl
    stosw

    popad
    ret

; Clear line with color
; EAX = line number, EBX = color
vga_clear_line:
    pushad

    ; Calculate line start
    mov edi, VGA_BUFFER
    imul eax, VGA_WIDTH * 2
    add edi, eax

    ; Clear line
    mov ecx, VGA_WIDTH
    mov ax, 0x20                        ; space
    mov ah, bl                          ; color
.clear_loop:
    stosw
    loop .clear_loop

    popad
    ret

; Helper functions that mimic old interface for compatibility
; These pass cursor coordinates as parameters to maintain cursor state in main kernel

; Print string using kernel cursor state
; ESI = string, uses cursor from main kernel
vga_print_string:
    pushad

    mov eax, [vga_cursor_x_main]
    mov ebx, [vga_cursor_y_main]
    mov ecx, esi
    mov edx, 0x0F                       ; default white on black
    call vga_print_string_at

    ; Update cursor (simple - just move to next line)
    inc dword [vga_cursor_y_main]
    mov dword [vga_cursor_x_main], 0

    popad
    ret

; Print colored string using kernel cursor
; ESI = string, AL = bg, AH = fg
vga_print_line_color:
    pushad

    mov edx, eax                        ; save colors
    mov eax, [vga_cursor_x_main]
    mov ebx, [vga_cursor_y_main]
    mov ecx, esi

    ; Combine colors
    shl dl, 4
    or dl, dh
    mov dh, 0

    call vga_print_string_at

    ; Update cursor
    inc dword [vga_cursor_y_main]
    mov dword [vga_cursor_x_main], 0

    popad
    ret

; Set cursor position
; EAX = x, EBX = y
vga_set_cursor:
    mov [vga_cursor_x_main], eax
    mov [vga_cursor_y_main], ebx
    ret

; Set color (compatibility - stores in main kernel)
; AL = color
vga_set_color:
    mov [vga_color_main], al
    ret

; String constants
welcome_header  db 'GenOS v1.0 - 32-bit Protected Mode Kernel', 0
separator_line  db '================================================================', 0
