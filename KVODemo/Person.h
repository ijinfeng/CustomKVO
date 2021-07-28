//
//  Person.h
//  KVODemo
//
//  Created by jinfeng on 2021/7/28.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject

@property (nonatomic, copy) NSString *name;

@property (nonatomic, assign) int age;

@property (nonatomic, assign) float money;

@property (nonatomic, assign) CGSize size;

@property (nonatomic, assign) double dd;

@property (nonatomic, assign) float ff;

@property (nonatomic, assign) CGFloat cgf;

@end

NS_ASSUME_NONNULL_END
