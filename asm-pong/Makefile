AS := as
AFLAGS := -g --fatal-warnings

LD := ld
LFLAGS := -static -e _start

# source files
SRCS := pong.s x11_utils.s helper.s

# object files
OBJS := $(SRCS:.s=.o)

# executable
EXEC := pong

all: $(EXEC)

$(EXEC): $(OBJS)
	$(LD) $(LFLAGS) $^ -o $@

%.o: %.s
	$(AS) $(AFLAGS) -o $@ $<

clean:
	rm -f $(EXEC) $(OBJS)
