<sanity_leaf>:
sub $0x98,%rsp
movq $0xfffffffffffffffe,0x20(%rsp)
lea 0x8859(%rip),%rdx
lea 0x28(%rsp),%rcx
call 0x140001c9c
nop
lea 0x50(%rsp),%rcx
call 0x140002150
nop
lea 0x87d4(%rip),%rax
mov %rax,0x50(%rsp)
lea 0x28(%rsp),%rdx
lea 0x68(%rsp),%rcx
call 0x140001f08
nop
lea 0x87d0(%rip),%rax
mov %rax,0x50(%rsp)
lea 0xb4d4(%rip),%rdx
lea 0x50(%rsp),%rcx
call 0x1400026e8
int3
