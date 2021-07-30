

完美支持基本类型、指针类型、结构体属性的观察。自动释放观察者对象。支持自动和手动触发观察者。

### 原理讲解

`KVO` 即 `Key Value observing` ，名为键值观察。KVO是一种观察者模式的实现，它允许其他对象观察某一对象指定属性的变化。

那么它是如何实现的呢？

苹果官方文档有段话:
> ### Key-Value Observing Implementation Details
> 
> Key-Value Observing Implementation Details
Automatic key-value observing is implemented using a technique called isa-swizzling.
> 
> The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.
> 
> When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.
> 
> You should never rely on the isa pointer to determine class membership. Instead, you should use the class method to determine the class of an object instance.


翻译下就是 `KVO` 是使用 `isa-swizzling` 技术实现的。
isa指针，顾名思义，指向维护分派表的对象的类。这个分派表本质上包含指向类实现的方法的指针，以及其他数据。
当观察者为一个对象的属性注册时，被观察对象的isa指针被修改，指向一个中间类而不是真正的类。因此，isa指针的值不一定反映实例的实际类。
你不应该依赖isa指针来决定类的成员。相反，您应该使用类方法来确定对象实例的类。


看到这里就明白了，原来苹果修改了被观察对象的类的 `isa` 指针，指向一个派生类，观察这个派生类的同名属性变化即可实现 `KVO`。


但事实上，当我们打印被观察类的 `class` 时，发现事情并没有那么简单。

先准备一个`Person`演示类，结构如下：
```
@interface Person : NSObject

@property (nonatomic, copy) NSString *name;

@property (nonatomic, assign) int age;

@property (nonatomic, assign) float money;

@property (nonatomic, assign) CGSize size;

@property (nonatomic, assign) double dd;

@property (nonatomic, assign) float ff;

@property (nonatomic, assign) CGFloat cgf;

@end
```

给Person对象添加观察者，看如下代码：
```
Person *p = [Person new];
self.p = p;
[p addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
    
NSLog(@"person class= %@",[p class]);
```

打印如下：
> 2021-07-28 17:59:10.791388+0800 KVODemo[7948:395941] person class= Person

怎么回事，不是说指向一个中间类吗？为什么还是打印 **Person** 呢？我们再思考下，官方说修改了 `isa` 指针的指向，而方法 `- (Class)class`的实现是这样的：（想看源码的去这里下载[OBJC源码](https://opensource.apple.com/tarballs/objc4/)）
```
- (Class)class {
    return object_getClass(self);
}
```

难道是系统重写了 `- (Class)class` 方法的实现？我们直接用 `object_getClassName` 方法试下会如何：
```
Person *p = [Person new];
self.p = p;
[p addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
    
NSLog(@"person class= %@",[p class]);
NSLog(@"person class= %s",object_getClassName(p));
```

打印如下：
> 2021-07-28 18:09:58.412275+0800 KVODemo[8166:406263] person class= Person  
> 2021-07-28 18:09:58.412488+0800 KVODemo[8166:406263] person class= NSKVONotifying_Person

看到确实是指向了一个名为 `NSKVONotifying_Person` 的类。我们打印下它包含的方法有哪些。

```
NSLog(@"==============> begin");
    Class cls = object_getClass(obj);
    unsigned int count;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        Method method = methods[i];
        SEL sel = method_getName(method);
        NSLog(@"%@",NSStringFromSelector(sel));
    }
    NSLog(@"==============> end");
```

输出这个中间类有如下方法：
> 2021-07-28 18:13:16.646938+0800 KVODemo[8220:409815] ==============> begin  
> 2021-07-28 18:13:16.647070+0800 KVODemo[8220:409815] setName:  
> 2021-07-28 18:13:16.647177+0800 KVODemo[8220:409815] class  
> 2021-07-28 18:13:16.647273+0800 KVODemo[8220:409815] dealloc  
> 2021-07-28 18:13:16.647377+0800 KVODemo[8220:409815] _isKVOA  
> 2021-07-28 18:13:16.647448+0800 KVODemo[8220:409815] ==============> end


看到了熟悉的`class`方法，看来这个中间类确实重写了`class`，所以我们在调用Person的`class`时，才会返回`Person`。


### 实现思路

其实系统的说明文档已经给出了实现思路，我们细分下：
1. 创建被监听对象的类的派生类
2. 重写这个派生类的`class`、`set[keyPath]`方法（主要是`set`方法）
3. 当重写`set`方法后，实现向父类也就是被监听类的目标属性传值
4. 在给父类属性传值后需回调给观察者


KVO的主要实现逻辑就上面这些，至于系统重写`class`类主要是为了防止开发者产生迷惑，同时也是为了掩盖KVO的实现细节。


### 动态创建类

`runtime` 为我们提供了三个方法:

基于一个类创建一个派生类，`Class` 和 `metaClass` 都可以。`superclass`：父类，`name`：新类的名字，`extraBytes`：在创建类是为变量分配的字节数，默认传0即可。  
* `Class _Nullable objc_allocateClassPair(Class _Nullable superclass, const char * _Nonnull name, size_t extraBytes) `   


新建的类需要注册后才能使用，这一步会把新创建的 `Class` 插入到底层的一个 `NXMapTable`中，这是个hash表，`key`为类型，`value`为`Class`。  
* `void objc_registerClassPair(Class _Nonnull cls)`

创建完类后，我们就需要 isa 和 Class 进行绑定，使用如下方法就可以实现
* `Class _Nullable object_setClass(id _Nullable obj, Class _Nonnull cls) `

完整创建注册类的代码如下：
```ObjectiveC
- (void)demo_addObserver:(id)observer forKeyPath:(NSString *)keyPath callback:(demoKVOCallback)callback {
    if (!observer) {
        return;
    }
    if (keyPath.length == 0) {
        return;
    }
    if (!callback) {
        return;
    }
    
    Class cls = [self class];
    NSString *oldClassName = NSStringFromClass(cls);
    NSString *newClassName = [NSString stringWithFormat:@"IjfKVONotifying_%@",oldClassName];
    Class newCls = NSClassFromString(newClassName);
    if (newCls == nil) {
        // 没有这个类，需要新建
        newCls = objc_allocateClassPair(cls, newClassName.UTF8String, 0);
        if (!newCls) {
            @throw [NSException exceptionWithName:@"IJFCustomException" reason:@"the desired name is already in use" userInfo:nil];
        }
        NSLog(@"注册类前---%@",objc_getClass(newClassName.UTF8String));
        objc_registerClassPair(newCls);
        NSLog(@"注册类后---%@",objc_getClass(newClassName.UTF8String));
    }
    // 修改 isa 指向
    object_setClass(self, newCls);
}


// 使用
Person *p = [Person new];
    
    NSLog(@"添加观察者之前-%@",p.class);
    
    [p demo_addObserver:self forKeyPath:@"name" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
            
    }];
    
    NSLog(@"添加观察者之后-%@",p.class);
```
运行后打印：
> 2021-07-29 16:34:14.331125+0800 KVODemo[6868:228989] 添加观察者之前-Person  
> 2021-07-29 16:34:14.331403+0800 KVODemo[6868:228989] 注册类前---(null)  
> 2021-07-29 16:34:14.331567+0800 KVODemo[6868:228989] 注册类后---IjfKVONotifying_Person  
> 2021-07-29 16:34:14.331679+0800 KVODemo[6868:228989] 添加观察者之后-IjfKVONotifying_Person  

可以看到当类注册后就能被搜到了，也代表着能像其他类那样被正常是用了。并且Person对象p的指向也变成了我们自建的派生类。


### 动态添加方法

创建类之后，我们就需要给这个类添加方法了。我们先添加一个`-class`实例方法。

```
if (newCls == nil) {
    ...
    // 重写 -class
        SEL classSEL = @selector(class);
        Method classMethod = class_getInstanceMethod(cls, classSEL);
        const char *classType = method_getTypeEncoding(classMethod);
        class_addMethod(newCls, classSEL, (IMP)ijf_kvo_class, classType);
}
 
 // 自定义class方法的实现
 static Class ijf_kvo_class(id receiver, SEL sel) {
 // 指向派生类的父类
    return class_getSuperclass(object_getClass(receiver));
}       
        
```

运行后打印：
> 2021-07-30 12:45:19.960182+0800 KVODemo[2971:116085] 添加观察者之前-Person  
> 2021-07-30 12:45:19.960477+0800 KVODemo[2971:116085] 注册类前---(null)  
> 2021-07-30 12:45:19.960644+0800 KVODemo[2971:116085] 注册类后---IjfKVONotifying_Person  
> 2021-07-30 12:45:19.960793+0800 KVODemo[2971:116085] 添加观察者之后-Person  


没问题，调用`Person`对象的`class`方法已经能返回我们想要的类型了。这里有个知识点，为什么我在调用 `class_addMethod` 函数的时候传入的 `IMP`需要写成 `Class ijf_kvo_class(id receiver, SEL sel)`这个样子？

这里涉及到 `ObjectiveC` 的消息发送知识点。我们在调用比如： `[obj play]`的方法时 ，最终都会被转换成C函数形式的 `objc_msgSend(id obj, SEL op,...)`。此函数定义 [objc源码](https://opensource.apple.com/tarballs/objc4/) `message.h`中。因此，我可以定义诸如这种 `Class ijf_kvo_class(id receiver, SEL sel)` 函数来接受传入的参数。其实这里写成我们熟悉的**OC**形式 `-(Class)class {...}` 也是完全没问题的。


接下来我们就要修改本文最重要的一个方法，对象的`set`方法。

我们知道，当我们调用 `p.name=@"ijinfeng"` 时，其实是调用了对象 `p` 的 `setName:` 方法，参数是 `NSString` 。那么我们重写派生类的同名方法即可。直接看代码：

```
 // 重写 -set
    SEL setterSEL = NSSelectorFromString([NSString stringWithFormat:@"set%@:",keyPath.capitalizedString]);
    Method setterMethod = class_getInstanceMethod(cls, setterSEL);
    const char *setterType = method_getTypeEncoding(setterMethod);
    class_addMethod(newCls, setterSEL, (IMP)ijf_setter_invoke, setterType);
    
    
    
static void ijf_setter_invoke(id receiver, SEL setSEL, id newValue) {
    NSLog(@"setSEL= %@",NSStringFromSelector(setSEL));
    NSLog(@"newValue= %@",newValue);
}
```

这一步，我们完成了向派生类添加`set`方法，由于 `keyPath` 为 `name`，因此最终插入的方法为 `setName:` 。大家可以通过打印派生类的方法列表确认。

我们找个合适的时机触发自定义**KVO**，
```
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.p.name = @"ijinfeng";
}
```

可以看到打印：
> 2021-07-30 12:50:29.427236+0800 KVODemo[3107:122373] setSEL= setName:  
> 2021-07-30 12:50:32.668304+0800 KVODemo[3107:122373] newValue= ijinfeng

我们成功接收到了外部传入的新值，**KVO**最核心的第一步也就实现了，但是接收到了还不够，我们需要修改的是我们父类的值，因为对使用者来说，他修改的是`Person`对象的`name`属性，而并不是我们创建的派生类`IjfKVONotifying_Person`的`name`，因此我们需要将值传递给父类。

```
static void ijf_setter_invoke(id receiver, SEL setSEL, id newValue) {
    NSLog(@"setSEL= %@",NSStringFromSelector(setSEL));
    NSLog(@"newValue= %@",newValue);
    
    SEL setterSel = setSEL;
    SEL getterSel = getterForSetter(setterSel);
    Class superCls = [receiver class];
    /*
     struct objc_super {
         __unsafe_unretained _Nonnull id receiver;
     #if !defined(__cplusplus)  &&  !__OBJC2__
         __unsafe_unretained _Nonnull Class class;
     #else
         __unsafe_unretained _Nonnull Class super_class;
     #endif
     };
     */
    struct objc_super s = {
        receiver, superCls
    };
    
    id oldValue = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
    
    ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&s, setterSel, newValue);
    
    NSLog(@"oldValue= %@",oldValue);
}

```
并且我们在更新`p`的属性`name`后，进行打印`self.p.name = @"ijinfeng"; NSLog(@"新值：%@",self.p.name);`，来看下结果如何：

> 2021-07-30 13:13:34.094102+0800 KVODemo[3413:138388] setSEL= setName:  
> 2021-07-30 13:13:34.094205+0800 KVODemo[3413:138388] newValue= ijinfeng  
> 2021-07-30 13:13:34.094317+0800 KVODemo[3413:138388] oldValue= (null)  
> 2021-07-30 13:13:34.094424+0800 KVODemo[3413:138388] 新值：ijinfeng

再更新下看打印：
> 2021-07-30 13:16:06.015924+0800 KVODemo[3413:138388] setSEL= setName:  
> 2021-07-30 13:16:06.016080+0800 KVODemo[3413:138388] newValue= ijinfeng  
> 2021-07-30 13:16:06.016219+0800 KVODemo[3413:138388] oldValue= ijinfeng  
> 2021-07-30 13:16:06.016362+0800 KVODemo[3413:138388] 新值：ijinfeng


可以看到我们的新值已经被我们设置进去了，并且旧值也能正确获取到。那么到这里已经结束了吗？我们是不是已经完成了KVO的核心呢？


当然不是，如果我修改了一个基本类型的值会如何？(记得修改监听的属性为`age`)
```
self.p.age = 10;
NSLog(@"新值：%d",self.p.age);
```

运行看看。
![carsh](https://note.youdao.com/yws/public/resource/d1fc5e3d93aa7f9721981b1f10cb99fd/xmlnote/WEBRESOURCEa44436fddfe0606ee461b7d451737d47/6897)

Crash了！提示 **Thread 1: EXC_BAD_ACCESS (code=1, address=0xa)** 错误。一般这个报错是由于访问已释放内存导致的。

这种情况怎么办，我们又不能将入参直接改为 `int newValue`，一旦这么改，那么其他类型的参数又该怎么接收？


我们尝试着用万能指针`void *` 来接收看看会如何。
```
static void ijf_setter_invoke(id receiver, SEL setSEL, void *newValue) {
    NSLog(@"setSEL= %@",NSStringFromSelector(setSEL));
    NSLog(@"newValue= %p",newValue);
}
```
运行打印：
> 2021-07-30 14:23:10.270407+0800 KVODemo[3827:163075] setSEL= setAge:  
> 2021-07-30 14:23:10.270559+0800 KVODemo[3827:163075] newValue= 0xa

这下没有再Crash，但是却出现了新的问题，我们传入的10去哪里了。看这个`0xa` 这个是16进制的值，转成10进制是不是10，看来10被塞到了指针`newValue`中去。也就是本来指针存的是一串地址，现在存了个值进来。

知道了原因，取值也简单，看代码。
```
int value = (int)newValue;
NSLog(@"get value= %d",value);
```
打印：
> 2021-07-30 14:40:55.352662+0800 KVODemo[4142:181244] get value= 10

可以看到，确实被我们取出来了，再试试其他类型行不行，我还是修改`name`属性。用下面的形式去接收newValue。

```
NSString *value = (__bridge NSString *)newValue;
NSLog(@"get value= %@",value);
```

打印如下：
> 2021-07-30 14:44:25.305722+0800 KVODemo[4231:185283] setSEL= setName:  
> 2021-07-30 14:44:25.305884+0800 KVODemo[4231:185283] newValue= 0x10d7c3360  
> 2021-07-30 14:44:25.306019+0800 KVODemo[4231:185283] get value= ijinfeng  

很好，还是没有问题，看起来基本类型和指针类型已经能够完美处理了。不过看到这里你有没有发现一个新的问题，就是我们怎么知道传入的`newValue`是什么类型的参数？毕竟函数定义时接收的可是`void *`类型。而我上面都是在已知参数类型的情况下去进行强转的。

#### 如何获取参数类型

不知道大家有没有接触过并且用到过 `NSMethodSignature` 类。这个类它是对我们方法的一个封装，并且返回方法签名。用这个类就能完美解决我们上诉的问题。

直接上代码:
```
NSMethodSignature *m = [receiver methodSignatureForSelector:setSEL];
// 第0个参数是 receiver, 第1个参数是 SEL，因此我们需要从第2个参数开始获取
const char *type = [m getArgumentTypeAtIndex:2];
NSLog(@"获取newValue的参数类型：%s",type);

```
> 2021-07-30 14:51:55.652546+0800 KVODemo[4310:190749] 获取newValue的参数类型：@

看到没，打印了一个 `@`，这个代表的就是id类型。而这个映射表可以在`runtime.h`下找到，这里直接贴出来了。

![map](https://note.youdao.com/yws/public/resource/d1fc5e3d93aa7f9721981b1f10cb99fd/xmlnote/WEBRESOURCE791f40ab1f6b3f256bcc7bf4eea49a48/6936)

也就是是说，我们可以做如下的编码：
```
NSMethodSignature *m = [receiver methodSignatureForSelector:setSEL];
    const char *type = [m getArgumentTypeAtIndex:2];
    NSLog(@"获取newValue的参数类型：%s",type);
    
    if (strcmp("@", type) == 0) {
        id value = (__bridge id)newValue;
        NSLog(@"get value= %@",value);
    } else if (strcmp("i", type) == 0) {
        int value = (int)newValue;
        NSLog(@"get value= %d",value);
    }
```

看打印：
> 2021-07-30 15:01:29.407734+0800 KVODemo[4543:200241] setSEL= setName:  
> 2021-07-30 15:01:29.407938+0800 KVODemo[4543:200241] newValue= 0x105b533e0  
> 2021-07-30 15:01:29.408124+0800 KVODemo[4543:200241] 获取newValue的参数类型：@  
> 2021-07-30 15:01:29.408271+0800 KVODemo[4543:200241] get value= ijinfeng  
> 2021-07-30 15:01:29.408558+0800 KVODemo[4543:200241] setSEL= setAge:  
> 2021-07-30 15:01:29.408677+0800 KVODemo[4543:200241] newValue= 0xa  
> 2021-07-30 15:01:29.408829+0800 KVODemo[4543:200241] 获取newValue的参数类型：i  
> 2021-07-30 15:01:29.408951+0800 KVODemo[4543:200241] get value= 10  

那后面的事就简单了，根据上面那个类型映射表，接着往下写不就行了。但是当我们写到接收`double`时，新的问题又出现了。

![double](https://note.youdao.com/yws/public/resource/d1fc5e3d93aa7f9721981b1f10cb99fd/xmlnote/WEBRESOURCE58a58dfbea55780fd0540138090e2489/6946)

编译器提示指针不能被强转成`double`。在快要收官的时候遇上了一个新坎...看来这个方法还是有待验证。

接下来我介绍另一种方法 **可变参数解析**。

`va_list` 就是用来处理当参数不定时的一个宏，这样，我们就不再需要自己转换参数类型，直接根据参数类型取值即可。

直接看代码演示：
```
static void ijf_setter_invoke(id receiver, SEL setSEL, ...) {
    
    NSMethodSignature *m = [receiver methodSignatureForSelector:setSEL];
    const char *type = [m getArgumentTypeAtIndex:2];
    
    va_list v;
    va_start(v, setSEL);
    if (strcmp(type, "@") == 0) {
        id actual = va_arg(v, id);
        NSLog(@"get value= %@",actual);

    } else if (strcmp(type, "i") == 0) {
        int actual = (int)va_arg(v, int);
        NSLog(@"get value= %d",actual);

    } else if (strcmp(type, "d") == 0) {
        double actual = (double)va_arg(v, double);
        NSLog(@"get value= %lf",actual);

    }
}
```

打印结果：
> 2021-07-30 15:19:07.890083+0800 KVODemo[4835:214726] setSEL= setName:  
> 2021-07-30 15:16:49.231051+0800 KVODemo[4800:212648] get value= ijinfeng  
> 2021-07-30 15:19:07.890540+0800 KVODemo[4835:214726] setSEL= setAge:  
> 2021-07-30 15:16:49.231416+0800 KVODemo[4800:212648] get value= 10  
> 2021-07-30 15:19:07.890818+0800 KVODemo[4835:214726] setSEL= setDd:  
> 2021-07-30 15:16:49.231712+0800 KVODemo[4800:212648] get value= 12.300000  

这下终于对了，剩下的就是将类型补全，以及将结果回调出去即可。完整的Demo演示看[这个](https://github.com/ijinfeng/CustomKVO)。

