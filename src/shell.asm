  .ifndef SHELL_ASM
SHELL_ASM = 1

shell:
  ld   hl,welcome_msg
  call print
shell_cmdloop:
  call shell_prompt
  call buffer_l
  ld   hl,final_prompt
  call print
  call exec_cmd
  jr   shell_cmdloop

shell_prompt:
  ld   hl,pre_prompt
  call print
  ld   a,(DEV_SELECT)
  call hex_out
  ld   hl,post_prompt
  call print
  ret

; execute the command in the input buffer
; clobbers: assume all
exec_cmd:
  call get_char
  cp   0
  ret  z
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
  cp   '\0'
  jr   z,.endofcmd
  out  (SERIAL),a
  ld   a,d
  cp   '\0'
  jr   z,.endofcmd
  out  (SERIAL),a
  ld   a,e
  cp   '\0'
  jr   z,.endofcmd
  out  (SERIAL),a
.endofcmd:
  ld   a,'?'
  out  (SERIAL),a
  ld   a,'\n'
  out  (SERIAL),a
  ret

; list files and their first sectors
cmd_dir:
  ld   a,$02
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   b,16
  ld   hl,DEV_READ
.loop:
  ld   a,(hl)
  cp   0
  jr   z,.unoccupied
  cp   '_' ; hidden files start with '_'
  jr   z,.unoccupied
  push hl
  ld   de,15
  add  hl,de
  ld   a,(hl)
  call hex_out
  ld   hl,dir_separator
  call print
  pop  hl
  push hl
  call print
  pop  hl
  ld   a,'\n'
  out  (SERIAL),a
.unoccupied:
  ld   de,16
  add  hl,de
  djnz .loop
  ret

; output the contents of a file as text
cmd_txt:
  call hex_in
.chsect:
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   b,$ff
  ld   de,DEV_READ
.loop:
  ld   a,(de)
  cp   0
  jr   z,.nullbyte
  out  (SERIAL),a
.nullbyte:
  inc  hl
  inc  de
  djnz .loop
  ld   a,(de)
  or   a
  jr   nz,.chsect
  ret

; return if a is printable in the carry flag
is_printable:
    cp  $20
    jr  c,.no
    cp  $7f
    jr  nc,.no
    scf
    ret
.no:
    or  a
    ret

; shutdown the machine
cmd_off:
  halt

; enter the firmware
cmd_sys:
  jp   BIOS

; clear the screen
cmd_cls:
  ld   hl,clear_scr
  call print
  ret

; change the active device
cmd_dsk:
  call hex_in
  ld   (DEV_SELECT),a
  call busy_wait
  ret

; show help text
cmd_hlp:
  ld   hl,help_txt
  call print
  ret

; run a program
cmd_run:
  call hex_in
  ld   hl,RUN_LOAD
  call fload
  jp   RUN_LOAD
  ; ret

cmd_table:
  .byte  "dir"
  .word  cmd_dir
  .byte  "txt"
  .word  cmd_txt
  .byte  "off"
  .word  cmd_off
  .byte  "sys"
  .word  cmd_sys
  .byte  "cls"
  .word  cmd_cls
  .byte  "dsk"
  .word  cmd_dsk
  .byte  "hlp"
  .word  cmd_hlp
  .byte  "run"
  .word  cmd_run
  .byte  0

help_txt:
  .binary "help.txt"
  .byte 0

welcome_msg:
  .text   "\e[35mWelcome to OS/M Version 0.0.0!\n"
  .asciiz "\e[90mType 'hlp' for help.\e[0m\n\n"
pre_prompt:
  .asciiz "\e[36m"
post_prompt:
  .asciiz "\e[90m ~> \e[32m"
final_prompt:
  .asciiz "\e[0m"
dir_separator:
  .asciiz "# "
clear_scr:
  .asciiz "\033[2J\033[H"

hexdump_addr:
  .asciiz "\033[34m"
hexdump_addrend:
  .ascii  "\033[0m  "
non_printable_char:
  .asciiz "\033[90m.\033[0m"

  .endif ; SHELL_ASM

