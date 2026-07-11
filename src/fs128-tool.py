import traceback
import argparse
import sys
import os

NEXT_SECTOR_LINK_POSTION = 255
SECTOR_SIZE = 256
SECTOR_COUNT = 256

FILE_CHAIN_END = 0x00
FILE_ENTRY_SIZE = 16

FREE_BYTE = 0x00
USED_BYTE = 0xff

LAST_METADATA_SECTOR = 5

class DiskFullError(Exception): ...
class BootSectorTooBigError(Exception): ...

def sector(num: int) -> int:
    return SECTOR_SIZE * num

def fail(text: str) -> None:
    print("\x1b[31m" + "fs128-tool: " + text + "\x1b[0m", file=sys.stderr)
    sys.exit(1)

class Filesystem:
    def __init__(self) -> None:
        self.image = bytearray(SECTOR_SIZE * SECTOR_COUNT)
        
        for i in range(LAST_METADATA_SECTOR+1):
            self.mark_used(i)
            
        self.file_table_end = sector(2)

        self.add_entry("./", 2)
        self.add_entry("../", 2)
        
    def is_used(self, sector_idx: int) -> int:
        return self.image[sector(1) + sector_idx] == USED_BYTE
    def mark_used(self, sector_idx: int) -> int:
        self.image[sector(1) + sector_idx] = USED_BYTE
    def mark_free(self, sector_idx: int) -> int:
        self.image[sector(1) + sector_idx] = FREE_BYTE
    def get_free(self) -> int:
        for i in range(LAST_METADATA_SECTOR+1, SECTOR_COUNT):
            if not self.is_used(i): return i
        raise DiskFullError("not enough space left to allocate more sectors")

    def add_entry(self, filename: str, sector_idx: int) -> None:
        if self.file_table_end >= sector(3) - FILE_ENTRY_SIZE:
            raise DiskFullError("directory full")
        
        for ch in filename.encode('ascii', errors="strict")[:14].ljust(15, b'\0'):
            self.image[self.file_table_end] = ch
            self.file_table_end += 1
        self.image[self.file_table_end] = sector_idx
        self.file_table_end += 1
        
    def add_file(self, filename: str, content: bytearray) -> list[int]:
        sector_idx = self.get_free()
        sectors = [sector_idx]

        self.add_entry(filename, sector_idx)
        
        byte_in_sector = 0
        self.mark_used(sector_idx)
        for byte in content:
            if byte_in_sector == NEXT_SECTOR_LINK_POSTION:
                byte_in_sector = 0
                new_sector = self.get_free()
                self.image[sector(sector_idx) + NEXT_SECTOR_LINK_POSTION] = new_sector
                self.mark_used(new_sector)
                sectors.append(new_sector)
                sector_idx = new_sector
            self.image[sector(sector_idx) + byte_in_sector] = byte
            byte_in_sector += 1
        self.image[sector(sector_idx) + NEXT_SECTOR_LINK_POSTION] = FILE_CHAIN_END
        
        return sectors

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="fs128-tool",
        description="generate fs/128-3 filesystem images",
    )
    
    parser.add_argument(
        "-b", "--boot",
        help="boot sector binary"
    )
    
    parser.add_argument(
        "-o", "--out",
        default="./a.out",
        help="path of the final image"
    )
    
    parser.add_argument(
        "-s", "--stdout",
        action="store_true",
        help="output the final image to stdout, instead of a file"
    )
    
    parser.add_argument(
        "-t", "--traceback",
        action="store_true",
        help="print full traceback information"
    )
    
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="print which sectors files are being "
    )

    parser.add_argument(
        "files",
        nargs="*",
        help="files to add to the image"
    )
    
    return parser.parse_args()          

def main(args: argparse.Namespace) -> None:
    fs = Filesystem()
    
    if args.boot:
        if not os.path.exists(args.boot):
            raise FileNotFoundError(f"{args.boot}: no such file or directory")
        with open(args.boot, "rb") as f:
            data = f.read()
            if len(data) > SECTOR_SIZE:
                raise BootSectorTooBigError("boot sector binary is larger than "
                                            "256 bytes")
            fs.image[:SECTOR_SIZE] = data.ljust(SECTOR_SIZE, b'\x00')
        
    for path in args.files:
        if not os.path.exists(path):
            fail(f"{path}: no such file or directory")
        name = os.path.basename(path)
        with open(path, "rb") as f:
            data = f.read()
        sectors = ", ".join(str(s) for s in fs.add_file(name, data))
        if args.verbose:
            print(f"fs128-tool: {path}: {sectors}", file=sys.stderr)
    
    if args.stdout:
        sys.stdout.buffer.write(fs.image)
        sys.stdout.buffer.flush()
    else:
        with open(args.out, "wb") as f:
            f.write(fs.image)
            
if __name__ == "__main__":
    args = parse_args()
    try:
        main(args)
    except Exception as e:
        if args.traceback:
            traceback.print_exc()
        else:
            fail(str(e))
