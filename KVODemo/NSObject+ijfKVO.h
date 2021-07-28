//
//  NSObject+ijfKVO.h
//  AlertMaker
//
//  Created by jinfeng on 2021/7/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ijfKVOCallback)(id _Nonnull observer, NSString * _Nonnull keyPath, id _Nonnull oldValue, id _Nonnull newValue);

@interface NSObject (ijfKVO)

/// 添加观察者对象，重复添加无效，当被观察者或观察者释放时自动移除
/// @param observer 观察者
/// @param keyPath 观察属性
/// @param callback 回调
- (void)ijf_addObserver:(id)observer
             forKeyPath:(NSString *)keyPath
               callback:(ijfKVOCallback)callback;

/// 主动移除观察keyPath的观察者
/// @param observer 观察者
/// @param keyPath 观察属性，当传入位nil时，讲移除所有的observer
- (void)ijf_removeObserver:(id)observer
                forKeyPath:(NSString *_Nullable)keyPath;

@end

NS_ASSUME_NONNULL_END
