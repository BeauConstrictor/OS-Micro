  .org $0100

start:
  ld   sp,$bfff
  jp   shell

  .include "io.asm"
  .include "mmap.asm"
  .include "shell.asm"
  .include "uninitialised.asm"
