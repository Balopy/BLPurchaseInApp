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
//@property (nonatomic, copy) NSString *address;
@end



@implementation BLPurchaseInApp

+ (instancetype)purchaseInApp {
    
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
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
        BLLog(@"不允许程序内付费");
    }
    
}
///请求商品
- (void)requestProductData:(NSString *)productId
{
    BLLog(@"-------------请求对应的产品信息----------------");
    
    NSSet *nsset = [NSSet setWithObjects:productId, nil];
    
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
    productsRequest.delegate = self;
    [productsRequest start];
}


///收到产品返回信息
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    BLLog(@"--------------收到产品反馈消息---------------------");
    NSArray *product = response.products;
    
    BLLog(@"invalidProductIdentifiers:%@", response.invalidProductIdentifiers);
    
    BLLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    
    SKProduct *skProduct = nil;
    for (SKProduct *tmp in product) {
        BLLog(@"--------%@", [tmp description]);
        BLLog(@"--------%@", [tmp localizedTitle]);
        BLLog(@"--------%@", [tmp localizedDescription]);
        BLLog(@"--------%@", [tmp price]);
        BLLog(@"--------%@", [tmp productIdentifier]);
        
        if([tmp.productIdentifier isEqualToString:self.productId])
        {
            skProduct = tmp;
        }
    }
    
    SKPayment *payment = [SKPayment paymentWithProduct:skProduct];
    
    BLLog(@"发送购买请求");
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

///请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    if (self.failTransaction) {
        self.failTransaction (@"网络连接失败");
    }
    BLLog(@"------------------错误-----------------:%@", error);
}

- (void)requestDidFinish:(SKRequest *)request
{
    BLLog(@"------------反馈信息结束-----------------");
}

///监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction
{
    for(SKPaymentTransaction *tran in transaction)
    {
        switch (tran.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                BLLog(@"交易完成");
                [self completeTransaction:tran];
                
                break;
            case SKPaymentTransactionStatePurchasing:
                BLLog(@"商品添加进列表");
                
                break;
            case SKPaymentTransactionStateRestored:
                BLLog(@"已经购买过商品");
                [self restoreTransaction:tran];
                
                break;
            case SKPaymentTransactionStateFailed: {
                BLLog(@"打印错误日志---%@",tran.error.description);
                
                [self failedTransaction:tran];
            } break;
            default:
                break;
        }
    }
}




///交易结束
- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    //https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html
    
    [self requestReceipt:AppStore];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)requestReceipt:(NSString *)url {
    
    //系统IOS7.0以上获取支付验证凭证的方式应该改变，切验证返回的数据结
    //得到的凭证只能使用 base64解码,规则这么定的
    
    //file:///private/var/mobile/Containers/Data/Application/4F044402-6EFB-4C89-ACBB-2F0BC95664DD/StoreKit/sandboxReceipt
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];

    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    
    if (!receipt) {
        
        if (self.failTransaction) {
            
            self.failTransaction (@"交易失败");
        }
        return;
    }
    
    NSString *receiptCode = [receipt base64EncodedStringWithOptions:0];
    NSError *error;
    NSDictionary *requestContents = @{ @"receipt-data": receiptCode };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&error];
    
    // Create a POST request with the receipt data.
    NSURL *storeURL = [NSURL URLWithString:url];
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
                
                [self checkPayForReciept:jsonResponse receipt:receiptCode url:url];
            }
        }
    }];
}
- (void) checkPayForReciept:(NSDictionary *)jsonResponse receipt:(NSString *)receipt url:(NSString *)url {
    
    NSUInteger status = [[jsonResponse objectForKey:@"status"] integerValue];
    
    NSString *message = @"";
    switch (status) {
            
        case 0: {//验证成功
            
//            NSString *temp = [NSString stringWithFormat:@"%@#", url];
//            message = [temp stringByAppendingString:receipt];
            if (self.purchaseBlock) {
                self.purchaseBlock (receipt);
            }
        } break;
            
        case 21007://使用的是沙盒测试账号, 但是线上环境
        {
//            NSString *temp = [NSString stringWithFormat:@"%@#",SANDBOX];
//            message = [temp stringByAppendingString:receipt];
            [self requestReceipt:SANDBOX];
            
        }
            break;
        case 21008://使用的是线上账号, 但是沙盒测试环境
        {
//            NSString *temp = [NSString stringWithFormat:@"%@#",url];
//            message = [temp stringByAppendingString:receipt];
            if (self.purchaseBlock) {
                self.purchaseBlock (receipt);
            }
        }
            break;
            
        default:
            break;
    }
    BLLog(@"^^^^^^^^^^^^%@", message);
    
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    NSString *descrip = @"";
    
    if(transaction.error.code != SKErrorPaymentCancelled) {
        
        descrip = transaction.error.userInfo[@"NSLocalizedDescription"];
    } else {
        descrip = @"交易取消";
    }
    
    BLLog(@"----%@", descrip);
    
    if (self.failTransaction) {
        
        self.failTransaction (descrip);
    }
    ///从队列中移除已添加的交易
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
}

#pragma mark--------内购结束---------
- (void)restoreTransaction:(SKPaymentTransaction *)transaction
{
    BLLog(@"----内购结束----");
    /// 对于已购商品，处理恢复购买的逻辑
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}


- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    BLLog(@"---SKPaymentQueue---dealloc---");
}

@end

