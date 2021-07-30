//
//  DemoViewController.m
//  KVODemo
//
//  Created by jinfeng on 2021/7/29.
//

#import "DemoViewController.h"
#import "Person.h"
#import "NSObject+demoKVO.h"

@interface DemoViewController ()
@property (nonatomic, strong) Person *p;
@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    Person *p = [Person new];
    self.p = p;
    NSLog(@"添加观察者之前-%@",p.class);
    
    [p demo_addObserver:self forKeyPath:@"name" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
    }];
    
    [p demo_addObserver:self forKeyPath:@"age" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
    }];
    
    [p demo_addObserver:self forKeyPath:@"dd" callback:^(id  _Nonnull observer, NSString * _Nonnull keyPath, id  _Nonnull oldValue, id  _Nonnull newValue) {
    }];
    
    NSLog(@"添加观察者之后-%@",p.class);
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.p.name = @"ijinfeng";
    NSLog(@"新值：%@",self.p.name);
    self.p.age = 10;
    NSLog(@"新值：%d",self.p.age);
    
    self.p.dd = 12.3;
    NSLog(@"新值：%lf",self.p.dd);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
