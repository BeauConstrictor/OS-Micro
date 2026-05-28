ASM := vasmz80_oldstyle
ASMFLAGS := -dotdir -Fbin -esc

FS128_TOOL := python3 src/fs128-tool.py

.PHONY: all
all: build/img.bin

.PHONY: build
build:
	mkdir -p build

.PHONY: build/bootloader.out
build/bootloader.out: build
	$(ASM) $(ASMFLAGS) -o $@ src/bootloader.asm

.PHONY: build/kernel.out
build/kernel.out: build
	$(ASM) $(ASMFLAGS) -o $@ src/kernel.asm -L build/link.txt -Llo

build/img.bin: build/bootloader.out build/kernel.out | build
	cp build/kernel.out build/_k
	$(FS128_TOOL) -b $< -o $@ build/_k
	rm build/_k

.PHONY: run
run: all
	ozm -m bdsk:build/img.bin@00

.PHONY: clean
clean:
	rm -rf build
