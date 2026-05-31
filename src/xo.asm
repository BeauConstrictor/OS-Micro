  .include "mmap.asm"

  .org RUN_LOAD

start:
  ; save the return address for later
  pop  hl
  ld   (exit_vec),hl

  ld   hl,init_term
  call print
mainloop:
  call draw_board
  call make_move
  jr   mainloop

make_move:
  call buffer_l

  call get_char
  cp   'q'
  jp   z,exit
  cp   'c'
  jp   z,restart
  call unget_char

  call hex_in
  ld   hl,positions
  ld   e,a
  ld   d,0
  add  hl,de
  ld   a,(next_turn)
  ld   (hl),a

  cp   'x'
  jr   z,.o_next
  ld   a,'x'
  jr   .set_next
.o_next:
  ld   a,'o'
.set_next:
  ld   (next_turn),a
  ret

exit:
  ld   hl,norm_term
  call print
  ld   hl,(exit_vec)
  jp   hl

restart:
  ld   b,0
  ld   hl,positions
.loop:
  ld   (hl),' '
  inc  hl
  djnz .loop
  ld   a,'x'
  ld   (next_turn),a
  jp   mainloop

draw_board:
  ld   hl,letter_row
  call print

  ld   a,(positions + $1a)
  out  (SERIAL),a
  ld   hl,row_middle
  call print
  ld   a,(positions + $1b)
  out  (SERIAL),a
  ld   hl,row_middle
  call print
  ld   a,(positions + $1c)
  out  (SERIAL),a

  ld   hl,separator
  call print

  ld   hl,row_2
  call print
  ld   a,(positions + $2a)
  out  (SERIAL),a
  ld   hl,row_middle
  call print
  ld   a,(positions + $2b)
  out  (SERIAL),a
  ld   hl,row_middle
  call print
  ld   a,(positions + $2c)
  out  (SERIAL),a

  ld   hl,separator
  call print

  ld   hl,row_3
  call print
  ld   a,(positions + $3a)
  out  (SERIAL),a
  ld   hl,row_middle
  call print
  ld   a,(positions + $3b)
  out  (SERIAL),a
  ld   hl,row_middle
  call print
  ld   a,(positions + $3c)
  out  (SERIAL),a

  ld   a,(next_turn)
  cp   'x'
  jr   nz,.o_turn
  ld   hl,x_turn
  call print
  ret
.o_turn
  ld   hl,o_turn
  call print
  ret

exit_vec:
  .reserve 2

next_turn:
  .byte   "x"

positions:
  .repeat 256
  .byte " "
  .endrep

init_term:
  .byte   "\e[?1049h"
  .asciiz "\e[H\e[2J"
norm_term:
  .asciiz "\e[?1049l"

letter_row:
  .text   "\e[H\e[2J"
  .text   "\n\e[35m   Welcome to OS/M X&Os!\n\e[0m"
  .text   "  Press q<RETURN> to exit.\n"
  .text   " Press c<RETURN> to restart.\n"
  .asciiz "\n\n\e[90m         A   B   C\e[0m\n      \e[90m1\e[0m  "
row_2:
  .asciiz "\n      \e[90m2\e[0m  "
row_3:
  .asciiz "\n      \e[90m3\e[0m  "
row_middle:
  .asciiz " \e[90m|\e[0m "
separator:
  .asciiz "\n        \e[90m---+---+---\e[0m"

x_turn:
  .asciiz "\n\n\e[90m  x's turn (digit first): \e[0m"
o_turn:
  .asciiz "\n\n\e[90m  o's turn (digit first): \e[0m"

  .include "io.asm"
