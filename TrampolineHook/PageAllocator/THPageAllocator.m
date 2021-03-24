//
//  THPageAllocator.m
//  TrampolineHook
//
//  Created by z on 2020/5/19.
//  Copyright © 2020 SatanWoo. All rights reserved.
//

#import "THPageAllocator.h"
#import "THPageDefinition.h"

@interface THPageAllocator()
@property (nonatomic, unsafe_unretained, readwrite) IMP redirectionFunction;
@property (nonatomic, strong) NSMutableArray *dynamicPages;
@end

@implementation THPageAllocator

- (instancetype)initWithRedirectionFunction:(IMP)redirectFunction
{
    self = [super init];
    if (self) {
        _redirectFunction = redirectFunction;   // 设置重定向的目标函数地址
    }
    return self;
}

- (IMP)allocateDynamicPageForFunction:(IMP)functionAdress
{
    if (!functionAdress) return NULL;
    
    void *dynamicePage = [self fetchCandidiateDynamicPage];
    
    if (!dynamicePage) return NULL;
    
    return [self replaceAddress:functionAdress inPage:dynamicePage];
}

#pragma mark - Abstract Function
- (void)configurePageLayoutForNewPage:(void *)newPage
{
    NSException *exception = [NSException exceptionWithName:@"com.satanwoo.pageallocator" reason:@"<configurePageLayoutForNewPage> must be override by subclass" userInfo:nil];
    [exception raise];
}

- (BOOL)isValidReusablePage:(void *)resuablePage
{
    NSException *exception = [NSException exceptionWithName:@"com.satanwoo.pageallocator" reason:@"<isValidReusablePage> must be override by subclass" userInfo:nil];
    [exception raise];
    
    return FALSE;
}

- (void *)templatePageAddress
{
    NSException *exception = [NSException exceptionWithName:@"com.satanwoo.pageallocator" reason:@"<templatePageAddress> must be override by subclass" userInfo:nil];
    [exception raise];
    
    return NULL;
}

- (IMP)replaceAddress:(IMP)functionAddress inPage:(void *)page
{
    NSException *exception = [NSException exceptionWithName:@"com.satanwoo.pageallocator" reason:@"<replaceAddress:inPage:> must be override by subclass" userInfo:nil];
    [exception raise];
    
    return NULL;
}

#pragma mark - Private
- (void *)fetchCandidiateDynamicPage
{
    void *reusablePage = [[self.dynamicPages lastObject] pointerValue];
    
    if (![self isValidReusablePage:reusablePage]) {
        
        void *toCopyAddress = [self templatePageAddress];   // 汇编中的 hook page 入口地址
        if (!toCopyAddress) return NULL;
        
        reusablePage = (void *)THCreateDynamicePage(toCopyAddress); // 根据入口地址通过 vm_remap copy 2*pagesize 创建一个可操作内存，后面会将内存和数据结构关联起来，便于存取 IMP 等
        if (!reusablePage) return NULL;
        
        [self configurePageLayoutForNewPage:reusablePage];
        
        [self.dynamicPages addObject:[NSValue valueWithPointer:reusablePage]];
    }
    return reusablePage;
}

#pragma mark - Getter
- (NSMutableArray *)dynamicPages
{
    if (!_dynamicPages) {
        _dynamicPages = @[].mutableCopy;
    }
    return _dynamicPages;
}


@end
