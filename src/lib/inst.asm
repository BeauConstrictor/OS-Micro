; inst.asm - Constants for Z80 instructions.
;
; This library maps readable constants to Z80 instruction bytes.
;
; NOTE: not all instructions are currently supported.

INST_LD_DE_NN  = $11 ; ld   de,nn
INST_SBC_HL_DE = $52 ; sbc  hl,de   - MISC PREFIXED
INST_HALT      = $76 ; halt
INST_OR_A      = $b7 ; or   a
INST_JP_NN     = $c3 ; jp   nn
INST_RET       = $c9 ; ret
INST_JP_Z      = $ca ; jp   z,nn
INST_CALL_NN   = $cd ; call nn
PREFIX_MISC    = $ed ;
