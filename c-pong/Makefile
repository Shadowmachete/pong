CC := gcc
CFLAGS := `sdl2-config --libs --cflags` -ggdb3 -O0 --std=c99 -lSDL2_ttf -lm -g -Wall -pedantic -Werror -Wextra
# headers
HDRS :=

# source files
SRCS := pong.c

# object files
OBJS := $(SRCS:.c=.o)

# executable
EXEC := pong

all: $(EXEC)

$(EXEC): $(OBJS) $(HDRS) Makefile
	$(CC) -o $@ $(OBJS) $(CFLAGS)

# pong: pong.c
# 	$(CC) $(CFLAGS) -o pong pong.c

clean:
	rm -f $(EXEC) $(OBJS)
