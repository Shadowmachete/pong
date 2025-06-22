.intel_syntax noprefix
.globl _start, id, id_base, id_mask, root_visual_id, WINDOW_W, WINDOW_H
.globl LEFT_PADDLE_X, LEFT_PADDLE_Y, RIGHT_PADDLE_X, RIGHT_PADDLE_Y, PADDLE_H, PADDLE_W
.globl BALL_X, BALL_Y, BALL_VELO_X, BALL_VELO_Y

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
WINDOW_H:
  .word 0
WINDOW_W:
  .word 0
LEFT_PADDLE_X:
  .word 0
RIGHT_PADDLE_X:
  .word 0
LEFT_PADDLE_Y:
  .word 0
RIGHT_PADDLE_Y:
  .word 0
PADDLE_H: # height / 4
  .word 0
PADDLE_W: # width / 80
  .word 0
BALL_X:
  .word 0
BALL_Y:
  .word 0
BALL_VELO_X:
  .word 10
BALL_VELO_Y:
  .word 0

.set SYSCALL_WRITE, 1
.set SYSCALL_EXIT, 60

.set BALL_RADIUS, 20

.section .text
_start:
  # start up
  mov     rax, SYSCALL_WRITE
  mov     rdi, 1              # stdout fd
  lea     rsi, msg            # load address of msg into rsi
  mov     rdx, len            # load length into rdi
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

  # WE NEED TO FIND THE WINDOW_W AND WINDOW_H
  # WE WILL SEND QueryExtension request to Xlib with extension RANDR
  # WE WILL THEN GET THE Extension opcode and get the monitors
  mov     rdi, r15
  call    x11_query_extension_randr

  cmp     rax, 0
  jne     .randr_present

  # if randr not present then just set the WINDOW_H and WINDOW_W
  # to some default values

  mov     WORD PTR [WINDOW_W], 1920
  mov     WORD PTR [WINDOW_H], 1080
  jmp     .past_randr

  .randr_present:
  mov     rdi, r15
  mov     esi, r12d
  call    x11_rrgetmonitors

  .past_randr:
  mov     rdi, r15
  mov     esi, ebx
  mov     edx, r12d
  mov     ecx, [root_visual_id]
  mov     r8d, 0 | (0 << 16)  # x and y are 0
  movzx   r9d, WORD PTR [WINDOW_H]
  shl     r9d, 16
  movzx   eax, WORD PTR [WINDOW_W]
  or      r9d, eax
  call    x11_create_window

  mov     rdi, r15
  mov     esi, ebx
  call    x11_map_window

  # calculate all the details for the paddles

  # calculate PADDLE_H and PADDLE_W
  # guess
  # PADDLE_H = WINDOW_H / 4
  # PADDLE_W = WINDOW_W / 80
  movzx   ax, WORD PTR [WINDOW_W]
  mov     cx, ax
  mov     di, 80
  xor     dx, dx
  div     di

  mov     WORD PTR [PADDLE_W], ax

  movzx   ax, WORD PTR [WINDOW_H]
  mov     di, 4
  xor     dx, dx
  div     di

  mov     WORD PTR [PADDLE_H], ax

  # calculate PADDLE_H / 2
  mov     di, 2
  xor     dx, dx
  div     di

  mov     si, ax              # keep PADDLE_H / 2 in si for now ig

  # calculate CENTER_H = WINDOW_H / 2
  movzx   ax, WORD PTR [WINDOW_H]
  mov     di, 2
  xor     dx, dx
  div     di                  # ax = CENTER_H

  sub     ax, BALL_RADIUS
  mov     WORD PTR [BALL_Y], ax

  add     ax, BALL_RADIUS
  sub     ax, si              # ax = CENTER_H - PADDLE_H / 2

  mov     WORD PTR [LEFT_PADDLE_Y], ax
  mov     WORD PTR [RIGHT_PADDLE_Y], ax

  # calculate CENTER_W = WINDOW_W / 2
  movzx   ax, cx
  mov     di, 2
  xor     dx, dx
  div     di

  sub     ax, BALL_RADIUS
  mov     WORD PTR [BALL_X], ax

  add     ax, BALL_RADIUS
  mov     di, 10
  xor     dx, dx
  div     di

  mov     WORD PTR [LEFT_PADDLE_X], ax
  sub     cx, ax
  mov     WORD PTR [RIGHT_PADDLE_X], cx

  # set fd to non-blocking
  mov     rdi, r15
  call    set_fd_non_blocking

  # poll messages
  mov     rdi, r15
  mov     esi, ebx
  mov     edx, r14d
  call    poll_messages

  # exit
  mov     rax, SYSCALL_EXIT
  mov     rdi, 0              # error code 0
  syscall

