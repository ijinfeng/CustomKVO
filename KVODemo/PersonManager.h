//
//  PersonManager.h
//  KVODemo
//
//  Created by jinfeng on 2021/7/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PersonManager : NSObject

@property (nonatomic, strong) NSString *name;

+ (instancetype)shared;

@end

NS_ASSUME_NONNULL_END
