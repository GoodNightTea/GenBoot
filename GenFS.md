# GenFS V2 Filesystem specifications
## Overview:
GenFS (genesis file system) is designed for simplicity for my bootloader and just to learn. I originally added it cause I was frustrated at fat12 format... now I am just sticking with it.
Version 2 introduces directory support while maintaining backwards compatibility.

### Design philosophy
* Bootloader friendly: can be read in 16 bit mode
* Simplicity: fixed size tables for easy parsing
* Scalable: Support for thousands of files
* Hierarchical: Directory support

### Disk Layout:
```
Sector 0:      Boot sector (512 bytes)
Sector 1:      Superblock (512 bytes) 
Sectors 2-3:   Stage 2 bootloader (1024 bytes) - BACKWARDS COMPATIBLE
Sectors 4-11:  Kernel (4096 bytes) - BACKWARDS COMPATIBLE
Sectors 12-27: File Allocation Table - FAT (16 sectors = 8192 bytes)
Sectors 28-43: Directory Table (16 sectors = 8192 bytes)  
Sectors 44-59: File Entry Table (16 sectors = 8192 bytes)
Sector 60+:    Data blocks
```
#### Note: Current implementation uses backwards compatibility by fixing Stage 2 and the kernel at specific locations for the bootloader
### Data structure:
#### Superblock (512 bytes)
```C
struct genfs_superblock {
    char     magic[8];           // "GENFS2\0\0"
    uint32_t version;            // File system version (2)
    uint32_t total_sectors;      // Total disk sectors
    uint32_t stage2_sector;      // Stage 2 location (sector 2)
    uint32_t kernel_sector;      // Kernel location (sector 3)
    uint32_t fat_start;          // FAT start sector (12)
    uint32_t fat_sectors;        // FAT size in sectors (16)
    uint32_t dir_start;          // Directory table start (28)
    uint32_t dir_sectors;        // Directory table sectors (16)
    uint32_t file_start;         // File entry table start (44)
    uint32_t file_sectors;       // File entry table sectors (16)
    uint32_t data_start;         // Data area start sector (60)
    uint32_t data_sectors;       // Data area size
    uint32_t max_files;          // Maximum files (2048)
    uint32_t max_dirs;           // Maximum directories (512)
    uint32_t files_used;         // Current file count
    uint32_t dirs_used;          // Current directory count
    uint32_t free_blocks;        // Free data blocks
    uint32_t block_size;         // Block size (512)
    char     volume_label[32];   // Volume name
    uint32_t created_time;       // FS creation timestamp
    uint32_t modified_time;      // Last modification
    uint8_t  reserved[400];      // Future expansion
};
```
### File entry (32 bytes)
```
struct genfs_file_entry {
    char     filename[16];       // Null-terminated filename
    uint32_t file_size;          // Size in bytes
    uint32_t start_sector;       // First data sector  
    uint32_t parent_dir_id;      // Parent directory ID (0 = root)
    uint16_t permissions;        // Unix-style permissions (rwxrwxrwx)
    uint16_t flags;              // File type flags
};
```
### Directory Entry (16 bytes)
```
struct genfs_directory {
    char     name[12];           // Directory name
    uint32_t dir_id;            // Unique directory ID (0 = root)
};
```
### File allocation table entry:
```
struct genfs_fat_entry {
    uint32_t next_block;         // Next block in chain (0xFFFFFFFF = end/free)
};
```

## Capacities:
* Max files: 2048 (16 sectors * 128 files/sectors)
* Max directories: 512 (16 sectors * 32Dirs/sector)
* Max file size: 2GB (sector addressing)
* Block size: 512 bytes
* Max filename: 15 chars + null terminator
### Backwards compatibility
we achieve that with the simple bootloader by:
* Placing Stage 2 at sector 2
* Placing kernel at sector 3-10 (4kb)
* Using GenFS builder python script to maintain that

this isnt the best implementation but it works, I will need to make things way more dynamic but as of rn. i will NOT touch it :)
