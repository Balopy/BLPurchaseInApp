# PurchaseInApp
# 内购的安全用法

*内购的用法,通过这个文件,基本上就可以实现. 在回调验证的时候需要注意.

```
交易结束时, 需要向 iTunes Store 验证票据信息. 分为两种, 这里我定义了两个宏
沙盒测试环境验证
#define SANDBOX @"https://sandbox.itunes.apple.com/verifyReceipt"
//正式环境验证
#define AppStore @"https://buy.itunes.apple.com/verifyReceipt"

```

```

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
  
  //系统IOS7.0以后，验证返回的数据
    //得到的凭证只能使用 base64解码,规则这么定的
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

```

```

/*! 通过返回的 jsonResponse 数据中的 status, 做判断, 验证票据信息, 是否正确
可参考
https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html
*/
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

```
