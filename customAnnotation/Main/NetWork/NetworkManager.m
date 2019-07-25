//
//  NetworkManager.m
//  customAnnotation
//
//  Created by ZHANG on 2019/7/25.
//  Copyright © 2019年 Z. All rights reserved.
//

#import "NetworkManager.h"
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetExportSession.h>
#import <AVFoundation/AVMediaFormat.h>
#import <Photos/Photos.h>
#import "AFNetworking.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "UIImage+CompressImage.h"
#import "NetworkManagerCache.h"


static NSMutableArray *tasks;
static NSString *privateNetworkBaseUrl = nil;
static NSUInteger maxCacheSize = 0;

@interface NetworkManager ()

@property(nonatomic, strong) AFHTTPSessionManager *sessionManager;

@end


@implementation NetworkManager

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 尝试清除缓存
        if (maxCacheSize > 0 && [NetworkManagerCache getAllHttpCacheSize] > maxCacheSize) {
            [NetworkManagerCache clearAllHttpCache];
        }
    });
}


+ (instancetype)sharedManager {
    static NetworkManager *manger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manger = [[super allocWithZone:NULL] init];
    });
    return manger;
}

+ (void)initialize {
    [self setupNetManager];
}

+ (void)setupNetManager {
    NetworkManagerShare.sessionManager = [AFHTTPSessionManager manager];
    /*! 设置请求超时时间，默认：30秒 */
    NetworkManagerShare.timeoutInterval = 30;
    /*! 打开状态栏的等待菊花 */
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    /*! 设置响应数据的基本类型 */
    NetworkManagerShare.sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/css", @"text/xml", @"text/plain", @"application/javascript", @"application/x-www-form-urlencoded", @"image/*", nil];
    // 配置自建证书的Https请求
    [self setupSecurityPolicy];
}

/**
 配置自建证书的Https请求，只需要将CA证书文件放入根目录就行
 */
+ (void)setupSecurityPolicy {
    NSSet <NSData *> *cerSet = [AFSecurityPolicy certificatesInBundle:[NSBundle mainBundle]];
    if (cerSet.count == 0) {
        /*!
         采用默认的defaultPolicy就可以了. AFN默认的securityPolicy就是它, 不必另写代码. AFSecurityPolicy类中会调用苹果security.framework的机制去自行验证本次请求服务端放回的证书是否是经过正规签名.
         */
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
        securityPolicy.allowInvalidCertificates = YES;
        securityPolicy.validatesDomainName = NO;
        NetworkManagerShare.sessionManager.securityPolicy = securityPolicy;
    } else {
        /*! 自定义的CA证书配置如下： */
        /*! 自定义security policy, 先前确保你的自定义CA证书已放入工程Bundle */
        // 使用证书验证模式
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:cerSet];
        // 如果需要验证自建证书(无效证书)，需要设置为YES
        securityPolicy.allowInvalidCertificates = YES;
        // 是否需要验证域名，默认为YES
        // securityPolicy.pinnedCertificates = [[NSSet alloc] initWithObjects:cerData, nil];
        
        NetworkManagerShare.sessionManager.securityPolicy = securityPolicy;
        /*! 如果服务端使用的是正规CA签发的证书, 那么以下几行就可去掉: */
        // NSSet <NSData *> *cerSet = [AFSecurityPolicy certificatesInBundle:[NSBundle mainBundle]];
        // AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate withPinnedCertificates:cerSet];
        // policy.allowInvalidCertificates = YES;
        // BANetManagerShare.sessionManager.securityPolicy = policy;
    }
}


/**
 网络请求的实例方法 get
 
 @param urlString 请求的地址
 @param isNeedCache 是否需要缓存，只有 get / post 请求有缓存配置
 @param parameters 请求的参数
 @param successBlock 请求成功的回调
 @param failureBlock 请求失败的回调
 @param progressBlock 进度
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)requestGETWithUrlString:(NSString *)urlString
                                   isNeedCache:(BOOL)isNeedCache
                                    parameters:(id)parameters
                                  successBlock:(NetResponseSuccessBlock)successBlock
                                  failureBlock:(NetResponseFailBlock)failureBlock
                                 progressBlock:(NetDownloadProgressBlock)progressBlock {
    
     return [self requestWithType:NetHttpRequestTypeGet
                      isNeedCache:isNeedCache
                        urlString:urlString
                       parameters:parameters
                     successBlock:successBlock
                     failureBlock:failureBlock
                    progressBlock:progressBlock];
}

/**
 网络请求的实例方法 post
 
 @param urlString 请求的地址
 @param isNeedCache 是否需要缓存，只有 get / post 请求有缓存配置
 @param parameters 请求的参数
 @param successBlock 请求成功的回调
 @param failureBlock 请求失败的回调
 @param progressBlock 进度
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)requestPOSTWithUrlString:(NSString *)urlString
                                    isNeedCache:(BOOL)isNeedCache
                                     parameters:(id)parameters
                                   successBlock:(NetResponseSuccessBlock)successBlock
                                   failureBlock:(NetResponseFailBlock)failureBlock
                                  progressBlock:(NetDownloadProgressBlock)progressBlock {
    
    return [self requestWithType:NetHttpRequestTypePost
                     isNeedCache:isNeedCache
                       urlString:urlString
                      parameters:parameters
                    successBlock:successBlock
                    failureBlock:failureBlock
                   progressBlock:progressBlock];

}

/**
 网络请求的实例方法 put
 
 @param urlString 请求的地址
 @param parameters 请求的参数
 @param successBlock 请求成功的回调
 @param failureBlock 请求失败的回调
 @param progressBlock 进度
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)requestPUTWithUrlString:(NSString *)urlString
                                    parameters:(id)parameters
                                  successBlock:(NetResponseSuccessBlock)successBlock
                                  failureBlock:(NetResponseFailBlock)failureBlock
                                 progressBlock:(NetDownloadProgressBlock)progressBlock {
    
    return [self requestWithType:NetHttpRequestTypePut
                     isNeedCache:NO
                       urlString:urlString
                      parameters:parameters
                    successBlock:successBlock
                    failureBlock:failureBlock
                   progressBlock:progressBlock];

}
/**
 网络请求的实例方法 delete
 
 @param urlString 请求的地址
 @param parameters 请求的参数
 @param successBlock 请求成功的回调
 @param failureBlock 请求失败的回调
 @param progressBlock 进度
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)requestDELETEWithUrlString:(NSString *)urlString
                                       parameters:(id)parameters
                                     successBlock:(NetResponseSuccessBlock)successBlock
                                     failureBlock:(NetResponseFailBlock)failureBlock
                                    progressBlock:(NetDownloadProgressBlock)progressBlock {
    
    return [self requestWithType:NetHttpRequestTypeDelete
                     isNeedCache:NO
                       urlString:urlString
                      parameters:parameters
                    successBlock:successBlock
                    failureBlock:failureBlock
                   progressBlock:progressBlock];

}



#pragma mark - 网络请求的类方法 --- get / post / put / delete
/*!
 *  网络请求的实例方法    已经做了拼接baseURL处理，如果有baseURL就会自动拼接，没有就传完整路径
 *
 *  @param type         get / post / put / delete
 *  @param isNeedCache  是否需要缓存，只有 get / post 请求有缓存配置
 *  @param urlString    请求的地址
 *  @param parameters    请求的参数
 *  @param successBlock 请求成功的回调
 *  @param failureBlock 请求失败的回调
 *  @param progressBlock 进度
 */
+ (NetURLSessionTask *)requestWithType:(NetHttpRequestType)type
                           isNeedCache:(BOOL)isNeedCache
                             urlString:(NSString *)urlString
                            parameters:(id)parameters
                          successBlock:(NetResponseSuccessBlock)successBlock
                          failureBlock:(NetResponseFailBlock)failureBlock
                         progressBlock:(NetDownloadProgressBlock)progressBlock {
    if (urlString == nil) {
        return nil;
    }
    
    kWeak;
    /*! 检查地址中是否有中文 */
    NSString *URLString = [NSURL URLWithString:urlString] ? urlString : [self strUTF8Encoding:urlString];
    NSString *absolute = [self absoluteUrlWithPath:URLString];
    if ([self baseUrl] == nil) {
        if ([NSURL URLWithString:urlString] == nil) {
            NSLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    } else {
        NSURL *absoluteURL = [NSURL URLWithString:absolute];
        if (absoluteURL == nil) {
            NSLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    }

    NSString *requestType;
    switch (type) {
        case 0:
            requestType = @"GET";
            break;
        case 1:
            requestType = @"POST";
            break;
        case 2:
            requestType = @"PUT";
            break;
        case 3:
            requestType = @"DELETE";
            break;
        default:
            break;
    }
    
    AFHTTPSessionManager *scc = NetworkManagerShare.sessionManager;
    AFHTTPResponseSerializer *scc2 = scc.responseSerializer;
    AFHTTPRequestSerializer *scc3 = scc.requestSerializer;
    NSTimeInterval timeoutInterval = NetworkManagerShare.timeoutInterval;
    
    NSString *isCache = isNeedCache ? @"开启":@"关闭";
    CGFloat allCacheSize = [NetworkManagerCache getAllHttpCacheSize];
    
    if (NetworkManagerShare.isOpenLog) {
        NSLog(@"\n\n\n******************** 请求参数 ***************************");
        NSLog(@"\n--请求头: %@\n--超时时间设置：%.1f 秒【默认：30秒】\n--AFHTTPResponseSerializer：%@【默认：AFJSONResponseSerializer】\n--AFHTTPRequestSerializer：%@【默认：AFJSONRequestSerializer】\n--请求方式: %@\n--请求URL: %@\n--请求param: %@\n--是否启用缓存：%@【默认：开启】\n--目前总缓存大小：%.6fM\n", NetworkManagerShare.sessionManager.requestSerializer.HTTPRequestHeaders, timeoutInterval, scc2, scc3, requestType, absolute, parameters, isCache, allCacheSize);
        NSLog(@"\n********************************************************\n\n----------------");
    }
    
    NetURLSessionTask *sessionTask = nil;
    
    // 读取缓存
    id responseCacheData = [NetworkManagerCache httpCacheWithUrlString:absolute parameters:parameters];
    
    if (isNeedCache && responseCacheData != nil) {
        if (successBlock) {
            successBlock(responseCacheData);
        }
        if (NetworkManagerShare.isOpenLog) {
            NSLog(@"取用缓存数据结果： *** %@", responseCacheData);
        }
        [[weakSelf tasks] removeObject:sessionTask];
        return nil;
    }
    
    //  string 参数序列化
    if (NetworkManagerShare.isSetQueryStringSerialization) {
        [NetworkManagerShare.sessionManager.requestSerializer setQueryStringSerializationWithBlock:^NSString * _Nonnull(NSURLRequest * _Nonnull request, id  _Nonnull parameters, NSError * _Nullable __autoreleasing * _Nullable error) {
            return parameters;
        }];
    }

    
    if (type == NetHttpRequestTypeGet) {
        sessionTask = [NetworkManagerShare.sessionManager GET:absolute parameters:parameters  progress:^(NSProgress * _Nonnull downloadProgress) {
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if (NetworkManagerShare.isOpenLog) {
                NSLog(@"get 请求数据结果\n===> %@", responseObject);
            }
            if (successBlock) {
                successBlock(responseObject);
            }
            // 对数据进行异步缓存
            [NetworkManagerCache setHttpCache:responseObject urlString:absolute parameters:parameters];
            [[weakSelf tasks] removeObject:sessionTask];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"错误信息：%@",error);
            if (failureBlock) {
                failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
        }];
        
    } else if (type == NetHttpRequestTypePost) {
        sessionTask = [NetworkManagerShare.sessionManager POST:absolute parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
            if (NetworkManagerShare.isOpenLog) {
                NSLog(@"上传进度--%lld, 总进度---%lld",uploadProgress.completedUnitCount,uploadProgress.totalUnitCount);
            }
            /*! 回到主线程刷新UI */
            dispatch_async(dispatch_get_main_queue(), ^{
                if (progressBlock) {
                    progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
                }
            });
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if (NetworkManagerShare.isOpenLog) {
                NSLog(@"post 请求数据结果\n===> %@", responseObject);
            }
            
            if (successBlock) {
                successBlock(responseObject);
            }
            // 对数据进行异步缓存
            [NetworkManagerCache setHttpCache:responseObject urlString:absolute parameters:parameters];
            [[weakSelf tasks] removeObject:sessionTask];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"错误信息：%@",error);
            if (failureBlock) {
                failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
        }];
        
    } else if (type == NetHttpRequestTypePut) {
        sessionTask = [NetworkManagerShare.sessionManager PUT:absolute parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if (NetworkManagerShare.isOpenLog) {
                NSLog(@"put 请求数据结果\n===> %@", responseObject);
            }
            if (successBlock) {
                successBlock(responseObject);
            }
            [[weakSelf tasks] removeObject:sessionTask];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"错误信息：%@",error);
            if (failureBlock) {
                failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
        }];
        
    } else if (type == NetHttpRequestTypeDelete) {
        sessionTask = [NetworkManagerShare.sessionManager DELETE:absolute parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if (NetworkManagerShare.isOpenLog) {
                NSLog(@"delete 请求数据结果\n===> %@", responseObject);
            }
            if (successBlock) {
                successBlock(responseObject);
            }
            [[weakSelf tasks] removeObject:sessionTask];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"错误信息：%@",error);
            if (failureBlock) {
                failureBlock(error);
            }
            [[weakSelf tasks] removeObject:sessionTask];
        }];
    }
    if (sessionTask) {
        [[weakSelf tasks] addObject:sessionTask];
    }
    return sessionTask;
}





/**
 上传图片(多图)    已经做了拼接baseURL处理，如果有baseURL就会自动拼接，没有就传完整路径
 
 @param urlString urlString description
 @param parameters 上传图片预留参数---视具体情况而定 可为空
 @param imageArray 上传的图片数组
 @param fileNames 上传的图片数组 fileName
 @param imageType 图片类型，如：png、jpg、gif
 @param imageScale 图片压缩比率（0~1.0）
 @param successBlock 上传成功的回调
 @param failureBlock 上传失败的回调
 @param progressBlock 上传进度
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)uploadImageWithUrlString:(NSString *)urlString
                                     parameters:(id)parameters
                                     imageArray:(NSArray *)imageArray
                                      fileNames:(NSArray <NSString *>*)fileNames
                                      imageType:(NSString *)imageType
                                     imageScale:(CGFloat)imageScale
                                   successBlock:(NetResponseSuccessBlock)successBlock
                                   failureBlock:(NetResponseFailBlock)failureBlock
                                  progressBlock:(NetUploadProgressBlock)progressBlock {
    
    if (urlString == nil) {
        return nil;
    }
    
    kWeak;
    /*! 检查地址中是否有中文 */
    NSString *URLString = [NSURL URLWithString:urlString] ? urlString : [self strUTF8Encoding:urlString];
    NSString *absolute = [self absoluteUrlWithPath:URLString];
    if ([self baseUrl] == nil) {
        if ([NSURL URLWithString:urlString] == nil) {
            NSLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    } else {
        NSURL *absoluteURL = [NSURL URLWithString:absolute];
        if (absoluteURL == nil) {
            NSLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    }
    
    if (NetworkManagerShare.isOpenLog) {
        NSLog(@"\n\n\n******************** 请求参数 ***************************");
        NSLog(@"\n--请求头: %@\n--请求方式: %@\n--请求URL: %@\n--请求param: %@\n\n",NetworkManagerShare.sessionManager.requestSerializer.HTTPRequestHeaders, @"POST",absolute, parameters);
        NSLog(@"\n********************************************************\n\n----------------");
    }
    
    NetURLSessionTask *sessionTask = nil;
    sessionTask = [NetworkManagerShare.sessionManager POST:absolute parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        /*! 出于性能考虑,将上传图片进行压缩 */
        [imageArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            /*! image的压缩方法 */
            UIImage *resizedImage;
            /*! 此处是使用原生系统相册 */
            if ([obj isKindOfClass:[PHAsset class]]) {
                PHAsset *asset = (PHAsset *)obj;
                PHCachingImageManager *imageManager = [[PHCachingImageManager alloc] init];
                [imageManager requestImageForAsset:asset targetSize:CGSizeMake(asset.pixelWidth , asset.pixelHeight) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                    if (NetworkManagerShare.isOpenLog) {
                        NSLog(@" width:%f height:%f",result.size.width,result.size.height);
                    }
                    [self uploadImageWithFormData:formData resizedImage:result imageType:imageType imageScale:imageScale fileNames:fileNames index:idx];
                }];
                
            } else {
                /*! 此处是使用其他第三方相册，可以自由定制压缩方法 */
                resizedImage = obj;
                [self uploadImageWithFormData:formData resizedImage:resizedImage imageType:imageType imageScale:imageScale fileNames:fileNames index:idx];
            }
        }];
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if (NetworkManagerShare.isOpenLog) {
            NSLog(@"上传进度--%lld, 总进度---%lld",uploadProgress.completedUnitCount,uploadProgress.totalUnitCount);
        }
                /*! 回到主线程刷新UI */
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progressBlock) {
                progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
            }
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (NetworkManagerShare.isOpenLog) {
            NSLog(@"上传图片成功 = %@",responseObject);
        }

        if (successBlock) {
            successBlock(responseObject);
        }
        
        [[weakSelf tasks] removeObject:sessionTask];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"错误信息：%@",error);
        if (failureBlock) {
            failureBlock(error);
        }
        [[weakSelf tasks] removeObject:sessionTask];
    }];
    
    if (sessionTask) {
        [[self tasks] addObject:sessionTask];
    }
    return sessionTask;
}

/**
 视频上传
 
 @param urlString 上传的url
 @param parameters 上传视频预留参数---视具体情况而定 可移除
 @param videoPath 上传视频的本地沙河路径
 @param successBlock 成功的回调
 @param failureBlock 失败的回调
 @param progressBlock 上传的进度
 */
+ (void)uploadVideoWithUrlString:(NSString *)urlString
                      parameters:(id)parameters
                       videoPath:(NSString *)videoPath
                    successBlock:(NetResponseSuccessBlock)successBlock
                    failureBlock:(NetResponseFailBlock)failureBlock
                   progressBlock:(NetUploadProgressBlock)progressBlock {
    /*! 获得视频资源 */
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:videoPath]  options:nil];
    /*! 压缩 */
    // NSString *const AVAssetExportPreset640x480;
    // NSString *const AVAssetExportPreset960x540;
    // NSString *const AVAssetExportPreset1280x720;
    // NSString *const AVAssetExportPreset1920x1080;
    // NSString *const AVAssetExportPreset3840x2160;
    
    /*! 创建日期格式化器 */
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
    /*! 转化后直接写入Library---caches */
    NSString *videoWritePath = [NSString stringWithFormat:@"output-%@.mp4",[formatter stringFromDate:[NSDate date]]];
    NSString *outfilePath = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@", videoWritePath];
    AVAssetExportSession *avAssetExport = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetMediumQuality];
    avAssetExport.outputURL = [NSURL fileURLWithPath:outfilePath];
    avAssetExport.outputFileType =  AVFileTypeMPEG4;
    
    [avAssetExport exportAsynchronouslyWithCompletionHandler:^{
        switch ([avAssetExport status]) {
            case AVAssetExportSessionStatusCompleted:
            {
                [NetworkManagerShare.sessionManager POST:urlString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                    NSURL *filePathURL2 = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", outfilePath]];
                    // 获得沙盒中的视频内容
                    [formData appendPartWithFileURL:filePathURL2 name:@"video" fileName:outfilePath mimeType:@"application/octet-stream" error:nil];
                    
                } progress:^(NSProgress * _Nonnull uploadProgress) {
                    if (NetworkManagerShare.isOpenLog) {
                        NSLog(@"上传进度--%lld, 总进度---%lld",uploadProgress.completedUnitCount,uploadProgress.totalUnitCount);
                    }
                    
                    /*! 回到主线程刷新UI */
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (progressBlock) {
                            progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
                        }
                    });
                } success:^(NSURLSessionDataTask * _Nonnull task, NSDictionary *  _Nullable responseObject) {
                    NSLog(@"上传视频成功 = %@",responseObject);
                    if (successBlock) {
                        successBlock(responseObject);
                    }
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    NSLog(@"上传视频失败 = %@", error);
                    if (failureBlock) {
                        failureBlock(error);
                    }
                }];
                break;
            }
            default:
                break;
        }
    }];
}


/**
 文件下载
 
 @param urlString 请求的url
 @param parameters 文件下载预留参数---视具体情况而定 可移除
 @param savePath 下载文件保存路径
 @param successBlock 下载文件成功的回调
 @param failureBlock 下载文件失败的回调
 @param progressBlock 下载文件的进度显示
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)downLoadFileWithUrlString:(NSString *)urlString
                                      parameters:(id)parameters
                                        savaPath:(NSString *)savePath
                                    successBlock:(NetResponseSuccessBlock)successBlock
                                    failureBlock:(NetResponseFailBlock)failureBlock
                                   progressBlock:(NetDownloadProgressBlock)progressBlock {
    if (urlString == nil) {
        return nil;
    }
    NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    if (NetworkManagerShare.isOpenLog) {
        NSLog(@"\n\n\n******************** 请求参数 ***************************");
        NSLog(@"\n--请求头: %@\n--请求方式: %@\n--请求URL: %@\n--请求param: %@\n\n",NetworkManagerShare.sessionManager.requestSerializer.HTTPRequestHeaders, @"download",urlString, parameters);
        NSLog(@"\n********************************************************\n\n----------------");
    }
   
    NetURLSessionTask *sessionTask = nil;
    
    sessionTask = [NetworkManagerShare.sessionManager downloadTaskWithRequest:downloadRequest progress:^(NSProgress * _Nonnull downloadProgress) {
        if (NetworkManagerShare.isOpenLog) {
            NSLog(@"下载进度：%.2lld%%",100 * downloadProgress.completedUnitCount/downloadProgress.totalUnitCount);
        }
        /*! 回到主线程刷新UI */
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progressBlock) {
                progressBlock(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
            }
        });
        
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        if (!savePath) {
            NSURL *downloadURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
            if (NetworkManagerShare.isOpenLog) {
                NSLog(@"默认路径--%@",downloadURL);
            }
            return [downloadURL URLByAppendingPathComponent:[response suggestedFilename]];
        } else {
            return [NSURL fileURLWithPath:savePath];
        }
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        [[self tasks] removeObject:sessionTask];
        
        NSLog(@"下载文件成功");
        if (error == nil) {
            if (successBlock) {
                /*! 返回完整路径 */
                successBlock([filePath path]);
            } else {
                if (failureBlock) {
                    failureBlock(error);
                }
            }
        }
    }];
    /*! 开始启动任务 */
    [sessionTask resume];
    if (sessionTask) {
        [[self tasks] addObject:sessionTask];
    }
    return sessionTask;
}

/**
 文件上传
 
 @param urlString 上传路径
 @param parameters 上传参数
 @param fileName 上传名字
 @param filePath 上传本地路径
 @param successBlock 成功回调
 @param failureBlock 失败回调
 @param progressBlock 上传进度回调
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)uploadFileWithUrlString:(NSString *)urlString
                                    parameters:(id)parameters
                                      fileName:(NSString *)fileName
                                      filePath:(NSString *)filePath
                                  successBlock:(NetResponseSuccessBlock)successBlock
                                  failureBlock:(NetResponseFailBlock)failureBlock
                                 progressBlock:(NetUploadProgressBlock)progressBlock {
    if (urlString == nil) {
        return nil;
    }
    if (NetworkManagerShare.isOpenLog) {
        NSLog(@"\n\n\n******************** 请求参数 ***************************");
        NSLog(@"\n--请求头: %@\n--请求方式: %@\n--请求URL: %@\n--请求param: %@\n\n",NetworkManagerShare.sessionManager.requestSerializer.HTTPRequestHeaders, @"uploadFile", urlString, parameters);
        NSLog(@"\n********************************************************\n\n----------------");
    }

    NetURLSessionTask *sessionTask = nil;
    sessionTask = [NetworkManagerShare.sessionManager POST:urlString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
        NSError *error = nil;
        [formData appendPartWithFileURL:[NSURL URLWithString:filePath] name:fileName error:&error];
        if (failureBlock && error) {
            failureBlock(error);
        }
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if (NetworkManagerShare.isOpenLog) {
            NSLog(@"上传进度--%lld, 总进度---%lld",uploadProgress.completedUnitCount,uploadProgress.totalUnitCount);
        }
        /*! 回到主线程刷新UI */
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progressBlock) {
                progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
            }
        });
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"上传文件成功");
        [[self tasks] removeObject:sessionTask];
        if (successBlock) {
            successBlock(responseObject);
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"错误信息：%@",error);
        [[self tasks] removeObject:sessionTask];
        if (failureBlock) {
            failureBlock(error);
        }
    }];
    
    /*! 开始启动任务 */
    [sessionTask resume];
    
    if (sessionTask) {
        [[self tasks] addObject:sessionTask];
    }
    return sessionTask;
}



#pragma mark - 网络状态监测
/*!
 *  开启网络监测
 */
+ (void)startNetWorkMonitoringWithBlock:(NetworkStatusBlock)networkStatus {
    /*! 1.获得网络监控的管理者 */
    AFNetworkReachabilityManager *manager = [AFNetworkReachabilityManager sharedManager];
    /*! 当使用AF发送网络请求时,只要有网络操作,那么在状态栏(电池条)wifi符号旁边显示  菊花提示 */
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    /*! 2.设置网络状态改变后的处理 */
    [manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        /*! 当网络状态改变了, 就会调用这个block */
        switch (status)
        {
            case AFNetworkReachabilityStatusUnknown:
                NSLog(@"未知网络");
                networkStatus ? networkStatus(NetworkStatusUnknown) : nil;
                break;
            case AFNetworkReachabilityStatusNotReachable:
                NSLog(@"没有网络");
                networkStatus ? networkStatus(NetworkStatusNotReachable) : nil;
                break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
                NSLog(@"手机自带网络");
                networkStatus ? networkStatus(NetworkStatusReachableViaWWAN) : nil;
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
                NSLog(@"wifi 网络");
                networkStatus ? networkStatus(NetworkStatusReachableViaWiFi) : nil;
                break;
        }
    }];
    [manager startMonitoring];
}

#pragma mark - 取消 Http 请求
/*!
 *  取消所有 Http 请求
 */
+ (void)cancelAllRequest {
    // 锁操作
    @synchronized(self) {
        [[self tasks] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            [task cancel];
        }];
        [[self tasks] removeAllObjects];
    }
}

/*!
 *  取消指定 URL 的 Http 请求
 */
+ (void)cancelRequestWithURL:(NSString *)URL {
    if (!URL) {
        return;
    }
    @synchronized (self) {
        [[self tasks] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task.currentRequest.URL.absoluteString hasPrefix:URL]) {
                [task cancel];
                [[self tasks] removeObject:task];
                *stop = YES;
            }
        }];
    }
}


#pragma mark - 压缩图片尺寸
/*! 对图片尺寸进行压缩 */
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    if (newSize.height > 375/newSize.width*newSize.height) {
        newSize.height = 375/newSize.width*newSize.height;
    }
    
    if (newSize.width > 375) {
        newSize.width = 375;
    }
    UIImage *newImage = [UIImage needCenterImage:image size:newSize scale:1.0];
    return newImage;
}



#pragma mark - url 中文格式化
+ (NSString *)strUTF8Encoding:(NSString *)str {
    /*! ios9适配的话 打开第一个 */
    if ([[UIDevice currentDevice] systemVersion].floatValue >= 9.0) {
        return [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    } else {
        return [str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
}

#pragma mark - setter / getter
/**
 存储着所有的请求task数组
 
 @return 存储着所有的请求task数组
 */
+ (NSMutableArray *)tasks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tasks = [[NSMutableArray alloc] init];
    });
    return tasks;
}


- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval {
    _timeoutInterval = timeoutInterval;
    NetworkManagerShare.sessionManager.requestSerializer.timeoutInterval = timeoutInterval;
}


- (void)setRequestSerializer:(NetHttpRequestSerializer)requestSerializer {
    _requestSerializer = requestSerializer;
    switch (requestSerializer) {
        case NetHttpRequestSerializerJSON:
        {
            NetworkManagerShare.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer] ;
        }
            break;
        case NetHttpRequestSerializerHTTP:
        {
            NetworkManagerShare.sessionManager.requestSerializer = [AFHTTPRequestSerializer serializer] ;
        }
            break;
        default:
            break;
    }
}

- (void)setResponseSerializer:(NetHttpResponseSerializer)responseSerializer {
    _responseSerializer = responseSerializer;
    switch (responseSerializer) {
        case NetHttpResponseSerializerJSON:
        {
            NetworkManagerShare.sessionManager.responseSerializer = [AFJSONResponseSerializer serializer] ;
        }
            break;
        case NetHttpResponseSerializerHTTP:
        {
            NetworkManagerShare.sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer] ;
        }
            break;
            
        default:
            break;
    }
}

- (void)setHttpHeaderFieldDictionary:(NSDictionary *)httpHeaderFieldDictionary {
    _httpHeaderFieldDictionary = httpHeaderFieldDictionary;
    
    if (![httpHeaderFieldDictionary isKindOfClass:[NSDictionary class]]) {
        NSLog(@"请求头数据有误，请检查！");
        return;
    }
    NSArray *keyArray = httpHeaderFieldDictionary.allKeys;
    
    if (keyArray.count <= 0) {
        NSLog(@"请求头数据有误，请检查！");
        return;
    }
    
    for (NSInteger i = 0; i < keyArray.count; i ++) {
        NSString *keyString = keyArray[i];
        NSString *valueString = httpHeaderFieldDictionary[keyString];
        
        [NetworkManager netSetValue:valueString forHTTPHeaderKey:keyString];
    }
}

/**
 *  自定义请求头
 */
+ (void)netSetValue:(NSString *)value forHTTPHeaderKey:(NSString *)HTTPHeaderKey {
    [NetworkManagerShare.sessionManager.requestSerializer setValue:value forHTTPHeaderField:HTTPHeaderKey];
}


/**
 删除所有请求头
 */
+ (void)netClearAuthorizationHeader {
    [NetworkManagerShare.sessionManager.requestSerializer clearAuthorizationHeader];
}

+ (void)uploadImageWithFormData:(id<AFMultipartFormData>  _Nonnull )formData
                   resizedImage:(UIImage *)resizedImage
                      imageType:(NSString *)imageType
                     imageScale:(CGFloat)imageScale
                      fileNames:(NSArray <NSString *> *)fileNames
                          index:(NSUInteger)index {
    /*! 此处压缩方法是jpeg格式是原图大小的0.8倍，要调整大小的话，就在这里调整就行了还是原图等比压缩 */
    if (imageScale == 0) {
        imageScale = 0.8;
    }
    NSData *imageData = UIImageJPEGRepresentation(resizedImage, imageScale ?: 1.f);
    /*! 拼接data */
    if (imageData != nil) {
        // 图片数据不为空才传递 fileName
        // [formData appendPartWithFileData:imgData name:[NSString stringWithFormat:@"picflie%ld",(long)i] fileName:@"image.png" mimeType:@" image/jpeg"];
        // 默认图片的文件名, 若fileNames为nil就使用
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyyMMddHHmmss";
        NSString *str = [formatter stringFromDate:[NSDate date]];
        NSString *imageFileName = [NSString stringWithFormat:@"%@%ld.%@",str, index, imageType?:@"jpg"];
        
        [formData appendPartWithFileData:imageData
                                    name:[NSString stringWithFormat:@"picflie%ld", index]
                                fileName:fileNames ? [NSString stringWithFormat:@"%@.%@",fileNames[index],imageType?:@"jpg"] : imageFileName
                                mimeType:[NSString stringWithFormat:@"image/%@",imageType ?: @"jpg"]];
        NSLog(@"上传图片 %lu 成功", (unsigned long)index);
    }
}

/**
 * 清空缓存：此方法可能会阻止调用线程，直到文件删除完成。
 */
- (void)clearAllHttpCache {
    [NetworkManagerCache clearAllHttpCache];
}


/** 更新基础URL */
+ (void)updateBaseUrl:(NSString *)baseUrl {
    privateNetworkBaseUrl = baseUrl;
}

+ (NSString *)baseUrl {
    return privateNetworkBaseUrl;
}


/**
 如果有baseURL，拼接baseURL和path

 @param path 路径
 @return 完整路径
 */
+ (NSString *)absoluteUrlWithPath:(NSString *)path {
    if (path == nil || path.length == 0) {
        return @"";
    }
    
    if ([self baseUrl] == nil || [[self baseUrl] length] == 0) {
        return path;
    }
    NSString *absoluteUrl = path;
    if (![path hasPrefix:@"http://"] && ![path hasPrefix:@"https://"]) {
        if ([[self baseUrl] hasSuffix:@"/"]) {
            if ([path hasPrefix:@"/"]) {
                NSMutableString * mutablePath = [NSMutableString stringWithString:path];
                [mutablePath deleteCharactersInRange:NSMakeRange(0, 1)];
                absoluteUrl = [NSString stringWithFormat:@"%@%@", [self baseUrl], mutablePath];
            } else {
                absoluteUrl = [NSString stringWithFormat:@"%@%@", [self baseUrl], path];
            }
        } else {
            if ([path hasPrefix:@"/"]) {
                absoluteUrl = [NSString stringWithFormat:@"%@%@", [self baseUrl], path];
            } else {
                absoluteUrl = [NSString stringWithFormat:@"%@/%@", [self baseUrl], path];
            }
        }
    }
    return absoluteUrl;
}

/** 当缓存超过了一定大小，清除   默认为0  不清除缓存，单位M */
+ (void)autoToClearCacheWithLimitedToSize:(NSUInteger)maxSize {
    maxCacheSize = maxSize;
}


@end

#pragma mark - NSDictionary,NSArray的分类
/*
 ************************************************************************************
 *新建 NSDictionary 与 NSArray 的分类, 控制台打印 json 数据中的中文
 ************************************************************************************
 */

#ifdef DEBUG
@implementation NSArray (NetworkManager)

- (NSString *)descriptionWithLocale:(id)locale {
    NSMutableString *strM = [NSMutableString stringWithString:@"(\n"];
    
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [strM appendFormat:@"\t%@,\n", obj];
    }];
    
    [strM appendString:@")"];
    
    return strM;
}

@end

@implementation NSDictionary (NetworkManager)

- (NSString *)descriptionWithLocale:(id)locale {
    NSMutableString *strM = [NSMutableString stringWithString:@"{\n"];
    
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [strM appendFormat:@"\t%@ = %@;\n", key, obj];
    }];
    
    [strM appendString:@"}\n"];
    
    return strM;
}
@end
#endif
