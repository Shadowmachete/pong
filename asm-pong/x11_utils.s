.intel_syntax noprefix
.globl x11_connect_to_server, x11_send_handshake, x11_next_id, x11_open_font, x11_create_gc, x11_create_window, x11_map_window

.extern id, id_base, id_mask, root_visual_id

.set SYSCALL_READ, 0
.set SYSCALL_WRITE, 1
.set SYSCALL_SOCKET, 41
.set SYSCALL_CONNECT, 42

.set AF_UNIX, 1               # Unix domain socket
.set SOCK_STREAM, 1           # Stream-oriented socket

.section .rodata
sun_path:
  .asciz "/tmp/.X11-unix/X1"
auth_protocol_name:
  .asciz "MIT-MAGIC-COOKIE-1"
xauth_path:
  .asciz "~/XAuthority"
xauth_path_2:
  .asciz "/run/user/1000/xauth_kiSfxG"

.section .bss
.balign 16
read_buf:
  .skip 65536                 # reserve 64 KB for reading

.section .text
.type x11_connect_to_server, @function
# Create a UNIX domain socket and connect to X11 server
# @returns Socket file descriptor.
x11_connect_to_server:
  # function prologue
  push    rbp                 # save base pointer on stack
  mov     rbp, rsp            # save position of stack pointer in base pointer

  # open a Unix socket: socket(2)
  mov     rax, SYSCALL_SOCKET
  mov     rdi, AF_UNIX        # Unix socket
  mov     rsi, SOCK_STREAM    # stream-oriented
  mov     rdx, 0              # automatic
  syscall

  cmp     rax, 0              # check return value from socket()
  jl      die                 # if return is negative then error

  mov     rdi, rax            # store the socket fd in rdi for rest of function

  sub     rsp, 112            # store struct sockaddr_un on the stack

  mov     WORD PTR [rsp], AF_UNIX      # set sockaddr_un.sun_family to AF_UNIX
  lea     rsi, sun_path       # fill sockaddr_un.sun_path with "/tmp/.X11-unix/X0"
  mov     r12, rdi            # save socket fd for now
  lea     rdi, [rsp + 2]      # set the destination to put in the sun_path
  cld                         # move forward
  mov     ecx, 19             # length to print with null terminator
  rep     movsb               # copy the text

  mov     rax, SYSCALL_CONNECT
  mov     rdi, r12
  lea     rsi, [rsp]
  mov     rdx, 2 + 108        # size of sockaddr_un
  syscall

  cmp     rax, 0
  jne     die

  mov     rax, rdi            # return socket fd

  add     rsp, 112

  # function epilogue
  pop     rbp                 # pop from stack into base pointer
  ret

.type x11_send_handshake, @function
# Send handshake to the X11 server and read the returned system information
# @params rdi The socket file descriptor
# @returns The window root id (uint32_t) in rax
x11_send_handshake:
  push    rbp
  mov     rbp, rsp

  mov     BYTE PTR [read_buf + 0], 'l' # set order to 'l' for little-endian
  mov     BYTE PTR [read_buf + 1], 0
  mov     WORD PTR [read_buf + 2], 11  # set major version to 11 for X11
  mov     WORD PTR [read_buf + 4], 0   # set minor version to 0
                # authentication that didnt work
                # mov     WORD PTR [read_buf + 6], 18  # auth protocol name length (MIT-MAGIC-COOKIE-1)
                # mov     WORD PTR [read_buf + 8], 16  # auth data length (cookie is 16 bytes)
                # copy "MIT-MAGIC-COOKIE-1" at read_buf+10 (18 bytes)
                # lea     rsi, auth_protocol_name      # fill
                # mov     r12, rdi                     # save socket fd for now
                # lea     rdi, [read_buf + 10]         # set the destination to put in the auth protocol name
                # cld
                # mov     ecx, 18                      # length to print with null terminator
                # rep     movsb                        # copy the text

                # read the 16-byte cookie from ~/.Xauthority or /run/user/1000/xauth_kiSfxG in my case
                # read ~/.Xauthority first 60 bytes if not present then check /run/user/1000/xauth_kiSfxG
                # try first cookie path
                # lea     rdi, xauth_path
                # call    read_xauth_cookie
                # cmp     rax, 0
                # jg      .got_cookie

                # fallback cookie path
                # lea     rdi, xauth_path_2
                # call    read_xauth_cookie
                # cmp     rax, 0
                # jle     die                          # if both paths dont work just die

              # .got_cookie:
                # copy cookie from rax into read_buf+30
                # mov     rsi, rax
                # lea     rdi, [read_buf + 28]
                # mov     ecx, 16
                # rep     movsb

  # send handshake to server: write(2)
  # socket fd stored in r12
  mov     rax, SYSCALL_WRITE
                # mov     rdi, r12
  lea     rsi, read_buf
  mov     rdx, 12
  syscall

  cmp     rax, 12                       # check that all 12 bytes were written
  jnz     die

  # read server response: read(2)
  # reading into the read_buf which is 64 KB
  # X11 server replies with 8 bytes and then the bigger message
  mov     rax, SYSCALL_READ
  lea     rsi, read_buf
  mov     rdx, 8
  syscall

  cmp     rax, 8
  jnz     die

  lea     rsi, read_buf
  cmp     BYTE PTR [rsi], 1       # check that first byte is 1 (success)
  jnz     die

  mov     rax, SYSCALL_READ
  lea     rsi, read_buf
  mov     rdx, 65536
  syscall

  cmp     rax, 0
  jle     die

  mov     rbx, rax                # store read length for checks

  # set id_base globally
  cmp     rbx, 4 + 4              # check that offset + size is available for reading
  jb      die

  mov     edx, DWORD PTR [rsi + 4]
  mov     DWORD PTR [id_base], edx

  # set id_mask globally
  cmp     rbx, 8 + 4
  jb      die

  mov     edx, DWORD PTR [rsi + 8]
  mov     DWORD PTR [id_mask], edx

  # read info needed, skip over the rest
  lea     rdi, [rsi]

  cmp     rbx, 16 + 4
  jb      die

  mov     cx, WORD PTR [rsi + 16]# vendor length (v)
  movzx   rcx, cx

  cmp     rbx, 21 + 1
  jb      die

  mov     al, BYTE PTR [rsi + 21] # number of formats (n)
  movzx   rax, al                 # fill with zeroes
  imul    rax, 8                  # sizeof(format) = 8

  add     rdi, 32                 # skip over connection setup
  add     rdi, rcx                # skip over vendor information

  # skip over padding
  add     rdi, 3
  and     rdi, -4

  add     rdi, rax                # skip over format information (n*8)

  lea     rdx, [rsi + rbx]        # calculate end of buffer
  cmp     rdi, rdx
  jae     die                     # if rdi >= end -> die

  lea     rcx, [rdi + 32]         # check that root_visual_id is there
  cmp     rcx, rdx
  ja      die

  mov     eax, DWORD PTR [rdi]    # store and return window root id

  mov     edx, DWORD PTR [rdi + 32]
  mov     DWORD PTR [root_visual_id], edx

  pop     rbp
  ret

.type x11_next_id, @function
# Increment global id.
# Need to generate new id to send to server when creating a new resource
# @return eax new id
x11_next_id:
  push    rbp
  mov     rbp, rsp

  mov     eax, DWORD PTR [id]         # load global id

  mov     edi, DWORD PTR [id_base]    # load global id_base
  mov     edx, DWORD PTR [id_mask]    # load global id_mask

  # return id_mask & (id) | id_basee
  and     eax, edx
  or      eax, edi

  add     DWORD PTR [id], 1           # increment id

  pop     rbp
  ret

.type x11_open_font, @function
# Open the font on the server side.
# @param rdi The socket fd
# @param esi The font id.
x11_open_font:
  push    rbp
  mov     rbp, rsp

  .set OPEN_FONT_NAME_BYTE_COUNT, 5
  .set OPEN_FONT_PADDING, ((4 - (OPEN_FONT_NAME_BYTE_COUNT % 4)) % 4)
  .set OPEN_FONT_PACKET_U32_COUNT, (3 + (OPEN_FONT_NAME_BYTE_COUNT + OPEN_FONT_PADDING) / 4)
  .set X11_OP_REQ_OPEN_FONT, 0x2d

  sub     rsp, 6*8
  mov     DWORD PTR [rsp + 0*4], X11_OP_REQ_OPEN_FONT | (OPEN_FONT_NAME_BYTE_COUNT << 16)
  mov     DWORD PTR [rsp + 1*4], esi
  mov     DWORD PTR [rsp + 2*4], OPEN_FONT_NAME_BYTE_COUNT
  mov     BYTE PTR [rsp + 3*4 + 0], 'f'
  mov     BYTE PTR [rsp + 3*4 + 1], 'i'
  mov     BYTE PTR [rsp + 3*4 + 2], 'x'
  mov     BYTE PTR [rsp + 3*4 + 3], 'e'
  mov     BYTE PTR [rsp + 3*4 + 4], 'd'

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, OPEN_FONT_PACKET_U32_COUNT * 4
  syscall

  cmp     rax, OPEN_FONT_PACKET_U32_COUNT * 4
  jnz     die

  add     rsp, 6*8

  pop     rbp
  ret

.type x11_create_gc, @function
# Create a X11 graphical context
# @param rdi The socket file descriptor
# @param esi The graphical context id
# @param edx The window root id
# @param ecx The font id
x11_create_gc:
  push    rbp
  mov     rbp, rsp

  sub     rsp, 8*8

  .set X11_OP_REQ_CREATE_GC, 0x37
  .set X11_FLAG_GC_BG, 0x00000004
  .set X11_FLAG_GC_FG, 0x00000008
  .set X11_FLAG_GC_FONT, 0x00004000
  .set X11_FLAG_GC_EXPOSE, 0x00010000

  .set CREATE_GC_FLAGS, X11_FLAG_GC_BG | X11_FLAG_GC_FG | X11_FLAG_GC_FONT
  .set CREATE_GC_PACKET_FLAG_COUNT, 3
  .set CREATE_GC_PACKET_U32_COUNT, (4 + CREATE_GC_PACKET_FLAG_COUNT)
  .set MY_COLOR_RGB, 0x0000ffff

  mov     DWORD PTR [rsp + 0*4], X11_OP_REQ_CREATE_GC | (CREATE_GC_PACKET_U32_COUNT << 16)
  mov     DWORD PTR [rsp + 1*4], esi
  mov     DWORD PTR [rsp + 2*4], edx
  mov     DWORD PTR [rsp + 3*4], CREATE_GC_FLAGS
  mov     DWORD PTR [rsp + 4*4], MY_COLOR_RGB
  mov     DWORD PTR [rsp + 5*4], 0
  mov     DWORD PTR [rsp + 6*4], ecx

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, CREATE_GC_PACKET_U32_COUNT * 4
  syscall

  cmp     rax, CREATE_GC_PACKET_U32_COUNT * 4
  jnz     die

  add     rsp, 8*8

  pop     rbp
  ret

.type x11_create_window, @function
# Create the X11 window
# @param rdi The socket file descriptor
# @param esi The new window id
# @param edx The window root id
# @param ecx The root visual id
# @param r8d Packed x and y
# @param r9d Packed w and h
x11_create_window:
  push    rbp
  mov     rbp, rsp

  .set X11_OP_REQ_CREATE_WINDOW, 0x01
  .set X11_FLAG_WIN_BG_COLOR, 0x00000002
  .set X11_EVENT_FLAG_KEY_RELEASE, 0x0002
  .set X11_EVENT_FLAG_EXPOSURE, 0x8000
  .set X11_FLAG_WIN_EVENT, 0x00000800

  .set CREATE_WINDOW_FLAG_COUNT, 2
  .set CREATE_WINDOW_PACKET_U32_COUNT, (8 + CREATE_WINDOW_FLAG_COUNT)
  .set CREATE_WINDOW_BORDER, 1
  .set CREATE_WINDOW_GROUP, 1

  sub     rsp, 12*8

  mov     DWORD PTR [rsp + 0*4], X11_OP_REQ_CREATE_WINDOW | (CREATE_WINDOW_PACKET_U32_COUNT << 16)
  mov     DWORD PTR [rsp + 1*4], esi
  mov     DWORD PTR [rsp + 2*4], edx
  mov     DWORD PTR [rsp + 3*4], r8d
  mov     DWORD PTR [rsp + 4*4], r9d
  mov     DWORD PTR [rsp + 5*4], CREATE_WINDOW_GROUP | (CREATE_WINDOW_BORDER << 16)
  mov     DWORD PTR [rsp + 6*4], ecx
  mov     DWORD PTR [rsp + 7*4], X11_FLAG_WIN_BG_COLOR | X11_FLAG_WIN_EVENT
  mov     DWORD PTR [rsp + 8*4], 0
  mov     DWORD PTR [rsp + 9*4], X11_EVENT_FLAG_KEY_RELEASE | X11_EVENT_FLAG_EXPOSURE

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, CREATE_WINDOW_PACKET_U32_COUNT * 4
  syscall

  cmp     rax, CREATE_WINDOW_PACKET_U32_COUNT * 4
  jnz     die

  add     rsp, 12*8

  pop     rbp
  ret

.type x11_map_window, @function
# Map a X11 window
# @param rdi The socket file descriptor
# @param esi The window id
x11_map_window:
  push    rbp
  mov     rbp, rsp

  sub     rsp, 16

  .set X11_OP_REQ_MAP_WINDOW, 0x08
  mov     DWORD PTR [rsp + 0*4], X11_OP_REQ_MAP_WINDOW | (2<<16)
  mov     DWORD PTR [rsp + 1*4], esi

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, 2*4
  syscall

  cmp     rax, 2*4
  jnz     die

  add     rsp, 16

  pop     rbp
  ret
