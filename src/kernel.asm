  .org $0100

start:
  ld   sp,STACK_START
  ld   a,$02 ; root directory
  ld   (cwd),a
  jp   welcome

  .include "io.asm"
  .include "fs.asm"
  .include "dev.asm"
  .include "mmap.asm"
  .include "shell.asm"
