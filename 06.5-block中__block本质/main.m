//
//  main.m
//  06.5-block中__block本质
//
//  Created by 刘光强 on 2020/2/5.
//  Copyright © 2020 guangqiang.liu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Person.h"

//struct __block_impl {
//  void *isa;
//  int Flags;
//  int Reserved;
//  void *FuncPtr;
//};
//
//// 结构体的内存地址：0x000000010073c240，也就是结构体首成员isa的内存地址
//struct __Block_byref_age_0 {
//  void *__isa; // 0x000000010073c240
//
// struct __Block_byref_age_0 *__forwarding; // 0x000000010073c240 + 8 = 0x000000010073c248
// int __flags; // 0x000000010073c248 + 8 = 0x000000010073c250
// int __size; // 0x000000010073c250 + 4 = 0x000000010073c254
// int age; // 0x000000010073c254 + 4 = 0x000000010073c258
//};
//
//static struct __main_block_desc_0 {
//  size_t reserved;
//  size_t Block_size;
//  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
//  void (*dispose)(struct __main_block_impl_0*);
//};
//
//struct __main_block_impl_0 {
//  struct __block_impl impl;
//  struct __main_block_desc_0* Desc;
//
//  struct __Block_byref_age_0 *age; // by ref
//};

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
//        __block int age = 10;
//        void (^block)(void) = ^{
//            age = 20;
//            NSLog(@"%d", age); //20
//        };
//
//        block();
        
//        struct __main_block_impl_0 *blockStruct = (__bridge struct __main_block_impl_0 *)block;
        
        
//        // ------- 探究__block修改对象类型变量 -------
//
        Person *person = [[Person alloc] init];

        // 对象属性不写默认就是__strong
        __block __strong typeof(Person) *strongPerson = person;

//        __block __weak typeof(Person) *weakPerson = person;

        void (^block)(void) = ^{
            NSLog(@"%@", strongPerson);
        };

        block();
    }
    return 0;
}
