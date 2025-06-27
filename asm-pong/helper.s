.intel_syntax noprefix
.globl die, set_fd_non_blocking, print_keypress, check_collision, update_velocity

.set SYSCALL_READ, 0
.set SYSCALL_WRITE, 1
.set SYSCALL_OPEN, 2
.set SYSCALL_CLOSE, 3
.set SYSCALL_EXIT, 60
.set SYSCALL_FCNTL, 72

.set BALL_RADIUS, 20

.section .rodata
err_msg:
  .asciz "Error encountered\n"
err_len = . - err_msg
key_press_msg:
  .ascii "[KEYPRESS] Key: "

.section .text
.type die, @function
# function to quit if error
die:
  mov     rax, SYSCALL_WRITE
  mov     rdi, 2              # stderr fd
  lea     rsi, err_msg[rip]   # load address of msg into %rsi
  mov     rdx, err_len        # load length into %rdx
  syscall

  mov     rax, SYSCALL_EXIT
  mov     rdi, 1              # error code 1
  syscall

.type set_fd_non_blocking, @function
# Sets a file descriptor to non-blocking mode
# @param rdi The file descriptor
set_fd_non_blocking:
  push    rbp
  mov     rbp, rsp

  .set F_GETFL, 3
  .set F_SETFL, 4

  .set O_NONBLOCK, 2048

  # get the flags
  mov     rax, SYSCALL_FCNTL
  mov     rsi, F_GETFL
  mov     rdx, 0
  syscall

  cmp     rax, 0
  jl      die

  # `or` current file status flag with O_NONBLOCK
  mov     rdx, rax
  or      rdx, O_NONBLOCK

  # set the flags
  mov     rax, SYSCALL_FCNTL
  mov     rsi, F_SETFL
  syscall

  cmp     rax, 0
  jl      die

  pop     rbp
  ret

.type print_keypress, @function
# Prints the keypress in AL as 2-digit hex to stdout
# @param al The code
print_keypress:
  push    rcx
  sub     rsp, 32

  mov     r8, rax            # Save original value (al)

  mov     rax, SYSCALL_WRITE
  mov     rdi, 1
  lea     rsi, key_press_msg
  mov     rdx, 16
  syscall

  mov     rax, r8
  and     al, 0xF0            # Upper nibble
  shr     al, 4
  cmp     al, 10
  jl      .upper_digit
  add     al, 'a' - 10
  jmp     .store_upper
  .upper_digit:
  add     al, '0'
  .store_upper:
  mov     BYTE PTR [rsp], al

  mov     al, r8b              # Restore full original byte
  and     al, 0x0F            # Lower nibble
  cmp     al, 10
  jl      .lower_digit
  add     al, 'a' - 10
  jmp     .store_lower
  .lower_digit:
  add     al, '0'
  .store_lower:
  mov     BYTE PTR [rsp + 1], al

  mov     BYTE PTR [rsp + 2], 10

  mov     rax, SYSCALL_WRITE  # write(1, &hex_buf, 2)
  mov     rdi, 1
  lea     rsi, [rsp]
  mov     rdx, 3
  syscall

  add     rsp, 32

  pop     rcx
  ret

.type check_collision, @function
# Checks for collision between the ball and different walls
# @returns rax The code for collision
check_collision:
  push    rbp
  mov     rbp, rsp

  .set NO_COLLISION, 0x00
  .set COLLISION_TOP, 0x01
  .set COLLISION_BOTTOM, 0x02
  .set COLLISION_PADDLE_LEFT, 0x04
  .set COLLISION_PADDLE_RIGHT, 0x08
  .set COLLISION_PADDLE_LENGTH, 0x10
  .set COLLISION_PADDLE_BREADTH, 0x20

  # r8 to store flags
  mov     r8, NO_COLLISION

  # check for collision with top and bottom walls
  .walls:
  .top_wall:
  movzx   si, WORD PTR [BALL_Y]
  cmp     si, 0
  jg      .bottom_wall

  movzx   si, WORD PTR [BALL_VELO_Y]
  cmp     si, 0
  jge     .bottom_wall

  # moving -ve Y and Y pos <= 0
  # collided with top wall
  or      r8, COLLISION_TOP

  # obviously we didnt collide with
  # the bottom wall if we collided with the top
  # save some time with this jump
  jmp     .paddle

  .bottom_wall:
  movzx   si, WORD PTR [BALL_Y]
  add     si, BALL_RADIUS * 2
  movzx   ax, WORD PTR [WINDOW_H]
  cmp     si, ax
  jl      .paddle

  movzx   si, WORD PTR [BALL_VELO_Y]
  cmp     si, 0
  jle     .paddle

  # moving +ve Y and Y pos >= WINDOW_H
  # collided with bottom wall
  or      r8, COLLISION_BOTTOM

  .paddle:
  # checks if the ball's X is less or
  # more than half the window
  movzx   si, WORD PTR [BALL_X]
  movzx   ax, WORD PTR [WINDOW_W]
  mov     di, 2
  xor     dx, dx
  div     di

  cmp     si, ax
  jge     .right_paddle

  .left_paddle:
  # can add a 5 px buffer if this range doesnt work

  # check if the X is in the range of collision with the paddle
  # on the left of the left paddle
  movzx   si, WORD PTR [BALL_X]
  add     si, BALL_RADIUS * 2
  movzx   ax, WORD PTR [LEFT_PADDLE_X]
  cmp     si, ax
  jl      .end

  # on the right of the left paddle
  movzx   si, WORD PTR [BALL_X]
  movzx   di, WORD PTR [PADDLE_W]
  add     ax, di
  cmp     si, ax
  jg      .end

  # check if the Y is in the range of collision with the paddle
  # above the left paddle
  movzx   si, WORD PTR [BALL_Y]
  add     si, BALL_RADIUS * 2
  movzx   ax, WORD PTR [LEFT_PADDLE_Y]
  cmp     si, ax
  jl      .end

  # below the left paddle
  movzx   si, WORD PTR [BALL_Y]
  movzx   di, WORD PTR [PADDLE_H]
  add     ax, di
  cmp     si, ax
  jg      .end

  # collision from the right
  # ball X is on the right-side boundary or left_paddle_x + paddle_w
  movzx   si, WORD PTR [BALL_X]
  movzx   ax, WORD PTR [LEFT_PADDLE_X]
  movzx   di, WORD PTR [PADDLE_W]
  add     ax, di
  cmp     si, ax
  jne     .top_collision

  or      r8, COLLISION_PADDLE_LENGTH
  or      r8, COLLISION_PADDLE_LEFT

  # collision from the top
  .top_collision:
  movzx   si, WORD PTR [BALL_Y]
  add     si, BALL_RADIUS * 2
  movzx   ax, WORD PTR [LEFT_PADDLE_Y]
  cmp     si, ax
  jne     .bottom_collision

  or      r8, COLLISION_PADDLE_BREADTH
  or      r8, COLLISION_PADDLE_LEFT

  # collision from the bottom
  .bottom_collision:
  movzx   si, WORD PTR [BALL_Y]
  movzx   ax, WORD PTR [LEFT_PADDLE_Y]
  movzx   di, WORD PTR [PADDLE_H]
  add     ax, di
  cmp     si, ax
  jne     .end

  or      r8, COLLISION_PADDLE_BREADTH
  or      r8, COLLISION_PADDLE_LEFT

  .right_paddle:
  # check if the X is in the range of collision with the paddle
  # on the left of the right paddle
  movzx   si, WORD PTR [BALL_X]
  add     si, BALL_RADIUS * 2
  movzx   ax, WORD PTR [RIGHT_PADDLE_X]
  cmp     si, ax
  jl      .end

  # on the right of the right paddle
  movzx   si, WORD PTR [BALL_X]
  movzx   di, WORD PTR [PADDLE_W]
  add     ax, di
  cmp     si, ax
  jg      .end

  # check if the Y is in the range of collision with the paddle
  # above the right paddle
  movzx   si, WORD PTR [BALL_Y]
  add     si, BALL_RADIUS * 2
  movzx   ax, WORD PTR [RIGHT_PADDLE_Y]
  cmp     si, ax
  jl      .end

  # below the right paddle
  movzx   si, WORD PTR [BALL_Y]
  movzx   di, WORD PTR [PADDLE_H]
  add     ax, di
  cmp     si, ax
  jg      .end

  # collision from the left
  movzx   si, WORD PTR [BALL_X]
  movzx   ax, WORD PTR [RIGHT_PADDLE_X]
  cmp     si, ax
  jge     .top_collision_2

  or      r8, COLLISION_PADDLE_LENGTH
  or      r8, COLLISION_PADDLE_RIGHT

  # collision from the top
  .top_collision_2:
  movzx   si, WORD PTR [BALL_Y]
  add     si, BALL_RADIUS * 2
  movzx   ax, WORD PTR [RIGHT_PADDLE_Y]
  cmp     si, ax
  jne     .bottom_collision_2

  or      r8, COLLISION_PADDLE_BREADTH
  or      r8, COLLISION_PADDLE_RIGHT

  # collision from the bottom
  .bottom_collision_2:
  movzx   si, WORD PTR [BALL_Y]
  movzx   ax, WORD PTR [RIGHT_PADDLE_Y]
  movzx   di, WORD PTR [PADDLE_H]
  add     ax, di
  cmp     si, ax
  jne     .end

  or      r8, COLLISION_PADDLE_BREADTH
  or      r8, COLLISION_PADDLE_RIGHT

  .end:
  mov     rax, r8

  pop     rbp
  ret

.type update_velocity, @function
# updates the ball's velocity based on collision
# @params rax Ball collision code
# @params rdx Which paddle is moving and the direction (if any)
update_velocity:
  push    rbp
  mov     rbp, rsp

  .set COLLISION_TOP, 0x01
  .set COLLISION_BOTTOM, 0x02
  .set COLLISION_PADDLE_LEFT, 0x04
  .set COLLISION_PADDLE_RIGHT, 0x08
  .set COLLISION_PADDLE_LENGTH, 0x10
  .set COLLISION_PADDLE_BREADTH, 0x20

  .set NO_PADDLE_MOVEMENT, 0x00
  .set LEFT_PADDLE_UP, 0x01
  .set LEFT_PADDLE_DOWN, 0x02
  .set RIGHT_PADDLE_UP, 0x04
  .set RIGHT_PADDLE_DOWN, 0x08

  .top:
  mov     rsi, COLLISION_TOP
  and     rsi, rax
  cmp     rsi, 0
  je      .bottom

  # set y to 0 and negate velo_y
  mov     si, 0
  mov     WORD PTR [BALL_Y], si

  mov     si, WORD PTR [BALL_VELO_Y]
  neg     si
  mov     WORD PTR [BALL_VELO_Y], si

  jmp     .length

  .bottom:
  mov     rsi, COLLISION_BOTTOM
  and     rsi, rax
  cmp     rsi, 0
  je      .length

  # set y to window_h and negate velo_y
  mov     si, WORD PTR [WINDOW_H]
  mov     WORD PTR [BALL_Y], si

  mov     si, WORD PTR [BALL_VELO_Y]
  neg     si
  mov     WORD PTR [BALL_VELO_Y], si

  .length:
  mov     rsi, COLLISION_PADDLE_LENGTH
  and     rsi, rax
  cmp     rsi, 0
  je      .breadth

  mov     si, WORD PTR [BALL_VELO_X]
  neg     si
  mov     WORD PTR [BALL_VELO_X], si

  jmp     .adjust_spin

  .breadth:
  mov     rsi, COLLISION_PADDLE_BREADTH
  and     rsi, rax
  cmp     rsi, 0
  je      .no_paddle_collision

  mov     si, WORD PTR [BALL_VELO_Y]
  neg     si
  mov     WORD PTR [BALL_VELO_Y], si

  .adjust_spin:
  cmp     rdx, NO_PADDLE_MOVEMENT
  je      .no_paddle_movement

  .check_left_paddle:
  mov     rsi, COLLISION_PADDLE_LEFT
  and     rsi, rax
  cmp     rsi, 0
  je      .check_right_paddle

  mov     ax, WORD PTR [BALL_VELO_Y]
  cmp     rdx, LEFT_PADDLE_UP
  jne     .left_paddle_down

  .left_paddle_up:
  cmp     ax, 0
  jl      .half
  jg      .threehalves

  .left_paddle_down:
  cmp     ax, 0
  jg      .half
  jl      .threehalves

  .check_right_paddle:
  cmp     rdx, RIGHT_PADDLE_UP
  jne     .right_paddle_down

  .right_paddle_up:
  cmp     ax, 0
  jl      .half
  jg      .threehalves

  .right_paddle_down:
  cmp     ax, 0
  jg      .half
  jl      .threehalves

  .half:
  mov     di, 2
  xor     dx, dx
  div     di
  mov     WORD PTR [BALL_VELO_Y], ax

  jmp     .end2

  .threehalves:
  imul    ax, 3

  mov     di, 2
  xor     dx, dx
  div     di
  mov     WORD PTR [BALL_VELO_Y], ax

  .end2:
  .no_paddle_collision:
  .no_paddle_movement:
  pop     rbp
  ret

                # authentication that didnt work
                # .type read_xauth_cookie, @function
                # # reads xauth cookie from file path
                # # @params rdi Pointer to the file path name
                # # @returns Pointer to cookie in rax
                # read_xauth_cookie:
                #   push    rbp
                #   mov     rbp, rsp
                # 
                #   mov     rax, SYSCALL_OPEN
                #   mov     rsi, 0              # O_RDONLY
                #   syscall
                # 
                #   cmp     rax, 0
                #   jle     fail
                # 
                #   mov     rdi, rax
                #   mov     rax, SYSCALL_READ
                #   lea     rsi, xauth_cookie
                #   mov     rdx, 60             # read the first entry
                #   syscall
                # 
                #   cmp     rax, 60
                #   jl      fail
                # 
                #   mov     r13, rsi
                # 
                #   mov     rax, SYSCALL_CLOSE
                #   syscall
                # 
                #   lea     rax, [r13 + 35]
                # 
                #   pop     rbp
                #   ret
                # 
                # fail:
                # fail:
                #   mov     rax, -1
                #   pop     rbp
                #   ret
