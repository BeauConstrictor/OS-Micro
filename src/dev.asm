  .ifndef DEV_ASM
DEV_ASM = 1

; return in hl a pointer to a string with the name of the device type
; given in a
; clobbers: TODO
get_devtype:
  ld   a,(DEV_STATUS)
  and  DEV_ID
  cp   NODEV
  jr   z,.nodev
  cp   SECTD
  jr   z,.sectd
  cp   XMEM
  jr   z,.xmem
  ld   hl,devtype_unknown
  ret
.nodev:
  ld   hl,devtype_nodev
  ret
.sectd:
  ld   hl,devtype_sectd
  ret
.xmem:
  ld   hl,devtype_xmem
  ret

devtype_nodev:
  .asciiz "No Device"
devtype_sectd:
  .asciiz "Sectored Storage"
devtype_xmem:
  .asciiz "Extended Memory"
devtype_unknown:
  .asciiz "Unknown Device"
; TODO in the future, maybe load the manufacturers device name here
; instead of a generic name:
devtype_custom:
  .asciiz "Custom Device"

  .include "mmap.asm"

  .endif ; DEV_ASM
