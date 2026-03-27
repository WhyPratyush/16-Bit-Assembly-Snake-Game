# Makefile for Snake OS

ASM = nasm
EMU = qemu-system-x86_64

all: run

build:
	$(ASM) -f bin snake.asm -o snake.bin

run: build
	$(EMU) -drive format=raw,file=snake.bin

clean:
	rm -f *.bin