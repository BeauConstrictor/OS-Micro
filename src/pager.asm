  .include "mmap.asm"

  .org RUN_LOAD

start:
  ; the string is passed in as an argument
  ld   hl,(parse)
  call ffind
  ld   hl,file
  call fload

  ; goes into the alternate screen buffer and hides the terminal
  ld   hl,init_term
  call print

  ; move cursor to the bottom of the screen
  call add_newlines
  call add_newlines
  call add_newlines

.draw_page:
  call draw_page
.loop:
  ld   hl,key_prompt
  call print
.wait
  in   a,(SERIAL)
  cp   0
  jr   z,.wait
  ; once a key is pressed, clear the line with the prompt on it so
  ; we can write lines there
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
  ; make sure to move the head to the next line
  ld   (head),hl
  jr   .loop
.exit:
  ld   hl,norm_term
  call print
  ret

; just calls draw_line <terminal_height-1> times
draw_page:
  ld   b,page_height
  ld   hl,(head)
.loop:
  call draw_line
  djnz .loop
  ld   (head),hl
  ret

; prints characters until a \n (prints the \n too)
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
  ret  z
  jr   .loop

add_newlines:
  ld b,0
  ld   a,'\n'
.loop:
  out  (SERIAL),a
  djnz .loop
  ret

page_height = 10

; the next character to start printing from
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

; start in ram at the point after our program is loaded. we don't
; reserve any space because that space would be included in the binary
file:
