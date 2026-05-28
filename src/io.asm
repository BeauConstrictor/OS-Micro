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
  push hl
  xor  a
  sbc  hl,de
  ; if so, ignore backspace
  pop  hl
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

; output the (unsigned) decimal byte in a
num_out:
    push af
    push bc
    push de
    push hl
    ; keep track of digits
    ld   b,0
.loop:
    ld   c,10
    ; repeatedly subtract
    ld   d,0
.sub:
    cp   10
    jr   c,.store
    sub  10
    inc  d
    jr   .sub
.store:
    push af ; remainder
    inc  b
    ld   a,d ; division result
    or   a
    jr   nz,.loop
.print:
    pop  af
    add  a,'0'
    out  (SERIAL),a
    djnz .print
    ld   a,' '
    out  (SERIAL),a
    pop  hl
    pop  de
    pop  bc
    pop  af
    ret

; print the hex word in hl
; clobbers a,b,hl
hex_word_out:
  ld   a,h
  call hex_out
  ld   a,l
  call hex_out
  ret

; read in a hex byte from input buffer (returns in a) (produces
; garbage for invalid hex)
; clobbers: a,b,hl
hex_in:
  ; read a single hex char
  call .nibble
  ; move it to high nibble spot
  rlca
  rlca
  rlca
  rlca
  ; save it for now
  ld   b,a
  ; read another char
  call .nibble
  ; it is in the low nibble spot. now or back in the high nibble we
  ; just saved
  or   b
  ret
.nibble:
  call get_char
  ; if less than 'A' in ascii code, must be a digit
  cp   'A'
  jr   c,.digit
  ; if less than 'a' in ascii code, must be an uppercase char
  cp   'a'
  jr   c,.uppercase
  ; otherwise, it must be lowercase
  sub  'a'-10
  ret 
.uppercase:
  sub  'A'-10
  ret
.digit:
  sub  '0'
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

; wait until the device busy flag is 0
; clobbers: a
busy_wait:
  ld   a,(DEV_STATUS)
  and  BUSY
  jr   nz,busy_wait
  ret

  .endif ; IO_ASM
