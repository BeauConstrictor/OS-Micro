ASM := vasmz80_oldstyle
ASMFLAGS := -dotdir -Fbin -esc -Isrc/lib

FS128_TOOL := python3 src/fs128-tool.py

.PHONY: all
all: build/osm.bin build/disk

.PHONY: build
build:
	mkdir -p build

.PHONY: build/bootloader.out
build/bootloader.out: build
	$(ASM) $(ASMFLAGS) -o $@ src/bootloader.asm

.PHONY: build/kernel.out
build/kernel.out: build
	$(ASM) $(ASMFLAGS) -o $@ src/kernel.asm -L build/link.txt -Llo

.PHONY: build/disk
build/disk: build/kernel.out | build
	mkdir -p $@
	cp build/kernel.out build/disk/_k
	nroff welcome.groff > build/disk/welcome.txt
	$(ASM) $(ASMFLAGS) -o build/disk/hexmon src/hexmon.asm
	# $(ASM) $(ASMFLAGS) -Lni -L build/sym.txt -o build/disk/forth src/forth.asm
	$(ASM) $(ASMFLAGS) -o build/disk/pager src/pager.asm
	$(ASM) $(ASMFLAGS) -o build/disk/xo src/xo.asm
	$(ASM) $(ASMFLAGS) -o build/disk/edit src/edit.asm

.PHONY: build/osm.bin
build/osm.bin: build/bootloader.out build/disk | build
	$(FS128_TOOL) -b $< -o $@ build/disk/*

.PHONY: run
run: all
	clear
	@ozm -m bdsk:build/osm.bin@00 -m xmem@01

.PHONY: clean
clean:
	rm -rf build
