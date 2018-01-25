///
///  BLPurchaseInApp.m
///  268EDU_Demo
///
///  Created by yzla50010 on 2017/3/30.
///  Copyright © 2017年 edu268. All rights reserved.
///

#import "BLPurchaseInApp.h"
#import <StoreKit/StoreKit.h>
//沙盒测试环境验证
#define SANDBOX @"https://sandbox.itunes.apple.com/verifyReceipt"
//正式环境验证
#define AppStore @"https://buy.itunes.apple.com/verifyReceipt"
@interface BLPurchaseInApp ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>

@property (nonatomic, copy) NSString *productId;

@end

@implementation BLPurchaseInApp

+ (instancetype)purchaseInApp {
    
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //添加监听, 在支付成功后, 移除监听
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)purchaseInAppWithProduct:(NSString *)product {
    
    self.productId = product;
    
    ///如果余额不足走内购
    if([SKPaymentQueue canMakePayments]) {
        
        [self requestProductData:product];
    } else {
        
        NSLog(@"不允许程序内付费");
    }
}
///请求商品
- (void)requestProductData:(NSString *)productId {
    NSLog(@"-------------请求对应的产品信息----------------");
    
    NSSet *nsset = [NSSet setWithObjects:productId, nil];
    
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
    productsRequest.delegate = self;
    [productsRequest start];
}


///收到产品返回信息
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
  
    NSLog(@"--------------收到产品反馈消息---------------------");
    NSArray *product = response.products;
    
    NSLog(@"invalidProductIdentifiers:%@", response.invalidProductIdentifiers);
    
    NSLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    
    SKProduct *skProduct = nil;
    for (SKProduct *tmp in product) {
        NSLog(@"--------%@", [tmp description]);
        NSLog(@"--------%@", [tmp localizedTitle]);
        NSLog(@"--------%@", [tmp localizedDescription]);
        NSLog(@"--------%@", [tmp price]);
        NSLog(@"--------%@", [tmp productIdentifier]);
        
        if([tmp.productIdentifier isEqualToString:self.productId]){
            skProduct = tmp;
        }
    }
    
    SKPayment *payment = [SKPayment paymentWithProduct:skProduct];
    
    NSLog(@"发送购买请求");
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

///请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"------------------错误-----------------:%@", error);
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"------------反馈信息结束-----------------");
}

///监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction {
  
    for(SKPaymentTransaction *tran in transaction) {
       
        switch (tran.transactionState){
            case SKPaymentTransactionStatePurchased:
             
                NSLog(@"交易完成");
                [self completeTransaction:tran];
                
                break;
            case SKPaymentTransactionStatePurchasing:
               
                NSLog(@"商品添加进列表");
                break;
            case SKPaymentTransactionStateRestored:
              
                NSLog(@"已经购买过商品");
                [self restoreTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed: {
              
                NSLog(@"打印错误日志---%@",tran.error.description);
                [self failedTransaction:tran];
            } break;
            default:
                break;
        }
    }
}




/*! 
* 交易结束
* 交易结束需要向服务端验证 iTunes store 产生的票据信息, 因为在测试阶段及上线审核时, 会有沙箱测试账号,
* 所以, 要验证两种情况, 本地做一次验证, 根据iTunes store 返回的信息, 向服务端发送 验证信息, 服务端进行二次验证,
* 我这里, 是向服务端, 发送了测试或线上的验证地址#reciept, 服务端,不需要在判断是不是沙盒测试, 还是线上, 直接验证.
*/
- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    //https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html
    //系统IOS7.0以上获取支付验证凭证的方式应该改变，切验证返回的数据结
    //得到的凭证只能使用 base64解码,规则这么订的
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    
    if (!receipt) {
        
        if (self.failTransaction) {
            
            self.failTransaction (@"交易失败");
        }
        return;
    }
   
    // Create the JSON object that describes the request
    NSString *receiptCode = [receipt base64EncodedStringWithOptions:0];
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": receiptCode
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&error];

    // Create a POST request with the receipt data.
    NSURL *storeURL = [NSURL URLWithString:AppStore];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    // Make a connection to the iTunes Store on a background queue.
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            /* ... Handle error ... */
        } else {
            
            NSError *error;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
           
            if (!jsonResponse) {//为空
               
                if (self.failTransaction) {
                    
                    self.failTransaction (@"验证失败");
                }

            } else {
            
                [self checkPayForReciept:jsonResponse receipt:receiptCode];
            }
        }
    }];
    
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


- (void) checkPayForReciept:(NSDictionary *)jsonResponse receipt:(NSString *)receipt {
    
    NSUInteger status = [[jsonResponse objectForKey:@"status"] integerValue];
    
    NSString *message = @"";
    switch (status) {
            
        case 0: {//验证成功
            NSString *temp = [NSString stringWithFormat:@"%@#",AppStore];
            
            message = [temp stringByAppendingString:receipt];
        } break;
            
        case 21007://使用的是沙盒测试账号, 但是线上环境
        {
            NSString *temp = [NSString stringWithFormat:@"%@#",SANDBOX];
            
            message = [temp stringByAppendingString:receipt];
        }
            break;
        case 21008://使用的是线上账号, 但是沙盒测试环境
        {
            
            NSString *temp = [NSString stringWithFormat:@"%@#",AppStore];
            
            message = [temp stringByAppendingString:receipt];
        }
            break;
            
        default:
            break;
    }
    
    if (self.purchaseBlock) {
        self.purchaseBlock (message);
    }
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    NSString *descrip = @"";
    
    if(transaction.error.code != SKErrorPaymentCancelled) {
        
        descrip = transaction.error.userInfo[@"NSLocalizedDescription"];
    } else {
        descrip = @"交易取消";
    }
    
    NSLog(@"----%@", descrip);
    
    if (self.failTransaction) {
        
        self.failTransaction (descrip);
    }
    ///从队列中移除已添加的交易
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
}
#pragma mark--------内购结束---------
- (void)restoreTransaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"----内购结束----");
    /// 对于已购商品，处理恢复购买的逻辑
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}


- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    NSLog(@"---SKPaymentQueue---dealloc---");
}

@end
