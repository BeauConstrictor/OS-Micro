  .include "mmap.asm"

  .org RUN_LOAD

; word types:
EOL = $00

start:
  ld   hl,temporary_code
  ld   (parse),hl
  ret

tokenise:
  ld   hl,(parse)
  ld   de,tokens
.loop:
  call skip_whitespace
  ld   a,(hl)
  cp   0
  jr   .done
  call .defined_word

.done:
  ld   (de),EOL
  ret
.defined_word:
.defined_word_loop:
  ld   (de
  ret

; increment hl while (hl) == ' ', '\t' or '\n'
; clobbers: a,hl
skip_whitespace:
  ld   a,(hl)
  inc hl
  cp   ' '
  jr   z,skip_whitespace
  cp   '\t'
  jr   z,skip_whitespace
  cp   '\n'
  jr   z,skip_whitespace
  dec hl
  ret

temporary_code:
  .asciiz "this is a test"

  .include "io.asm"

tokens = memory

memory:
