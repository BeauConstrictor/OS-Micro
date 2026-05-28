  .org $0100

start:
  ld   sp,$bfff
  jr   shell

  .include "io.asm"
  .include "mmap.asm"
  .include "shell.asm"
  .include "uninitialised.asm"
