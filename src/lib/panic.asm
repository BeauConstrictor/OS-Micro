; panic.asm - an exception library
;
; a 'panic' in os/m terms is like an exception. by default, it crashes
; the entire program, but you can easily create a panic handler around
; any group of subroutine calls and even handle specific errors.
;
; just overwrite the panic_vector to use your own handler, but make
; sure to call reset_panics once you are done.
;
; error codes are passed to the panic handler in hl, and are actually
; addresses to a null-terminated string, so you can either compare hl
; against known error addresses or just print the message if you don't
; really care.

; jump to the current panic handler
; clobbers <doesn't return>
panic_vector:
  .word default_panic

panic:
  ld   de,(panic_vector)
  push de
  ret

; reset the panic vector to its default value
; clobbers: <none>
reset_panics:
  push hl
  ld   hl,default_panic
  ld   (panic_vector),hl
  pop  hl
  ret

default_panic:
  ld   sp,STACK_START
  jp   KERNEL
