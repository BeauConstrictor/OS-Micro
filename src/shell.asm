  .ifndef SHELL_ASM
SHELL_ASM = 1

shell:
  ld   hl,welcome_msg
  call print
.loop:
  ld   hl,prompt
  call print
  call buffer_l
  call exec_cmd
  jr   .loop

exec_cmd:
  call get_char
  ld   c,a
  call get_char
  ld   d,a
  call get_char
  ld   e,a
  ld   hl,cmd_table
.check_match:
  push hl
  ld   a,c
  cp   (hl)
  jr   nz,.next_cmd
  inc  hl
  ld   a,d
  cp   (hl)
  jr   nz,.next_cmd
  inc  hl
  ld   a,e
  cp   (hl)
  jr   nz,.next_cmd
  ; dispatch the command
  pop  hl
  ld   de,3
  add  hl,de
  ld e, (hl)
  inc hl
  ld d, (hl)
  ld h,d
  ld l,e
  jp   (hl)
.next_cmd:
  pop hl
  push de
  ld   de,5
  add  hl,de
  pop  de
  ld   a,(hl)
  cp   0
  jr   z,.notfound
  jr   .check_match
.notfound:
  ld   a,c
  out  (SERIAL),a
  ld   a,d
  out  (SERIAL),a
  ld   a,e
  out  (SERIAL),a
  ld   a,'?'
  out  (SERIAL),a
  ld   a,'\n'
  out  (SERIAL),a
  ret

cmd_dir:
  ld   a,$02
  ld   (DEV_SECTOR),a
  ; call busy_wait
  ld   b,16
  ld   hl,DEV_READ
.loop:
  ld   a,(hl)
  cp   0
  jr   z,.unoccupied
  cp   '_' ; hidden files start with '_'
  jr   z,.unoccupied
  call print
  ld   a,'\n'
  out  (SERIAL),a
.unoccupied:
  ld   de,16
  add  hl,de
  djnz .loop
  ret

cmd_off:
  halt

cmd_sys:
  jp   BIOS

cmd_table:
  .byte  "dir"
  .word  cmd_dir
  .byte  "off"
  .word  cmd_off
  .byte  "sys"
  .word  cmd_sys
  .byte  0

welcome_msg:
  .asciiz "OS/M Version 0.0.0\n\n"
prompt:
  .asciiz "> "

  .endif ; SHELL_ASM

  .include "mmap.asm"

