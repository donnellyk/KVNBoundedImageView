//
//  KVNFaceAlignImageView.m
//  ImageTest
//
//  Created by Kevin Donnelly on 1/11/14.
//
//

#import "KVNBoundedImageView.h"

NSString * const BoundingBoxSchemeAll = @"BoundingBoxSchemeAll";
NSString * const BoundingBoxSchemeLargest = @"BoundingBoxSchemeLargest";
NSString * const BoundingBoxSchemeSmallest = @"BoundingBoxSchemeSmallest";

static CGFloat const FeaturePaddingDefault = 5.0;

@interface KVNBoundedImageView()

@property (strong) NSArray *features;

@property (nonatomic, strong) NSOperationQueue *asyncQueue;

// Properties related to URL image loading
@property (nonatomic, strong) NSOperation *imageFetchOperation;
@property (strong) NSURLRequest *imageURLRequest;
@property (nonatomic, strong) NSMutableData *imageData;
@property (nonatomic, strong) NSPort *runLoopPort;

@property CGSize latestBounds;

@property (nonatomic, strong) NSString *lastImageCacheName;

@end

@implementation KVNBoundedImageView
@synthesize detectorAccuracy = _detectorAccuracy;
@synthesize boundingBoxScheme = _boundingBoxScheme;


#pragma mark - Class Methods
+ (NSCache *)sharedCroppedImageCache {
    static NSCache *_sharedCroppedImageCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedCroppedImageCache = [[NSCache alloc] init];
    });
    
    return _sharedCroppedImageCache;
}

#pragma mark - Lifecycle
- (id)init {
    if (!(self = [super init])) {
        return nil;
    }
    
    [self commonSetup];
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) {
        return nil;
    }
    
    [self commonSetup];
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonSetup];
    
    self.lastImageCacheName = self.nibImageCacheName;
    [self fitToFeatures];
}

- (void)dealloc {
    [self halt];
    self.asyncQueue = nil;
}

- (void)commonSetup {
    self.asyncQueue = [[NSOperationQueue alloc] init];
    [self.asyncQueue setMaxConcurrentOperationCount:1];
    
    _detectorAccuracy = CIDetectorAccuracyLow;
    _boundingBoxScheme = BoundingBoxSchemeAll;
    _boundingEnabled = YES;
    _boundingPadding = FeaturePaddingDefault;
    _animated = YES;
    
    _latestBounds = self.bounds.size;
    
    self.clipsToBounds = YES;
    [self setContentMode:UIViewContentModeScaleAspectFill];
}

#pragma mark - Layout
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.boundingEnabled) {
        return;
    }
    
    if (AspectRatio(self.bounds.size) != AspectRatio(self.latestBounds)) {
        [self fitToFeatures];
    }
}

- (CGRect)boundingRectangleForImage:(UIImage *)image {
    CGRect boundingRectangle = CGRectNull;
    
    if (!self.features) {
        self.features = [self findFeaturesFromImage:image];
    }
    
    BOOL useAll = [self.boundingBoxScheme isEqualToString:BoundingBoxSchemeAll];
    for (NSValue *feature in self.features) {
        CGRect bounds = [feature CGRectValue];
        if (useAll) {
            bounds = CGRectInset(bounds, -self.boundingPadding, -self.boundingPadding);
            
            if (CGRectIsNull(boundingRectangle)) {
                boundingRectangle = bounds;
            } else {
                boundingRectangle = CGRectUnion(boundingRectangle, bounds);
            }
        } else {
            CGFloat boundArea = CGRectGetWidth(boundingRectangle) * CGRectGetHeight(boundingRectangle);
            CGFloat featureBoundArea = CGRectGetWidth(bounds) * CGRectGetHeight(bounds);
            
            if ([self.boundingBoxScheme isEqualToString:BoundingBoxSchemeLargest]) {
                if (featureBoundArea >= boundArea) {
                    boundingRectangle = CGRectInset(bounds, -self.boundingPadding, -self.boundingPadding);
                }
            } else {
                if (CGRectIsNull(boundingRectangle) || featureBoundArea <= boundArea) {
                    boundingRectangle = CGRectInset(bounds, -self.boundingPadding, -self.boundingPadding);
                }
            }
            
        }
    }
    
    return boundingRectangle;
}

#pragma mark - Class methods
+ (void)clearCache {
    [[KVNBoundedImageView sharedCroppedImageCache] removeAllObjects];
}

#pragma mark - Image Resizing
- (void)fitToFeatures {
    [self setImage:(self.originalImage) ? self.originalImage : self.image cacheName:self.lastImageCacheName];
}

- (void)halt {
    [self.asyncQueue cancelAllOperations];
}

- (void)resizeImage:(UIImage *)image name:(NSString *)name completion:(void(^)(UIImage *croppedImage))completion {
    if (!self.boundingEnabled) {
        if (completion) {
            completion(image);
        }
    }
    
    __weak __typeof__(self)weakSelf = self;
    __block NSBlockOperation *blockOp = [NSBlockOperation blockOperationWithBlock:^() {
        if (!weakSelf) {
            return;
        }
        
        __strong __typeof__(weakSelf)strongSelf = weakSelf;
        
        CGRect boundingRect = [strongSelf boundingRectangleForImage:image];
        
        if ([blockOp isCancelled]) {
            return;
        }
    
        if (CGRectIsEmpty(boundingRect)) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
                if (completion) {
                    completion(image);
                }
            }];
        }
        
        CGRect croppingRect = CGRectZero;
        CGFloat aspectRatio = AspectRatio(self.bounds.size);
        if (aspectRatio > 1.0) { // Scale by width
            croppingRect.size.width = image.size.width;
            croppingRect.size.height = CGRectGetWidth(croppingRect) / aspectRatio;
        } else { // Scale by height
            croppingRect.size.height = image.size.height;
            croppingRect.size.width = CGRectGetHeight(croppingRect) * aspectRatio;
        }
        
        CGFloat originX = MIN(MAX(0, CGRectGetMidX(boundingRect) - CGRectGetMidX(croppingRect)), image.size.width - CGRectGetWidth(croppingRect));
        CGFloat originY = MIN(MAX(0, CGRectGetMidY(boundingRect) - CGRectGetMidY(croppingRect)), image.size.height - CGRectGetHeight(croppingRect));
        croppingRect.origin = CGPointMake(originX, originY);
        
        // Flipping to CGImage Coordinate System
        croppingRect.origin.y = image.size.height - croppingRect.origin.y - croppingRect.size.height;
        
        if ([blockOp isCancelled]) {
            return;
        }
    
        CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, croppingRect);
        UIImage *croppedImage = [[UIImage alloc] initWithCGImage:imageRef];
        CGImageRelease(imageRef);
        
        if (name) {
            [[KVNBoundedImageView sharedCroppedImageCache] setObject:croppedImage forKey:[self cacheKeyWithName:name]];
        }
        
        if ([blockOp isCancelled]) {
            return;
        }
    
        [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
            if (completion) {
                completion(croppedImage);
            }
        }];
    }];

    [self.asyncQueue addOperation:blockOp];
}

- (void)setCroppedImage:(UIImage *)image {
    [super setImage:image];
    
    if (self.animated) {
        CATransition *transition = [CATransition animation];
        transition.duration = .3f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        
        [self.layer addAnimation:transition forKey:nil];
    }
}

#pragma mark - Face Detection
- (NSArray *)findFeaturesFromImage:(UIImage *)image {
    NSMutableArray *valueFeatures = [NSMutableArray array];

    // Not reusing the detector because that seemed to cause unbounded memory growth. until the detector was released. This was a workaround for that. http://openradar.appspot.com/radar?id=6645353252126720
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:@{CIDetectorAccuracy: self.detectorAccuracy}];
    
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    NSArray *array = [detector featuresInImage:ciImage];
    
    for (CIFaceFeature *feature in array) {
        [valueFeatures addObject:[NSValue valueWithCGRect:feature.bounds]];
    }
    
    return valueFeatures;
}

- (NSArray *)foundfeatures {
    return self.features;
}

#pragma mark - Synthesis Override
- (void)setImage:(UIImage *)image {
    [self setImage:image cacheName:nil];
}

- (void)setPlaceholderImage:(UIImage *)placeholderImage {
    _placeholderImage = placeholderImage;
    
    if (!self.image) {
        [super setImage:placeholderImage];
    }
}

- (void)setBoundingBoxScheme:(NSString *)boundingBoxScheme {
    _boundingBoxScheme = boundingBoxScheme;
    [[KVNBoundedImageView sharedCroppedImageCache] removeObjectForKey:[self cacheKeyWithName:self.lastImageCacheName]];
    
    if (self.originalImage) {
        [self setImage:self.originalImage cacheName:self.lastImageCacheName];
    }
}

- (void)setDetectorAccuracy:(NSString *)detectorAccuracy {
    if (_detectorAccuracy == detectorAccuracy) {
        return;
    }
    [[KVNBoundedImageView sharedCroppedImageCache] removeObjectForKey:[self cacheKeyWithName:self.lastImageCacheName]];
    
    _detectorAccuracy = detectorAccuracy;
    
    if (self.originalImage) {
        [self setImage:self.originalImage cacheName:self.lastImageCacheName];
    }
}

- (void)setBoundingEnabled:(BOOL)boundingEnabled {
    _boundingEnabled = boundingEnabled;
    
    if (self.originalImage) {
        [self setImage:self.originalImage cacheName:self.lastImageCacheName];
    }
}

- (void)setContentMode:(UIViewContentMode)contentMode {
    [super setContentMode:UIViewContentModeScaleAspectFill];
}

#pragma mark - Setting Image
- (void)setImageFromURL:(NSURL *)url placeholder:(UIImage *)placeholder {
    [self setPlaceholderImage:placeholder];
    
    [self.asyncQueue cancelAllOperations];
    self.imageData = [[NSMutableData alloc] init];
    
    UIImage *cachedImage = [[KVNBoundedImageView sharedCroppedImageCache] objectForKey:[self cacheKeyWithName:[url absoluteString]]];
    
    if (cachedImage) {
        [super setImage:cachedImage];
        [self  setLastImageCacheName:[url absoluteString]];
        return;
    }
    
    __weak __typeof__(self)weakSelf = self;
    self.imageFetchOperation = [NSBlockOperation blockOperationWithBlock:^(){
        __strong __typeof__(weakSelf)strongSelf = weakSelf;

        if (!strongSelf) {
            return;
        }
        
        self.imageURLRequest = [NSURLRequest requestWithURL:url];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:self.imageURLRequest delegate:strongSelf startImmediately:NO];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        strongSelf.runLoopPort = [NSPort port];
        [runLoop addPort:strongSelf.runLoopPort forMode:NSDefaultRunLoopMode];
        
        [connection scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];
        [connection start];
        [runLoop run];
        
    }];
    
    [self.asyncQueue addOperation:self.imageFetchOperation];
}

- (void)setImage:(UIImage *)image cacheName:(NSString *)cacheName {
    _originalImage = image;
    [self halt];
    self.imageURLRequest = nil;
    
    UIImage *cachedCroppedImage;
    if (!self.boundingEnabled) {
        [super setImage:image];
        return;
    } else if ((cachedCroppedImage = [[KVNBoundedImageView sharedCroppedImageCache] objectForKey:[self cacheKeyWithName:cacheName]])) {
        [super setImage:cachedCroppedImage];
        return;
    } else if (!self.image && self.placeholderImage) {
        [super setImage:self.placeholderImage];
    }
    
    __weak __typeof__(self)weakSelf = self;
    [self resizeImage:image name:(NSString *)cacheName completion:^(UIImage *croppedImage) {
        __strong __typeof__(weakSelf)strongSelf = weakSelf;
        [strongSelf setCroppedImage:croppedImage];
        strongSelf.lastImageCacheName = cacheName;
    }];
}

- (void)setImage:(UIImage *)image cacheName:(NSString *)cacheName placeholder:(UIImage *)placeholder {
    [self setPlaceholderImage:placeholder];
    [self setImage:image cacheName:cacheName];
}

#pragma mark NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if ([self.imageFetchOperation isCancelled]) {
        [connection cancel];
        [self stopRunLoop];
        return;
    }
    
    [self.imageData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self stopRunLoop];
    
    UIImage *image = [UIImage imageWithData:self.imageData];
    if ([self.imageFetchOperation isCancelled]) {
        return;
    }
    
    __block NSString *cacheName = [self.imageURLRequest.URL absoluteString];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
        [self setImage:image cacheName:cacheName];
    }];
    
    self.imageData = nil;
    self.imageURLRequest = nil;
}

- (void)stopRunLoop {
    [[NSRunLoop currentRunLoop] removePort:self.runLoopPort forMode:NSDefaultRunLoopMode];
    self.runLoopPort = nil;
}

#pragma mark - Private Convenience Methods
- (NSString *)cacheKeyWithName:(NSString *)name {
    if (!name || !self.detectorAccuracy || !self.boundingBoxScheme) {
        return nil;
    }
    
    NSNumber *aspectRatio = [NSNumber numberWithFloat:AspectRatio(self.bounds.size)];
    return [NSString stringWithFormat:@"%@+%@+%@+%@", name, [aspectRatio stringValue], self.detectorAccuracy, self.boundingBoxScheme];
}

static inline CGFloat AspectRatio(CGSize size) {
    return size.width / size.height;
}

@end