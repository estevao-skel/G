default rel

global main
extern XOpenDisplay, XDefaultScreen, XRootWindow, XBlackPixel, XWhitePixel
extern XCreateSimpleWindow, XSelectInput, XMapWindow, XDefaultGC
extern XNextEvent, XFillRectangle, XDrawString, XSetForeground, XFlush
extern XLookupString, XStoreName, exit

SYS_OPEN    equ 2
SYS_WRITE   equ 1
SYS_CLOSE   equ 3
O_WRONLY    equ 1
O_CREAT     equ 64
O_TRUNC     equ 512

PERMS       equ 420 

section .data
    filename db "arquivo.txt", 0
    window_title db "G", 0
    
    COLOR_BG        equ 0x1E1E1E
    COLOR_FG        equ 0xFFFFFF
    COLOR_GUTTER    equ 0x252526
    COLOR_LINE_NUM  equ 0x5C6370
    COLOR_CURSOR    equ 0x528BFF

section .bss
    display: resq 1
    window: resq 1
    gc: resq 1
    event: resb 192
    
    buffer: resb 65536 
    buffer_end_addr: equ $
    
    gap_start: resq 1
    gap_end: resq 1
    
    scroll_offset: resq 1
    
    num_str: resb 16
    temp_char: resb 1

section .text

main:
    push rbp
    mov rbp, rsp
    
    lea rax, [buffer]
    mov [gap_start], rax
    add rax, 32768
    mov [gap_end], rax
    mov qword [scroll_offset], 0
    
    xor edi, edi
    call XOpenDisplay wrt ..plt
    test rax, rax
    jz .exit_fail
    mov [display], rax
    
    mov rdi, rax
    call XDefaultScreen wrt ..plt
    mov r12, rax
    
    mov rdi, [display]
    mov rsi, r12
    call XRootWindow wrt ..plt
    mov r13, rax
    
    sub rsp, 32
    mov rdi, [display]
    mov rsi, r13
    mov edx, 100
    mov ecx, 100
    mov r8d, 900
    mov r9d, 600
    mov qword [rsp], 0
    mov qword [rsp+8], 0
    mov qword [rsp+16], 0
    call XCreateSimpleWindow wrt ..plt
    add rsp, 32
    mov [window], rax
    
    mov rdi, [display]
    mov rsi, [window]
    lea rdx, [window_title]
    call XStoreName wrt ..plt
    
    mov rdi, [display]
    mov rsi, [window]
    mov edx, 0x8001
    call XSelectInput wrt ..plt
    
    mov rdi, [display]
    mov rsi, [window]
    call XMapWindow wrt ..plt
    
    mov rdi, [display]
    mov rsi, r12
    call XDefaultGC wrt ..plt
    mov [gc], rax

    call draw_editor

.event_loop:
    mov rdi, [display]
    lea rsi, [event]
    call XNextEvent wrt ..plt
    
    mov eax, [event]
    cmp eax, 2
    je .handle_keypress
    cmp eax, 12
    je .handle_expose
    jmp .event_loop

.handle_keypress:
    call on_key_press
    call draw_editor
    jmp .event_loop

.handle_expose:
    call draw_editor
    jmp .event_loop

.exit_fail:
    mov edi, 1
    call exit wrt ..plt

save_file:
    push rbp
    mov rbp, rsp
    
    mov rax, SYS_OPEN
    lea rdi, [filename]
    mov rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, PERMS
    syscall
    
    cmp rax, 0
    jl .save_err
    mov r12, rax
    
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [buffer]
    mov rdx, [gap_start]
    sub rdx, rsi
    syscall
    
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    
.save_err:
    leave
    ret

on_key_press:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    lea rdi, [event]
    lea rsi, [rbp-16]
    mov edx, 10
    xor ecx, ecx
    xor r8d, r8d
    call XLookupString wrt ..plt
    
    test eax, eax
    jz .done_key
    
    movzx eax, byte [rbp-16]
    
    cmp eax, 19
    je .do_save
    
    cmp eax, 8
    je .do_backspace
    cmp eax, 127
    je .do_backspace
    cmp eax, 13
    je .do_enter
    
    cmp eax, 32
    jl .done_key
    cmp eax, 126
    jg .done_key
    
    call gap_insert
    jmp .done_key

.do_save:
    call save_file
    jmp .done_key

.do_backspace:
    call gap_delete
    jmp .done_key

.do_enter:
    mov al, 10
    call gap_insert
    
.done_key:
    leave
    ret

gap_insert:
    mov rcx, [gap_start]
    mov rdx, [gap_end]
    cmp rcx, rdx
    jge .full
    mov [rcx], al
    inc qword [gap_start]
.full:
    ret

gap_delete:
    mov rax, [gap_start]
    lea rcx, [buffer]
    cmp rax, rcx
    jle .empty
    dec qword [gap_start]
.empty:
    ret

draw_editor:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 128
    
    mov rdi, [display]
    mov rsi, [gc]
    mov edx, COLOR_BG
    call XSetForeground wrt ..plt
    
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc]
    xor ecx, ecx
    xor r8d, r8d
    mov r9d, 900
    push 600
    call XFillRectangle wrt ..plt
    pop rax
    
    mov rdi, [display]
    mov rsi, [gc]
    mov edx, COLOR_GUTTER
    call XSetForeground wrt ..plt
    
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc]
    xor ecx, ecx
    xor r8d, r8d
    mov r9d, 40
    push 600
    call XFillRectangle wrt ..plt
    pop rax
    
    xor r12, r12
    xor r13, r13
    mov r14, 20
    mov r15, 50
    
    mov rdi, [display]
    mov rsi, [gc]
    mov edx, COLOR_FG
    call XSetForeground wrt ..plt

.render_loop:
    mov rax, [gap_start]
    lea rcx, [buffer]
    sub rax, rcx
    cmp r13, rax
    jge .render_end
    
    cmp r13, 0
    jne .check_nl
    call draw_line_number
.check_nl:

    lea rbx, [buffer]
    add rbx, r13
    movzx eax, byte [rbx]
    
    cmp al, 10
    je .handle_newline
    
    mov [temp_char], al
    
    push rax
    push rbx
    push rcx
    push rdx
    
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc]
    mov ecx, r15d
    mov r8d, r14d
    lea r9, [temp_char]
    push 1
    call XDrawString wrt ..plt
    add rsp, 8
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    
    add r15, 10
    inc r13
    jmp .render_loop

.handle_newline:
    inc r13
    add r14, 20
    inc r12
    mov r15, 50
    
    call draw_line_number
    jmp .render_loop

.render_end:
    mov rdi, [display]
    mov rsi, [gc]
    mov edx, COLOR_CURSOR
    call XSetForeground wrt ..plt
    
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc]
    mov ecx, r15d
    mov r8d, r14d
    sub r8d, 10
    mov r9d, 2
    push 16
    call XFillRectangle wrt ..plt
    pop rax

    mov rdi, [display]
    call XFlush wrt ..plt
    
    add rsp, 128
    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret
 

; Albion Online é um MMORPG sandbox em que você escreve sua própria história, em vez de seguir um caminho pré-determinado. Explore um vasto mundo aberto que consiste de 5 ecossistemas únicos. Tudo o que você faz gera um impacto no mundo, já que em Albion, a economia é conduzida pelo jogador. Cada peça de equipamento é construída por jogadores a partir dos recursos obtidos por eles. O equipamento que você usa define quem você é. Ir de cavaleiro para feiticeiro é tão fácil quanto trocar a armadura e a arma, ou uma combinação das duas. Aventure-se no mundo aberto e enfrente os habitantes e as criaturas de Albion. Saia em expedições ou entre em masmorras para enfrentar inimigos ainda mais desafiadores. Enfrente outros jogadores em confrontos do mundo aberto, lute pelo controle de territórios ou cidades inteiras em batalhas táticas em grupo. Relaxe descansando em sua ilha pessoal, onde você pode construir uma casa, cultivar alimentos e criar animais. Junte-se à uma guilda, tudo fica mais divertido quando se trabalha em equipe. Entre hoje mesmo no mundo de Albion, e escreva sua própria história.
; 5

draw_line_number:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r12
    push r14

    mov rdi, [display]
    mov rsi, [gc]
    mov edx, COLOR_LINE_NUM
    call XSetForeground wrt ..plt
    
    mov rax, r12
    inc rax
    lea rdi, [num_str]
    call int_to_str
    
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc]
    mov ecx, 5
    mov r8d, r14d
    lea r9, [num_str]
    
    mov rax, 0
    lea rbx, [num_str]
.ln_len:
    cmp byte [rbx], 0
    je .ln_done
    inc rax
    inc rbx
    jmp .ln_len
.ln_done:
    push rax
    call XDrawString wrt ..plt
    add rsp, 8
    
    mov rdi, [display]
    mov rsi, [gc]
    mov edx, COLOR_FG
    call XSetForeground wrt ..plt

    pop r14
    pop r12
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

int_to_str:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    mov rbx, 10
    add rdi, 15
    mov byte [rdi], 0
    dec rdi
    
    test rax, rax
    jnz .convert
    mov byte [rdi], '0'
    jmp .finish_conv
.convert:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    test rax, rax
    jnz .convert
.finish_conv:
    inc rdi
    lea rsi, [num_str]
    cmp rdi, rsi
    je .done_move
.move_loop:
    mov al, [rdi]
    mov [rsi], al
    test al, al
    jz .done_move
    inc rdi
    inc rsi
    jmp .move_loop
; haha bora bil bora fi do bill hahahaha amostradinho la ele
.done_move:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret