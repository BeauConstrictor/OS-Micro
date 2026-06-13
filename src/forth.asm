  .include "mmap.asm"

  .org RUN_LOAD

start:
  pop  hl
  ld   (exit_vec),hl

  ld   hl,greeting
  call print
repl:
  call prompt
  call buffer_l
  ld   hl,reset
  call print
  call interpret_words
  jr   repl

prompt:
  ld   hl,data_stack
.loop:
  ld   a,(data_stack_top+1)
  cp   h
  jr   nz,.not_eq
  ld   a,(data_stack_top)
  cp   l
  jr   z,.done
.not_eq:
  ld   e,(hl)
  inc  hl
  ld   d,(hl)
  inc  hl
  push hl
  ld   h,d
  ld   l,e
  call num_word_out
  pop  hl
  ld   a,' '
  out  (SERIAL),a
  jr   .loop
.done:
  ld   hl,.text
  jp print
.text:
  .asciiz "\e[33m>>>\e[0m \e[32m"

interpret_words:
  call interpret_word
  call skip_until_whitespace
  jr   nc,interpret_words
  ld   hl,ok_msg
  jp   print

interpret_word:
  call skip_and_check_whitespace
  ld   hl,(parse)
  call find_name
  jr   c,.not_a_normal_word
  jp   (hl)
  ; the word will return for us
.not_a_normal_word:
  ; only hex literals are supported for now
  call get_char
  cp   '$'
  jr   nz,.not_hex_literal
  call hex_word_in
  call dpush_hl
  ret
.not_hex_literal:
  cp   ':'
  jr   nz,.not_definition
  ld   hl,(parse)
  ld   a,(hl)
  cp   ' '
  jr   nz,.not_definition
  inc  hl
  ld   (parse),hl
  call splitarg ; not really for this, but will place a null after the
                ; word name
  ld   hl,(parse)
  ld   de,(code_block_top)
  call add_name
  ret
.not_definition:
  call unget_char
  call is_num
  jr   c,.not_num_literal
  ; TODO: use num_word_in
  call num_word_in
  call dpush_hl
  ret
.not_num_literal:
.undefined:
  ld   hl,undefined_start
  call print
  ld   hl,(parse)
  call print_word
  ld   hl,undefined_end
  call print
  jp   repl

; skip all whitespace starting at (parse). returns c if there is no
; whitespace left (or nc otherwise).
; clobbers: a,hl
skip_and_check_whitespace:
  ld   hl,(parse)
  ld   a,(hl)
  cp   ' '
  jr   z,.has_whitespace
  scf
  ret
.has_whitespace:
  or   a ; clear carry
.loop:
  inc  hl
  ld   a,(hl)
  cp   ' '
  jr   z,.loop
  ld   (parse),hl
  ret

; skip all chars until a whitespace (not including the whitespace)
; returns c if (parse) is a \0
skip_until_whitespace:
  ld   hl,(parse)
.loop:
  ld   a,(hl)
  inc  hl
  cp   ' '
  jr   z,.done
  cp   '\0'
  jr   z,.null
  jr   .loop
.done:
  ld   (parse),hl
  ; clear carry
  or  a
  ret
.null:
  scf
  ret

; return in hl the address of the string in hl in the name table
; returns c if word not found, or nc if found
find_name:
  ld   d,h
  ld   e,l
  ; save start of search string for later
  push de
  ld   hl,name_table
.check:
  ld   a,(de)
  ld   b,a
  ld   a,(hl)
  inc  hl
  inc  de
  cp   '\0'
  jr   z,.match
  cp   b
  jr   z,.check
  ; go back to start of search string
  pop  de
  push de
  ; end-of-table sentinel value
  cp   $01
  jr   z,.notfound
.skip_loop:
  ld   a,(hl)
  inc  hl
  ; wait for end of name
  cp   '\0'
  jr   nz,.skip_loop
  ; skip past the address
  inc  hl
  inc  hl
  jr   .check
.notfound:
  pop  de
  scf
  ret
.match:
  ld   a,(hl)
  ld   e,a
  inc  hl
  ld   a,(hl)
  ld   d,a
  ld   h,d
  ld   l,e
  pop  de
  ; clear carry
  or   a
  ret

; add the string in the hl register to the name table, pointing to the
; address in de
; names can be at most 13 characters; null terminated
; clobbers: a,de,hl
add_name:
  push de
  ld   de,(name_table_top)
  call strcpy
  pop  de
  ; we are at the null-byte; move past
  inc  hl
  ld   (hl),e
  inc  hl
  ld   (hl),d
  inc  hl
  ; sentinel value
  ld   (hl),$01
  ld   (name_table_top),hl
  ret

; return in hl a pointer to a new block of code allocated, of size
; de
; clobbers; de,hl
alloc_code:
  ld   hl,(code_block_top)
  push hl
  add  hl,de
  ld   (code_block_top),hl
  pop  hl
  ret

; prints a null/whitespace-terminated string
print_word:
  ld   a,(hl)
  cp   ' '
  ret  z
  cp   '\0'
  ret  z
  out  (SERIAL),a
  inc  hl
  jr   print_word

; pop a single i16 from the data stack into de
; clobbers: de
dpop_de:
  push hl
  ld   hl,(data_stack_top)
  dec  hl
  ld   d,(hl)
  dec  hl
  ld   e,(hl)
  ld   (data_stack_top),hl
  pop  hl
  ret

; pop a single i16 from the data stack into hl
; clobbers: hl
dpop_hl:
  push de
  call dpop_de
  ld   h,d
  ld   l,e
  pop  de
  ret

; pop a single i16 from the data stack into bc
; clobbers: bc
dpop_bc:
  push de
  call dpop_de
  ld   b,d
  ld   c,e
  pop  de
  ret

; push a single i16 (in de) onto the data stack
; clobbers: <none>
dpush_de:
  push hl
  ld   hl,(data_stack_top)
  ld   (hl),e
  inc  hl
  ld   (hl),d
  inc  hl
  ld   (data_stack_top),hl
  pop  hl
  ret

; push a single i16 (in hl) onto the data stack
; clobbers: <none>
dpush_hl:
  push de
  ld   d,h
  ld   e,l
  call dpush_de
  pop  de
  ret

; push a single i16 (in bc) onto the data stack
; clobbers: <none>
dpush_bc:
  push de
  ld   d,b
  ld   e,c
  call dpush_de
  pop  de
  ret

word_hex:
  call dpop_hl
  call hex_word_out
  ld   a,' '
  out  (SERIAL),a
  ret

word_number:
  call dpop_hl
  call num_word_out
  ld   a,' '
  out  (SERIAL),a
  ret

word_emit:
  call dpop_hl
  ld   a,l
  out  (SERIAL),a
  ret

word_add:
  call dpop_de
  call dpop_hl
  add  hl,de
  call dpush_hl
  ret

word_sub:
  call dpop_de
  call dpop_hl
  or   a ; clear carry
  sbc  hl,de
  call dpush_hl
  ret

word_dup:
  call dpop_hl
  call dpush_hl
  jp   dpush_hl

word_swap:
  call dpop_de
  call dpop_hl
  call dpush_de
  jp   dpush_hl

word_over:
  call dpop_de
  call dpop_hl
  call dpush_hl
  call dpush_de
  jp   dpush_hl

word_rot:
  call dpop_bc
  call dpop_de
  call dpop_hl
  call dpush_de
  call dpush_bc
  call dpush_hl
  ret

word_exit:
  ld   hl,(exit_vec)
  jp   (hl)

word_words:
  ld   hl,name_table
.outer:
  ld   a,(hl)
  cp   $01
  ret  z
.inner:
  ld   a,(hl)
  out  (SERIAL),a
  inc  hl
  cp   $00
  jr   nz,.inner
  inc  hl
  inc  hl
  ld   a,'\n'
  out  (SERIAL),a
  jr   .outer

greeting:
  .asciiz "\e[90mType 'exit' to exit\e[0m\n"
reset:
  .asciiz "\e[0m"
ok_msg:
  .asciiz " \e[90mok\e[0m\n"
undefined_start:
  .asciiz "\e[31m"
undefined_end:
  .asciiz "?\e[0m\n"

; future program to use (fibonacci numbers):
;
; : ? ( n -- n ) dup . ;
;
; : fib-num ( n1 n2 -- n2 n1+n2 ) dup rot + ;
; : fib-nums ( count -- ) 2 - 0 ? 1 ? rot 0 do fib-num ? loop drop drop ;
;
; 10 fib-nums

name_table_top:
  .word _name_table_top
exit_stack_top:
  .word exit_stack
data_stack_top:
  .word data_stack
code_block_top:
  .word code_block
exit_vec:
  .reserve 2

exit_stack = memory + $1000 ; 256 b
data_stack = memory + $1100 ; 256 b
code_block = memory + $1200 ; rest of memory

  .include "io.asm"

memory:

name_table:
  .asciiz "+"
  .word word_add
  .asciiz "-"
  .word word_sub
  .asciiz "."
  .word word_number
  .asciiz ".$"
  .word word_hex
  .asciiz "emit"
  .word word_emit
  .asciiz "dup"
  .word word_dup
  .asciiz "drop"
  .word dpop_de
  .asciiz "swap"
  .word word_swap
  .asciiz "over"
  .word word_over
  .asciiz "rot"
  .word word_rot
  .asciiz "exit"
  .word word_exit
  .asciiz "words"
  .word word_words
_name_table_top:
  .byte $01
