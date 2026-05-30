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

; undo previous call to get_char
; clobbers: a,hl
unget_char:
  ld   hl,(parse)
  dec  hl
  ld   a,(hl)
  cp   ' '
  jr   z,unget_char
  ld   (parse),hl
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

; output decimal byte in a
; clobbers: <none>
num_out:
    push af
    push bc
    ld   b,a ; save value
    ld   c,'0'-1 ; tens digit ASCII
.tens:
    inc  c
    sub  10
    jr   nc,.tens
    add  a,10 ; A = units digit
    ld   b,a ; save units digit
    ld   a,c
    cp   '0'
    jr   z,.units
    out  (SERIAL),a ; print tens digit
.units:
    ld   a,b
    add  a,'0'
    out  (SERIAL),a
    pop  bc
    pop  af
    ret

; output hl in decimal
; clobbers: a,b,de,hl
num_word_out:
    ld   b,0 ; keep track of leading zeroes

    ld   de,-10000
    call .digit
    ld   de,-1000
    call .digit
    ld   de,-100
    call .digit
    ld   de,-10
    call .digit
    ld   a,l
    add  a,'0'
    out  (SERIAL),a
    ret
.digit:
    ld   a,'0'-1
.loop:
    inc  a
    add  hl,de
    jr   c,.loop
    sbc  hl,de
    ; decide if we print this digit
    ld   c,a
    cp   '0'
    jr   z,.skip_if_leading
.print_digit:
    out  (SERIAL),a
    ld   b,1 ; set printed flag
    ret
.skip_if_leading:
    ld   a,b
    cp   0
    jr   z,.done
    ld   a,c
    jr   .print_digit
.done:
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

; read a 16-byte hex value into hl
; clobbers: a,b,e,hl
hex_word_in:
  call hex_in
  ld   e,a
  call hex_in
  ld   h,e
  ld   l,a
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

linebuf:
  .reserve 128
parse:
  .reserve 2

  .endif ; IO_ASM
