#!/usr/bin/env python3
"""
GenFS v2 Image Builder - FIXED VERSION
Creates GenFS v2 file system images with directory support
"""

import struct
import os
import sys
import time

class GenFSv2Builder:
    def __init__(self, image_size_mb=1.44):
        """Initialize GenFS v2 builder"""
        self.image_size = int(image_size_mb * 1024 * 1024)
        self.sector_size = 512
        self.total_sectors = self.image_size // self.sector_size
        
        # Layout constants - BACKWARDS COMPATIBLE
        self.superblock_sector = 1
        self.stage2_sector = 2
        self.kernel_sector = 3
        self.fat_start = 4
        self.fat_sectors = 16
        self.dir_start = 20  
        self.dir_sectors = 16
        self.file_start = 36
        self.file_sectors = 16
        self.data_start = 52
        
        # Limits
        self.max_files = 2048
        self.max_dirs = 512
        self.max_blocks = (self.total_sectors - self.data_start)
        
        # Data structures
        self.directories = {}
        self.files = []
        self.fat = [0xFFFFFFFF] * self.max_blocks
        self.next_dir_id = 1
        self.next_file_id = 1
        self.next_free_block = 0
        
        # FIXED: Initialize boot file data
        self.stage2_data = None
        self.kernel_data = None
        
        # Add root directory
        self.directories[0] = {
            'name': '',
            'id': 0,
            'parent_id': 0
        }
        
        print(f"GenFS v2 Builder initialized (Backwards Compatible)")
        print(f"  Image size: {image_size_mb:.2f} MB ({self.total_sectors} sectors)")
        print(f"  Stage 2 sector: {self.stage2_sector}")
        print(f"  Kernel sector: {self.kernel_sector}")
        print(f"  Data area: sectors {self.data_start}-{self.total_sectors-1}")
        print(f"  Max files: {self.max_files}")
        print(f"  Max directories: {self.max_dirs}")
    
    def create_directory(self, name, parent_id=0):
        """Create a new directory"""
        if len(self.directories) >= self.max_dirs:
            raise Exception(f"Maximum {self.max_dirs} directories supported")
        
        if len(name) > 11:
            raise Exception(f"Directory name '{name}' too long (max 11 chars)")
        
        dir_id = self.next_dir_id
        self.directories[dir_id] = {
            'name': name,
            'id': dir_id,
            'parent_id': parent_id
        }
        self.next_dir_id += 1
        
        print(f"  Created directory: {name} (ID: {dir_id}, parent: {parent_id})")
        return dir_id
    
    def add_file(self, filepath, data, parent_dir_id=0, permissions=0o755):
        """Add a file to the file system"""
        
        filename = os.path.basename(filepath)
        
        # Special handling for boot files
        if filename.upper() == 'STAGE2.BIN':
            if len(data) > 512:
                raise Exception("Stage 2 must be ≤ 512 bytes for compatibility")
            self.stage2_data = data.ljust(512, b'\x00')
            print(f"  Reserved Stage 2 at sector {self.stage2_sector}")
            return -1
            
        if filename.upper() == 'KERNEL.BIN':
            max_kernel_size = 8 * 512  # 4KB limit
            if len(data) > max_kernel_size:
                raise Exception(f"Kernel too large: {len(data)} bytes (max {max_kernel_size})")
            sectors_needed = (len(data) + 511) // 512
            self.kernel_data = data.ljust(sectors_needed * 512, b'\x00')
            print(f"  Reserved Kernel at sector {self.kernel_sector} ({sectors_needed} sectors, {len(data)} bytes)")
            return -2
        
        # Regular file handling (simplified for now)
        print(f"  Added file: {filename} ({len(data)} bytes) - Regular file handling not implemented yet")
        return self.next_file_id
    
    def build_image(self, bootloader_path, output_path):
        """Build complete GenFS v2 image"""
        
        # Read bootloader
        try:
            with open(bootloader_path, 'rb') as f:
                bootloader = f.read()
        except FileNotFoundError:
            print(f"Error: Bootloader '{bootloader_path}' not found")
            return False
        
        if len(bootloader) != 512:
            print(f"Error: Bootloader must be 512 bytes, got {len(bootloader)}")
            return False
        
        # Create image
        image = bytearray(self.image_size)
        
        # Write bootloader
        image[0:512] = bootloader
        
        # Write Stage 2 at fixed sector
        if self.stage2_data:
            image[self.stage2_sector*512:(self.stage2_sector+1)*512] = self.stage2_data
        
        # Write Kernel at fixed sector  
        if self.kernel_data:
            kernel_sectors = len(self.kernel_data) // 512
            start_byte = self.kernel_sector * 512
            end_byte = start_byte + len(self.kernel_data)
            image[start_byte:end_byte] = self.kernel_data
        
        # Write basic superblock (minimal for now)
        superblock = bytearray(512)
        superblock[0:8] = b'GENFS2\x00\x00'
        image[512:1024] = superblock
        
        # Write image to disk
        try:
            with open(output_path, 'wb') as f:
                f.write(image)
        except Exception as e:
            print(f"Error writing image: {e}")
            return False
        
        print(f"\n✓ GenFS v2 image created: {output_path}")
        print(f"  Boot files: Stage 2 @ sector {self.stage2_sector}, Kernel @ sector {self.kernel_sector}")
        
        return True

def main():
    if len(sys.argv) < 4:
        print("Usage: python3 genfs_v2_builder.py <bootloader.bin> <output.img> <stage2.bin> <kernel.bin>")
        return 1
    
    bootloader_path = sys.argv[1]
    output_path = sys.argv[2] 
    stage2_path = sys.argv[3]
    kernel_path = sys.argv[4]
    
    # Create GenFS v2 instance
    fs = GenFSv2Builder()
    
    # Add Stage 2
    try:
        with open(stage2_path, 'rb') as f:
            stage2_data = f.read()
        fs.add_file('STAGE2.BIN', stage2_data)
    except Exception as e:
        print(f"Error adding Stage 2: {e}")
        return 1
    
    # Add Kernel
    try:
        with open(kernel_path, 'rb') as f:
            kernel_data = f.read()
        fs.add_file('KERNEL.BIN', kernel_data)
    except Exception as e:
        print(f"Error adding kernel: {e}")
        return 1
    
    # Build image
    if fs.build_image(bootloader_path, output_path):
        print(f"\nTest with: qemu-system-x86_64 -drive file={output_path},format=raw,if=floppy")
        return 0
    else:
        return 1

if __name__ == "__main__":
    sys.exit(main())
