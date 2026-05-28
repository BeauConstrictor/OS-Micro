
  .section code

start:
  ld   sp,STACK_START
.loop:
  call find_kernel
  call load_kernel
  call start_kernel

; return in a the first sector of the file called '_k'
; note: only supports disks with < 16 files on disk before '_k'
; clobbers: a,b,de,hl
find_kernel:
  ld   hl,finding_msg
  call print
  ; the correct device is already loaded from bios
  ; start of the file table:
  ld   a,$02
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   hl,DEV_READ
  ld   b,16
.find_entry:
  ld   a,'.'
  out  (SERIAL),a
  call check_filename
  jr   nc,.found
  ld   de,16
  add  hl,de
  djnz .find_entry
.notfound:
  ld   hl,kernel_notfound
  call print
  halt
.found:
  ld   a,'\n'
  out  (SERIAL),a
  ld   a,l
  and  $f0
  or   $0f
  ld   l,a
  ld   a,(hl)
  ret

; load kernel starting from sector in a register
; clobbers: a,b,de,hl
load_kernel:
  ld   hl,loading_msg
  push af
  call print
  pop  af
  ld   hl,KERNEL
.chsect:
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   a,'.'
  out  (SERIAL),a
  ld   b,$ff
  ld   de,DEV_READ
.loop:
  ld   a,(de)
  ld   (hl),a
  inc  hl
  inc  de
  djnz .loop
  ld   a,(de)
  or   a
  jr   nz,.chsect
  ld   a,'\n'
  out  (SERIAL),a
  ret

start_kernel:
  ld   hl,starting_msg
  call print
  jp   KERNEL

; clear carry on matching (hl) with _k\0 or set it otherwise
; clobbers: a,hl
check_filename:
  push hl
  ld   a,(hl)
  cp   '_'
  jr   nz,.noteq
  inc  hl
  ld   a,(hl)
  cp   'k'
  jr   nz,.noteq
  inc  hl
  ld   a,(hl)
  cp   '\0'
  jr   nz,.noteq
  pop  hl
  xor  a
  ret
.noteq:
  pop  hl
  scf
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

; wait until the busy flag is 0
; clobbers: a
busy_wait:
  ld   a,(DEV_STATUS)
  and  BUSY
  jr   nz,busy_wait
  ret

finding_msg:
  .asciiz "\n\e[90mFinding kernel..."
loading_msg:
  .asciiz "Loading kernel..."
starting_msg:
  .asciiz "Starting kernel...\e[0m\n\n"
kernel_notfound:
  .asciiz "\e[31m\nKernel not found :(\n"

  .include "mmap.asm"
