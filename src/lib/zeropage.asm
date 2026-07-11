; a shared library that defines everything in memory that is shared between the kernel and running program.

  .ifndef ZEROPAGE_ASM
ZEROPAGE_ASM = 1

parse   = $0000
cwd     = $0002
linebuf = $0003

  .endif ; ZEROPAGE_ASM
