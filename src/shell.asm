  .ifndef SHELL_ASM
SHELL_ASM = 1

welcome:
  ld   hl,welcome_msg
  call print
shell:
  ld   sp,STACK_START
  call shell_prompt
  call buffer_l
  ld   hl,final_prompt
  call print
  call exec_cmd
  jr   shell

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
  cp   '_' ; hidden files
  jr   z,.unoccupied
  push hl
  ld   c,b
  ld   de,15
  add  hl,de
  ld   a,(hl)
  call hex_out
  ld   hl,dir_separator
  call print
  ld   b,c
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

; check for a space and at least one more char. fails if not
; clobbers: <nothing>
expect_arg:
  push hl
  push af
  ld   hl,(parse)
  ld   a,(hl)
  cp   ' '
  jr   nz,.fail
  inc  hl
  ld   a,(hl)
  cp   '\0'
  jr   z,.fail
  ; advance parse past the space
  ld   (parse),hl
  pop  af
  pop  hl
  ret
.fail:
  ld   hl,missing_argument
  call print
  jp   shell

; shutdown the machine
cmd_bye:
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
  ; preserve original device in case new one is invalid
  ld   a,(DEV_SELECT)
  ld   d,a
  call hex_in
  ld   (DEV_SELECT),a
  call busy_wait
  call chkdsk
  ret  nc
  ; invalid!
  ld   a,d
  ; go back to original device
  ld   (DEV_SELECT),a
  ld   hl,must_format_first
  call print
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

; format a disk for fs/128
cmd_fmt:
  call hex_in
  ld   (DEV_SELECT),a
  call busy_wait
  ld   a,(DEV_STATUS)
  and  DEV_ID
  cp   0
  jr   z,.nodev
  call fmtdsk
  call chkdsk
  ret  nc
  ld   hl,not_writeable
  call print
  ret
.nodev:
  ld   hl,no_dev_there
  call print
  ret

; create a new file
cmd_new:
  call fnew
  call expect_arg
  ld   hl,(parse)
  call frename
  ret

; rename a file
cmd_ren:
  call hex_in
  call expect_arg
  ld   hl,(parse)
  call frename
  ret

; set the contents of an empty text file
cmd_wrt:
  call hex_in
  ld   b,a
  call expect_arg
  ; add a newline to the end of the string
  ld   hl,(parse)
.findterminator:
  ld   a,(hl)
  cp   '\0'
  jr   z,.found
  inc  hl
  jr   .findterminator
.found:
  ld   a,'\n'
  ld   (hl),a
  inc  hl
  ld   a,'\0'
  ld   (hl),a
  ; go back to start
  ld   hl,(parse)
  ld   a,b
  call fwrite
  ret

cmd_table:
  .byte  "dir"
  .word  cmd_dir
  .byte  "txt"
  .word  cmd_txt
  .byte  "bye"
  .word  cmd_bye
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
  .byte  "fmt"
  .word  cmd_fmt
  .byte  "new"
  .word  cmd_new
  .byte  "ren"
  .word  cmd_ren
  .byte  "wrt"
  .word  cmd_wrt
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
must_format_first:
  .asciiz "\033[31mThat device is not formatted.\n\033[0m" 
not_writeable:
  .asciiz "\033[31mThat device is not writeable.\n\033[0m" 
no_dev_there:
  .asciiz "\033[31mThere is no device in that slot.\n\033[0m" 
missing_argument:
  .asciiz "\033[31mMissing argument.\n\033[0m" 
  .endif ; SHELL_ASM


