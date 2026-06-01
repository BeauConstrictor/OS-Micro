  .include "mmap.asm"

  .org RUN_LOAD

start:
  pop  hl
  ld   (exit_vec),hl

  ld   hl,init_term
  call print

  ; this way we can draw the cursor at the eof
  ld   a,'\n'
  ld   (bufend),a

.loop:
  call draw_buffer
.wait:
  in   a,(SERIAL)
  cp   0
  jr   z,.wait
  call handle_key
  jr   .loop

draw_buffer:
  ld   hl,clearscr
  call print
  ld   b,0 # lines

  ld   hl,bufstart
.before:
  ; make sure we haven't reached the gap yet
  ld   a,(gapstart+1)
  cp   h
  jr   nz,.before_not_eq
  ld   a,(gapstart)
  cp   l
  jr   z,.before_done
.before_not_eq:
  ld   a,(hl)
  ; increment the lines counter (bc)
  cp   '\n'
  jr   nz,.before_not_nl
  inc  b
.before_not_nl:
  out  (SERIAL),a
  ; move to next character
  inc  hl
  jr   .before
.before_done:

  ld   hl,reverse_video
  call print
  ld   hl,(aftergap)
  ld   a,(hl)
  cp   '\n'
  jr   nz,.cursor_isnt_space
.cursor_is_space:
  ld   a,' '
  jr   .cursor_is_space2
.cursor_isnt_space:
  inc  hl
.cursor_is_space2:
  out  (SERIAL),a
  push hl
  ld   hl,ansi_reset
  call print
  pop  hl

.after:
  ; make sure we haven't reached end of the buffer yet
  ld   a,>bufend
  cp   h
  jr   nz,.after_not_eq
  ld   a,<bufend
  cp   l
  jr   z,.after_done
.after_not_eq:
  ld   a,(hl)
  ; increment the lines counter (bc)
  cp   '\n'
  jr   nz,.after_not_nl
  inc  b
.after_not_nl:
  out  (SERIAL),a
  ; move to next character
  inc  hl
  jr   .after
.after_done:

  ; print tildes to meet the line height
.tilde_loop:
  ld   hl,eof_line
  call print
  inc  b
  ld   a,(term_height)
  cp   b
  jr   nz,.tilde_loop

  ld   a,'\n'
  out  (SERIAL),a
  out  (SERIAL),a
  ld   hl,status
  call print

  ret

insert_c:
  ld   hl,(gapstart)
  ld   (hl),a
  inc  hl
  ld   (gapstart),hl
  ; TODO: mark as unsaved
  ret

backspace:
  ; check if there is anything to backspace
  ld   a,(gapstart+1)
  cp   >bufstart
  jr   nz,.not_eq
  ld   a,(gapstart)
  cp   <bufstart
  ret  z
.not_eq:
  ld   hl,(gapstart)
  dec  hl
  ld   (gapstart),hl
  ; TODO: mark as unsaved
  ret

cursor_l:
  ; make sure there is space to go left
  ld   a,(gapstart+1)
  cp   >bufstart
  jr   nz,.not_eq
  ld   a,(gapstart)
  cp   <bufstart
  ret  z
.not_eq:

  ld   hl,(aftergap)
  dec  hl
  ld   (aftergap),hl

  ld   hl,(gapstart)
  dec  hl
  ld   a,(hl)
  ld   hl,(aftergap)
  ld   (hl),a

  ld   hl,(gapstart)
  dec  hl
  ld   (gapstart),hl
  ret

cursor_r:
  ; make sure there is space to go right
  ld   a,(aftergap+1)
  cp   >bufend
  jr   nz,.not_eq
  ld   a,(aftergap)
  cp   <bufend
  ret  z
.not_eq:
  ; *gapstart = *aftergap
  ld   hl,(aftergap)
  ld   a,(hl)
  ld   hl,(gapstart)
  ld   (hl),a
  ; inc aftergap
  ld   hl,(aftergap)
  inc  hl
  ld   (aftergap),hl
  ; inc gapstart
  ld   hl,(gapstart)
  inc  hl
  ld   (gapstart),hl
  ret

handle_key:
  ld   b,a
  ld   a,(mode)
  cp   INSERT
  jr   z,handle_insert_key
  cp   NORMAL
  jr   z,handle_normal_key
  halt

handle_insert_key:
  ld   a,b
  cp   '\033'
  jr   nz,.not_esc
  ld   a,NORMAL
  ld   (mode),a
  ld   a,'\0'
  ld   (status),a
  ret
.not_esc:
  cp   '\b'
  jr   nz,.not_bcksp
.is_bcksp:
  jp   backspace
.not_bcksp:
  cp   '\177'
  jr   z,.is_bcksp
  jp   insert_c

handle_normal_key:
  ld   a,b
  cp   'i'
  jr   nz,.not_i
.is_i:
  ld   a,INSERT
  ld   (mode),a
  ld   hl,insert_mode_msg
  ld   de,status
  call strcpy
  ret
.not_i:
  cp   'h'
  jp   z,cursor_l
.not_h:
  cp   'a'
  jr   nz,.not_a
  call cursor_r
  jr   .is_i
.not_a:
  cp   'l'
  jp   z,cursor_r
.not_l:
  cp   'q'
  jr   nz,.not_q
  ld   hl,norm_term
  call print
  ld   hl,(exit_vec)
  jp   (hl)
.not_q:
  cp   '_'
  jr   nz,.not__
  ld   hl,statusline_prompt
  call print
  call buffer_l
  call hex_in
  ld   (term_height),a
  ld   hl,hide_cursor
  call print
  ret
.not__:
  ret

clearscr:
  .asciiz "\033[2J\033[H"

init_term:
  .byte   "\e[?1049h"
  .byte   "\e[H\e[2J"
hide_cursor:
  .asciiz "\e[?25l"
norm_term:
  .byte   "\e[?1049l"
  .asciiz "\e[?25h"

insert_mode_msg:
  .asciiz "-- INSERT --"

statusline_prompt:
  .asciiz "\e[2K\r\e[90mTerminal height (2-digit hex)? \e[0m\e[?25h"

eof_line:
  .asciiz "\n\e[90m~\e[0m"

reverse_video:
  .asciiz "\e[7m"
ansi_reset:
  .asciiz "\e[0m"

NORMAL = 0
INSERT = 1

exit_vec:
  .reserve 2
term_height:
  .byte 25
gapstart:
  .word bufstart
aftergap:
  .word bufend
mode:
  .word NORMAL

status:
  .ascii "To set terminal height, press _ and enter a new height in 2-digit hex."
  .reserve 256-14

  .include "io.asm"

bufend = bufstart + 32*1024 ; first char after the buffer
bufstart:
