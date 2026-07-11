; fs.asm - The OS/M FS/128-2 library
;
; This library implements the FS/128-2 spec, not the original
; FS/128 spec, as it is more complicated and less foward-compatible.
;
; Most of these routines take so-called 'fids'. These are single byte
; identifiers of files on disk which you can obtain using ffind.
;
; Writing to a file does not work the same as in modern operating
; systems. It will not create a file if it does not exist, so you
; should make sure to create it first. Also, you should only write to
; a blank file, so existing files should be deleted and recreated if
; you want to change their contents.

  .ifndef FS_ASM
FS_ASM = 1

; return in a the fid of the null-terminated filename in hl
; return nc if file found, or c if not
; clobbers: a,b,c,de,hl
ffind_noerr:
  ld   d,h
  ld   e,l
  ld   a,$02
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   hl,DEV_READ
.chentry:
  ld   c,0
.cmp:
  ld   a,(hl)
  push af
  ld   a,(de)
  ld   b,a
  pop  af
  cp   b
  jr   nz,.noteq
  cp   '\0'
  jr   z,.found
  inc  hl
  inc  de
  inc  c
  jr   .cmp
.found:
  ld   b,0
  xor  a ; clear the carry flag
  ; go back to the start of the directory entry
  sbc  hl,bc
  ld   de,15
  ; go to sector byte
  add  hl,de
  ld   a,(hl)
  or   a
  ret
.noteq:
  ; subtract however many chars we matched from hl and de to go back
  ; to start
  ld   b,0
  xor  a
  sbc  hl,bc
  push hl
  ld   h,d
  ld   l,e
  sbc  hl,bc
  ld   d,h
  ld   e,l
  pop  hl
  ; go to next directory entry
  ld   bc,16
  add  hl,bc
  ld   a,l
  cp   0
  jr   z,.notfound
  jr   .chentry
.notfound:
  scf
  ret

; return in a the fid of the null-terminated filename in hl
; return nc if file found, or c if not
; clobbers: a,b,c,de,hi
ffind:
  call ffind_noerr
  ret  nc
  ld   hl,file_not_found
  call print
  jp   panic

; load the file starting at the sector in the a register into memory,
; starting at hl. returns the byte after the end of the file in hl.
; clobbers: a,de,hl
fload:
  ld   (DEV_SECTOR),a
  call busy_wait
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
  jr   nz,fload
  ret

; verify that the active disk contains an fs/128 filesystem
; returns 0 in carry if valid, otherwise returns 1
; clobbers: a,b,e,hl
chkdsk:
  ; preserve the original sector in e
  ld   a,(DEV_SECTOR)
  ld   e,a
  ; go to usage table
  ld   a,$01
  ld   (DEV_SECTOR),a
  call busy_wait
  ; ensure first 6 sectors are marked as used
  ld   b,6
  ld   hl,DEV_READ
.loop:
  ld   a,(hl)
  cp   $ff
  jr   nz,.noteq
  inc  hl
  djnz .loop
  ld   a,e
  ld   (DEV_SECTOR),a
  call busy_wait
  ; clear carry
  xor  a
  ret
.noteq:
  ; go back to original sector
  ld   a,e
  ld   (DEV_SECTOR),a
  call busy_wait
  scf
  ret

; format the active disk for fs/128
; clobbers: a,b,c,hl
fmtdsk:
  ld   a,(DEV_SECTOR)
  ld   c,a
  ; don't touch the boot sector
  ld   a,$01
  ld   (DEV_SECTOR),a
.loop:
  call .zero_sector
  ld   hl,DEV_SECTOR
  inc  (hl)
  ; keep zeroing sectors until we wrap back to sector 0
  jr   nz,.loop
  ; mark the first 6 sectors as used
  ld   a,$01
  ld   (DEV_SECTOR),a
  ld   hl,DEV_READ
  ld   b,6
.usedloop:
  ld   (hl),$ff
  inc  hl
  djnz .usedloop
  ld   a,c
  ld   (DEV_SECTOR),a
  ret
.zero_sector:
  ld   b,0
  ld   hl,DEV_READ
.zero_sector_loop:
  ld   (hl),0
  inc  hl
  djnz .zero_sector_loop
  ret

; return the next free sector on the active disk in a
; clobbers: a,b,c,e,hl
getfree:
  ; preserve the original sector we were in
  ld   a,(DEV_SECTOR)
  ld   e,a
  ; go to usage table
  ld   a,$01
  ld   (DEV_SECTOR),a
  call busy_wait
  ; loop over all 256 sectors
  ld   b,0
  ; keep track of which sector we're in
  ld   c,0
  ld   hl,DEV_READ
.loop:
  ld   a,(hl)
  ; check if marked as free
  cp   $00
  jr   z,.found
  inc  hl
  inc  c
  djnz .loop
  ld   hl,disk_full
  call print
  jp   panic
.found:
  ; go back to original sector
  ld   a,e
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   a,c
  ret

; set the usage byte for a sector (a) to the c register
; clobbers: a,b,c,de,hl
mark_sect:
  ld   e,a
  ld   d,0
  ; preserve original sector
  ld   a,(DEV_SECTOR)
  ld   b,a
  ; go to usage table
  ld   a,$01
  ld   (DEV_SECTOR),a
  call busy_wait
  ; write value to sector's corresponding byte
  ld   hl,DEV_READ
  add  hl,de
  ld   a,c
  ld   (hl),c
  ; restore original sector
  ld   a,b
  ld   (DEV_SECTOR),a
  call busy_wait
  ret

mkused:
  ld c,$ff
  jr mark_sect
mkfree:
  ld c,$00
  jr mark_sect

; return the sector number in a of a newly created file on the
; current disk. returns new file's id in a. you should probably
; rename it.
; clobbers: a,b,c,de,hl, sector
fnew:
  ; go to directory table
  ld   a,02
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   hl,DEV_READ
  ld   b,16
.loop:
  ld   a,(hl)
  cp   0
  jr   z,.found
  ld   de,16
  add  hl,de
  djnz .loop
  ld   hl,disk_full
  call print
  jp   panic
.found:
  ld   a,'n'
  ld   (hl),a
  inc  hl
  ld   a,'e'
  ld   (hl),a
  inc  hl
  ld   a,'w'
  ld   (hl),a
  inc  hl
  ld   a,'\0'
  ld   (hl),a
  ld   de,12
  add  hl,de
  push hl
  call getfree
  pop  hl
  ld   (hl),a
  push af
  call mkused
  pop  af
  ; zero out the allocated sector
  ld   (DEV_SECTOR),a
  push af
  call busy_wait
  pop  af
  ld   b,0
  ld   hl,DEV_READ
.zeroout:
  ld   (hl),0
  inc  hl
  djnz .zeroout
  ret

; rename the file in the a register to the string hl
; clobbers: a,b,c,de,hl
frename:
  ; save args for later
  ld   c,a
  ld   d,h
  ld   e,l

  ld   h,d
  ld   l,e
  ; preserve original sector
  ld   a,(DEV_SECTOR)
  push af
  ; go to directory table
  ld   a,$02
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   b,16
  ld   hl,DEV_READ
.find:
  push de
  ld   de,15
  add  hl,de
  pop  de
  ld   a,(hl)
  cp   c
  jr   z,.found
  inc  hl
  djnz .find
.notfound:
  ld   hl,file_not_found
  call print
  jp   panic
.found:
  push de
  ld   de,15
  xor  a
  sbc  hl,de
  pop  de
.copy:
  ld   a,(de)
  ld   (hl),a
  cp   0
  jr   z,.done
  inc  hl
  inc  de
  jr  .copy
.done:
  ; restore original sector
  pop  af
  ld   (DEV_SECTOR),a
  call busy_wait
  ret

; set the contents of the file in the a register to hl.
; NOTE: should not be used to overwrite a file's contents, only for
; writing to a new file. delete old ones first (for now).
; (a null-terminated string)
; clobbers: a,b,c,de,hl
fwrite:
  ld   d,h
  ld   e,l
.chsect:
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   a,(DEV_SECTOR)
  push de
  call mkused
  pop  de
  ; only 255 bytes of data per sector!
  ld   b,255
  ld   hl,DEV_READ
.write:
  ld   a,(de)
  ; if at end of string, stop
  cp   '\0'
  jr   z,.done
  ld   (hl),a
  inc  hl
  inc  de
  djnz .write
  call getfree
  ld   (hl),a
  ; we pass the new sector back into chsect
  jr   .chsect
.done:
  inc  b ; this time, we do want to write to the sector byte
.zeroout:
  ld   a,'\0'
  ld   (hl),a
  djnz .zeroout
  ret

; flush all changes to disk
; clobbers: a
fflush:
  ld   a,(DEV_SECTOR)
  ld   (DEV_SECTOR),a
  jp   busy_wait

; returns the number of sectors used in the active disk in a
; clobbers: a,b,c,hl, sector
disk_usg:
  ld   a,$01
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   hl,DEV_READ
  ld   b,0
  ld   c,0
.loop:
  ld   a,(hl)
  cp   $ff
  jr   nz,.unused
  inc  c
.unused:
  ld   a,c
  inc  hl
  djnz .loop
  ld   a,c
  ret

; return in a the number of sectors in file a
; clobbers: a,b,hl
fsize:
  ld   hl,DEV_READ
  ld   l,$ff ; sector byte
  ld   b,0
.chsect:
  ld   (DEV_SECTOR),a
  call busy_wait
  inc  b
  ld   a,(hl) ; read the next sector
  cp   0 ; check if there even is another sector
  jr   nz,.chsect
  ld   a,b
  ret

; delete the file in a
; clobbers: TODO
fdel:
  push af
.chsect:
  ld   (DEV_SECTOR),a
  call busy_wait
  ld   a,(DEV_SECTOR)
  call mkfree
  ld   hl,DEV_READ
  ld   l,$ff ; go straight to sector byte
  ld   a,(hl)
  cp   0
  jr   nz,.chsect
  ; now, we need to find that fid's entry in the directory
  ld   a,$02
  ld   (DEV_SECTOR),a
  ; go back to original sector
  pop  af
  ld   b,a
  ld   hl,DEV_READ
.findloop:
  ld   de,15
  add  hl,de
  ld   a,(hl)
  cp   b
  jr   z,.found
  ; we have already added 15, add one more to go to next entry
  inc  hl
  jr   .findloop
.found:
  ld   de,15
  xor  a ; clear carry flag
  sbc  hl,de
  ; clear the file entry
  ld   b,16
.clear:
  ld   (hl),0
  inc  hl
  djnz .clear
  ret

; handle an error
panic:
  ld   sp,STACK_START
  jp   KERNEL

disk_full:
  .asciiz "\e[31mThe disk is full.\n\e[0m"
file_not_found:
  .asciiz "\e[31mFile not found.\n\e[0m"

  .include "dev.asm"
  .include "mmap.asm"

  .endif ; FS_ASM
