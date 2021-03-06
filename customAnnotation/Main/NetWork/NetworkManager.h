//
//  NetworkManager.h
//  customAnnotation
//
//  Created by ZHANG on 2019/7/25.
//  Copyright © 2019年 Z. All rights reserved.
//

#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

#define NetworkManagerShare [NetworkManager sharedManager]

#define kWeak  __weak __typeof(self) weakSelf = self


/*! 使用枚举NS_ENUM:区别可判断编译器是否支持新式枚举,支持就使用新的,否则使用旧的 */
typedef NS_ENUM(NSUInteger, NetworkStatus) {
    /*! 未知网络 */
    NetworkStatusUnknown           = 0,
    /*! 没有网络 */
    NetworkStatusNotReachable,
    /*! 手机 3G/4G 网络 */
    NetworkStatusReachableViaWWAN,
    /*! wifi 网络 */
    NetworkStatusReachableViaWiFi
};

/*！定义请求类型的枚举 */
typedef NS_ENUM(NSUInteger, NetHttpRequestType) {
    /*! get请求 */
    NetHttpRequestTypeGet = 0,
    /*! post请求 */
    NetHttpRequestTypePost,
    /*! put请求 */
    NetHttpRequestTypePut,
    /*! delete请求 */
    NetHttpRequestTypeDelete
};

typedef NS_ENUM(NSUInteger, NetHttpRequestSerializer) {
    /** 设置请求数据为JSON格式*/
    NetHttpRequestSerializerJSON,
    /** 设置请求数据为HTTP格式*/
    NetHttpRequestSerializerHTTP,
};

typedef NS_ENUM(NSUInteger, NetHttpResponseSerializer) {
    /** 设置响应数据为JSON格式*/
    NetHttpResponseSerializerJSON,
    /** 设置响应数据为HTTP格式*/
    NetHttpResponseSerializerHTTP,
};

/*! 实时监测网络状态的 block */
typedef void(^NetworkStatusBlock)(NetworkStatus status);

/*! 定义请求成功的 block */
typedef void(^NetResponseSuccessBlock)(id response);
/*! 定义请求失败的 block */
typedef void(^NetResponseFailBlock)(NSError *error);

/*! 定义上传进度 block */
typedef void(^NetUploadProgressBlock)(int64_t bytesProgress,
                                       int64_t totalBytesProgress);
/*! 定义下载进度 block */
typedef void(^NetDownloadProgressBlock)(int64_t bytesProgress,
                                         int64_t totalBytesProgress);

/*!
 *  方便管理请求任务。执行取消，暂停，继续等任务.
 *  - (void)cancel，取消任务
 *  - (void)suspend，暂停任务
 *  - (void)resume，继续任务
 */
typedef NSURLSessionTask NetURLSessionTask;

@interface NetworkManager : NSObject

/**
 创建的请求的超时间隔（以秒为单位），此设置为全局统一设置一次即可，默认超时时间间隔为30秒。
 */
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

/**
 设置网络请求参数的格式，此设置为全局统一设置一次即可，默认：NetHttpRequestSerializerJSON
 */
@property (nonatomic, assign) NetHttpRequestSerializer requestSerializer;

/**
 设置服务器响应数据格式，此设置为全局统一设置一次即可，默认：NetHttpResponseSerializerJSON
 */
@property (nonatomic, assign) NetHttpResponseSerializer responseSerializer;

/**
 自定义请求头：httpHeaderField
 */
@property(nonatomic, strong) NSDictionary *httpHeaderFieldDictionary;

/**
 将传入 的 string 参数序列化
 */
@property(nonatomic, assign) BOOL isSetQueryStringSerialization;

/**
 是否开启 log 打印，默认不开启
 */
@property(nonatomic, assign) BOOL isOpenLog;


/**
 用于指定网络接口的基础URL

 @param baseUrl 网络接口基础URL
 */
+ (void)updateBaseUrl:(NSString *)baseUrl;
+ (NSString *)baseUrl;


/**
 *    默认不会自动清除缓存，如果需要，可以设置自动清除缓存，并且需要指定上限。当指定上限>0M时，
 *    若缓存达到了上限值，则每次启动应用则尝试自动去清理缓存。
 *    @param maxSize   缓存上限大小，单位为M（兆），默认为0，表示不清理
 */
+ (void)autoToClearCacheWithLimitedToSize:(NSUInteger)maxSize;




/*!
 *  获得全局唯一的网络请求实例单例方法
 *
 *  @return 网络请求类NetManager单例
 */
+ (instancetype)sharedManager;

#pragma mark - 网络请求的类方法 --- get / post / put / delete
/**
 网络请求的实例方法 get    已经做了拼接baseURL处理，如果有baseURL就会自动拼接，没有就传完整路径
 
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
                                progressBlock:(NetDownloadProgressBlock)progressBlock;

/**
 网络请求的实例方法 post    已经做了拼接baseURL处理，如果有baseURL就会自动拼接，没有就传完整路径
 
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
                                  progressBlock:(NetDownloadProgressBlock)progressBlock;

/**
 网络请求的实例方法 put    已经做了拼接baseURL处理，如果有baseURL就会自动拼接，没有就传完整路径
 
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
                                 progressBlock:(NetDownloadProgressBlock)progressBlock;
/**
 网络请求的实例方法 delete    已经做了拼接baseURL处理，如果有baseURL就会自动拼接，没有就传完整路径
 
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
                                    progressBlock:(NetDownloadProgressBlock)progressBlock;
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
                                  progressBlock:(NetUploadProgressBlock)progressBlock;

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
                   progressBlock:(NetUploadProgressBlock)progressBlock;


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
                                   progressBlock:(NetDownloadProgressBlock)progressBlock;

/**
 文件上传
 
 @param urlString urlString description
 @param parameters parameters description
 @param fileName fileName description
 @param filePath filePath description
 @param successBlock successBlock description
 @param failureBlock failureBlock description
 @param progressBlock progressBlock description
 @return BAURLSessionTask
 */
+ (NetURLSessionTask *)uploadFileWithUrlString:(NSString *)urlString
                                    parameters:(id)parameters
                                      fileName:(NSString *)fileName
                                      filePath:(NSString *)filePath
                                  successBlock:(NetResponseSuccessBlock)successBlock
                                  failureBlock:(NetResponseFailBlock)failureBlock
                                 progressBlock:(NetUploadProgressBlock)progressBlock;

#pragma mark - 网络状态监测
/*!
 *  开启实时网络状态监测，通过Block回调实时获取(此方法可多次调用)
 */
+ (void)startNetWorkMonitoringWithBlock:(NetworkStatusBlock)networkStatus;

#pragma mark - 自定义请求头
/**
 *  自定义请求头
 */
+ (void)netSetValue:(NSString *)value forHTTPHeaderKey:(NSString *)HTTPHeaderKey;

/**
 删除所有请求头
 */
+ (void)netClearAuthorizationHeader;

#pragma mark - 取消 Http 请求
/*!
 *  取消所有 Http 请求
 */
+ (void)cancelAllRequest;

/*!
 *  取消指定 URL 的 Http 请求
 */
+ (void)cancelRequestWithURL:(NSString *)URL;

/**
 清空缓存：此方法可能会阻止调用线程，直到文件删除完成。
 */
- (void)clearAllHttpCache;



@end

//NS_ASSUME_NONNULL_END
