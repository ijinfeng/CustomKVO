//
//  Person.m
//  KVODemo
//
//  Created by jinfeng on 2021/7/28.
//

#import "Person.h"

@implementation Person

- (void)dealloc {
    NSLog(@"%@-%s",self,__func__);
}


//- (NSString *)description {
//    return [NSString stringWithFormat:@"name=%@|age=%d|money=%f",self.name,self.age,self.money];
//}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    return YES;
}

@end
