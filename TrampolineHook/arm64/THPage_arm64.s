#if defined(__arm64__)

.text
.align 14
.globl _th_dynamic_page

interceptor:
.quad 0                     ;分配 8 个字节，初始化为 0，因为设置了 .align 14，所以和下面的 _th_entry 相差 4k，就落在 dataPage 入口处，代码中会设置这里为重定向函数地址

.align 14
_th_dynamic_page:

_th_entry:

nop
nop
nop
nop
nop


sub x12, lr,   #0x8
sub x12, x12,  #0x4000      ;减去 PAGESIZE 再减去 0x8，就是对应的 originIMP 所在地址，即和 mov x13, lr 对应的地址，保持偏移正确，地址占 8 个字节
mov lr,  x13                ;x13 保存的是目标 hook 函数被调用时的下一行地址，设置给 lr 便于结束时跳回

ldr x10, [x12]              ;提取 originIMP 到 x10

stp q0,  q1,   [sp, #-32]!
stp q2,  q3,   [sp, #-32]!
stp q4,  q5,   [sp, #-32]!
stp q6,  q7,   [sp, #-32]!

stp lr,  x10,  [sp, #-16]!
stp x0,  x1,   [sp, #-16]!
stp x2,  x3,   [sp, #-16]!
stp x4,  x5,   [sp, #-16]!
stp x6,  x7,   [sp, #-16]!
str x8,        [sp, #-16]!  ;以上都是保存寄存器相关，栈操作是 16 字节对齐

ldr x8,  interceptor        ;label 能得到相对偏移
blr x8                      ;跳转到重定向目标函数并返回

ldr x8,        [sp], #16
ldp x6,  x7,   [sp], #16
ldp x4,  x5,   [sp], #16
ldp x2,  x3,   [sp], #16
ldp x0,  x1,   [sp], #16
ldp lr,  x10,  [sp], #16

ldp q6,  q7,   [sp], #32
ldp q4,  q5,   [sp], #32
ldp q2,  q3,   [sp], #32
ldp q0,  q1,   [sp], #32      ;以上都是恢复寄存器相关

br  x10                 ;调用 x10 保存的原函数地址，并且不会设置 lr，结束后跳转到 lr

.rept 2034              ;(4096 - 32)/2
mov x13, lr             ;lr 是目标 hook 函数被调用时的下一行地址，这里保存下来，以便后续跳回
bl _th_entry;           ;lr 是当前桩位被调用时的下一行地址，即 bl _th_entry; 之后的一条指令的起始地址
.endr

#endif

# 赋值就是将新调用地方放到 dynamicpage 中，原有impl保存到codepage
# 为什么要对齐，非4的倍数有什么问题？(0x4000 - 27*4)/8
#vm_remap
# 64位上是 16kb 对齐，但是 32 就不一定，所以要支持 32 就得用 arm64 arm32 的宏走不同的汇编函数
