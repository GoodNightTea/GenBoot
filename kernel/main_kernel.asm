;bug fix: added proper working PIC/interrupt fix from vga_driver
;moving timer_interrupt_handler into main as it could fix it not being found, lets pray
;...I once again was corrupting my IDT again by using mov byte instead of mov word
;forgot to init the pics and messed up the idt descriptor
[BITS 32]
[ORG 0x100000]

kernel_entry:
    ; Set up stack
    mov esp, 0x200000
    cli

    ; Initialize VGA display AND PIC systems
    call vga_init
    call init_pics

    ; Set up IDT
    mov eax, 0
    mov ebx, 3
    mov ecx, idt_setup_msg
    mov edx, 0x0F
    call vga_print_string_at
    call setup_idt

    ; Show IDT success
    mov eax, 0
    mov ebx, 4
    mov ecx, idt_success_msg
    mov edx, 0x0A
    call vga_print_string_at

    ; Enable interrupts
    mov eax, 0
    mov ebx, 5
    mov ecx, interrupt_enable_msg
    mov edx, 0x0F
    call vga_print_string_at
    sti

    ; Show system ready
    mov eax, 0
    mov ebx, 6
    mov ecx, system_ready_msg
    mov edx, 0x0A
    call vga_print_string_at

    ; Demo VGA features
    call demo_vga_features

    ; Enter main loop
    mov eax, 0
    mov ebx, 12
    mov ecx, entering_loop_msg
    mov edx, 0x0F
    call vga_print_string_at

main_loop:
    ; Show heartbeat
    call show_heartbeat

    ; Delay
    mov ecx, 800
.delay:
    dec ecx
    jnz .delay

    jmp main_loop

; Demo VGA features using safe functions
demo_vga_features:
    pushad

    ; Print colored text demo
    mov eax, 2
    mov ebx, 8
    mov ecx, color_demo_msg
    mov edx, 0x0F
    call vga_print_string_at

    ; Show different colors using direct positioning
    mov eax, 4
    mov ebx, 9
    mov ecx, red_text
    mov edx, 0x0C                       ; red
    call vga_print_string_at

    mov eax, 4
    mov ebx, 10
    mov ecx, green_text
    mov edx, 0x0A                       ; green
    call vga_print_string_at

    mov eax, 4
    mov ebx, 11
    mov ecx, blue_text
    mov edx, 0x09                       ; blue
    call vga_print_string_at

    popad
    ret

; Heartbeat display
show_heartbeat:
    pushad

    ; Update counter
    inc dword [heartbeat_counter]

    ; Display at bottom right
    mov eax, 65
    mov ebx, 24
    mov ecx, heartbeat_msg
    mov edx, 0x0B                       ; cyan
    call vga_print_string_at

    popad
    ret

; IDT setup
setup_idt:
    pushad

    ; Clear IDT
    mov edi, idt_table
    mov ecx, 512
    xor eax, eax
    rep stosd

    ; Setup timer interrupt (INT 32)
    mov eax, 0x100000
    add eax, (timer_handler - kernel_entry)
    mov edi, idt_table + (32 * 8)
    mov word [edi], ax
    mov word [edi + 2], 0x08
    mov byte [edi + 4], 0
    mov byte [edi + 5], 0x8E
    shr eax, 16
    mov word [edi + 6], ax

    ; Set up divide by zero handler
    mov eax, 0x100000
    add eax, (divide_handler - kernel_entry)
    mov edi, idt_table
    mov word [edi], ax
    mov word [edi + 2], 0x08
    mov byte [edi + 4], 0
    mov byte [edi + 5], 0x8E
    shr eax, 16
    mov word [edi + 6], ax

    ; Load IDT
    lidt [idt_desc]

    popad
    ret

timer_handler:
    pushad
    ; Acknowledge interrupt
    mov al, 0x20
    out 0x20, al
    inc dword [timer_ticks]
    popad
    iret

divide_handler:
    pushad

    ; Display error using safe VGA
    mov eax, 10
    mov ebx, 15
    mov ecx, divide_error_msg
    mov edx, 0x4F                       ; white on red
    call vga_print_string_at

    cli
    hlt
    jmp $

; Include safe VGA driver
%include "vga/vga_driver.asm"

; String constants
idt_setup_msg        db 'Setting up IDT...', 0
idt_success_msg      db 'IDT configured successfully!', 0
interrupt_enable_msg db 'Enabling interrupts...', 0
system_ready_msg     db 'System ready and operational!', 0
entering_loop_msg    db 'Entering main kernel loop...', 0
color_demo_msg       db 'VGA Color demonstration:', 0
red_text            db 'Red text demonstration', 0
green_text          db 'Green text demonstration', 0
blue_text           db 'Blue text demonstration', 0
heartbeat_msg       db 'System Active', 0
divide_error_msg    db 'FATAL ERROR: Division by zero!', 0

; Variables - safe in main kernel
heartbeat_counter   dd 0
timer_ticks         dd 0

; Cursor state for compatibility with old VGA interface
vga_cursor_x_main   dd 0
vga_cursor_y_main   dd 2
vga_color_main      db 0x0F

; IDT structures
idt_desc:
    dw 2047
    dd idt_table

idt_table:
    times 2048 db 0

times 4096-($-$$) db 0
