//
//  THDynamicAllocator.m
//  TrampolineHook
//
//  Created by z on 2020/4/25.
//  Copyright © 2020 SatanWoo. All rights reserved.
//

#import "THSimplePageAllocator.h"
#import "THPageDefinition.h"

FOUNDATION_EXTERN id th_dynamic_page(id, SEL);  // 位于汇编中，动态页的开始，4k 大小

#if defined(__arm64__)
#import "THPageDefinition_arm64.h"
static const int32_t THSimplePageInstructionCount = 32;
//static const int32_t THSimplePageInstructionCount = 27;   // 测试去掉 nop 这里调整大小，改为 2^n 便于对齐，不对齐会出问题
#else
#error x86_64 & arm64e to be supported
#endif

static const size_t THNumberOfDataPerSimplePage = (THPageSize - THSimplePageInstructionCount * sizeof(int32_t)) / sizeof(THDynamicPageEntryGroup);  // 可以支持的 hook 数量，THPageSize 是 page 总大小，THSimplePageInstructionCount 是存放 hook sub 之外的指令的长度，每一组 hook 的 sub 存放在 THDynamicPageEntryGroup[2] 中

typedef struct {
    union { // 使用 union 这样里面的 struct 和 int32_t 复用内存，placeholder 只是为了占位对齐
        struct {
            IMP redirectFunction;
            int32_t nextAvailableIndex;
        };
        
        int32_t placeholder[THSimplePageInstructionCount];
    };
    
    THDynamicData dynamicData[THNumberOfDataPerSimplePage]; // 保存 originIMP
} THDataPage;

typedef struct {
    int32_t fixedInstructions[THSimplePageInstructionCount];
    THDynamicPageEntryGroup jumpInstructions[THNumberOfDataPerSimplePage];  // 保存 hook 后的地址
} THCodePage;

typedef struct {
    THDataPage dataPage;
    THCodePage codePage;
} THDynamicPage;    // 27 的话 0x4000 占不满，那这里codePage起始就不是0x4000了，就会出现问题，有余数字节数的偏差，所以还是整数的好


@implementation THSimplePageAllocator

- (void)configurePageLayoutForNewPage:(void *)newPage
{
    if (!newPage) return;
    
    THDynamicPage *page = (THDynamicPage *)newPage;
    page->dataPage.redirectFunction = self.redirectFunction;    // 设置重定向的目标地址，值会被初始化为 vm_remap 汇编 2*pagesize 的内存的入口，设置的就是 interceptor
}

- (BOOL)isValidReusablePage:(void *)resuablePage
{
    if (!resuablePage) return FALSE;
    // 使用的 hook sub 量达到了上限之前复用
    THDynamicPage *page = (THDynamicPage *)resuablePage;
    if (page->dataPage.nextAvailableIndex == THNumberOfDataPerSimplePage) return FALSE;
    return YES;
}

- (void *)templatePageAddress
{
    return &th_dynamic_page;
}

- (IMP)replaceAddress:(IMP)functionAddress inPage:(void *)page
{
    if (!page) return NULL;
    
    THDynamicPage *dynamicPage = (THDynamicPage *)page;
    
    int slot = dynamicPage->dataPage.nextAvailableIndex;
    
    // dataPage 中保存 originIMP，即 functionAddress
    dynamicPage->dataPage.dynamicData[slot].originIMP = (IMP)functionAddress;
    dynamicPage->dataPage.nextAvailableIndex++;

    // 返回 codePage 对应偏移位置构建的 sub，这个 sub 里有汇编指令进行目标 hook 函数调用、调用原函数等
    return (IMP)&dynamicPage->codePage.jumpInstructions[slot];
}


@end
