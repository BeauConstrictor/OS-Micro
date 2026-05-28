  .include "mmap.asm"

  .org RUN_LOAD

fib:
  ld   a,0
  call print_num
  ld   a,1
  call print_num
  ld   e,0
  ld   d,1
  ld   b,10

  .repeat 12
  ld   a,e
  add  a,d
  call print_num
  ld   e,d
  ld   d,a
  .endrep

  ret

print_num:
  push af
  call num_out
  ld   a,'\n'
  out  (SERIAL),a
  pop  af
  ret

wait_key:
  in   a,(SERIAL)
  cp   0
  jr   z,wait_key
  ret

  .include "io.asm"
  .include "uninitialised.asm"
