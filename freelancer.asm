; build instructions:
;   nasm -f elf64 freelancer.asm -o freelancer.o
;   ld -o freelancer.elf freelancer.o -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2
;
; optional:
;   strip -s -R .comment -R .gnu.version freelancer.elf
;   sstrip-3.0a freelancer.elf

; syscall related constants
syscall:    equ 0x80

sys_exit:   equ 1
sys_read:   equ 3
sys_write:  equ 4

success:    equ 0

stdin:      equ 0
stdout:     equ 1

; border line constants
val_low:    equ 1
val_warn:   equ 90
val_crit:   equ 100

; property indexes
v_pov:    equ 0
v_hun:    equ 1
v_fat:    equ 2
v_bil:    equ 3
v_stp:    equ 4
v_count:  equ 5

; action indexes
a_pay:    equ 0
a_sleep:  equ 1
a_eat:    equ 2
a_work:   equ 3
a_count:  equ 4

%macro p_s  2 ; prints string
              ; input: str, len
    mov     rdi,        %1
    mov     rsi,        %2
    call _p_str  
%endmacro

section .data
    s_term_r:   db `\033[31m`
    s_term_g:   db `\033[32m`
    s_term_c:   db `\033[00m`
    l_term:     equ $-s_term_c

    s_name:     db `poverty`, `hunger `, `fatigue`, `bills  `, `step   `
    l_name:     equ 7

    s_actn:     db `    p[ay]  : `, `    s[leep]: `, \
                   `    e[at]  : `, `    w[ork] : `
    l_actn:     equ 13

    s_dead:     db `sent to shelter \n`, \
                   `starved to death\n`, \
                   `died of fatigue \n`, \
                   `sent to prison  \n`, \
                   `you are winner  \n`
    l_dead:     equ 17

    s_actn_t:   db `stats:\n`
    l_actn_t:   equ $-s_actn_t
    s_actn_i:   db `say:\n`
    l_actn_i:   equ $-s_actn_i
    s_actn_g:   db `-`
    l_actn_g:   equ $-s_actn_g
    s_actn_b:   db `+`
    l_actn_b:   equ $-s_actn_b
    s_actn_c:   db `, `
    l_actn_c:   equ $-s_actn_c
    s_actn_n:   db `\n`
    l_actn_n:   equ $-s_actn_n
    s_actn_u:   db `> `
    l_actn_u:   equ $-s_actn_u

    s_link_e:   db `  `
    s_link_c:   db `: `
    s_link_o:   db ` (`
    s_link_n:   db `)\n`
    l_link:   equ 2

    s_none_i:   db `bad command\n`
    l_none_i:   equ $-s_none_i    

    ; initial values, see property indexes
    v_vars:     dd 10, 80, 15, 50, 100
    ; increment values, see property indexes
    v_incs:     dd  0,  0,  0,  0,   0

    ; increment rules, see action indexes
    v_rules:    dd  20,   2,  2, -50,  -1, \
                     0,   1, -2,   2,  -1, \
                    15, -10,  1,   1,  -1, \
                    -5,   2,  1,   1,  -1
    ; influence, see property indexes
    t_posit:    db  v_bil, v_fat, v_hun, v_pov   
    t_negat:    db  v_pov, v_bil, v_pov, v_fat   

section .bss
    v_inpt_m:   resb 2
    v_loop_i:   resb 1

section .text
    global _start

_p_str: ; print string value
        ; rdi - string
        ; rsi - len
    push    rax
    push    rbx
    push    rcx
    push    rdx

    mov     rax,    sys_write
    mov     rbx,    stdout
    mov     rcx,    rdi
    mov     rdx,    rsi
    int     syscall

    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

_p_int: ; print integer value
        ; eax - input
    push    rdx
    push    rcx
    push    rbx
    push    rdi

    cmp     eax,        0
    jl      .val_signed
    p_s     s_actn_b,   l_actn_b
    jmp     .val_unsigned

    .val_signed:        
        p_s     s_actn_g,   l_actn_g
        not     eax 
        inc     eax
        
    .val_unsigned:

    mov     ecx,    0

    .p_loop:
        xor     edx,        edx
        mov     ebx,        10
        idiv    ebx
        add     edx,        30h
        push    rdx
        inc     ecx
        cmp     eax,        0
        jnz     .p_loop

    .p_print:
        pop     rax
        mov     [v_loop_i], eax
        p_s     v_loop_i,   1
        loop    .p_print 

    pop     rdi
    pop     rbx
    pop     rcx
    pop     rdx
    ret

_p_val: ; prints value of param, 
        ; eax - base value, 
        ; ebx - increment value
        ; ecx - value name
    p_s     s_link_e,   l_link
    p_s     s_link_e,   l_link
    
    p_s     rcx,        l_name
    p_s     s_link_c,   l_link
    
    cmp     eax,        val_warn
    jl      .val_green
    p_s     s_term_r,   l_term
    jmp     .val_exit

    .val_green:
        p_s    s_term_g,   l_term
    .val_exit:
        call    _p_int

    p_s     s_term_c,   l_term
    p_s     s_link_o,   l_link

    cmp     ebx,        0
    jle     .inc_green
    p_s     s_term_r,   l_term
    jmp     .inc_exit

    .inc_green:
        p_s     s_term_g,   l_term
    .inc_exit:
        mov     eax,        ebx
        call    _p_int

    p_s     s_term_c,   l_term
    p_s     s_link_n,   l_link
    ret

_p_vals: ; prints values of variables
    p_s     s_actn_t,   l_actn_t

    xor     edx,        edx
    .v_loop:
        push    rdx
        mov     eax,        l_name
        mul     edx
        add     eax,        s_name
        mov     rcx,        rax
        pop     rdx

        mov     eax,        [v_vars + edx * 4]
        mov     ebx,        [v_incs + edx * 4]
        call    _p_val

        inc     edx
        cmp     edx,        v_count
        je      .v_exit
        jmp     .v_loop        

    .v_exit:

    p_s     s_actn_n,   l_actn_n
    ret

_p_line: ; prints info line
         ; rax - str: action name
         ; rbx - str: positive property
         ; rcx - str: negative property
    p_s     rax,        l_actn
    p_s     s_term_g,   l_term
    p_s     s_actn_g,   l_actn_g
    p_s     rbx,        l_name
    p_s     s_term_c,   l_term
    p_s     s_actn_c,   l_actn_c
    p_s     s_term_r,   l_term
    p_s     s_actn_b,   l_actn_b
    p_s     rcx,        l_name
    p_s     s_term_c,   l_term
    p_s     s_actn_n,   l_actn_n
    ret

_p_info: ; print move info
    p_s     s_actn_i,   l_actn_i

    xor     edx,        edx
    .i_loop:
        push    rdx         
            xor     eax,     eax  
            mov      al,     [t_negat + edx]
            mov     ecx,     l_name
            mul     ecx
            add     rax,     s_name
            mov     rcx,     rax  
        pop     rdx
        push    rdx
            xor     eax,     eax
            mov      al,     [t_posit + edx]
            mov     ebx,     l_name
            mul     ebx
            add     rax,     s_name
            mov     rbx,     rax            
        pop     rdx
        push    rdx
            mov     eax,    l_actn
            mul     edx
            add     rax,    s_actn
        pop     rdx
        call _p_line
        
        inc     edx
        cmp     edx,     a_count
        je      .i_exit
        jmp     .i_loop        

    .i_exit:

    p_s     s_actn_n,   l_actn_n
    p_s     s_actn_u,   l_actn_u
    ret
 
_r_move: ; read users' move    
    call    _p_info

    mov     rax,        sys_read
    mov     rbx,        stdin
    mov     rcx,        v_inpt_m
    mov     rdx,        2
    int     syscall
    
    ; converting character to index:
    ; 'xxxxxabx' >> 1 & 3
    ; `p` becomes 00
    ; `s` becomes 01
    ; `e` becomes 10
    ; `w` becomes 11
    mov     eax,        [v_inpt_m]
    shr     eax,        1
    and     eax,        3

    mov     ebx,        v_count * 4
    mul     ebx
    add     eax,        v_rules
    mov     ecx,        v_count
    mov     esi,        eax
    mov     edi,        v_incs
    cld
    rep     movsd
    ret

_v_check: ; checks if user is dead
    xor     ecx,        ecx
    
    .c_loop:
        mov     eax,        [v_vars + ecx * 4]
        cmp     ecx,        v_stp
        je      .c_step
        jmp     .c_others

        .c_step:
            cmp     eax,        val_low
            jle     .c_exit
            jmp     .c_cont

        .c_others:
            cmp     eax,        val_crit
            jge     .c_exit

        .c_cont:        

        inc     ecx
        cmp     ecx,        v_count
        je      .c_alive
        jmp     .c_loop

    .c_exit:
        mov     eax,        ecx
        mov     ebx,        l_dead
        mul     ebx
        add     eax,        s_dead
        p_s     s_term_r,   l_term
        p_s     rax,        l_dead
        p_s     s_term_c,   l_term
        call    _exit

    .c_alive:
        ret

_v_calc: ; calcs next move's vars
    xor     ecx,    ecx
    .c_loop:
        mov     eax,        [v_vars + ecx * 4]
        add     eax,        [v_incs + ecx * 4]
        mov     [v_vars + ecx * 4],        eax
        inc     ecx
        cmp     ecx,        v_count
        jne     .c_loop
    ret

_exit:
    mov     rbx,        success
    mov     rax,        sys_exit
    int     syscall

_start:
    call    _p_vals
    call    _r_move
    call    _v_check
    call    _v_calc
    jmp     _start
   