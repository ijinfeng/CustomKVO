//
//  NSObject+ijfKVO.m
//  AlertMaker
//
//  Created by jinfeng on 2021/7/27.
//

#import "NSObject+ijfKVO.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

const void *ijf_kvo_bind_key = &ijf_kvo_bind_key;
const void *ijf_kvo_sign_key = &ijf_kvo_sign_key;

@interface IjfObserver : NSObject

@property (nonatomic, weak) id observer;

@property (nonatomic, copy) NSString *keyPath;

@property (nonatomic, copy) ijfKVOCallback callback;

- (instancetype)initWithObserver:(id)observer keyPath:(NSString *)keyPath callback:(ijfKVOCallback)callback;
@end


@implementation IjfObserver

- (instancetype)initWithObserver:(id)observer keyPath:(NSString *)keyPath callback:(ijfKVOCallback)callback {
    self = [super init];
    if (self) {
        _observer = observer;
        _keyPath  = keyPath;
        _callback = callback;
    }
    return self;
}

@end


@implementation NSObject (ijfKVO)

- (void)ijf_addObserver:(id)observer forKeyPath:(NSString *)keyPath callback:(nonnull ijfKVOCallback)callback {
    if (!observer) {
        return;
    }
    if (keyPath.length == 0) {
        return;
    }
    if (!callback) {
        return;
    }
    
    // 保存观察者信息
    NSMutableArray *observers = objc_getAssociatedObject(self, ijf_kvo_bind_key);
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, ijf_kvo_bind_key, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (int i = 0; i < observers.count; i++) {
        IjfObserver *o = observers[i];
        if (o == observer && [o.keyPath isEqualToString:keyPath]) {
            // 已经存在这个观察者，返回
            return;
        }
    }
    IjfObserver *o = [[IjfObserver alloc] initWithObserver:observer keyPath:keyPath callback:callback];
    [observers addObject:o];
    
    // 判断被观察对象是否响应观察属性
    SEL keyPathSelector = NSSelectorFromString(keyPath);
    if (![self respondsToSelector:keyPathSelector]) {
        return;
    }
    
    // 动态生成子类
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
        objc_registerClassPair(newCls);
        
        // 重写 -class
        SEL classSEL = @selector(class);
        Method classMethod = class_getInstanceMethod(cls, classSEL);
        const char *classType = method_getTypeEncoding(classMethod);
        class_addMethod(newCls, classSEL, (IMP)ijf_kvo_class, classType);
        
        // 重写 -dealloc
        SEL deallocSEL = NSSelectorFromString(@"dealloc");
        Method dealloc = class_getInstanceMethod(cls, deallocSEL);
        const char *deallocType = method_getTypeEncoding(dealloc);
        Method kvoDeallocM = class_getInstanceMethod(cls, @selector(ijf_kvo_dealloc));
        class_addMethod(newCls, deallocSEL, method_getImplementation(kvoDeallocM), deallocType);
        
        // 重写 -willChangeValueForKey:
        SEL willChangeSEL = @selector(willChangeValueForKey:);
        Method willChange = class_getInstanceMethod(cls, willChangeSEL);
        const char *willChangeType = method_getTypeEncoding(willChange);
        class_addMethod(newCls, willChangeSEL, (IMP)ijf_willChangeWithkey, willChangeType);
        
        // 重写 -didChangeValueForKey:
        SEL didChangeSEL = @selector(didChangeValueForKey:);
        Method didChange = class_getInstanceMethod(cls, didChangeSEL);
        const char *didChangeType = method_getTypeEncoding(didChange);
        class_addMethod(newCls, didChangeSEL, (IMP)ijf_didChangeWithkey, didChangeType);
    }
    
    // 重写 -setter:
    SEL setterSEL = NSSelectorFromString([NSString stringWithFormat:@"set%@:",keyPath.capitalizedString]);
    Method setterMethod = class_getInstanceMethod(cls, setterSEL);
    const char *setterType = method_getTypeEncoding(setterMethod);
    class_addMethod(newCls, setterSEL, (IMP)ijf_setter_invoke, setterType);
    
    object_setClass(self, newCls);
}

- (void)ijf_removeObserver:(id)observer forKeyPath:(NSString *)keyPath {
    if (!observer) {
        return;
    }
    NSMutableArray *observers = objc_getAssociatedObject(self, ijf_kvo_bind_key);
    NSMutableArray *removes = [NSMutableArray array];
    for (int i = 0; i < observers.count; i++) {
        IjfObserver *o = observers[i];
        if (keyPath == nil) {
            if (o.observer == observer) {
                [removes addObject:o];
            }
        } else {
            if ([o.keyPath isEqualToString:keyPath]) {
                [observers removeObject:o];
                break;
            }
        }
    }
    
    if (removes.count > 0) {
        [observers removeObjectsInArray:removes];
    }
    
    // 修正isa的指向
    if (observers.count == 0) {
        rebindClass(self);
    }
}

#pragma mark -- Override methods

static Class ijf_kvo_class(id receiver, SEL sel) {
    return class_getSuperclass(object_getClass(receiver));
}

- (void)ijf_kvo_dealloc {
    objc_setAssociatedObject(self, ijf_kvo_bind_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, ijf_kvo_sign_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    Class superCls = [self class];

    rebindClass(self);

    struct objc_super s = {
        self, superCls
    };

    SEL deallocSEL = _cmd;

    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s, deallocSEL);
}

static void ijf_setter_invoke(id receiver, SEL setSEL, ...) {
    id resValue = nil;
    id oldValue = nil;
    
    NSMethodSignature *m = [receiver methodSignatureForSelector:setSEL];
    const char *type = [m getArgumentTypeAtIndex:2];
    
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
    
    va_list v;
    va_start(v, setSEL);
    id obj = nil;
    if (strcmp(type, @encode(id)) == 0) {
        id actual = va_arg(v, id);
        obj = actual;
        
        oldValue = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        
        ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(CGPoint)) == 0) {
        CGPoint actual = (CGPoint)va_arg(v, CGPoint);
        obj = [NSValue value:&actual withObjCType:type];
        
        CGPoint o = ((CGPoint (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSValue valueWithCGPoint:o];
        
        ((void (*)(struct objc_super *, SEL, CGPoint))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(CGSize)) == 0) {
        CGSize actual = (CGSize)va_arg(v, CGSize);
        obj = [NSValue value:&actual withObjCType:type];
        
        CGSize o = ((CGSize (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSValue valueWithCGSize:o];
        
        ((void (*)(struct objc_super *, SEL, CGSize))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
        UIEdgeInsets actual = (UIEdgeInsets)va_arg(v, UIEdgeInsets);
        obj = [NSValue value:&actual withObjCType:type];
        
        UIEdgeInsets o = ((UIEdgeInsets (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSValue valueWithUIEdgeInsets:o];
        
        ((void (*)(struct objc_super *, SEL, UIEdgeInsets))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(CGRect)) == 0) {
        CGRect actual = (CGRect)va_arg(v, CGRect);
        obj = [NSValue valueWithCGRect:actual];
        
        CGRect o = ((CGRect (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSValue valueWithCGRect:o];
        
        ((void (*)(struct objc_super *, SEL, CGRect))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(double)) == 0) {
        double actual = (double)va_arg(v, double);
        obj = [NSNumber numberWithDouble:actual];
        
        double o = ((double (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithDouble:o];
        
        ((void (*)(struct objc_super *, SEL, double))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(float)) == 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvarargs"
        float actual = (float)va_arg(v, float);
#pragma clang diagnostic pop
        obj = [NSNumber numberWithFloat:actual];
        
        float o = ((float (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithFloat:o];
        
        ((void (*)(struct objc_super *, SEL, float))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(int)) == 0) {
        int actual = (int)va_arg(v, int);
        obj = [NSNumber numberWithInt:actual];
        
        int o = ((int (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithInt:o];
        
        ((void (*)(struct objc_super *, SEL, int))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(long)) == 0) {
        long actual = (long)va_arg(v, long);
        obj = [NSNumber numberWithLong:actual];
        
        long o = ((long (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithLong:o];
        
        ((void (*)(struct objc_super *, SEL, long))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(long long)) == 0) {
        long long actual = (long long)va_arg(v, long long);
        obj = [NSNumber numberWithLongLong:actual];
        
        long long o = ((long long (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithLongLong:o];
        
        ((void (*)(struct objc_super *, SEL, long long))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(short)) == 0) {
        short actual = (short)va_arg(v, int);
        obj = [NSNumber numberWithShort:actual];
        
        short o = ((short (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithShort:o];
        
        ((void (*)(struct objc_super *, SEL, short))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(char)) == 0) {
        char actual = (char)va_arg(v, int);
        obj = [NSNumber numberWithChar:actual];
        
        char o = ((char (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithChar:o];
        
        ((void (*)(struct objc_super *, SEL, char))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(bool)) == 0) {
        bool actual = (bool)va_arg(v, int);
        obj = [NSNumber numberWithBool:actual];
        
        bool o = ((bool (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithBool:o];
        
        ((void (*)(struct objc_super *, SEL, bool))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(unsigned char)) == 0) {
        unsigned char actual = (unsigned char)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedChar:actual];
        
        unsigned char o = ((unsigned char (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithUnsignedChar:o];
        
        ((void (*)(struct objc_super *, SEL, unsigned char))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(unsigned int)) == 0) {
        unsigned int actual = (unsigned int)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedInt:actual];
        
        unsigned int o = ((unsigned int (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithUnsignedInt:o];
        
        ((void (*)(struct objc_super *, SEL, unsigned int))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(unsigned long)) == 0) {
        unsigned long actual = (unsigned long)va_arg(v, unsigned long);
        obj = [NSNumber numberWithUnsignedLong:actual];
        
        unsigned long o = ((unsigned long (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithUnsignedLong:o];
        
        ((void (*)(struct objc_super *, SEL, unsigned long))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(unsigned long long)) == 0) {
        unsigned long long actual = (unsigned long long)va_arg(v, unsigned long long);
        obj = [NSNumber numberWithUnsignedLongLong:actual];
        
        unsigned long long o = ((unsigned long long (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithUnsignedLongLong:o];
        
        ((void (*)(struct objc_super *, SEL, unsigned long long))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, @encode(unsigned short)) == 0) {
        unsigned short actual = (unsigned short)va_arg(v, unsigned int);
        obj = [NSNumber numberWithUnsignedShort:actual];
        
        unsigned short o = ((unsigned short (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
        oldValue = [NSNumber numberWithUnsignedShort:o];
        
        ((void (*)(struct objc_super *, SEL, unsigned short))objc_msgSendSuper)(&s, setterSel, actual);
    }
    va_end(v);
    
    resValue = obj;

    BOOL automaticallyNotifies = NO;
    // 判断是否支持自动触发KVO
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([superCls respondsToSelector:@selector(automaticallyNotifiesObserversForKey:)]) {
        automaticallyNotifies = [superCls performSelector:@selector(automaticallyNotifiesObserversForKey:) withObject:keyPathForSetter(setterSel)];
    }
#pragma clang diagnostic pop
    
    NSMutableArray *observers = objc_getAssociatedObject(receiver, ijf_kvo_bind_key);
    NSString *keyPath = keyPathForSetter(setterSel);
    NSMutableArray *releaseObservers = [NSMutableArray array];
    for (int i = 0; i < observers.count; i++) {
        IjfObserver *o = observers[i];
        if (o.observer == nil) {
            // 对象已释放，收集起来
            [releaseObservers addObject:o];
        } else if ([o.keyPath isEqualToString:keyPath]) {
            NSMutableSet *signKeys = objc_getAssociatedObject(receiver, ijf_kvo_sign_key);
            if ((o.callback && automaticallyNotifies) || [signKeys containsObject:keyPath]) {
                o.callback(o.observer, o.keyPath, oldValue, resValue);
            }
            break;
        }
    }
    
    // 释放已经释放的观察者对象，这种情况出现在被观察者没释放，观察者释放了
    if (releaseObservers.count > 0) {
        [observers removeObjectsInArray:releaseObservers];
    }
}

static void ijf_willChangeWithkey(id receiver, SEL sel, NSString *key) {
    if (!key) return;
    // 标记这个对象的这个属性可以被触发KVO
    NSMutableSet *signKeys = objc_getAssociatedObject(receiver, ijf_kvo_sign_key);
    if (!signKeys) {
        signKeys = [NSMutableSet set];
    }
    [signKeys addObject:key];
    objc_setAssociatedObject(receiver, ijf_kvo_sign_key, signKeys, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void ijf_didChangeWithkey(id receiver, SEL sel, NSString *key) {
    if (!key) return;
    NSMutableSet *signKeys = objc_getAssociatedObject(receiver, ijf_kvo_sign_key);
    [signKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isEqualToString:key]) {
            *stop = YES;
            [signKeys removeObject:key];
        }
    }];
    if (signKeys.count == 0) {
        objc_setAssociatedObject(receiver, ijf_kvo_sign_key, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

static void rebindClass(id receiver) {
    Class superCls = [receiver class];
    object_setClass(receiver, superCls);
}

static SEL getterForSetter(SEL setter) {
    // setName:
    NSString *getterName = keyPathForSetter(setter);
    return NSSelectorFromString(getterName);
}

static NSString *keyPathForSetter(SEL setter) {
    NSString *setterName = NSStringFromSelector(setter);
    NSString *getterName = [setterName substringFromIndex:3];
    getterName = [getterName substringToIndex:getterName.length - 1];
    return getterName.lowercaseString;
}

@end
