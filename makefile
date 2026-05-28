ASM := vasmz80_oldstyle
ASMFLAGS := -dotdir -Fbin -esc

FS128_TOOL := python3 src/fs128-tool.py

.PHONY: all
all: build/img.bin build/disk

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
	$(ASM) $(ASMFLAGS) -o build/disk/fib src/fib.asm
	echo "Hello, world!" > build/disk/test.txt

.PHONY: build/img.bin
build/img.bin: build/bootloader.out build/disk | build
	$(FS128_TOOL) -b $< -o $@ build/disk/*

.PHONY: run
run: all
	ozm -m bdsk:build/img.bin@00 -m xm@01

.PHONY: clean
clean:
	rm -rf build
