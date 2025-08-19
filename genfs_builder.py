#!/usr/bin/env python3


import struct
import os
import sys

class GenFS:
    def __init__(self):
        self.files = []
        self.sector_size = 512
        self.floppy_size = 1440 * 1024  # 1.44MB standard floppy
        self.total_sectors = self.floppy_size // self.sector_size  # 2880 sectors
        
    def add_file(self, filename, data):
        if len(self.files) >= 16:
            raise Exception("GenFS supports maximum 16 files")
        
        if len(filename) > 15:
            raise Exception(f"Filename '{filename}' too long (max 15 chars)")
            
        self.files.append({
            'name': filename,
            'data': data,
            'size': len(data)
        })
        
    def build_image(self, bootloader_path, output_path):
        
        try:
            with open(bootloader_path, 'rb') as f:
                bootloader = f.read()
        except FileNotFoundError:
            print(f"Error: Bootloader '{bootloader_path}' not found")
            return False
            
        if len(bootloader) != 512:
            print(f"Error: Bootloader must be exactly 512 bytes, got {len(bootloader)}")
            return False
        
        next_sector = 2  # Sector 0 = boot, Sector 1 = file table
        
        for file_info in self.files:
            file_info['start_sector'] = next_sector
            sectors_needed = (file_info['size'] + 511) // 512  # Round up
            next_sector += sectors_needed
            
        if next_sector > self.total_sectors:
            print(f"Error: Files too large for 1.44MB floppy!")
            print(f"Need {next_sector} sectors, but only have {self.total_sectors}")
            return False
        
        file_table = bytearray(512)
        
        for i, file_info in enumerate(self.files):
            offset = i * 32
            
            # Filename (16 bytes, null-terminated)
            name_bytes = file_info['name'].encode('ascii')[:15]
            file_table[offset:offset+len(name_bytes)] = name_bytes
            
            # File size (4 bytes, little endian)
            file_table[offset+16:offset+20] = struct.pack('<I', file_info['size'])
            
            # Starting sector (4 bytes, little endian)  
            file_table[offset+20:offset+24] = struct.pack('<I', file_info['start_sector'])
            
            # Reserved fields (8 bytes, zeros)
            # Already zero from bytearray initialization
        
        image = bytearray(self.floppy_size)
        
        image[0:512] = bootloader
        
        image[512:1024] = file_table
        
        for file_info in self.files:
            start_byte = file_info['start_sector'] * 512
            end_byte = start_byte + file_info['size']
            image[start_byte:end_byte] = file_info['data']
        
        try:
            with open(output_path, 'wb') as f:
                f.write(image)
        except Exception as e:
            print(f"Error writing image: {e}")
            return False
            
        print(f"  image created: {output_path}")
        print(f"  Size: {len(image)} bytes ({len(image)//512} sectors)")
        print(f"  Files: {len(self.files)}")
        
        for i, file_info in enumerate(self.files):
            print(f"    {i+1}. {file_info['name']} - {file_info['size']} bytes @ sector {file_info['start_sector']}")
            
        return True

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 genfs_builder.py <bootloader.bin> <output.img> [file1] [file2] ...")
        return 1
    
    bootloader_path = sys.argv[1]
    output_path = sys.argv[2]
    file_paths = sys.argv[3:]
    
    fs = GenFS()
    
    for file_path in file_paths:
        try:
            with open(file_path, 'rb') as f:
                data = f.read()
            
            # Use just the filename, not the full path
            filename = os.path.basename(file_path).upper()
            fs.add_file(filename, data)
            
        except FileNotFoundError:
            print(f"Error: File '{file_path}' not found")
            return 1
        except Exception as e:
            print(f"Error adding file '{file_path}': {e}")
            return 1
    

if __name__ == "__main__":
    sys.exit(main())
