# This is a very simple bootloader + kernel which I will be expanding with features into a very small OS.
### Note: This will not be the next ubuntu, this is just my graduation project. If bugs are found please reach out! 

## Workflow is pretty easy:
This bootchain uses the NASM assembler. The kernel files are seperated and use the -I include option to tie them together.
When changes are made or you want to compile it yourself:
* nasm -f bin *.asm -o build/*.bin
  if a file is included, the -I options is needed
* nasm -f bin -I kernel/ kernel/*.asm -o build/*bin

after that we patch all the files together via my own File System calle GenFS:

* python3 tools/genfs_v2_builder.py build/boot.bin build/images/genos.img build/stage2.bin build/kernel.bin

after that it can be launched via qemu using a floppy format:

* qemu-system-x86_64 -drive file=build/images/genos.img,format=raw,if=floppy

it should launch and display the basic prints, a heartbeat and colors via VGA!
### Discord: GoodNightTea
