  .include "mmap.asm"

  .org RUN_LOAD

start:
  ld   hl,height_prompt
  call print
  call buffer_l
  call hex_in
  dec  a ; don't include the status line
  ld   (term_height),a

  ld   hl,file_prompt
  call print
  call buffer_l
  ld   hl,(parse)
  call ffind

  ld   hl,file
  call fload

  ld   hl,init_term
  call print

.draw_page:
  call draw_page
.loop:
  ld   hl,key_prompt
  call print
.wait
  in   a,(SERIAL)
  cp   0
  jr   z,.wait
  push af
  ld   hl,key_pressed
  call print
  pop  af
  cp   ' '
  jr   z,.draw_page
  cp   '\n'
  jr   z,.draw_line
  cp   'q'
  jr   z,.exit
  jr   .loop
.draw_line:
  ld   hl,(head)
  call draw_line
  ld   (head),hl
  jr   .loop
.exit:
  ld   hl,norm_term
  call print
  ret

draw_page:
  ld   a,(term_height)
  ld   b,a
  ld   hl,(head)
.loop:
  call draw_line
  djnz .loop
  ld   (head),hl
  ret

draw_line:
.loop:
  ld   a,(hl)
  ; we check null before incrementing so following calls also see
  ; the 'eof'
  cp   0
  ret  z
  inc  hl
  out  (SERIAL),a
  cp   '\n'
  jr   nz,.loop
  ret

term_height:
  .reserve 1
head:
  .word file

init_term:
  .byte   "\e[?25l"
  .byte   "\e[?1049h"
  .asciiz "\e[H\e[2J"

norm_term:
  .byte   "\e[?1049l"
  .asciiz "\e[?25h"

file_prompt:
  .asciiz "\e[90mFile?\e[0m "
height_prompt:
  .asciiz "\e[90mTerminal lines (in 2-digit hex!)?\e[0m "
key_prompt:
  .asciiz "\e[90m[Press q to quit, return for next line, space for next page]\e[0m"
key_pressed:
  .asciiz "\r\e[2K"

  .include "io.asm"
  .include "fs.asm"

file:
