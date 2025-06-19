.intel_syntax noprefix
.globl die, read_xauth_cookie

.set SYSCALL_READ, 0
.set SYSCALL_WRITE, 1
.set SYSCALL_OPEN, 2
.set SYSCALL_CLOSE, 3
.set SYSCALL_EXIT, 60

.section .rodata
err_msg:
  .asciz "Error encountered\n"
err_len = . - err_msg

.section .bss
xauth_cookie:
  .skip 64

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
