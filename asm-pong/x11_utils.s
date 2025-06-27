.intel_syntax noprefix
.globl x11_connect_to_server, x11_send_handshake, x11_next_id, x11_open_font, x11_create_gc, x11_query_extension_randr, x11_rrgetmonitors, x11_create_window, x11_map_window, poll_messages

.extern id, id_base, id_mask, root_visual_id

.set SYSCALL_READ, 0
.set SYSCALL_WRITE, 1
.set SYSCALL_POLL, 7
.set SYSCALL_NANOSLEEP, 35
.set SYSCALL_SOCKET, 41
.set SYSCALL_CONNECT, 42
.set SYSCALL_CLOCK_GETTIME, 228

.set AF_UNIX, 1               # Unix domain socket
.set SOCK_STREAM, 1           # Stream-oriented socket

.set BALL_RADIUS, 20

.section .data
left_score:
  .quad 0
right_score:
  .quad 0
score_buf:
  .space 21
digits:
  .asciz "0123456789"

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
start_time:
  .skip 16
end_time:
  .skip 16
sleep_time:
  .skip 16

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

  cmp   rax, 0              # check return value from socket()
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

  mov     cx, WORD PTR [rsi + 16] # vendor length (v)
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

.type x11_query_extension_randr, @function
# Query extension for RANDR opcode
# @param rdi The socket file descriptor
# @returns rax The extension opcode for RANDR
x11_query_extension_randr:
  push    rbp
  mov     rbp, rsp

  .set X11_OP_REQ_QUERY_EXTENSION, 0x62
  .set CREATE_QUERY_EXTENSION_PACKET_U32_COUNT, 4

  sub     rsp, 2*8

  mov     BYTE PTR [rsp + 0], X11_OP_REQ_QUERY_EXTENSION
  mov     BYTE PTR [rsp + 1], 0
  mov     WORD PTR [rsp + 2], CREATE_QUERY_EXTENSION_PACKET_U32_COUNT
  mov     WORD PTR [rsp + 4], 5
  mov     WORD PTR [rsp + 6], 0
  mov     BYTE PTR [rsp + 8], 'R'
  mov     BYTE PTR [rsp + 9], 'A'
  mov     BYTE PTR [rsp + 10], 'N'
  mov     BYTE PTR [rsp + 11], 'D'
  mov     BYTE PTR [rsp + 12], 'R'
  mov     BYTE PTR [rsp + 13], 0
  mov     BYTE PTR [rsp + 14], 0
  mov     BYTE PTR [rsp + 15], 0

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, CREATE_QUERY_EXTENSION_PACKET_U32_COUNT * 4
  syscall

  cmp     rax, CREATE_QUERY_EXTENSION_PACKET_U32_COUNT * 4
  jnz     die

  mov     rax, SYSCALL_READ
  lea     rsi, [read_buf]
  mov     rdx, 32
  syscall

  cmp     rax, 32
  jnz     die

  cmp     BYTE PTR [read_buf + 8], 1      # check if the extension is present
  jz      .randr_present

  # If extension not present, set rax 0
  mov     rax, 0
  jmp     .end

  .randr_present:
  # get the major-opcode
  mov     al, BYTE PTR [read_buf + 9]
  movzx   rax, al                         # fill with zeroes

  .end:
  add     rsp, 2*8

  pop     rbp
  ret

.type x11_rrgetmonitors, @function
# Request for the monitor layout
# @param rdi The socket file descriptor
# @param rax RANDR extension opcode from QueryExtension
# @param esi Root window id
x11_rrgetmonitors:
  push    rbp
  mov     rbp, rsp

  .set X11_OP_REQ_RRGETMONITORS, 0x2A
  .set CREATE_RRGETMONITORS_PACKET_U32_COUNT, 3

  sub     rsp, 2*8

  mov     BYTE PTR [rsp], al
  mov     BYTE PTR [rsp + 1], X11_OP_REQ_RRGETMONITORS
  mov     WORD PTR [rsp + 2], CREATE_RRGETMONITORS_PACKET_U32_COUNT
  mov     DWORD PTR [rsp + 4], esi
  mov     BYTE PTR [rsp + 8], 1
  mov     BYTE PTR [rsp + 9], 0
  mov     BYTE PTR [rsp + 10], 0
  mov     BYTE PTR [rsp + 11], 0

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, CREATE_RRGETMONITORS_PACKET_U32_COUNT * 4
  syscall

  cmp     rax, CREATE_RRGETMONITORS_PACKET_U32_COUNT * 4
  jnz     die

  mov     rax, SYSCALL_READ
  lea     rsi, [read_buf]
  mov     rdx, 32 + 40                        # 32 for header + 40 for first Window
  syscall

  cmp     rax, 32 + 40
  jnz     die

  cmp     BYTE PTR [read_buf], 1              # check for success
  jnz     die

  mov     dx, WORD PTR [read_buf + 32 + 12]   # magic numbers derived from gdbing
  mov     WORD PTR [WINDOW_W], dx

  mov     dx, WORD PTR [read_buf + 32 + 14]   # and finding my screen size in the bytes
  mov     WORD PTR [WINDOW_H], dx

  add     rsp, 2*8

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
  .set X11_EVENT_FLAG_KEY_PRESS, 0x0001
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
  mov     DWORD PTR [rsp + 9*4], X11_EVENT_FLAG_KEY_PRESS | X11_EVENT_FLAG_EXPOSURE

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

.type x11_read_reply, @function
# Read the X11 server reply
# @return The message code in al
x11_read_reply:
  push    rbp
  mov     rbp, rsp

  # read 32 bytes into read_buf
  # all messages are 32 bytes
  mov     rax, SYSCALL_READ
  lea     rsi, [read_buf]
  mov     rdx, 32
  syscall

  cmp     rax, 1
  jle     die

  mov     al, BYTE PTR [read_buf]

  pop     rbp
  ret

.type poll_messages, @function
# Poll messages from the X11 server with poll(2)
# @param rdi The socket file descriptor
# @param esi The window id
# @param edx The gc id
poll_messages:
  push    rbp
  mov     rbp, rsp

  sub     rsp, 32

  .set POLLIN, 0x001
  .set POLLPRI, 0x002
  .set POLLOUT, 0x004
  .set POLLERR, 0x008
  .set POLLHUP, 0x010
  .set POLLNVAL, 0x020

  .set X11_EVENT_KEYPRESS, 0x2
  .set X11_EVENT_EXPOSURE, 0xc

  # KEYSYMs from the documentation that are wrong
  # .set KEYSYM_Q, 0x0071
  # .set KEYSYM_S, 0x0073
  # .set KEYSYM_W, 0x0077
  # .set KEYSYM_ESC, 0xff1b
  # .set KEYSYM_UP, 0xff52
  # .set KEYSYM_DOWN, 0xff54

  .set KEYSYM_Q, 0x18
  .set KEYSYM_S, 0x27
  .set KEYSYM_W, 0x19
  .set KEYSYM_ESC, 0x09
  .set KEYSYM_UP, 0x6f
  .set KEYSYM_DOWN, 0x74

  .set NO_PADDLE_MOVEMENT, 0x00
  .set LEFT_PADDLE_UP, 0x01
  .set LEFT_PADDLE_DOWN, 0x02
  .set RIGHT_PADDLE_UP, 0x04
  .set RIGHT_PADDLE_DOWN, 0x08

  .set CLOCK_MONOTONIC, 1

  mov     DWORD PTR [rsp + 0*4], edi
  mov     DWORD PTR [rsp + 1*4], POLLIN

  mov     DWORD PTR [rsp + 16], esi         # window id
  mov     DWORD PTR [rsp + 20], edx         # gc id
  mov     BYTE PTR [rsp + 24], 0            # exposed? (bool)

  .loop:
    mov   rdi, 1
    lea   rsi, [rip + start_time]
    mov   eax, SYSCALL_CLOCK_GETTIME
    syscall

    mov   rax, SYSCALL_POLL
    lea   rdi, [rsp]                        # struct pollfd *fds
    mov   rsi, 1                            # nfds_t nfds
    mov   rdx, 16                           # int timeout, 16 ms ~60 FPS
    syscall

    cmp   rax, 0
    je    .display
    jl    die

    # polling error
    cmp   DWORD PTR [rsp + 2*4], POLLERR
    je    die

    # other side has closed
    cmp   DWORD PTR [rsp + 2*4], POLLHUP
    je    die

    mov   rdi, [rsp + 0*4]
    call  x11_read_reply

    cmp   eax, X11_EVENT_EXPOSURE
    jz    .received_exposed_event

    cmp   eax, X11_EVENT_KEYPRESS
    jz    .received_keypress_event

    jnz   .received_other_event

    .received_exposed_event:

    mov   BYTE PTR [rsp + 24], 1            # Mark as exposed

    jmp   .display

    .received_keypress_event:

    mov   al, BYTE PTR [read_buf + 1]       # Get the keycode

    movzx ecx, al

    call  print_keypress

    mov   eax, ecx

    # q or esc quit
    cmp   eax, KEYSYM_Q
    jz   .quit

    cmp   eax, KEYSYM_ESC
    jz   .quit

    # w and s control left paddle
    cmp   eax, KEYSYM_W
    jnz   .not_left_up

    # move LEFT_PADDLE_Y up

    mov   r8, LEFT_PADDLE_UP

    movzx ax, WORD PTR [LEFT_PADDLE_Y]
    cmp   ax, 20
    jl    .display
    sub   ax, 20
    mov   WORD PTR [LEFT_PADDLE_Y], ax
    jmp   .display

    .not_left_up:
    cmp   eax, KEYSYM_S
    jnz   .not_left_down

    # move LEFT_PADDLE_Y down

    mov   r8, LEFT_PADDLE_DOWN

    movzx ax, WORD PTR [LEFT_PADDLE_Y]
    movzx si, WORD PTR [PADDLE_H]
    add   ax, si
    movzx si, WORD PTR [WINDOW_H]
    sub   si, 20
    cmp   ax, si
    jg    .display
    movzx ax, WORD PTR [LEFT_PADDLE_Y]
    add   ax, 20
    mov   WORD PTR [LEFT_PADDLE_Y], ax
    jmp   .display

    # up and down control right paddle
    .not_left_down:
    cmp   eax, KEYSYM_UP
    jnz   .not_right_up

    # move RIGHT_PADDLE_Y up

    mov   r8, RIGHT_PADDLE_UP

    movzx ax, WORD PTR [RIGHT_PADDLE_Y]
    cmp   ax, 20
    jl    .display
    sub   ax, 20
    mov   WORD PTR [RIGHT_PADDLE_Y], ax
    jmp   .display

    .not_right_up:
    cmp   eax, KEYSYM_DOWN
    jnz   .not_right_down                   # no more things to check

    # move RIGHT_PADDLE_Y down

    mov   r8, RIGHT_PADDLE_DOWN

    movzx ax, WORD PTR [RIGHT_PADDLE_Y]
    movzx si, WORD PTR [PADDLE_H]
    add   ax, si
    movzx si, WORD PTR [WINDOW_H]
    sub   si, 20
    cmp   ax, si
    jg    .display
    movzx ax, WORD PTR [RIGHT_PADDLE_Y]
    add   ax, 20
    mov   WORD PTR [RIGHT_PADDLE_Y], ax
    jmp   .display

    .not_right_down:

    mov   r8, NO_PADDLE_MOVEMENT

    .received_other_event:

    cmp   BYTE PTR [rsp + 24], 1            # exposed?
    jnz   .sleep

    .display:
    .update_ball:
      movzx ax, WORD PTR [BALL_VELO_X]
      movzx di, WORD PTR [BALL_X]
      add   ax, di
      mov   BALL_X, ax

      movzx ax, WORD PTR [BALL_VELO_Y]
      movzx di, WORD PTR [BALL_Y]
      add   ax, di
      mov   BALL_Y, ax

    .ball_outside:
      movzx ax, WORD PTR [BALL_X]
      cmp   ax, 0
      jle   .inc_right_score
      movzx di, WORD PTR [WINDOW_W]
      sub   di, BALL_RADIUS * 2
      cmp   ax, di
      jle   .clear_window

      .inc_left_score:
      mov   rax, QWORD PTR [left_score]
      inc   rax
      mov   QWORD PTR [left_score], rax

      jmp  .update_ball_position

      .inc_right_score:
      mov   rax, QWORD PTR [right_score]
      inc   rax
      mov   QWORD PTR [right_score], rax

      .update_ball_position:
      movzx ax, WORD PTR [BALL_VELO_X]
      neg   ax
      mov   WORD PTR [BALL_VELO_X], ax

      movzx ax, WORD PTR [BALL_VELO_Y]
      test  ax, ax
      jnz   .velo_y_not_zero
      mov   WORD PTR [BALL_VELO_Y], 4

      .velo_y_not_zero:
      movzx ax, WORD PTR [WINDOW_W]
      mov   di, 2
      xor   dx, dx
      div   di

      sub   ax, BALL_RADIUS
      mov   WORD PTR [BALL_X], ax

    .clear_window:
      mov   rdi, [rsp + 0]
      mov   esi, [rsp + 16]
      call  x11_clear_window

    .draw_paddles:
      mov   rdi, [rsp + 0]                  # socket fd
      mov   esi, [rsp + 16]                 # window id
      mov   edx, [rsp + 20]                 # gc id
      call  x11_draw_paddles

    .draw_ball:
      mov   rdi, [rsp + 0]
      mov   esi, [rsp + 16]
      mov   edx, [rsp + 20]
      call  x11_draw_ball

    .draw_score:
      mov   rax, left_score
      call  fill_score_buf

      mov   r10, rax

      movzx ax, WORD PTR [WINDOW_W]
      mov   di, 2
      xor   dx, dx
      div   di

      mov   rdi, [rsp + 0]
      lea   rsi, [score_buf + 20]
      sub   rsi, r10
      mov   edx, r10d
      mov   ecx, [rsp + 16]
      mov   r8d, [rsp + 20]
      mov   r9d, 100
      shl   r9d, 16
      or    r9d, eax
      mov   r11d, r10d
      .subtract_1:
      sub   r9d, 20
      dec   r11d
      test  r11d, r11d
      jnz   .subtract_1
      call  x11_draw_text

      mov   rax, right_score
      call  fill_score_buf

      mov   r10, rax

      movzx ax, WORD PTR [WINDOW_W]
      mov   di, 2
      xor   dx, dx
      div   di

      mov   rdi, [rsp + 0]
      lea   rsi, [score_buf + 20]
      sub   rsi, r10
      mov   edx, r10d
      mov   ecx, [rsp + 16]
      mov   r8d, [rsp + 20]
      mov   r9d, 100
      shl   r9d, 16
      or    r9d, eax
      add   r9d, 20
      call  x11_draw_text

    # check for collisions and update velocity
    .check_collision:
      mov   rdx, r8
      call  check_collision

    cmp     rax, 0
    je      .no_collision

    .collision:
      call  update_velocity

    .no_collision:
    .sleep:
    mov   rdi, CLOCK_MONOTONIC
    lea   rsi, [rip + end_time]
    mov   eax, SYSCALL_CLOCK_GETTIME
    syscall

    # compute elapsed time in nanoseconds
    mov   rax, QWORD PTR [rip + end_time]
    sub   rax, QWORD PTR [rip + start_time]
    mov   rcx, 1000000000
    mul   rcx
    mov   r8, rax

    mov   rax, QWORD PTR [rip + end_time + 8]
    sub   rax, QWORD PTR [rip + start_time + 8]
    add   r8, rax

    mov   rax, 16000000
    cmp   r8, rax
    jae   .loop

    mov   rax, 16000000
    sub   rax, r8

    xor   rdx, rdx
    mov   rcx, 1000000000
    div   rcx

    mov   QWORD PTR [rip + sleep_time], rax
    mov   QWORD PTR [rip + sleep_time + 8], rdx

    lea   rdi, [rip + sleep_time]
    xor   rsi, rsi
    mov   eax, SYSCALL_NANOSLEEP
    syscall

    jmp .loop

  .quit:
  add     rsp, 32

  pop     rbp
  ret

.type x11_clear_window, @function
# Clears the window using WINDOW_H and WINDOW_W
# @param rdi The socket file descriptor
# @param esi The window id
x11_clear_window:
  push    rbp
  mov     rbp, rsp

  .set X11_OP_REQ_CLEAR_AREA, 0x3d

  sub     rsp, 32

  mov     BYTE PTR [rsp + 0], X11_OP_REQ_CLEAR_AREA
  mov     BYTE PTR [rsp + 1], 0
  mov     WORD PTR [rsp + 2], 4
  mov     DWORD PTR [rsp + 4], esi

  mov     WORD PTR [rsp + 8], 0
  mov     WORD PTR [rsp + 10], 0

  movzx   ax, WORD PTR [WINDOW_W]
  mov     WORD PTR [rsp + 12], ax

  movzx   ax, WORD PTR [WINDOW_H]
  mov     WORD PTR [rsp + 14], ax

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, 16
  syscall

  add     rsp, 32

  pop     rbp
  ret

.type x11_draw_paddles, @function
# Draw the paddles in a X11 window
# @param rdi The socket file descriptor
# @param esi The window id
# @param edx The gc id
x11_draw_paddles:
  push    rbp
  mov     rbp, rsp

  .set  X11_OP_REQ_POLY_FILL_RECTANGLE, 0x46

  sub     rsp, 32

  mov     BYTE PTR [rsp + 0], X11_OP_REQ_POLY_FILL_RECTANGLE
  mov     BYTE PTR [rsp + 1], 0
  mov     WORD PTR [rsp + 2], 3 + 2 * 2   # request length 3+2n, 2 rectangles
  mov     DWORD PTR [rsp + 4], esi
  mov     DWORD PTR [rsp + 8], edx

  # RECTANGLE [x, y: INT16, width, height: CARD16]
  # left paddle
  movzx   ax, WORD PTR [LEFT_PADDLE_X]
  mov     WORD PTR [rsp + 12], ax

  movzx   ax, WORD PTR [LEFT_PADDLE_Y]
  mov     WORD PTR [rsp + 14], ax

  movzx   ax, WORD PTR [PADDLE_W]
  mov     WORD PTR [rsp + 16], ax

  movzx   ax, WORD PTR [PADDLE_H]
  mov     WORD PTR [rsp + 18], ax

  # right paddle
  movzx   ax, WORD PTR [RIGHT_PADDLE_X]
  mov     WORD PTR [rsp + 20], ax

  movzx   ax, WORD PTR [RIGHT_PADDLE_Y]
  mov     WORD PTR [rsp + 22], ax

  movzx   ax, WORD PTR [PADDLE_W]
  mov     WORD PTR [rsp + 24], ax

  movzx   ax, WORD PTR [PADDLE_H]
  mov     WORD PTR [rsp + 26], ax

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, 28
  syscall

  cmp     rax, 28
  jnz     die

  add     rsp, 32

  pop     rbp
  ret

.type x11_draw_ball, @function
# Draw the paddles in a X11 window
# @param rdi The socket file descriptor
# @param esi The window id
# @param edx The gc id
x11_draw_ball:
  push    rbp
  mov     rbp, rsp

  .set X11_OP_REQ_POLY_FILL_ARC, 0x47

  sub     rsp, 32

  mov     BYTE PTR [rsp + 0], X11_OP_REQ_POLY_FILL_ARC
  mov     BYTE PTR [rsp + 1], 0
  mov     WORD PTR [rsp + 2], 3 + 3           # request length 3+3n, 1 arc
  mov     DWORD PTR [rsp + 4], esi
  mov     DWORD PTR [rsp + 8], edx

  # ARC [x, y: INT16, width, height: CARD16, angle1, angle2: INT16]
  movzx   ax, WORD PTR [BALL_X]
  mov     WORD PTR [rsp + 12], ax

  movzx   ax, WORD PTR [BALL_Y]
  mov     WORD PTR [rsp + 14], ax

  mov     WORD PTR [rsp + 16], BALL_RADIUS * 2
  mov     WORD PTR [rsp + 18], BALL_RADIUS * 2

  mov     WORD PTR [rsp + 20], 0 * 64
  mov     WORD PTR [rsp + 22], 360 * 64

  mov     rax, SYSCALL_WRITE
  lea     rsi, [rsp]
  mov     rdx, 24
  syscall

  cmp     rax, 24
  jnz     die

  add     rsp, 32

  pop     rbp
  ret

.type x11_draw_text, @function
# Draw text in a X11 window with server-side text rendering.
# @param rdi The socket file descriptor.
# @param rsi The text string.
# @param edx The text string length in bytes.
# @param ecx The window id.
# @param r8d The gc id.
# @param r9d Packed x and y.
x11_draw_text:
  push    rbp
  mov     rbp, rsp
 
  sub     rsp, 1024

  mov     DWORD PTR [rsp + 1*4], ecx
  mov     DWORD PTR [rsp + 2*4], r8d
  mov     DWORD PTR [rsp + 3*4], r9d

  mov     r8d, edx
  mov     QWORD PTR [rsp + 1024 - 8], rdi

  # Compute padding and packet u32 count with division and modulo 4.
  mov     eax, edx                   # Put dividend in eax.
  mov     ecx, 4                     # Put divisor in ecx.
  cdq                                # Sign extend.
  idiv    ecx                        # Compute eax / ecx, and put the remainder (i.e. modulo) in edx.
  # LLVM optimizer magic: `(4-x)%4 == -x & 3`, for some reason.
  neg     edx
  and     edx, 3
  mov     r9d, edx                   # Store padding in r9.

  mov     eax, r8d 
  add     eax, r9d
  shr     eax, 2                     # Compute: eax /= 4
  add     eax, 4                     # eax now contains the packet u32 count.

  .set X11_OP_REQ_IMAGE_TEXT8, 0x4c
  mov     DWORD PTR [rsp + 0*4], r8d
  shl     DWORD PTR [rsp + 0*4], 8
  or      DWORD PTR [rsp + 0*4], X11_OP_REQ_IMAGE_TEXT8
  mov     ecx, eax
  shl     ecx, 16
  or      [rsp + 0*4], ecx

  # Copy the text string into the packet data on the stack.
  mov     rsi, rsi                   # Source string in rsi.
  lea     rdi, [rsp + 4*4]           # Destination
  cld                                # Move forward
  mov     ecx, r8d                   # String length.
  rep     movsb                      # Copy.

  mov     rdx, rax                   # packet u32 count
  imul    rdx, 4
  mov     rax, SYSCALL_WRITE
  mov     rdi, QWORD PTR [rsp + 1024 - 8]
  lea     rsi, [rsp]
  syscall

  cmp     rax, rdx
  jnz     die

  add     rsp, 1024

  pop     rbp
  ret

.type fill_score_buf, @function
# Fills the score_buf with the score as a string
# @param rax The score
# @return rax Length of string
fill_score_buf:
  push    rbp
  mov     rbp, rsp

  lea     rdi, [score_buf + 20]
  mov     rcx, 10
  mov     rbx, rcx
  mov     r8, 0

  convert_loop:
    inc   r8
    xor   rdx, rdx
    div   rbx
    dec   rdi
    movzx rcx, BYTE PTR [digits + rdx]
    mov   [rdi], cl
    test  rax, rax
    jnz   convert_loop

  mov     rax, r8

  pop     rbp
  ret
