# head.s 包含32位保护模式初始化设置代码、时钟中断代码、系统调用中断代码和两个任务的代码。
# 在初始化完成之后程序移动到任务0开始执行，并在时钟中断控制下进行任务0和1之间的切换操作。
LATCH       = 11930         # 定时器初始计数值，即每隔10毫秒发送一次中断请求。
SCRN_SEL    = 0x18
TSS0_SEL    = 0x20
LDT0_SEL    = 0x28
TSS1_SEL    = 0x30
LDT1_SEL    = 0x38
.text
_main:
movl $0x10, %eax
mov %ax, %ds
lss init_stack, %esp

# 在新的位置重新设置IDT和GDT表。
call setup_idt
call setup_gdt
movl $0x10, %eax
mov %ax, %ds
mov %ax, %es
mov %ax, %fs
mov %ax, %gs
lss init_stack, %esp

# 设置8253定时芯片。把计时器通道0设置成每隔10毫秒向中断控制器发送一个中断请求信号。
movb $0x36, %al
movl $0x43, %eax
outb %al, %dx
movl $LATCH, %eax
movl $0x40, %edx
outb %al, %dx
movb %ah, %al
outb %al, %dx

# 在IDT表第8和128（0x80）项处分别设置定时中断门描述符和系统调用陷阱门描述符。
movl $0x00080000, %eax
movw $timer_interrupt, %ax
movw $0x8E00, %dx
movl $0x08, %ecx
lea idt(,%ecx,8), %esi
movl %eax, (%esi)
movl %edx, 4(%esi)
movw $system_interrupt, %ax
movw $0xEF00, %dx
movl $0x80, %ecx
lea idt(,%ecx,8), %esi
movl %eax, (%esi)
movl %edx, 4(%esi)

# 好了，现在我们为移动到任务0（任务A）中执行来操作堆栈内容，在堆栈中人工建立中断返回时的场景。
pushfl
andl $0xffffbfff, (%esp)
popfl
movl $TSS0_SEL, %eax
ltr %ax
movl $LDT0_SEL, %eax
lldt %ax
movl $0, current
sti
pushl $0x17
pushl $init_stack
pushfl
pushl $0x0f
pushl $task0
iret

# 以下是设置GDT和IDT中描述符项的子程序。
setup_gdt:
lgdt lgdt_opcode
ret

setup_idt:
lea ignore_int, %edx
movl $0x00080000, %eax
movw %dx, %ax
movw $0x7E00, %dx
lea idt, %edi
mov $256, %ecx
rp_idt:
movl %eax, (%edi)
movl %edx, 4(%edi)
addl $8, %edi
dec %ecx
jne rp_idt
lidt lidt_opcode
ret

# 显示字符子程序。取当前光标位置并把AL中的字符显示在屏幕上。整屏可显示80 * 25个字符。
write_char:
    push %gs
    pushl %ebx
    mov $SCRN_SEL, %ebx
    mov %bx, %gs
    movl scr_loc, %ebx
    shl $1, %ebx
    movb %al, %gs:(%ebx)
    shr $1, %ebx
    incl %ebx
    cmpl $2000, %ebx
    jb 1f 
    movl $0, %ebx
1:  movl %ebx, scr_loc
    popl %ebx
    pop %gs
    ret

# 以下是3个中断处理程序：默认中断、定时中断和系统调用中断
# ignore_int是默认的中断修理程序，若系统产生了其它中断，则会在屏幕上显示一个字符‘C’。
.align 2
ignore_int:
    push %ds
    pushl %eax
    movl $0x10, %eax
    mov %ax, %ds
    mov $67, %eax
    call write_char
    popl %eax
    pop %ds
    iret

# 这是定时中断处理程序。其中主要执行任务切换操作。
.align 2
timer_interrupt:
    push %ds
    pushl %eax
    movl $0x10, %eax
    mov %ax, %ds
    movb $0x20, %al
    outb %al, $0x20
    movl $1, %eax
    cmpl %eax, current
    je 1f
    movl %eax, current
    ljmp $TSS1_SEL, $0
    jmp 2f
1:  movl $0, current
    ljmp $TSS0_SEL, $0
2:  popl %eax
    pop %ds
    iret

# 系统调用中断 int 0x80 处理程序。该示例只有一个显示字符功能。
.align 2
system_interrupt:
    push %ds
    pushl %edx
    pushl %ecx
    pushl %ebx
    pushl %eax
    movl $0x10, %edx
    mov %dx, %ds
    call write_char
    popl %eax
    popl %ebx
    popl %ecx
    popl %edx
    pop %ds
    iret

/***************************/
current: .long 0
scr_loc: .long 0

.align 2
lidt_opcode:
    .word 256*8-1
    .long idt
lgdt_opcode:
    .word (end_gdt-gdt)-1
    .long gdt

.align 3
idt:
    .fill 256,8,0

gdt:
    .quad 0x0000000000000000
    .quad 0x00c09a00000007ff
    .quad 0x00c09200000007ff
    .quad 0x00c0920b80000002
    .word 0x68, tss0, 0xe900, 0x0       # 第5个是TSS0段的描述符。其选择符是0x20。
    .word 0x40, ldt0, 0xe200, 0x0       # 第6个是LDT0段的描述符。其选择符是0x28。
    .word 0x68, tss1, 0xe900, 0x0       # 第7个是TSS1段的描述符。其选择符是0x30。
    .word 0x40, ldt1, 0xe200, 0x0       # 第8个是LDT1段的描述符。其选择符是0x38。
end_gdt:
    .fill 128,4,0                       # 初始内核堆栈空间
init_stack:                             # 刚进入保护模式时用于加载SS:ESP堆栈指针值。
    .long init_stack                    # 堆栈段偏移位置。
    .word 0x10                          # 堆栈段同内核数据段。

# 下面是任务0的LDT表段中的局部段描述符。
.align 3
ldt0:
    .quad 0x0000000000000000            # 第1个描述符，不用。
    .quad 0x00c0fa00000003ff            # 第2个局部代码段描述符，对应选择符是0x0f。
    .quad 0x00c0f200000003ff            # 第3个局部数据段描述符，对应选择符是0x17。
# 下面是任务0的TSS段的内容。注意其中标号等字段在任务切换时不会改变。
tss0:
    .long 0                             /* back link*/
    .long krn_stk0, 0x10                /* esp0, ss0 */
    .long 0, 0, 0, 0, 0                 /* esp1, ss1, esp2, ss2, cr3 */
    .long 0, 0, 0, 0, 0                 /* eip, eflags, eax, ecx, edx */
    .long 0, 0, 0, 0, 0                 /* ebx, esp, ebp, esi, edi */
    .long 0, 0, 0, 0, 0, 0              /* es, cs, ss, ds, fs, gs */
    .long LDT0_SEL, 0x80000000          /* ldt, trace bitmap */

    .fill 128,4,0                       # 这是任务0的内核栈空间。
krn_stk0:

# 下面是任务1的LDT表段内容和TSS段内容。
.align 3
ldt1:
    .quad 0x0000000000000000            # 第1个描述符，不用。
    .quad 0x00c0fa00000003ff            # 选择符是0x0f, 基地址 = 0x00000。
    .quad 0x00c0f200000003ff            # 选择符是0x17, 基地址 = 0x00000。

tss1:
    .long 0                             /* back link */
    .long krn_stk1, 0x10                /* esp0, ss0 */
    .long 0, 0, 0, 0, 0                 /* esp1, ss1, esp2, ss2, cr3 */
    .long task1, 0x200                  /* eip, eflags */
    .long 0, 0, 0, 0                    /* eax, ecx, edx, ebx */
    .long usr_stk1, 0, 0, 0             /* esp, ebp, esi, edi */
    .long 0x17, 0x0f, 0x17, 0x17, 0x17, 0x17    /* es, cs, ss, ds, fs, gs */
    .long LDT1_SEL, 0x80000000          /* ldt, trace bitmap */

    .fill 128,4,0                       # 这是任务1的内核栈空间。其用户栈直接使用初始栈空间。
krn_stk1:

# 下面是任务0和任务1的程序，它们分别循环显示字符‘A’和‘B’。
task0:
    movl $0x17, %eax
    movw %ax, %ds
    mov $65, %al
    int $0x80
    movl $0xfff, %ecx
1:  loop 1b
    jmp task0

task1:
    mov $70, %al
    int $0x80
    movl $0xfff, %ecx
1:  loop 1b
    jmp task1

    .fill 128,4,0           # 这是任务1的用户栈空间
usr_stk1: