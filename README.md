# 06.5-block中__block本质

我们知道在block内部不能够直接修改外部的变量的值，但是我们给变量添加`__block`修饰后，在block内部就可以修改外部变量的值，那`__block`底层是怎么做到的尼？

我们新建一个工程，在`main`函数中添加测试代码如下：

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
        int age = 10;
        void (^block)(void) = ^{
            age = 20;
            NSLog(@"%d", age);
        };
        
        block();
    }
    return 0;
}
```

这时我们编译程序，发现程序报错，编译器不通过这种写法，那么我们对`main`函数中的代码进行修改如下：

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
        // 使用__block修饰
        __block int age = 10;
        void (^block)(void) = ^{
            age = 20;
            NSLog(@"%d", age); //20
        };
        
        block();
    }
    return 0;
}
```

我们在`age`变量前面添加`__block`修饰后，编译器就不在报错，并且可以正确修改age的值

接下来我们执行命令`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 main.m`将`main.m`文件转换为c++文件

`main`函数：

```
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

        // `__block int age = 10;`这句代码最终转换为__Block_byref_age_0 age = {}结构体
        __Block_byref_age_0 age = {
            0,
            // __Block_byref_age_0 age结构体自身的内存地址传递
            &age,
            0,
            sizeof(__Block_byref_age_0),
            10
        };
        
        void (*block)(void) = &__main_block_impl_0(
                                                   __main_block_func_0,
                                                   &__main_block_desc_0_DATA,
                                                   // 包装好的age结构体内存地址传递
                                                   &age,
                                                   570425344
                                                   );
        block->FuncPtr(block);
    }
    return 0;
}
```

`block`结构体：

```
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
    
    /**
     捕获进来的不是`Int age`变量，而是包装成`__Block_byref_age_0`类型的结构体对象。
     这个age指针一直都是强指针，强引用着__Block_byref_age_0结构体对象
     */
  __Block_byref_age_0 *age; // by ref
    
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_age_0 *_age, int flags=0) : age(_age->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

`__Block_byref_age_0`包装好的捕获变量的结构体：

```
struct __Block_byref_age_0 {
  void *__isa; // isa指针
    
    // __forwarding指针是指向自己的指针，也就是指向__Block_byref_age_0结构体
  __Block_byref_age_0 *__forwarding;
 int __flags;
 int __size;
 int age; // 这里的age才真正是block内部要修改的age变量
};
```

`__main_block_desc_0`结构体：

```
static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
}
```

`__main_block_copy_0`内存管理copy函数：

```
// 当block调用copy函数从栈上拷贝到堆上时，调用此函数
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct 
__main_block_impl_0*src) {
    
    /**
     直接产生强引用，执行retain操作，引用计数器+1
     是block对__main_block_impl_0结构体对象产生强引用
     */
    _Block_object_assign(
                         (void*)&dst->age,
                         (void*)src->age,
                         8/*BLOCK_FIELD_IS_BYREF*/
                         );
    
}
```

`__main_block_dispose_0`内存管理dispose函数：

```
// 当block要从堆上销毁时，调用此函数
static void __main_block_dispose_0(struct __main_block_impl_0*src) {
    
    // 当block要从堆上销毁时，就断开block对`__Block_byref_age_0 *age`的强引用，执行release操作，引用计数器-1
    _Block_object_dispose(
                          (void*)src->age,
                          8/*BLOCK_FIELD_IS_BYREF*/
                          );
    
}
```

`__main_block_func_0`block代码块函数FuncPtr：

```
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    // __cself就是block结构体对象
    
    // __cself->age:取出block结构体对象中的`age`成员
  __Block_byref_age_0 *age = __cself->age; // bound by ref
    
    // age->__forwarding->age:取出__Block_byref_age_0结构体中的`int age`成员，进行赋值操作
  (age->__forwarding->age) = 20;
    
  NSLog((NSString *)&__NSConstantStringImpl__var_folders_lr_81gwkh751xzddx_ffhhb5_0m0000gn_T_main_68aaa7_mi_0, (age->__forwarding->age));
}
```

那么我们怎么验证在block内部修改的`age`就是`__Block_byref_age_0`结构体内部的`age`，而不是`__main_block_impl_0`结构体内部的`age`尼？

我们修改`main.m`文件的代码如下：

```
struct __block_impl {
  void *isa;
  int Flags;
  int Reserved;
  void *FuncPtr;
};

// 结构体的内存地址：0x000000010073c240，也就是结构体首成员isa的内存地址
struct __Block_byref_age_0 {
  void *__isa; // 0x000000010073c240
    
 struct __Block_byref_age_0 *__forwarding; // 0x000000010073c240 + 8 = 0x000000010073c248
 int __flags; // 0x000000010073c248 + 8 = 0x000000010073c250
 int __size; // 0x000000010073c250 + 4 = 0x000000010073c254
 int age; // 0x000000010073c254 + 4 = 0x000000010073c258
};

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  
  struct __Block_byref_age_0 *age; // by ref
};

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
        __block int age = 10;
        void (^block)(void) = ^{
            age = 20;
            NSLog(@"%d", age); //20
        };
        
        // 将block变量转换为`struct __main_block_impl_0 *`类型
        struct __main_block_impl_0 *blockStruct = (__bridge struct __main_block_impl_0 *)block;
        
        
//        block();
        
        NSLog(@"%p",&age); // 0x000000010073c258
    }
    return 0;
}
```

我们通过断点查看`blockStruct`结构体对象包含的信息如图：

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200205-215300@2x.png)

如图我们得到`blockStruct -> age`的内存地址为：`0x000000010073c240 `，`NSLog(@"%p",&age);`打印的age变量内存地址为：`0x000000010073c258`

然后通过`__Block_byref_age_0`结构体成员的内存地址运算如下：

```
struct __Block_byref_age_0 {
  void *__isa; // 0x000000010073c240
    
 struct __Block_byref_age_0 *__forwarding; // 0x000000010073c240 + 8 = 0x000000010073c248
 int __flags; // 0x000000010073c248 + 8 = 0x000000010073c250
 int __size; // 0x000000010073c250 + 4 = 0x000000010073c254
 int age; // 0x000000010073c254 + 4 = 0x000000010073c258
};
```

由此也可知，我们在block内部修改外部的变量时，其实就是修改`__Block_byref_age_0`结构体内部的成员age，而不是`__main_block_impl_0`结构体内部的成员age

通过在控制台输入`p/x &(blockStruct->age->age)`打印出来的地址值也是`0x000000010073c258`也可以证明上面的结论

---

上面我们一直讲的都是使用`__block`修饰基本数据类型，如果使用`__block`修饰对象类型尼，和修饰基本数据类型有什么不同尼？

我们创建一个`Person`对象，然后修改`main.m`文件代码如下：

`Person`类：

```
@interface Person : NSObject

@end

@implementation Person

- (void)dealloc {
    NSLog(@"%s", __func__);
}
@end
```

`main`函数：

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
                
        Person *person = [[Person alloc] init];
        
        // 变量修饰符默认就是__strong
        __block __strong typeof(Person) *strongPerson = person;
        
//        __block __weak typeof(Person) *weakPerson = person;
        
        void (^block)(void) = ^{
            NSLog(@"%@", strongPerson);
        };
        
        block();
    }
    return 0;
}
```

然后我们执行命令`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 main.m -o main2.cpp` 将`main.m`文件转换为`main2.cpp`文件，代码如下：

`main`函数：

```
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        
        // Person *person = [[Person alloc] init];
        Person *person = ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"), sel_registerName("alloc")), sel_registerName("init"));

        // __block __strong typeof(Person) *strongPerson = person;
        __Block_byref_strongPerson_0 strongPerson = {
            0,
            &strongPerson,
            33554432,
            sizeof(__Block_byref_strongPerson_0),
            __Block_byref_id_object_copy_131,
            __Block_byref_id_object_dispose_131,
            person
        };

        void (*block)(void) = &__main_block_impl_0(
                                                   __main_block_func_0,
                                                   &__main_block_desc_0_DATA,
                                                   &strongPerson,
                                                   570425344
                                                   );
        block->FuncPtr(block);
    }
    return 0;
}
```

`block`结构体：

```
sstruct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
    
    // 这个指针一直是强指针
  __Block_byref_strongPerson_0 *strongPerson; // by ref
    
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_strongPerson_0 *_strongPerson, int flags=0) : strongPerson(_strongPerson->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

`__Block_byref_strongPerson_0`结构体：

```
struct __Block_byref_strongPerson_0 {
  void *__isa; // 8
 __Block_byref_strongPerson_0 *__forwarding; // 8
 int __flags; // 4
 int __size; // 4
    
    // 在__block修饰变量新增的结构体内，新增了两个内存管理函数
    
    // __Block_byref_id_object_copy_131
 void (*__Block_byref_id_object_copy)(void*, void*); // 8
    
    // __Block_byref_id_object_dispose_131
 void (*__Block_byref_id_object_dispose)(void*); // 8
    
    // 这个指针有强弱之分，是强指针还是弱指针取决于修饰符是__strong还是__weak
    // 当前是strongPerson是强指针，强引用着block外面创建的`person`对象
    Person *__strong strongPerson;
};
```

`__main_block_copy_0`block的copy函数：

```
// block的内存管理函数，当block执行copy从栈拷贝到堆上时，调用此函数
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {
    /**
     当block拷贝到堆上时，它也会将`struct __Block_byref_strongPerson_0`这个结构体从栈上拷贝到堆上，
     这个结构体内部也有自己的内存管理，因为`__Block_byref_strongPerson_0`结构体内部的`Person *__strong strongPerson`指针会引用着block外部的Person对象
     
     注意：当调用_Block_object_assign函数，函数内部会调用`__Block_byref_id_object_copy_131`函数
     */
    _Block_object_assign(
                         (void*)&dst->strongPerson,
                         (void*)src->strongPerson,
                         8/*BLOCK_FIELD_IS_BYREF*/
                         );
    
}
```

`__main_block_dispose_0`block的dispose函数

```
// block的内存管理函数，当block需要从堆上销毁时，调用此函数
static void __main_block_dispose_0(struct __main_block_impl_0*src) {
    /**
     block从堆上销毁时，就断开对`__Block_byref_strongPerson_0`结构体的强引用，执行release操作，引用计数器-1
     
     注意：当调动_Block_object_dispose函数，函数内部会调用`__Block_byref_id_object_dispose_131`函数
     */
    _Block_object_dispose(
                          (void*)src->strongPerson,
                          8/*BLOCK_FIELD_IS_BYREF*/
                          );
}
```

`__Block_byref_id_object_copy_131`:__Block_byref_strongPerson_0结构体的copy函数

```
// __Block_byref_strongPerson_0结构体的内存管理函数 copy
static void __Block_byref_id_object_copy_131(void *dst, void *src) {
    /**
     这里的`dst`指针指向的地址值就是`__Block_byref_strongPerson_0`结构体的地址值
     `dst`的地址值 + 40个字节，对应的正好是`__Block_byref_strongPerson_0`结构体内的`Person *__strong strongPerson;`成员
     
     也就是说_Block_object_assign()函数会根据传递的`person`参数是强指针还是弱指针进行内存管理操作
     */
 _Block_object_assign(
                      (char*)dst + 40,
                      *(void * *) ((char*)src + 40),
                      131);
}
```

`__Block_byref_id_object_dispose_131`:__Block_byref_strongPerson_0结构体的dispose函数

```
// __Block_byref_strongPerson_0结构体的内存管理函数 dispose
static void __Block_byref_id_object_dispose_131(void *src) {
 _Block_object_dispose(
                       *(void * *) ((char*)src + 40),
                       131);
}
```

`__main_block_func_0`block代码块FuncPtr：

```
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    // 取出block结构体内的`__Block_byref_strongPerson_0`对象：__cself->strongPerson
  __Block_byref_strongPerson_0 *strongPerson = __cself->strongPerson; // bound by ref
  NSLog((NSString *)&__NSConstantStringImpl__var_folders_lr_81gwkh751xzddx_ffhhb5_0m0000gn_T_main_721406_mi_0, (strongPerson->__forwarding->strongPerson));
}
```

__block底层数据结构图解如下：

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-115141@2x.png)
![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-115724@2x.png)

__block修饰对象类型内存管理图解如下：

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-115459@2x.png)

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-115546@2x.png)

__block修饰对象生成结构体中的__forwarding指针用法图解：

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-115841@2x.png)

__block修饰对象类型底层用法图解：

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-120222@2x.png)


__block修饰对象类型变量，并且使用__strong修饰，代码如下：


```
	 Person *person = [[Person alloc] init];

    // 对象属性不写默认就是__strong修饰
    __block __strong typeof(Person) *strongPerson = person;
    
    void (^block)(void) = ^{
        NSLog(@"%@", strongPerson);
    };

    block();
```

block引用关系如图：

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-121418@2x.png)

__block修饰对象类型变量，并且使用__weak修饰，代码如下：

```
	 Person *person = [[Person alloc] init];

    __block __weak typeof(Person) *weakPerson = person;

    void (^block)(void) = ^{
        NSLog(@"%@", weakPerson);
    };

    block();
```

block引用关系如图：

![](https://imgs-1257778377.cos.ap-shanghai.myqcloud.com/QQ20200206-134601@2x.png)


讲解示例代码Demo地址：[https://github.com/guangqiang-liu/06.5-__blockDemo]()


## 更多文章
* ReactNative开源项目OneM(1200+star)：**[https://github.com/guangqiang-liu/OneM](https://github.com/guangqiang-liu/OneM)**：欢迎小伙伴们 **star**
* iOS组件化开发实战项目(500+star)：**[https://github.com/guangqiang-liu/iOS-Component-Pro]()**：欢迎小伙伴们 **star**
* 简书主页：包含多篇iOS和RN开发相关的技术文章[http://www.jianshu.com/u/023338566ca5](http://www.jianshu.com/u/023338566ca5) 欢迎小伙伴们：**多多关注，点赞**
* ReactNative QQ技术交流群(2000人)：**620792950** 欢迎小伙伴进群交流学习
* iOS QQ技术交流群：**678441305** 欢迎小伙伴进群交流学习