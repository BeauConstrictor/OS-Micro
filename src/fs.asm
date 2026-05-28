  .ifndef FS_ASM
FS_ASM = 1


; load the file starting at the sector in the a register into memory,
; starting at hl
; clobbers: a,de,hl
fload:
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   b,$ff
  ld   de,DEV_READ
.loop:
  ld   a,(de)
  ld   (hl),a
  inc  hl
  inc  de
  djnz .loop
  ld   a,(de)
  or   a
  jr   nz,fload
  ; jp   RUN_LOAD
  ret


  .endif ; FS_ASM
