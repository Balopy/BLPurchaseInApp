///
///  BLPurchaseInApp.h
///  268EDU_Demo
///
///  Created by yzla50010 on 2017/3/30.
///  Copyright © 2017年 edu268. All rights reserved.
///

#import <Foundation/Foundation.h>

//内购流程-商品购买成功,回调, 传一个reciept 票据字符串
typedef void(^BLPurchaseBlock)(NSString *str);
//商品购买失败,或取消
typedef void(^BLFailedTransaction)(NSString *str);

@interface BLPurchaseInApp : NSObject

//一个类方法
+ (instancetype) purchaseInApp;

//通过商口id 发起内购支付流程
- (void) purchaseInAppWithProduct:(NSString *)product;

///验证内购凭证
@property (nonatomic, copy) BLPurchaseBlock purchaseBlock;
///内购执行失败
@property (nonatomic, copy) BLFailedTransaction failTransaction;

@end
