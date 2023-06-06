ubuntu:
	nasm boot.S -o boot
	dd if=boot of=Image bs=512 count=1 conv=notrunc
	gcc-12 -c -o head.o -m32 head.s		
	ld -m elf_i386 -Ttext 0 -e startup_32 -x -s -o system head.o
	dd bs=512 if=system of=Image skip=8 seek=1 conv=notrunc
	bochs -q -unlock

gas:
	nasm boot.S -o boot
	dd if=boot of=Image bs=512 count=1 conv=notrunc
	as -arch i386 -o head.o head.s 
	dd bs=280 if=head.o of=head.bin skip=1
	dd bs=512 if=head.bin of=Image seek=1 conv=notrunc
	bochs -q -unlock
	# -m elf_i386 -Ttext 0 -e startup_32 -s -x -M 
	
zero:
	nasm boot.S -o boot
	dd if=boot of=Image bs=512 count=1 conv=notrunc
	nasm -f bin -o head.bin head.nasm
	dd bs=512 if=head.bin of=Image seek=1 conv=notrunc
	bochs -q -unlock


hello:
	nasm hello.asm -o hello.bin
	dd if=hello.bin of=master.img bs=512 count=1 conv=notrunc
	bochs -q -unlock
