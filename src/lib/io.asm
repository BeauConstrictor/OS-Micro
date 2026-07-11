; io.asm - The OS/M I/O library
;
; This library implements various routines for handling input and
; output, as well as parsing input in various ways.
;
; If you need to use the various subroutines that for parsing numbers
; and hex values on strings not in the input buffer, you can set the
; value of (parse) to the address of your string before the call.

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
  cp   'D' & 0x1f ; ctrl+d
  jr   z,.interrupt
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
  ; clear carry
  or  a
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
.interrupt:
  ld   hl,interrupt
  call print
  ld   sp,STACK_START
  jp   KERNEL

; replace the first space after (parse) with a \0, and return a
; pointer to the next char after that space in hl
; clobbers: a,hl
splitarg:
  ld   hl,(parse)
.loop:
  ld   a,(hl)
  cp   ' '
  jr   z,.found
  inc  hl
  jr   .loop
.found:
  ld   (hl),'\0'
  inc  hl
  ret

; read a single char from the input buffer and advance to the next
; char (returns in a)
; clobbers: a,hl
get_char_any:
  ld   hl,(parse)
  ld   a,(hl)
  inc  hl
  ld   (parse),hl
  ret

; undo previous call to get_char_any
; clobbers: a,hl
unget_char_any:
  ld   hl,(parse)
  dec  hl
  ld   a,(hl)
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

; check if all characters until whitespace or \0 are digits.
; returns nc if so or c if not.
; clobbers: a,hl
is_num:
  ld   hl,(parse)
.loop:
  ld   a,(hl)
  cp   ' '
  jr   z,.done
  cp   '\0'
  jr   z,.done
  cp   '0'
  jr   c,.not_digit
  cp   '9'+1
  jr   nc,.not_digit
  inc  hl
  jr   .loop
.not_digit:
  scf
  ret
.done:
  ; clear carry
  or  a
  ret

; parse a single number and return in hl, until first non-digit char
; (or end of input).
; clobbers: a,b,de,hl
num_word_in:
  ld   hl,0
.loop:
  push hl
  call get_char_any
  pop  hl
  ; if char is not a digit, we are done
  ; < '0'
  cp   '0'
  jr   c,.done
  ; > '9'
  cp   '9'+1
  jr   nc,.done
  ; shift existing digits over one place value
  push af
  call .mult_10
  pop  af
  ; add in the new digit
  sub  '0'
  ld   d,0
  ld   e,a
  add  hl,de
  jr   .loop
.done:
  ; we want to leave the last char after the number un-parsed.
  push hl
  call unget_char_any
  pop  hl
  ret
; multiply hl by 10
.mult_10:
  ld   d,h
  ld   e,l
  ld   hl,0
  ld   b,10
.mult_loop:
  add  hl,de
  djnz .mult_loop
  ret

; parse a single number and return in a, until first non-digit char
; (or end of input).
; clobbers: a,b,de,hl
num_in:
  call num_word_in
  ld   h,0
  ld   a,l
  ret

; copy the null-terminated string in hl to de. returns the address of
; the null-byte in both strings.
; clobbers: a,de,hl
strcpy:
  ld   a,(hl)
  ld   (de),a
  cp   0
  ret  z
  inc  hl
  inc  de
  jr   strcpy

; return nc if the strings in he and de are equal (c otherwise).
; returns the address of the first mismatch in hl and de. if equal,
; returns the address of the null terminator.
; clobbers: a,b,de,hl
strcmp:
  ld  a,(de)
  ld  b,a
  ld  a,(hl)
  cp  '\0'
  jr  z,.match
  cp  b
  inc hl
  inc de
  jr  z,strcmp
  scf
  ret
.match:
  or  a ; clear carry
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

interrupt:
  .asciiz "\e[31m <interrupt> \e[0m\n"

  .include "zeropage.asm"

  .endif ; IO_ASM
