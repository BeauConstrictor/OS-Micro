  .ifndef IO_ASM
IO_ASM = 1

; buffer a line of input for later reading
; clobbers: a,hl
buffer_l:
  ld   hl,linebuf
.loop:
  in   a,(SERIAL)
  ; check if no key pressed...
  cp   0
  ; if so, check again
  jr   z,.loop
  cp   '\n'
  jr   z,.done
  cp   DELETE
  jr   z,.backspace
  cp   '\b'
  jr   z,.backspace
  ; write the char to the end of the buffer
  ld   (hl),a
  ; move to the next spot in the buffer
  inc  hl
  ; echo the char
  out  (SERIAL),a
  ; repeat
  jr   .loop
.backspace:
  ; load the start of the bufferr
  ld   de,linebuf
  ; check if we're already at it
  xor  a
  sbc  hl,de
  ; if so, ignore backspace
  jr   z,.loop
  ; move cursor back,
  ld   a,'\b'
  out  (SERIAL),a
  ; replace prev char with space (moves forward),
  ld   a,' '
  out  (SERIAL),a
  ; and go back again
  ld   a,'\b'
  out  (SERIAL),a
  dec  hl
  jr   .loop
.done:
  out  (SERIAL),a
  ; mark eol with a null char
  ld   (hl),'\0'
  ; move parsing to start of line
  ld   hl,linebuf
  ld   (parse),hl
  ret

; read a single char from the input buffer and advance to the next
; char (skips whitespace) (returns in a)
; clobbers: a,hl
get_char:
  ld   hl,(parse)
  ld   a,(hl)
  inc  hl
  ld   (parse),hl
  cp   ' '
  jr   z,get_char
  ret

; output the hex byte in a
; clobbers: a,b
hex_out:
  ; save full byte into a
  ld   b,a
  ; extract high nibble
  rrca
  rrca
  rrca
  rrca
  and  $0f
  ; print it
  call .nibble
  ; extract low nibble
  ld   a,b
  and  $0f
  ; print it
  call .nibble
  ret
.nibble:
  ; if nibble < 10, print it's digit
  cp   10
  jr   c,.digit
  ; otherwise, print it's letter
  add  a,'A'-10
  out  (SERIAL),a
  ret
.digit:
  add  a,'0'
  out  (SERIAL),a
  ret

; print the null-terminated string (hl)
; clobbers: a,hl
print:
  ld   a,(hl)
  cp   0
  ret  z
  out  (SERIAL),a
  inc  hl
  jr   print

  .endif ; IO_ASM
