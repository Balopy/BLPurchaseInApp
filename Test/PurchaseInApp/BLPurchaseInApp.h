///
///  BLPurchaseInApp.h
///  268EDU_Demo
///
///  Created by yzla50010 on 2017/3/30.
///  Copyright © 2017年 edu268. All rights reserved.
///

#import <Foundation/Foundation.h>

typedef void(^BLPurchaseBlock)(NSString *str);
typedef void(^BLFailedTransaction)(NSString *str);

@interface BLPurchaseInApp : NSObject

+ (instancetype) purchaseInApp;

- (void) purchaseInAppWithProduct:(NSString *)product;

///验证内购凭证
@property (nonatomic, copy) BLPurchaseBlock purchaseBlock;
///内购执行失败
@property (nonatomic, copy) BLFailedTransaction failTransaction;

@end

