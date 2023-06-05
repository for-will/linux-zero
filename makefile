
zero:
	nasm boot.S -o boot
	dd if=boot of=master.img bs=512 count=1 conv=notrunc
	bochs -q -unlock


hello:
	nasm hello.asm -o hello.bin
	dd if=hello.bin of=master.img bs=512 count=1 conv=notrunc
	bochs -q -unlock
