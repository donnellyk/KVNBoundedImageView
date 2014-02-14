//
//  KVNFaceAlignImageView.h
//  ImageTest
//
//  Created by Kevin Donnelly on 1/11/14.
//
//

#import <UIKit/UIKit.h>

extern NSString * const BoundingBoxSchemeAll; // Bounding rectangle uses all face features detected. A rectangle that that contains all feature bounds is used.
extern NSString * const BoundingBoxSchemeLargest; // Bounding rectangle uses only the largest face feature detected. The bounds of that feature is used. If two bounds are equal the last feature detected is used.
extern NSString * const BoundingBoxSchemeSmallest; // Bounding rectangle uses only the smallest face feature detected. The bounds of that feature is used. If two bounds are equal the last feature detected is used. Why would you ever want to use this, you ask? I have no idea, it was just easy to implement so I threw it in. Everyone loves an underdog!

@interface KVNBoundedImageView : UIImageView <NSURLConnectionDataDelegate>

@property CGFloat boundingPadding; // Padding added to each features bounds. Helpful for a face detected near the top of the image, as forheads are often not included. Default is 10.0.
@property (nonatomic, strong) NSString *detectorAccuracy; // Used as value for `CIDetectorAccuracy` key in `CIDetector` options. Default is `CIDetectorAccuracyLow`
@property (nonatomic, strong) NSString *boundingBoxScheme; // How the bounding rectangle is calculated. Default is `BoundingBoxSchemeAll`
@property (nonatomic) BOOL boundingEnabled; // If `NO`, acts like normal `UIImageView`. Defaults to `YES`.
@property (nonatomic) BOOL animated; // If YES, cropped image is animated into the view. Defaults to YES.

@property (nonatomic, strong, readonly) UIImage *originalImage; // Image before bounding/resizing
@property (nonatomic, strong) UIImage *placeholderImage; // Image to be shown before loading/cropping is completed. If an image is already displayed in the UIImageView, nothing is displayed.
@property (nonatomic, strong) NSString *nibImageCacheName; // If loading from nib, you can set this in the User Defined Runtime Attributes to cache the cropped image for reuse. Will be ignored for programmically set images.

/**
 *  Forces the current image to be resized again.
 */
- (void)fitToFeatures;

/**
 *  Stops URL loading and detection
 */
- (void)halt;

/**
 *  Clears cache of cropped and remotely loaded images
 */
+ (void)clearCache;

/**
 *  Bounding rectangle used to resize image. Override for alternative boundaries besides face detection. If subclassing, rectangle returned origin should be upper-left, as in `UIView` coordinate system.
 *
 *  @param image `UIImage` to build bounding rectangle from
 *
 *  @return `CGRect` of the bounding rectangle
 *
 *  @warning This method will be run on a background thread.
 */
- (CGRect)boundingRectangleForImage:(UIImage *)image;

/**
 *  Array of features found for previously set images. If overriding, return the individual rectangles, if any, that were used to calculate the bounding rectangle. The `CGRect` stored are in their original coordinate system
 *
 *  @return `NSArray` of `NSValue` objects that represent `CGRect`
 */
- (NSArray *)foundfeatures;

/**
 *  Remotely sets image from URL. Default `NSURLRequestCachePolicy` is used. Absolute URL is used for  the cropped image cache.
 
 *
 *  @param url URL where image is hosted
 */
- (void)setImageFromURL:(NSURL *)url placeholder:(UIImage *)placeholder;

/**
 *  Detects features, crops, and set UIImageView image, then caches results using name as key. If there is a valid cached version of the cropped image, it is set immediately
 *
 *  @param image Image to be presented
 *  @param cacheName  Key for image cache
 */
- (void)setImage:(UIImage *)image cacheName:(NSString *)cacheName;

/**
 *  Kicks off detection by setting the UIImage and displays the placeholder while the detection is ongoing.
 *
 *  @param image  Image to be displayed
 *  @param cacheName  Key for image cache
 *  @param placeholder Placeholder image to be displayed during detection and cropping
 */
- (void)setImage:(UIImage *)image cacheName:(NSString *)cacheName placeholder:(UIImage *)placeholder;
@end
