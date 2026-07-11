# OS/Micro

An experimental disk operating system for the [Ozpex Micro](https://github.com/beauconstrictor/ozpex-micro), taking heavy inspiration from CP/M.

![A screenshot of the help command](assets/screenshot.png)

The operating system is built in 4 layers:

1. The bootloader, which is very minimal as it has to fit into just 256 bytes.
2. The libraries, which implement the filesystem, I/O and interacting with external devices.
3. The shell, which allows the user to run simple commands which wrap library functions and load programs from disk.
4. The userland programs, which are more complex and interactive than the shell commands.

# Getting Started

To boot OS/M, you will first need to install the latest release of the [Ozpex Micro emulator](https://github.com/beauconstrictor/ozpex-micro).  This is the fantasy computer that OS/M runs under. Then, download the latest release of OS/M from this repo. You can then boot the operating system like this (assuming you have `osm.bin` in your directory):

```sh
ozm -m bdsk:osm.bin@0
```

This distribution image also includes a few small programs to help you get started, although the primary goal of OS/M is to use it as a development target.

For a complete on interacting with the system and developing your own software for it, run this command:

```
00 ~> pager welcome.txt
```

## Shell

OS/Micro's shell uses 3 letter commands, followed by any number of arguments. If you want to read a file, use the `prn 00` command. If you want to run a command, just type it's name.

If you are curious how the filesystem works, read the FS/128 [spec](https://github.com/BeauConstrictor/OS-128/blob/main/filesystem.md). Note that the filesystem actually implemented in OS/M is [FS/128-3](/specs/fs128-3.md), which adds support for directories.

## License

This project is licensed under the GNU GPL-2.0
