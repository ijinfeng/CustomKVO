//
//  SysKVOViewController.m
//  KVODemo
//
//  Created by jinfeng on 2021/7/28.
//

#import "SysKVOViewController.h"
#import "Person.h"
#import "PersonManager.h"
#import <objc/runtime.h>

@interface SysKVOViewController ()
@property (nonatomic, strong) Person *p;
@end

@implementation SysKVOViewController

- (void)dealloc {
    NSLog(@"%@-%s",self,__func__);
    
//    [[PersonManager shared] removeObserver:self forKeyPath:@"name"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    Person *p = [Person new];
    self.p = p;
    [p addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
    
    NSLog(@"person class= %@",[p class]);
    NSLog(@"person class= %s",object_getClassName(p));
    
//    [p addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew context:nil];
//
//    __weak typeof(self) weakSelf = self;
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        __strong typeof(weakSelf) self = weakSelf;
//        self.p.age = 18;
//        NSLog(@"执行");
//    });
    
//    PersonManager *pm = [PersonManager shared];
//    [pm addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];
    [self printMethods:self.p];
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
    
    self.p.name = @"ijinfeng";
    
    self.p.age = 20;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"%@",object);
    NSLog(@"keyPath=%@",keyPath);
    NSLog(@"change=%@",change);
}

@end
