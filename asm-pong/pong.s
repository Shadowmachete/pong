.intel_syntax noprefix
.globl _start, id, id_base, id_mask, root_visual_id

.section .data
msg:
  .asciz "Starting up...\n"
len = . - msg
id:
  .long 0
id_base:
  .long 0
id_mask:
  .long 0
root_visual_id:
  .long 0

.set SYSCALL_WRITE, 1
.set SYSCALL_EXIT, 60

.section .text
_start:
  # start up
  mov     rax, SYSCALL_WRITE
  mov     rdi, 1              # stdout fd
  lea     rsi, msg            # load address of msg into %rsi
  mov     rdx, len            # load length into %rdi
  syscall

  cmp     rax, 0
  jl      die                 # if rax < 0, syscall failed

  # connect to server
  call    x11_connect_to_server

  mov     r15, rax            # store socket fd in r15

  mov     rdi, rax
  call    x11_send_handshake
  mov     r12d, eax           # store root window id in r12

  call    x11_next_id
  mov     r13d, eax           # store font_id in r13

  mov     esi, eax
  mov     rdi, r15
  call    x11_open_font

  call    x11_next_id
  mov     r14d, eax           # store gc_id in r14

  mov     rdi, r15
  mov     esi, r14d
  mov     edx, r12d
  mov     ecx, r13d
  call    x11_create_gc

  call    x11_next_id
  mov     ebx, eax            # store window id in ebx

  mov     rdi, r15
  mov     esi, eax
  mov     edx, r12d
  mov     ecx, [root_visual_id]
  mov     r8d, 200 | (200 << 16)    # x and y are 200
  .set WINDOW_W, 800
  .set WINDOW_H, 600
  mov     r9d, WINDOW_W | (WINDOW_H << 16)
  call    x11_create_window

  mov     rdi, r15
  mov     esi, ebx
  call    x11_map_window

loop:
  jmp     loop

  # exit
  mov     rax, SYSCALL_EXIT
  mov     rdi, 0              # error code 0
  syscall

