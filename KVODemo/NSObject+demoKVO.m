//
//  NSObject+demoKVO.m
//  KVODemo
//
//  Created by jinfeng on 2021/7/29.
//

#import "NSObject+demoKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <objc/objc.h>

static const void *ijf_kvo_bind_key = &ijf_kvo_bind_key;
static const void *ijf_kvo_sign_key = &ijf_kvo_sign_key;

@implementation NSObject (demoKVO)

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
        
        // 重写 -class
        SEL classSEL = @selector(class);
        Method classMethod = class_getInstanceMethod(cls, classSEL);
        const char *classType = method_getTypeEncoding(classMethod);
        class_addMethod(newCls, classSEL, (IMP)ijf_kvo_class, classType);
    }
    
    // 重写 -set
    SEL setterSEL = NSSelectorFromString([NSString stringWithFormat:@"set%@:",keyPath.capitalizedString]);
    Method setterMethod = class_getInstanceMethod(cls, setterSEL);
    const char *setterType = method_getTypeEncoding(setterMethod);
    class_addMethod(newCls, setterSEL, (IMP)ijf_setter_invoke, setterType);
    
    object_setClass(self, newCls);
}

static Class ijf_kvo_class(id receiver, SEL sel) {
    return class_getSuperclass(object_getClass(receiver));
}

// 例子1
//static void ijf_setter_invoke(id receiver, SEL setSEL, id newValue) {
//    NSLog(@"setSEL= %@",NSStringFromSelector(setSEL));
//    NSLog(@"newValue= %@",newValue);
//
//    SEL setterSel = setSEL;
//    SEL getterSel = getterForSetter(setterSel);
//    Class superCls = [receiver class];
//    /*
//     struct objc_super {
//         __unsafe_unretained _Nonnull id receiver;
//     #if !defined(__cplusplus)  &&  !__OBJC2__
//         __unsafe_unretained _Nonnull Class class;
//     #else
//         __unsafe_unretained _Nonnull Class super_class;
//     #endif
//     };
//     */
//    struct objc_super s = {
//        receiver, superCls
//    };
//
//    id oldValue = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
//
//    ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&s, setterSel, newValue);
//
//    NSLog(@"oldValue= %@",oldValue);
//}


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













// 例子2
//static void ijf_setter_invoke(id receiver, SEL setSEL, void *newValue) {
//    NSLog(@"setSEL= %@",NSStringFromSelector(setSEL));
//    NSLog(@"newValue= %p",newValue);
//
//    NSMethodSignature *m = [receiver methodSignatureForSelector:setSEL];
//    const char *type = [m getArgumentTypeAtIndex:2];
//    NSLog(@"获取newValue的参数类型：%s",type);
//
//    int value = (int)newValue;
//    int value = (int)*(&newValue);
//    NSLog(@"get value= %d",value);
    
//    if (strcmp("@", type) == 0) {
//        id value = (__bridge id)newValue;
//        NSLog(@"get value= %@",value);
//    } else if (strcmp("i", type) == 0) {
//        int value = (int)newValue;
//        NSLog(@"get value= %d",value);
//    } else if (strcmp("d", type) == 0) {
//        double value = (double)newValue;
//        NSLog(@"get value= %lf",value);
//    }
//
//}












// 例子3
static void ijf_setter_invoke(id receiver, SEL setSEL, ...) {
    NSLog(@"setSEL= %@",NSStringFromSelector(setSEL));
    
    NSMethodSignature *m = [receiver methodSignatureForSelector:setSEL];
    const char *type = [m getArgumentTypeAtIndex:2];
    
    va_list v;
    va_start(v, setSEL);
    id obj = nil;
    if (strcmp(type, "@") == 0) {
        id actual = va_arg(v, id);
        NSLog(@"get value= %@",actual);
        
//        obj = actual;
//        oldValue = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
//
//        ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, "i") == 0) {
        int actual = (int)va_arg(v, int);
        NSLog(@"get value= %d",actual);
//        obj = [NSNumber numberWithInt:actual];
//        int o = ((int (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
//        oldValue = [NSNumber numberWithInt:o];
//
//        ((void (*)(struct objc_super *, SEL, int))objc_msgSendSuper)(&s, setterSel, actual);
    } else if (strcmp(type, "d") == 0) {
        double actual = (double)va_arg(v, double);
        NSLog(@"get value= %lf",actual);
        
//        obj = [NSNumber numberWithDouble:actual];
//        double o = ((double (*)(struct objc_super *, SEL))objc_msgSendSuper)(&s,getterSel);
//        oldValue = [NSNumber numberWithDouble:o];
//
//        ((void (*)(struct objc_super *, SEL, double))objc_msgSendSuper)(&s, setterSel, actual);
    }
}

@end
