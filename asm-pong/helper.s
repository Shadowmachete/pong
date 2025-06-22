.intel_syntax noprefix
.globl die, set_fd_non_blocking, print_hex_2

.set SYSCALL_READ, 0
.set SYSCALL_WRITE, 1
.set SYSCALL_OPEN, 2
.set SYSCALL_CLOSE, 3
.set SYSCALL_EXIT, 60
.set SYSCALL_FCNTL, 72

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

.type print_hex_2, @function
# Prints AL as 2-digit hex to stdout
# @param al The code
print_hex_2:
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
