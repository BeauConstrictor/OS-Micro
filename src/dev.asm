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

; find a device with the id in a. sets carry if no device was found
; leaves the found device selected, and returns in a
; clobbers: a,b, device
dev_find:
  ld   b,a
  ld   a,0
  ld   (DEV_SELECT),a
.loop:
  call busy_wait
  ld   a,(DEV_STATUS)
  and  DEV_ID
  cp   NODEV
  jr   z,.nodev
  cp   b
  jr   z,.found
.nodev
  ld   a,(DEV_SELECT)
  inc  a
  ld   (DEV_SELECT),a
  jr   nz,.loop
  call busy_wait
  scf
  ret
.found:
  xor  a
  ld   a,(DEV_SELECT)
  ret

; wait until the device busy flag is 0
; clobbers: a
busy_wait:
  ld   a,(DEV_STATUS)
  and  BUSY
  jr   nz,busy_wait
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
