  .ifndef SHELL_ASM
SHELL_ASM = 1

welcome:
  ld   hl,welcome_msg
  call print
  ; remove the welcome string so if a panic sends us back here, we
  ; don't print it again
  ld   hl,welcome_msg
  ld   (hl),0
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

  ld   hl,middle_prompt
  call print

  ld   a,(cwd)
  ld   hl,.cwd_name
  call get_dir_name
  jr   c,.isroot
  ld   hl,.cwd_name
  call print
.isroot:

  ld   hl,post_prompt
  call print
  ret
.cwd_name:
  .reserve 15

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
  jr   z,.notfound_internal
  jr   .check_match
.notfound_internal:
  ld   hl,linebuf
  ld   (parse),hl
  call splitarg
  push hl
  ld   hl,linebuf
  call exec_lookup
  pop  hl
  jr   c,.notfound_external
  ld   (parse),hl
  ld   hl,RUN_LOAD
  call fload
  jp   RUN_LOAD
.notfound_external:
  ld   hl,linebuf
  call print
  ld   a,'?'
  out  (SERIAL),a
  ld   a,'\n'
  out  (SERIAL),a
  ret

; return in a the fid of the file in the standard executable locations
; with the name hl (1st checked: cwd, hen root, then disk 0 root)
; return c if not found anywhere, nc otherwise
; clobbers: TODO
exec_lookup:
  push  hl
  call ffind_noerr
  pop  hl
  ret  nc
  ld   a,(cwd)
  ld   b,a
  push bc
  ld   a,0
  ld   (cwd),a
  push hl
  call ffind_noerr
  pop  hl
  pop  bc
  jr   c,.not_in_root
  ld   a,b
  ld   (cwd),a
  or   a
  ret
.not_in_root;
  ld   a,(DEV_SELECT)
  ld   c,a
  push bc
  ld   a,0
  ld   (DEV_SELECT),a
  call busy_wait
  ld   a,0
  ld   (cwd),a
  call ffind_noerr
  pop  bc
  push af
  ; we now have original cwd in b and the original device in c
  ld   a,b
  ld   (cwd),a
  ld   a,c
  ld   (DEV_SELECT),a
  call busy_wait
  ; just return whatever carry and fid that ffind_noerr returns
  pop  af
  ret

; list files and their first sectors
cmd_dir:
  ld   a,(cwd)
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
  ld   a,(hl)
  cp   '.'
  jr   z,.dimmed
.identify:
  ld   a,(hl)
  cp   0
  jr   z,.normalfile
  cp   '/'
  jr   z,.isdir
  inc  hl
  jr   .identify
.isdir:
  ld   hl,dir_subdir_ansi
  call print
  jr   .normalfile
.dimmed:
  ld   hl,dir_dimmed_ansi
  call print
.normalfile:
  pop  hl
  push hl
  call print
  ld   hl,ansi_reset
  call print
  pop  hl
  ld   a,'\n'
  out  (SERIAL),a
.unoccupied:
  ld   de,16
  add  hl,de
  djnz .loop
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

; print the sector count in a as a number of kilobytes (with decimal
; point!)
; clobbers: a,c
print_ks:
  ld   c,a
  ; get the 'decimal point' of sectors used (0-3)
  and  %00000011
  push af
  ld   a,c
  ; divide by 4 to convert from units 256b sectors to units of 1024b
  or a ; (clear carry)
  rra
  or a ; (clear carry)
  rra
  call num_out
  pop  af
  ld   c,a
  ; now, we print the number of quarters of a kb
  cp   0
  ret  z
  ld   a,'.'
  out  (SERIAL),a
  ld   a,c
  cp   1
  jr   z,.one_quarter
  cp   2
  jr   z,.one_half
  ; otherwise, must be 3 quarters
  ld   a,'7'
  jr   .write_5
  ret
.one_quarter:
  ld   a,'2'
  jr   .write_5
.write_5:
  out  (SERIAL),a
.one_half:
  ld   a,'5'
  out  (SERIAL),a
  ret

; shutdown the machine
cmd_bye:
  call fflush ; save any chan
  halt        ; closest thing to a power off we have

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
  jr   nc,.hasfs
.invalid:
  ; invalid!
  ld   a,d
  ; go back to original device
  ld   (DEV_SELECT),a
  ld   hl,must_format_first
  call print
  ret
.hasfs:
  ; check if the device id is SECTD
  ld   a,(DEV_STATUS)
  and  DEV_ID
  cp   SECTD
  jp   z,.isvalid
  ld   hl,not_a_disk
  jp   print
.isvalid:
  ld   a,0
  ld   (cwd),a
  ret

; show help text
cmd_hlp:
  ld   hl,help_txt
  call print
  ret

; format a disk for fs/128
cmd_fmt:
  ld   a,(DEV_SELECT)
  push af
  call hex_in
  ld   (DEV_SELECT),a
  call busy_wait
  ld   a,(DEV_STATUS)
  and  DEV_ID
  cp   0
  jr   z,.nodev
  cp   SECTD
  jr   nz,.notadisk
  call fmtdsk
  call chkdsk
  ret  nc
  ld   hl,not_writeable
  call print
  pop  af
  ret
.nodev:
  pop  af
  ld   (DEV_SELECT),a
  call busy_wait
  ld   hl,no_dev_there
  jp   print
.notadisk:
  pop  af
  ld   (DEV_SELECT),a
  call busy_wait
  ld   hl,not_a_disk
  jp   print

; create a new file
cmd_new:
  call fnew
  push af
  call expect_arg
  ld   hl,(parse)
  call frename
  ld   hl,(parse)
.goto_end:
  ld   a,(hl)
  inc  hl
  cp   '/'
  jr   z,.is_dir
  cp   0
  jr   nz,.goto_end
  pop  af
  ret
.is_dir:
  pop  af
  jp   init_dir

; rename a file
cmd_ren:
  call expect_arg
  call splitarg
  push hl
  ld   hl,(parse)
  call ffind
  pop  hl
  call frename
  ret

; move a file
cmd_mov:
  call expect_arg
  call splitarg
  push hl
  ld   hl,(parse)
  call ffind
  pop  hl
  push af
  call ffind
  ld   b,a
  pop  af
  call fmove
  ret

; list installed devices
cmd_dev:
  ld   a,0
  ld   (DEV_SELECT),a
.loop:
  call busy_wait
  ld   a,(DEV_STATUS)
  and  DEV_ID
  cp   NODEV
  jr   z,.nodev
  ld   hl,devlist_before
  call print
  ld   a,(DEV_SELECT)
  call hex_out
  ld   hl,devlist_after
  call print
  call get_devtype
  call print
  ld   a,'\n'
  out  (SERIAL),a
.nodev
  ld   a,(DEV_SELECT)
  inc  a
  ld   (DEV_SELECT),a
  jr   nz,.loop
  call busy_wait
  ld   hl,ansi_reset
  call print
  ret

; show how much disk space is used
cmd_usg:
  call disk_usg
  call print_ks
  ld   hl,usg_after
  jp   print

; show how large a file is
cmd_siz:
  call expect_arg
  ld   hl,(parse)
  call ffind
  call fsize
  call print_ks
  ld   a,'K'
  out  (SERIAL),a
  ld   a,'\n'
  out  (SERIAL),a
  ret

; delete a file
cmd_del:
  call expect_arg
  ld   hl,(parse)
  call ffind
  call fdel
  ret

; print a file
cmd_prn:
  call hex_in
  ld   c,a
  push bc
  ld   hl,(parse)
  ; skip any whitespace
  call get_char
  call unget_char_any
  call ffind
  ld   hl,RUN_LOAD
  push hl
  call fload
  pop  de
  ex   de,hl
  ; we now have head in hl, eof in de
  pop bc
  ; and we have the printer port in c
.loop:
  ld   a,h
  cp   d
  jr   nz,.noteq
  ld   a,l
  cp   e
  ret  z
.noteq:
  ld   a,(hl)
  out  (c),a
  inc  hl
  jr   .loop

; change directory
cmd_cwd:
  call expect_arg
  ld   hl,(parse)
  call ffind
  ld   (cwd),a
  ret

cmd_table:
  .byte "dir"
  .word cmd_dir
  .byte "bye"
  .word cmd_bye
  .byte "sys"
  .word cmd_sys
  .byte "cls"
  .word cmd_cls
  .byte "dsk"
  .word cmd_dsk
  .byte "hlp"
  .word cmd_hlp
  .byte "fmt"
  .word cmd_fmt
  .byte "new"
  .word cmd_new
  .byte "ren"
  .word cmd_ren
  .byte "dev"
  .word cmd_dev
  .byte "usg"
  .word cmd_usg
  .byte "siz"
  .word cmd_siz
  .byte "del"
  .word cmd_del
  .byte "prn"
  .word cmd_prn
  .byte "cwd"
  .word cmd_cwd
  .byte "mov"
  .word cmd_mov
  .byte 0x00

help_txt:
  .binary "help.txt"
  .byte 0
welcome_msg:
  .text   "\e[35mWelcome to OS/M Version 1.0.0!\n"
  .asciiz "\e[90mType 'hlp' for help.\e[0m\n\n"
pre_prompt:
  .asciiz "\e[36m"
middle_prompt:
  .asciiz "\e[90m:\e[33m"
post_prompt:
  .asciiz "\e[90m ~> \e[32m"
final_prompt:
  .asciiz "\e[0m"
dir_fid_color:
  .asciiz "\e[90m"
clear_scr:
  .asciiz "\e[2J\e[H"
must_format_first:
  .asciiz "\e[31mThat device is not formatted.\n\e[0m" 
not_a_disk:
  .asciiz "\e[31mThat device is not a disk.\n\e[0m"
not_writeable:
  .asciiz "\e[31mThat device is not writeable.\n\e[0m" 
no_dev_there:
  .asciiz "\e[31mThere is no device in that slot.\n\e[0m" 
missing_argument:
  .asciiz "\e[31mMissing argument.\n\e[0m" 
devlist_before:
  .asciiz "\e[90m"
devlist_after:
  .asciiz ": \e[0m"
ansi_reset:
  .asciiz "\e[0m"
usg_after:
  .asciiz "K / 64K\n"
dir_subdir_ansi:
  .asciiz "\e[33m"
dir_dimmed_ansi:
  .asciiz "\e[90m"
cwd_name:
  .reserve 15

  .endif ; SHELL_ASM


