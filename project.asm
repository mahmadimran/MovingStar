[org 0x100]

jmp start

;old isrs
oldkbisr: dd 0
oldtisr: dd 0

;flags and variables
direction:  db 0      ; 0=right, 1=left, 2=up, 3=down
exit: db 0            ;1 = esc key pressed(exit)
game_lost: db 0       ;1 = lost
game_won: db 0        ;1 = won
tickCount: db 2       ;wait for 2 timer interrupts
isStarted: db 0       ;0 is not, 1 if yes (a check for exiting the game)
row: db 0             ;row variable used to calculate offset
col: db 0             ;col variable used to calculate offset

;output strings
name: db 'Moving Star - by Muhammad Ahmad Imran 24L-0790',0
controls: db 'Move Using Arrow Keys  -  Quit Using ESC',0
press: db 'Press SPACE to start',0
lost: db 'Game Lost',0
won: db 'Game Won',0
exit_: db 'You Quit',0

;Helper Sub Routines
clrscrn: 
    pusha 
    
    mov ax, 0xb800
    mov es, ax
    mov di, 0
    mov ax, 0x7020
    mov cx, 2000

    rep stosw

    popa
    ret 
calc_offset:   
 ; Uses [cs:row] and [cs:col], stores offset in DI
    push ax
    push bx
    push cx

    xor ax, ax
    mov al, [cs:row]
    mov bl, [cs:col]

    mov ah, 0
    mov cx, 80
    mul cx                ;ax = row*80
    add al, bl            ;ax = row*80 + col
    adc ah, 0
    shl ax, 1             ;ax = (row*80+col)*2
    mov di, ax

    pop cx
    pop bx
    pop ax
    ret

print_screen:
    pusha

    mov ax, 0xb800
    mov es, ax

    call calc_offset  ;di gets the offset
    mov ah, 0x70

    nextchar:
        mov al, [si]
        mov [es:di], ax 
        add di, 2
        inc si
        loop nextchar
    
    popa 
    ret

;Screen Initialisers
horizontal_rect:   
    pusha

    mov ax, 0xb800
    mov es, ax

    call calc_offset  ;di gets the offset

    mov ax, 0x2220
    rep stosw

    popa
    ret 

vertical_rect:
    pusha

    mov ax, 0xb800
    mov es, ax

    call calc_offset  ;di gets the offset

    mov ax, 0x2220

    l1:
        mov[es:di], ax
        add di, 160
        loop l1

    popa
    ret 

place_obstacles: 
    pusha

    ;1st
    mov byte [cs:col], 9  ;column
    mov byte [cs:row], 9  ;row
    mov cx, 6             ;length

    call vertical_rect

    ;2nd
    mov byte [cs:col], 21  ;column
    mov byte [cs:row], 10  ;row
    mov cx, 10             ;length

    call horizontal_rect

    ;3rd
    mov byte [cs:col], 26  ;column
    mov byte [cs:row], 16  ;row
    mov cx, 10             ;length

    call horizontal_rect
    
    ;4th
    mov byte [cs:col], 46  ;column
    mov byte [cs:row], 11  ;row
    mov cx, 6              ;length

    call vertical_rect

    ;5th
    mov byte [cs:col], 53  ;column
    mov byte [cs:row], 7   ;row
    mov cx, 6              ;length
    
    call vertical_rect
   
    ;6th
    mov byte [cs:col], 62  ;column
    mov byte [cs:row], 10  ;row
    mov cx, 10             ;length

    call horizontal_rect
    
    ;7th
    mov byte [cs:col], 79  ;column
    mov byte [cs:row], 0   ;row
    mov cx, 25             ;length
    
    call vertical_rect

    popa
    ret

goal_player: 
    pusha

    mov ax, 0xb800
    mov es, ax
    mov di, 0

    mov ax, 0x4420    ;goal
    mov [es:di], ax

    mov di, 3920
    mov ax, 0x712A    ;player
    mov [es:di], ax

    popa
    ret

initScreen: 
    pusha 

    call clrscrn
    call place_obstacles
    call goal_player
    
    popa
    ret

;Game Mechanics
move_player: 
    pusha
    push es

    mov ax, 0xb800
    mov es, ax

    ;erase star from previous position
    call calc_offset  ;di gets the offset
    mov word [es:di], 0x7020

    ;determine new position
    mov al, [cs:direction]

    cmp al, 0
    je move_right

    cmp al, 1
    je move_left

    cmp al, 2
    je move_up

    cmp al, 3
    je move_down

    jmp update_screen

    move_right:     ;no edge check here as this edge is an entire obstacle
        inc byte [cs:col]       ;change coordinate
        jmp update_screen

    move_left:
        cmp byte [cs:col], 0    ;checking if at left edge
        jbe bounce_from_left 
        
        dec byte [cs:col]       ;change coordinate
        jmp update_screen

    move_up:
        cmp byte [cs:row], 0    ;checking if at top edge
        jbe bounce_from_top 
        
        dec byte [cs:row]       ;change coordinate
        jmp update_screen

    move_down:
        cmp byte [cs:row], 24    ;checking if at bottom edge
        jae bounce_from_bottom 
       
        inc byte [cs:row]       ;change coordinate
        jmp update_screen

    bounce_from_left:
        mov byte [cs:direction], 0   ;move right
        jmp update_screen

    bounce_from_top:
        mov byte [cs:direction], 3   ;move down
        jmp update_screen

    bounce_from_bottom:
        mov byte [cs:direction], 2   ;move up
    
    ;check for collision and draw star at updated position
    update_screen:
        call calc_offset  ;di gets the new offset

        mov ax, [es:di]

        cmp ax, 0x2220        ;updated position is same as obstacle(green space)
        je hit_obstacle

        cmp ax, 0x4420        ;updated position is same as goal(red space)
        je hit_goal

        mov word [es:di], 0x712A   ;updated position is fine(place player at new position)
        jmp done_

    hit_obstacle:
        mov byte [cs:game_lost], 1
        jmp done_

    hit_goal:
        mov byte [cs:game_won], 1

    done_:
        pop es
        popa
        ret

kbisr:
    push ax
    push es

    in al, 0x60    ;read character from keyboard port

    test al, 80h   ;check if key is pressed and not released(msb 0 or 1)
    jnz done

    cmp al, 0x48 ;up arrow
    je set_up

    cmp al, 0x50 ;down arrow
    je set_down

    cmp al, 0x4B ;left arrow
    je set_left

    cmp al, 0x4D ;right arrow
    je set_right

    cmp al, 01h
    je set_exit

    jmp done

    set_up:
        mov byte [cs:direction], 2
        jmp done

    set_down:
        mov byte [cs:direction], 3
        jmp done

    set_left:
        mov byte [cs:direction], 1
        jmp done

    set_right:
        mov byte [cs:direction], 0
        jmp done

    set_exit:
        mov byte [cs:exit], 1

    done:
        pop es
        pop ax
        jmp far [cs:oldkbisr]

tisr:
    push ax
    push es

    dec byte [cs:tickCount]
    jnz restore

    ;2 ticks passed 
    mov byte [cs:tickCount], 2 

    call move_player

    restore:
        pop es
        pop ax
        
        jmp far [cs:oldtisr] 

hook:
    pusha

    xor ax, ax
    mov es, ax

    ;saving original isrs
    mov ax, [es:9*4]        ;keyboard interrupt
    mov [oldkbisr], ax
    mov ax, [es:9*4+2]
    mov [oldkbisr+2], ax

    mov ax, [es:8*4]        ;timer interrupt 
    mov [oldtisr], ax
    mov ax, [es:8*4+2]
    mov [oldtisr+2], ax

    ;hooking interrupts
    cli
    mov word [es:9*4], kbisr  ;keyboard interrupt
    mov [es:9*4+2], cs

    mov word [es:8*4], tisr  ;timer interrupt 
    mov [es:8*4+2], cs
    sti

    popa
    ret

unhook:
    pusha

    xor ax, ax
    mov es, ax

    ;restoring original isrs
    mov ax, [oldkbisr]         ;keyboard interrupt
    mov bx, [oldkbisr+2]

    cli
    mov word [es:9*4], ax
    mov [es:9*4+2], bx
    sti

    mov ax, [oldtisr]         ;timer interrupt
    mov bx, [oldtisr+2]

    cli
    mov word [es:8*4], ax
    mov [es:8*4+2], bx
    sti

    popa
    ret

;Display Screens
starting_screen: 
    pusha

    call clrscrn

    ;print name
    mov byte [cs:row], 10
    mov byte [cs:col], 16

    mov cx, 46    ;length of string
    mov si, name
    call print_screen

    ;print controls
    mov byte [cs:row], 11
    mov byte [cs:col], 19
    
    mov cx, 40    ;length of string
    mov si, controls
    call print_screen

    ;print how to start
    mov byte [cs:row], 12
    mov byte [cs:col], 29
    
    mov cx, 20    ;length of string
    mov si, press
    call print_screen

    ;wait for keypress - Space bar to play - ESC to quit before playing
    wait_:
        mov ah, 00h
        int 16h
        cmp ah, 0x01    ;check esc
        je exit_screen
        cmp ah, 0x39    ;check space bar
        jne wait_
        
    mov byte [cs:isStarted], 1  

    popa
    ret

game_lost_screen: 
    pusha

    call clrscrn

    mov byte [cs:row], 10
    mov byte [cs:col], 35

    mov cx, 9    ;length of string
    mov si, lost
    call print_screen

    popa
    jmp end

game_won_screen: 
    pusha

    call clrscrn

    mov byte [cs:row], 10
    mov byte [cs:col], 35

    mov cx, 8    ;length of string
    mov si, won
    call print_screen

    popa
    jmp end

exit_screen: 
    pusha

    call clrscrn

    mov byte [cs:row], 10
    mov byte [cs:col], 35

    mov cx, 8
    mov si, exit_
    call print_screen

    popa
    cmp byte [isStarted], 1
    je end    ;ended during the game(we have to unhook the interrupts aswell)
    jne end_  ;ended before starting the game(no need to unhook interrupts as they were never hooked)

;Main 
start: 
    call starting_screen
    call initScreen

    ;initial player coordinates
    mov byte [cs:row], 24
    mov byte [cs:col], 40

    call hook

    gamp_loop:     ;loops until esc pressed or either won/lost
        cmp byte [cs:exit], 1       ;exit check(esc pressed)
        je exit_screen

        cmp byte [cs:game_lost], 1  ;lost check
        je game_lost_screen
        
        cmp byte [cs:game_won], 1   ;won check
        je game_won_screen

        jmp gamp_loop
    
    end:
        call unhook

    end_:
        mov ax, 0x4c00
        int 21h
