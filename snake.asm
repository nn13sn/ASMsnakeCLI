global _start 

section .bss 
termios resb 60 ;termios structure, i need it to change the cli into non-canonical mode (no enter needed to read)
origin_flags resq 1
key_buff resb 1
tailcord resb 1 
finalscore resb 3

section .data
  red db 27, '[1;31m'
  yellow db 27, '[1;33m'
  green db 27, '[1;32m'
  blue db 27, '[1;35m'
  
  yellowptr dq yellow 
  greenptr dq green
  redptr dq red 
  blueptr dq blue

  clear db 27, '[', '2', 'J'
  snakefields dq 0
  snakefieldsSize dq 0
  direction db 0
  field times 225 db '0'
  endline db 10
  space db ' ' 
  overmsg db "Game over! Your score is: "
  sleeptime:
    dq 0
    dq 3000000


section .text
  changeColor:
  push rsi 
  mov rax, 1 
  mov rdi, 1 
  mov rsi, r12 
  mov rdx, 7 
  syscall 
  pop rsi 
  jmp continue 
  printframe:
  xor r9, r9  
  outerloop:
  xor r8, r8
  innerloop:
    mov rax, 1
    mov rdi, 1
    mov rsi, space
    mov rdx, 1
    syscall 

    xor rsi, rsi
    imul rsi, r9, 15 
    add rsi, field 
    add rsi, r8
    cmp [rsi], '0'
    cmove r12, [yellowptr] 
    je changeColor
    cmp [rsi], '1' 
    cmove r12, [greenptr] 
    je changeColor 
    cmp [rsi], 'A' 
    cmove r12, [redptr]
    je changeColor
    cmp [rsi], '2'
    cmove r12, [blueptr]
    je changeColor
    continue: 
    mov rax, 1 
    mov rdi, 1 
    mov rdx, 1
    syscall

    inc r8
    cmp r8, 15
    jne innerloop 
  mov rax, 1
  mov rdi, 1
  mov rsi, endline
  mov rdx, 1
  syscall
  inc r9
  cmp r9, 15
  jne outerloop
  ret

  AddToSnake:
  mov rax, [snakefields] 
  add rax, [snakefieldsSize] 
  mov [rax], rdi 
  inc [snakefieldsSize] 
  ret

  Set_toNonCanonical:
  mov rax, 16  ;number of ioctl syscall 
  mov rdi, 0  
  mov rsi, 0x5401   ;command to get termios struct 
  mov rdx, termios 
  syscall 

  mov eax, dword [termios + 12] ;getting c_lflag 
  and eax, ~(10 | 2)     ;basically just removing ICANON and ECHO bits 
  mov [termios + 12], eax  ;putting new cl_flag back to the struct 

  mov rax, 16   
  mov rdi, 0  
  mov rsi, 0x5402   ;command to set termios struct 
  mov rdx, termios 
  syscall

  mov rax, 72   ;fcntl
  mov rdi, 0 
  mov rsi, 3  ;getting
  mov rdx, 0 
  syscall 

  mov [origin_flags], rax 
  or rax, 2048  ;adding NONBLOCK flag, so the read() is not gonna block write()
  mov rdx, rax 
  mov rax, 72   ;setting 
  mov rdi, 0 
  mov rsi, 4   
  syscall 
  ret 

  SetBackCanonical:
  mov eax, dword [termios + 12] 
  xor eax, (10 | 2)      
  mov [termios + 12], eax   

  mov rax, 16   
  mov rdi, 0  
  mov rsi, 0x5402   ;command to set termios struct 
  mov rdx, termios 
  syscall

  mov rax, 72 
  mov rdi, 0 
  mov rsi, 4 
  mov rdx, [origin_flags]
  ret 

  CheckTheKey:
    mov rax, 0
    mov rdi, 0 
    mov rsi, key_buff
    mov rdx, 1 
    syscall
    cmp rax, 0 
    jg ChangeDirection
    back:
    ret 

  ChangeDirection:  
  mov byte [direction], 0 
  cmp [key_buff], 'w' 
  je back
  mov byte [direction], 3 
  cmp [key_buff], 'a' 
  je back 
  mov byte [direction], 2 
  cmp [key_buff], 's' 
  je back 
  mov byte [direction], 1
  cmp [key_buff], 'd'
  je back 
  jmp back 

  UpdateSnake:
  mov r8, [snakefields] 
  mov r8b, byte [r8]
  cmp byte [direction], 0
  je .up 
  cmp byte [direction] , 1 
  je .right 
  cmp byte [direction], 2 
  je .down 
  cmp byte [direction], 3 
  je .left 
  
  .up:
  mov r9, [snakefields]
  sub byte [r9], 15
  jmp .tail 
  .right:
  mov r9, [snakefields]
  inc byte [r9]
  jmp .tail 
  .down:
  mov r9, [snakefields]
  add byte [r9], 15 
  jmp .tail 
  .left:
  mov r9, [snakefields]
  dec byte [r9]
  .tail:
  mov rcx, 1 
  .mainloop:
  mov r9, [snakefields]
  mov r9b, byte [r9 + rcx]
  mov r10, [snakefields] 
  mov byte [r10 + rcx], r8b
  mov r8b, r9b 
  inc rcx 
  cmp rcx, [snakefieldsSize]
  jne .mainloop
  mov byte [tailcord], r8b 
  ret 
  
  UpdateField:
  mov rax, [snakefields]
  movzx eax, byte [rax + 1]
  mov byte [field + rax], '1'
  mov rax, [snakefields]
  movzx eax, byte [rax]
  cmp [field + rax], '1'
  je over 
  cmp [field + rax], 'A'
  je .appleeaten 
  mov byte [field + rax], '2'
  movzx eax, byte [tailcord] 
  mov byte [field + rax], '0'
  ret 
  .appleeaten:
  movzx edi, byte [tailcord]
  mov byte [field + rax], '2'
  call AddToSnake
  call GenerateApple
  ret 
  ClearField:
  mov rax, 1 
  mov rdi, 1
  mov rsi, clear 
  mov rdx, 4 
  syscall
  ret 
  Sleep:
  mov rax, 35 
  mov rdi, sleeptime 
  mov rsi, 0
  syscall 
  ret 
  CrashCheck:
  mov r8, [snakefields] 
  movzx eax, byte [r8] 
  cdq
  mov ebx, 15  
  idiv ebx 
  cmp edx, 14  
  jne .checknext 
  cmp byte [direction], 1 
  je over 
  .checknext: 
  movzx eax, byte [r8]
  cdq
  mov ebx, 15 
  idiv ebx 
  cmp edx, 0 
  jne .checknext1 
  cmp byte [direction], 3 
  je over 
  .checknext1:
  movzx eax, byte [r8] 
  cmp eax, 14 
  jg .checknext2
  cmp byte [direction], 0
  je over 
  .checknext2:
  movzx eax, byte [r8] 
  cmp eax, 210 
  jl .checknext3 
  cmp byte [direction], 2 
  je over 
  .checknext3:
  ret 
  PrintScore:
  call ClearField 
  mov rax, 1 
  mov rdi, 1 
  mov rsi, overmsg 
  mov rdx, 26 
  syscall 
  mov rbx, 10 
  mov rcx, 3 
  mov rax, [snakefieldsSize]
  .mainloop:
  cqo 
  idiv rbx 
  add rdx, 48 
  mov [finalscore + rcx - 1], dl
  cmp rax, 0 
  jz .out 
  loop .mainloop 
  .out:
  mov rax, 1 
  mov rdi, 1 
  mov rsi, finalscore 
  mov rdx, 3
  syscall
  ret 
  
GenerateApple:
  rdrand eax 
  jnc GenerateApple 

  xor edx, edx 
  mov ecx, 225
  div ecx 

  cmp [field + rdx], '1' 
  je GenerateApple 
  cmp [field + rdx], '2'
  je GenerateApple
  mov [field + rdx], 'A'
  ret
  _start: 
  call Set_toNonCanonical
    mov rax, 12
    mov rdi, 0 
    syscall 
    
    mov [snakefields], rax 
    add rax, 512 ;512 doesnt really matter here, in reality 4096 bytes would be allocated anyway
    mov rdi, rax 
    mov rax, 12 
    syscall 
    
    mov rdi, 97 
    call AddToSnake
    mov rdi, 112
    call AddToSnake 
    mov rdi, 127
    call AddToSnake
    
    mov [field + 97], '1'
    mov [field + 112], '1'
    mov [field + 127], '1'

    call GenerateApple

    .outerloop:
    xor r14, r14 
      .innerloop:
      call ClearField
      call printframe 
      call CheckTheKey
      call Sleep
      inc r14 
      cmp r14, 100  
      jne .innerloop 
    call CrashCheck  
    call UpdateSnake
    call UpdateField
    jmp .outerloop 

    over:
    call PrintScore
    call SetBackCanonical 
    mov rax, 60
    syscall
