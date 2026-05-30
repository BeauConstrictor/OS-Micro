  .include "mmap.asm"

  .org RUN_LOAD

start:
  pop  hl
  ld   (exit_vec),hl
  ld   hl,init_term
  call print
mainloop:
  call draw_game
  call step
  ld   a,(frame)
  inc  a
  ld   (frame),a
  jr   mainloop

kill:
  ld   hl,dead
  call print
.loop:
  in   a,(SERIAL)
  cp   '\n'
  jr   nz,.loop
  ld   hl,norm_term
  call print
  ld   hl,(exit_vec)
  jp   (hl)

draw_game:
  ld   hl,startframe
  call print
  ld   hl,verticalwall
  call print

  ; y position
  ld   b,0
 
.yloop:
  ld   hl,leftwall
  call print

  ; draw player
  ld   a,(plry)
  cp   b
  jr   nz,.not_eq_plry
.eq_plry
  ld   hl,plr
  call print
  jr   .plr_done
.not_eq_plry:
  ld   a,' '
  out  (SERIAL),a
  out  (SERIAL),a
.plr_done:

  ; draw the ball:
  ; x position
  ld   c,0
.xloop:
  ld   a,(ballx)
  cp   c
  jr   nz,.not_eq_ballpos
  ld   a,(bally)
  cp   b
  jr   nz,.not_eq_ballpos
  ld   hl,ball
  call print
  jr   .eq_ballpos
.not_eq_ballpos:
  ld   a,' '
  out  (SERIAL),a
  out  (SERIAL),a
.eq_ballpos
  inc  c
  ld   a,c
  cp   16
  jr   nz,.xloop

  ; draw bot (always ball's pos)
  ld   a,(bally)
  cp   b
  jr   nz,.not_eq_bally
.eq_bally:
  ld   hl,bot
  call print
  jr   .bot_done
.not_eq_bally:
  ld   a,' '
  out  (SERIAL),a
  out  (SERIAL),a
.bot_done:

  ld  hl,rightwall
  call print

  inc b
  ld  a,b
  cp  16
  jr  nz,.yloop

  ld   hl,verticalwall
  call print
  ret

step:
  ; move player
  in   a,(SERIAL)

  cp   '\e'
  jp   z,kill

  cp   'j'
  jr   nz,.not_down
  ld   a,(plry)
  inc  a
  ld   (plry),a
  jr   .not_up
.not_down:
  cp   'k'
  jr   nz,.not_up
  ld   a,(plry)
  dec  a
  ld   (plry),a
.not_up:

  ; keep player onscreen
  ld   a,(plry)
  and  $0f
  ld   (plry),a

  ; ball moves slower than player (1/256th the speed)
  ld   a,(frame)
  cp   0
  ret  nz

  ; move ball
  ld   a,(ballv)
  ld   b,a
  ld   a,(bally)
  add  b
  ld   (bally),a
  ld   a,(ballh)
  ld   b,a
  ld   a,(ballx)
  add  b
  ld   (ballx),a

  ; bounce ball horizontally
  ld   a,(ballx)
  cp   15
  jr   nz,.not_at_horzontal_right
  ld   a,$ff
  ld   (ballh),a
.not_at_horzontal_right:
  ld   a,(ballx)
  cp   0
  jr   nz,.not_at_horzontal_left
  ld   a,$01
  ld   (ballh),a
.not_at_horzontal_left:

  ; bounce ball vertically
  ld   a,(ballx)
  cp   15
  jr   z,.bounce_vertically
  cp   0
  jr   nz,.no_vert_bounce
  ld   a,(plry)
  ld   b,a
  ld   a,(ballx)
  cp   b
  jr   nz,.no_vert_bounce
  call randbit
  jr   z,.bounce_vertically
.no_vert_bounce:

  ; kill player
  ld   a,(plry)
  ld   b,a
  ld   a,(ballx)
  cp   0
  jr   nz,.dont_kill
  ld   a,(bally)
  dec  b
  cp   b
  jp   c,kill ; bally < plry-1
  inc  b
  inc  b
  inc  b
  cp   b
  jp   nc,kill ; >= plry+2
.dont_kill:

  ; ceiling & floor bounce
  ld   a,(bally)
  cp   15
  jr   nz,.no_ceil_bounce
  ld   a,$ff
  ld   (ballv),a
  jr   .no_floor_bounce
.no_ceil_bounce:
  cp   0
  jr   nz,.no_floor_bounce
  ld   a,$01
  ld   (ballv),a
.no_floor_bounce:

  ; keep ball onscreen
  ld   a,(ballx)
  and  $0f
  ld   (ballx),a
  ld   a,(bally)
  and  $0f
  ld   (bally),a

  ret

.bounce_vertically:
  ld   a,(ballv)
  cp   0
  jr   z,.vb_randbit
  ld   a,0
  ld   (ballv),a
.vb_randbit:
  call randbit
  jr   z,.vb_go_down
  ld   a,$ff
  ld   (ballv),a
  jr   .no_vert_bounce
.vb_go_down:
  ld   a,0
  ld   (ballv),a
  jr   .no_vert_bounce

randbit:
  ld   a,(rand_state)
  inc  a
  ld   (rand_state),a
  and  1
  ret

exit_vec:
  .reserve 2

init_term:
  .byte   "\e[?25l"
  .byte   "\e[?1049h"
  .asciiz "\e[2J"

norm_term:
  .byte   "\e[?1049l"
  .asciiz "\e[?25h"

plry:
  .byte 8
ballx:
  .byte 8
bally:
  .byte 0
ballv:
  .byte 1
ballh:
  .byte 1
frame:
  .byte 0

rand_state:
  .reserve 1

plr:
  .asciiz " \e[34m\e[7m \e[0m"
bot:
  .asciiz "\e[31m\e[7m \e[0m "
ball:
  .asciiz "\e[7m  \e[0m"

startframe:
  .asciiz "\e[H"

leftwall:
  .asciiz "\e[90m\e[7m \e[0m "

rightwall:
  .asciiz " \e[90m\e[7m \e[0m\n"

verticalwall:
  .byte   "\e[90m"
  .byte   "\e[7m"
  .repeat 40
  .byte   " "
  .endrep
  .byte   "\e[0m"
  .asciiz "\n"

dead:
  .byte   "\n\033[31m"
  .byte   "You died!\n"
  .asciiz "Press <ENTER> to exit. "

  .include "io.asm"
