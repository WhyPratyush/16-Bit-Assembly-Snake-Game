bits 16
org 0x7c00

; ==========================================
; Memory Layout & Circular Buffer Constants
; ==========================================
; We use memory starting at 0x0500 to store the screen coordinates
; of every segment of the snake's body as a circular buffer.
START equ 0x0500
SIZE  equ 32768     
END   equ START + SIZE

; ==========================================
; VGA Mode 13h Color Palette
; ==========================================
BACKGROUND_COLOUR  equ 0x00  ; Black
WALL_COLOUR        equ 0x09  ; Light Blue
SNAKE_COLOUR       equ 0x0A  ; Light Green
APPLE_COLOUR       equ 0x0C  ; Light Red

start:
    ; --- Set up Data and Stack Segments ---
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x9000         ; Set stack safely far away at 0x9000

    ; --- Enter Graphics Mode ---
    mov ax, 0x0013
    int 0x10               ; BIOS Interrupt: Set VGA Mode 13h (320x200, 256 colors)

    push 0xA000
    pop es                 ; ES segment now points to VGA framebuffer (0xA0000)

    ; --- Initialize Game State ---
    mov ax, 320*100 + 160  ; Calculate center screen offset (Y * 320 + X)
    mov di, ax             ; DI tracks the current linear screen position of the snake's head
    mov bx, 1              ; BX tracks movement direction/offset (+1 = Right)
    
    mov bp, START          ; BP acts as the Head Pointer for the circular buffer
    mov si, START          ; SI acts as the Tail Pointer for the circular buffer

    call walls             ; Draw the border
    
    mov [bp], di           ; Store initial head position in the buffer
    
    call apple             ; Spawn the first apple
    jmp game_loop

; ==========================================
; Routine: Draw Border Walls
; ==========================================
walls:
    push ax
    push bx
    push cx
    push di

    ; Draw Top Wall
    mov di, 0
    mov cx, 320            ; Loop across top 320 pixels
top:
    mov byte [es:di], WALL_COLOUR
    inc di
    loop top

    ; Draw Bottom Wall
    mov di, 320*199        ; Start at last row
    mov cx, 320
bottom:
    mov byte [es:di], WALL_COLOUR
    inc di
    loop bottom

    ; Draw Side Walls
    mov cx, 200            ; Loop down 200 rows
    mov di, 0
side:
    mov byte [es:di], WALL_COLOUR         ; Left wall pixel
    mov byte [es:di+319], WALL_COLOUR     ; Right wall pixel (offset by row width - 1)
    add di, 320                           ; Move to next row
    loop side

    pop di
    pop cx
    pop bx
    pop ax
    ret

; ==========================================
; Main Game Loop
; ==========================================
game_loop:
    ; --- CPU Delay ---
    ; Without this nested loop, modern CPUs will run the game instantly.
    mov dx, 1250           ; Outer loop counter (Tune this to change game speed)
delay_outer:
    mov cx, 0xFFFF         ; Inner loop counter
delay_inner:
    nop
    loop delay_inner
    dec dx
    jnz delay_outer

    ; --- Handle Keyboard Input ---
    mov ah, 0x01           ; BIOS Keyboard Interrupt: Check buffer status
    int 0x16
    jz movement            ; If ZF is set, no key pressed, continue current movement
    mov ah, 0x00           ; Key pressed, fetch it from buffer to clear it
    int 0x16
    
    ; Compare AL (ASCII character) to WASD keys
    cmp al, 'a'
    je left
    cmp al, 'd'
    je right
    cmp al, 'w'
    je up
    cmp al, 's'
    je down
    jmp movement

; --- Directional Logic ---
; Prevents the snake from doing a 180-degree turn directly into itself.
; Movement offsets in 320x200 space: 
; Left = -1, Right = +1, Up = -320, Down = +320
left:
    cmp bx, 1              ; Check if currently moving right
    je movement      
    mov bx, -1
    jmp movement

right:
    cmp bx, -1             ; Check if currently moving left
    je movement
    mov bx, 1
    jmp movement

up:
    cmp bx, 320            ; Check if currently moving down
    je movement
    mov bx, -320
    jmp movement

down:
    cmp bx, -320           ; Check if currently moving up
    je movement
    mov bx, 320

; --- Update Position & Collision Logic ---
movement:
    add di, bx             ; Apply movement offset to current head position
    cmp di, 64000          ; Check if head went entirely out of bounds (failsafe)
    jae game_over
    
    ; Check the pixel colour at the new head position
    mov al, [es:di] 
    cmp al, SNAKE_COLOUR   ; Self Collision
    je game_over
    cmp al, WALL_COLOUR    ; Hitting a wall
    je game_over
   
    cmp al, APPLE_COLOUR   ; Hitting Apple
    je ate

    ; --- Move Tail (If NO apple was eaten) ---
    ; Retrieve the oldest stored position, paint it black, and advance tail pointer
    push bx         
    mov bx, [si]           ; Get linear screen pos of the tail segment
    mov byte [es:bx], BACKGROUND_COLOUR ; Erase tail from screen
    add si, 2              ; Advance tail pointer (2 bytes for 16-bit address)
    
    ; Wrap circular buffer if needed
    cmp si, END
    jb tail_ok
    mov si, START

tail_ok:
    pop bx      
    jmp update_head

ate:
    ; If apple eaten, skip erasing the tail this frame (snake grows)
    call apple

; --- Move Head ---
update_head:
    mov byte [es:di], SNAKE_COLOUR ; Draw the new head on screen
    
    ; Advance head pointer and store the new screen position
    add bp, 2
    cmp bp, END
    jb head_ok
    mov bp, START          ; Wrap circular buffer if needed

head_ok:
    mov [bp], di           ; Save current linear head position to buffer
    jmp game_loop

; ==========================================
; Game Over State
; ==========================================
game_over:
    int 0x19               ; BIOS Interrupt: Reboot the system

; ==========================================
; Routine: Spawn Apple
; ==========================================
apple:
    push ax
    push cx
    push dx
    push si

retry:
    ; Get system time (clock ticks) to use as a seed for RNG
    mov ah, 0x00
    int 0x1A       

    ; DX contains lower half of clock ticks. 
    mov ax, dx
    xor dx, dx             ; Clear DX for division
    mov cx, 64000          ; Total pixels on screen
    div cx                 ; Remainder is stored in DX

    mov si, dx             ; SI = Random screen offset
    mov al, [es:si]        ; Check pixel at random offset
    cmp al, BACKGROUND_COLOUR ; Make sure we only spawn the apple on empty space
    jne retry              ; Try again if spawning on a wall or the snake

    mov byte [es:si], APPLE_COLOUR ; Draw the apple

    pop si
    pop dx
    pop cx
    pop ax
    ret            

; ==========================================
; Boot Sector Signature
; ==========================================
times 510-($-$$) db 0      ; Pad the rest of the 512 bytes with zeroes
dw 0xAA55                  ; Boot signature