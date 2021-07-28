//
//  PersonManager.m
//  KVODemo
//
//  Created by jinfeng on 2021/7/28.
//

#import "PersonManager.h"

@implementation PersonManager

+ (instancetype)shared {
    static PersonManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PersonManager new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tRepeat) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)tRepeat {
    self.name = @"ijinfeng";
}

- (void)setName:(NSString *)name {
    _name = name;
    
}

@end
