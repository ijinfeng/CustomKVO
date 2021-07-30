//
//  NSObject+demoKVO.h
//  KVODemo
//
//  Created by jinfeng on 2021/7/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^demoKVOCallback)(id _Nonnull observer, NSString * _Nonnull keyPath, id _Nonnull oldValue, id _Nonnull newValue);

@interface NSObject (demoKVO)

- (void)demo_addObserver:(id)observer
             forKeyPath:(NSString *)keyPath
               callback:(demoKVOCallback)callback;

@end

NS_ASSUME_NONNULL_END
