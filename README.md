# OS/Micro

OS/Micro is an experimental disk operating system for the [Ozpex
Micro](https://github.com/beauconstrictor/ozpex-micro), taking heavy
inspiration from CP/M.

![A screenshot of the help command](assets/screenshot.png)

The operating system is built in 3 layers:

1. The bootloader, which is very minimal as it has to fit into just
   256 bytes.
2. The libraries, which implement the filesystem, I/O and interacting
   with external devices.
3. The shell, which allows the user to run simple commands which wrap
   library functions and load programs from disk.

# Getting Started

To boot OS/M, you will first need to install the latest release of the
[Ozpex Micro emulator](https://github.com/beauconstrictor/ozpex-micro).
This is the fantasy computer that OS/M runs under. Then, download the
latest release of OS/M from this repo. You can then boot the operating
system like this (assuming you have `osm.bin` in your directory):

```sh
ozm -m bdsk:osm.bin@0
```

This distribution image also includes two programs: a hex monitor and
a basic pong game (which uses vim keybinds for movement). The hex
monitor uses quite an archaic syntax which is explained in the [source
file](src/monitor.asm).

You can easily write your own programs for OS/M that statically link
with the OS's libraries. Using
[`vasm`](http://www.compilers.de/vasm.html), you can compile this
hello world program:

```
  .include "mmap.asm"

  .org RUN_LOAD

start:
  ld   hl,message
  call print
  ret

message:
  .asciiz "Hello, world!\n"

  .include "io.asm"
```

...like this:

```sh
vasmz80_oldstyle -dotdir -Fbin -esc hello.asm -o hello
```

As long as you have copied the needed libraries (`mmap.asm` and
`io.asm`) from this repo's `src/` into your directory.

Then, you just have to create a disk image with your program on it.
This repository includes a [utility](src/fs128-tool.py) just for this
purpose (you need Python to run the tool):

```
python3 fs128-tool.py hello -o mydisk.bin
```

Once you have a disk image, you just need to boot into OS/M and run
your program!

```
$ ozm -m bdsk:osm.bin@0 -m disk:mydisk.bin@1
00 ~> dsk 01
01 ~> dir
06# hello
01 ~> run 06
Hello, world!
01 ~>
```

That's all it takes to develop for OS/M!

## License

This project is licensed under the GNU GPL-2.0
