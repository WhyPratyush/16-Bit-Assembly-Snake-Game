# 16-bit Assembly Snake

A classic Snake game written entirely in x86 assembly that fits completely within a 512-byte boot sector. It runs in 16-bit real mode using VGA Mode 13h (320x200, 256 colors) and does not require an operating system to run.

## Prerequisites & Installation
To compile and run this game, you need the Netwide Assembler (`nasm`) and an emulator like `qemu`. 

**Debian / Ubuntu:**
\`\`\`bash
sudo apt update
sudo apt install nasm qemu-system-x86
\`\`\`

**macOS (using Homebrew):**
\`\`\`bash
brew install nasm qemu
\`\`\`

**Arch Linux:**
\`\`\`bash
sudo pacman -S nasm qemu-desktop
\`\`\`

## How to Play

### Build and Run
If you have `make` installed, you can build and run the game in one step:
\`\`\`bash
make run
\`\`\`

Alternatively, you can run the commands manually:
\`\`\`bash
nasm -f bin snake.asm -o snake.bin
qemu-system-x86_64 -drive format=raw,file=snake.bin
\`\`\`

### Controls
* **W** - Up
* **S** - Down
* **A** - Left
* **D** - Right

> **Important:** Ensure **Caps Lock is OFF** while playing. The game specifically listens for lowercase ASCII characters for movement.

## Customizing the Game

### Changing the Speed
If you find the game too fast or too slow, you can adjust the delay loop in `snake.asm`. 

Look for this line under the `game_loop` label (around line 72):
\`\`\`nasm
    mov dx, 1250  ; Controls the delay between frames
\`\`\`
* **To make it slower:** Increase the number (e.g., `mov dx, 2000`).
* **To make it faster:** Decrease the number (e.g., `mov dx, 800`).
Recompile the code using `make run` after saving your changes.