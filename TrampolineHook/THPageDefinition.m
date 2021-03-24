//
//  THPageLayout.m
//  TrampolineHook
//
//  Created by z on 2020/5/18.
//  Copyright © 2020 SatanWoo. All rights reserved.
//

#import "THPageDefinition.h"

void *THCreateDynamicePage(void *toMapAddress)
{
    if (!toMapAddress) return NULL;
    
    vm_address_t fixedPage = (vm_address_t)toMapAddress; // 构造的可执行代码 page 内存的起始地址
    
    vm_address_t newDynamicPage = 0;
    kern_return_t kernResult = KERN_SUCCESS;

    //分配 PAGE_SIZE * 2 大小的虚拟内存，内存起始地址为 newDynamicPage
    kernResult = vm_allocate(current_task(), &newDynamicPage, PAGE_SIZE * 2, VM_FLAGS_ANYWHERE);
    NSCAssert1(kernResult == KERN_SUCCESS, @"[THDynamicPage]::vm_allocate failed", kernResult);
    
    // 释放 newDynamicPage + PAGE_SIZE 之后 PAGE_SIZE 大小的虚拟内存
    vm_address_t newCodePageAddress = newDynamicPage + PAGE_SIZE;
    kernResult = vm_deallocate(current_task(), newCodePageAddress, PAGE_SIZE);
    NSCAssert1(kernResult == KERN_SUCCESS, @"[THDynamicPage]::vm_deallocate failed", kernResult);
    
    vm_prot_t currentProtection, maxProtection;
    // 将构造的 page 内存的起始地址开始 PAGE_SIZE 大小内存，映射到 newCodePageAddress 位置，使得这段内存可执行代码
    kernResult = vm_remap(current_task(), &newCodePageAddress, PAGE_SIZE, 0, 0, current_task(), fixedPage, FALSE, &currentProtection, &maxProtection, VM_INHERIT_SHARE);
    NSCAssert1(kernResult == KERN_SUCCESS, @"[THDynamicPage]::vm_remap failed", kernResult);
    
    // 返回分配的 2*PAGE_SIZE 大小的内存起始地址，第一个 PAGE_SIZE 为空，第二个为构造的汇编代码占用的内存
    // 第一个 PAGE_SIZE 用来保存 originIMP，会运行时进行修改
    // 因为和第二个 PAGE_SIZE 相差保持的是 PAGE_SIZE，所以 hook 后的桩位被调用后，当前位置 - PAGE_SIZE 即可得到保存 originIMP 对应的地址
    return (void *)newDynamicPage;
}
