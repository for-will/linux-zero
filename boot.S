BOOTSEQ equ 0x07c0
SYSSEG  equ 0x1000
SYSLEN  equ 17

start:
    jmp BOOTSEQ:go

go:
mov ax, cx
mov ds, ax
mov ss, ax
mov sp, 0x400

;; 加载内核代码到内存0x10000开始处。
load_system:
mov dx, 0x0000              ; DH-磁头吓 DL-驱动器号
mov cx, 0x0002              ; CH-10位磁道号低8位 CL-位7、6是磁道号高2位，位5-0起始扇区号（从1计）
mov ax, SYSSEG
mov es, ax          
xor bx, bx                  ; ES:BX-读入扇区位置（0x1000:0x0000）
mov ax, 0x200+SYSLEN        ; AH-读扇区功能号（2） AL-需读的扇区数（17）
int 0x13                    ; 利用BIOS中断 int 0x13功能2从启动盘读取head代码
jnc ok_load
die:
jmp die

;; 把内核代码移动到内存0开始处。共移动8KB字节（内核长度不超过8KB）
ok_load:
cli
mov ax, SYSSEG
mov ds, ax
xor ax, ax
mov es, ax
mov cx, 0x1000
sub si, si
sub di, di
rep movsw
;;加载IDT和GDT基地址寄存器IDTR和GDTR。
mov ax, BOOTSEQ
mov ds, ax
lidt [idt_48]
lgdt [gdt_48]

;; 设置控制寄存器CR0（即机器状态字），进入保护模式。段选择符值8对应GDT表中第2wh段描述符。
mov ax, 0x0001
lmsw ax                 ; 将源操作数加载到机器状态字，即寄存器 CR0 的位 0 到 15
jmp 8:0

;; 下面是全局描述符表GDT的内容。其中包含3个段描述符。第1个不用，第2个是代码和数据段描述符。
gdt:
dw 0,0,0,0            ; 段描述符0，不用。每个描述符项占8字节。

dw 0x07FF             ; 段描述符1。8MB - 段限长值=2047（2048*4096=8MB）。
dw 0x0000             ; 段基地址=0x0000
dw 0x9A00             ; 是代码段，可读/执行。
dw 0x00C0             ; 段属性颗粒度=4KB，80386

dw 0x07FF             ; 段描述符2。 8MB - 段限长值=2047
dw 0x0000             ; 段基地址=0x0000
dw 0x9200             ; 昰数据段，可读写。
dw 0x00C0             ; 段属性颗粒度=4KB，80386。

;; 下面分别是LIDT和LGDT指令的6字节操作数。
idt_48:
dw 0                    ; IDT表长度是0
dw 0, 0                 ; IDT表的线性地址也是0

gdt_48:
dw 0x7ff                ; GDT表长度是2048字节，可容纳256个描述符项。
dw 0x7c00+gdt, 0        ;GDT表的线性基地址在0x7c0段的偏移gdt处。



hello_world:
mov ax, 3
int 0x10 ; 将显示模式设置成文本模式

mov ax, 0xb800
mov ds, ax

mov byte [0], 'h'
mov byte [2], 'e'
mov byte [4], 'l'
mov byte [6], 'l'
mov byte [8], 'o'
mov byte [10], ','
mov byte [12], ' '
mov byte [14], 'w'
mov byte [16], 'o'
mov byte [18], 'r'
mov byte [20], 'l'
mov byte [22], 'd'

halt:
	jmp halt

times 510 - ($ - $$) db 0
db 0x55, 0xaa
