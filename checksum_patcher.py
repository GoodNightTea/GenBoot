#!/usr/bin/env python3

import sys
import struct

def patch_checksum(bootloader_path):
    
    try:
        with open(bootloader_path, 'rb') as f:
            data = bytearray(f.read())
    except FileNotFoundError:
        print(f"Error: {bootloader_path} not found")
        return False
    
    if len(data) != 512:
        print(f"Error: Bootloader must be exactly 512 bytes, got {len(data)}")
        return False
    
    if data[510:512] != b'\x55\xAA':
        print("Error: Invalid boot signature")
        return False
    
    checksum = sum(data[0:508]) & 0xFFFF  # 16-bit checksum with carry handling
    
    print(f"Calculated checksum: 0x{checksum:04X}")
    
    data[508:510] = struct.pack('<H', checksum)
    
    try:
        with open(bootloader_path, 'wb') as f:
            f.write(data)
    except Exception as e:
        print(f"Error writing file: {e}")
        return False
    
    print(f"checksum injected into {bootloader_path}")
    return True

def verify_checksum(bootloader_path):
    
    try:
        with open(bootloader_path, 'rb') as f:
            data = f.read()
    except FileNotFoundError:
        print(f"Error: {bootloader_path} not found")
        return False
    
    # Calculate checksum of first 508 bytes
    calculated = sum(data[0:508]) & 0xFFFF
    
    # Read stored checksum
    stored = struct.unpack('<H', data[508:510])[0]
    
    print(f"Calculated checksum: 0x{calculated:04X}")
    print(f"Stored checksum:     0x{stored:04X}")
    
    if calculated == stored:
        print("checksum verification PASSED")
        return True
    else:
        print("checksum verification FAILED")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 checksum_patcher.py <bootloader.bin>        # Patch checksum")
        print("  python3 checksum_patcher.py <bootloader.bin> verify # Verify checksum")
        return 1
    
    bootloader_path = sys.argv[1]
    
    if len(sys.argv) > 2 and sys.argv[2] == 'verify':
        success = verify_checksum(bootloader_path)
    else:
        success = patch_checksum(bootloader_path)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
