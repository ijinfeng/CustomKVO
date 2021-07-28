//
//  CustomKVOViewController.m
//  KVODemo
//
//  Created by jinfeng on 2021/7/28.
//

#import "CustomKVOViewController.h"
#import "NSObject+ijfKVO.h"
#import "Person.h"
#import "PersonManager.h"
#import <objc/runtime.h>

@interface CustomKVOViewController ()
@property (nonatomic, strong) Person *p;

@end

@implementation CustomKVOViewController

- (void)dealloc {
    NSLog(@"%@-%s",self,__func__);
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    Person *p = [Person new];
    self.p = p;
    [p ijf_addObserver:self forKeyPath:@"name" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"keyPath=%@",keyPath);
        NSLog(@"old=%@",oldValue);
        NSLog(@"new=%@",newValue);
    }];
    [p ijf_addObserver:self forKeyPath:@"age" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"keyPath=%@",keyPath);
        NSLog(@"old=%@",oldValue);
        NSLog(@"new=%@",newValue);
    }];
    
    [p ijf_addObserver:self forKeyPath:@"size" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"keyPath=%@",keyPath);
        NSLog(@"old=%@",oldValue);
        NSLog(@"new=%@",newValue);
    }];
    
    [p ijf_addObserver:self forKeyPath:@"dd" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"keyPath=%@",keyPath);
        NSLog(@"old=%@",oldValue);
        NSLog(@"new=%@",newValue);
    }];
    
    [p ijf_addObserver:self forKeyPath:@"ff" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"keyPath=%@",keyPath);
        NSLog(@"old=%@",oldValue);
        NSLog(@"new=%@",newValue);
    }];
    
    [p ijf_addObserver:self forKeyPath:@"cgf" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"keyPath=%@",keyPath);
        NSLog(@"old=%@",oldValue);
        NSLog(@"new=%@",newValue);
    }];
    
    
    [self printMethods:self.p];
    
//    [[PersonManager shared] ijf_addObserver:self forKeyPath:@"name" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
//        NSLog(@"keyPath=%@",keyPath);
//        NSLog(@"old=%@",oldValue);
//        NSLog(@"new=%@",newValue);
//    }];
}

- (void)printMethods:(id)obj {
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
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    self.p.name = @"ijinfeng";
//    self.p.age = 10;
    self.p.dd = 10.123;
    self.p.ff = 99.9;
    self.p.size = CGSizeMake(20, 30);
    
    self.p.cgf = 0.0001;
    
    [self.p willChangeValueForKey:@"name"];
    self.p.name = @"ijinfeng";
    self.p.age = 18;
    [self.p didChangeValueForKey:@"name"];
    
    
    
//    [self.p ijf_removeObserver:self forKeyPath:nil];
}


@end
