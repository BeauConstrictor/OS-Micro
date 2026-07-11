  .ifndef MMAP_ASM
MMAP_ASM = 1

DELETE = 127

SERIAL = 0

DEV_READ    = $c000 ; (sector memory mapped)
DEV_SELECT  = $c100
DEV_SECTOR  = $c101
DEV_STATUS  = $c102

BIOS        = $e000
KERNEL      = $0100

BUSY        = %00000010
DEV_ID      = %11110000

NODEV       = $00
SECTD       = $10
XMEM        = $20
CUSTOM      = $f0

RUN_LOAD    = $2000
STACK_START = $bfff

  .endif ; MMAP_ASM
