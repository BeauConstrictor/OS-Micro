  .org $0100

start:
  ld   sp,STACK_START
  jp   shell

  .include "io.asm"
  .include "fs.asm"
  .include "mmap.asm"
  .include "shell.asm"
  .include "uninitialised.asm"
