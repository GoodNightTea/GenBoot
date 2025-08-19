## Workflow is pretty easy:
use the nasm assembler to assemble all .asm i.e:
  * nasm -f bin boot.asm -o boot.bin
    
create and inject the checksum for boot.bin and [optional] verify it, its pretty basic as its a poc
  * python3 checksum_patcher.py <bootloader.bin> verify 

 compile all with the genfs_builder into a .img
  * python3 genfs_builder.py <bootloader.bin> <output.img> [file1] [file2]

it should launch and display the basic kernels print
