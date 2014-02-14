# KVNBoundedImageView

KVNBoundedImageView attempts to keep faces visible and centered in a UIImageView. It is designed to be easy to use and extensible for different types of image detection.

From ![Disabled ImageView](https://raw.github.com/donnellyk/KVNBoundedImageView/master/Assets/disabled.png) to ![Enabled](https://raw.github.com/donnellyk/KVNBoundedImageView/master/Assets/enabled.png) 

With configurable detection speed, operation queues, caching, and utilizing the optimized image rendering of UIImageView (no custom drawing here), KVNBoundedImageView aims to be as fast as possible, without blocking the main thread when heavy lifting is needed. Simple image loading via a URL is also available, so you may even be able to throw away that UIImageView catagory you've been dragging along between projects.

[![Version](http://cocoapod-badges.herokuapp.com/v/KVNBoundedImageView/badge.png)](http://cocoadocs.org/docsets/KVNBoundedImageView)
[![Platform](http://cocoapod-badges.herokuapp.com/p/KVNBoundedImageView/badge.png)](http://cocoadocs.org/docsets/KVNBoundedImageView)

## Usage

KVNBoundedImageView attempts to watch as many changes as possible within the UIImageView's properties and respond appropriately to keep the features visible. However, if at any point you find the view not responding to changes, you can manually force it to update by calling `fitToFeature`. See the Example project for more details on all the examples below

### Creating from NIB or Storyboard

Drag a UIImageView onto the scene and change it's class to KVNBoundedImageView in the Utilities pane under Identity Inspector. You can set the reuse cache name under User Defined Runtime Attributes by setting `nibImageCacheName` with an NSString value.

![Utility Pane screenshot](https://raw.github.com/donnellyk/KVNBoundedImageView/master/Assets/utility.png)

### Creating Programically

#### Bare Minimal
```objective-c
KVNBoundedImageView *imageView = [[KVNBoundedImageView alloc] initWithFrame:aRect];
[imageView setImage:[UIImage imageNamed:@"test"] cacheName:@"test"];
    
[imageScrollView addSubview:imageView];
```

#### With Some Configuration

When doing custom configuration, it is adviced to set the all the parameters before you set the image to be detected. Otherwise, the detection & cropping will start, and then immediatly be cancelled & restarted.  

```objective-c
KVNBoundedImageView *imageView = [[KVNBoundedImageView alloc] initWithFrame:aRect];
[imageView setBoundingBoxScheme:BoundingBoxSchemeLargest];
[imageView setBoundingPadding:10.0];
[imageView setImage:[UIImage imageNamed:@"test"] cacheName:@"test" placeholder:[UIImage imageNamed:@"placeholder"]];
    
[imageScrollView addSubview:imageView];
```

#### Load from a URL

```objective-c
KVNBoundedImageView *imageView = [[KVNBoundedImageView alloc] initWithFrame:aRect];    
[imageScrollView setImageFromURL:aURL cacheName:@"test" placeholder:[UIImage imageNamed:@"placeholder"]];
```

### Properties

- `boundingPadding`: `CIDetector` has a thing against foreheads, it doesn't include them in the detection bounds. If you roughly know the size of the faces in your image or if you have having trouble with foreheads being cut off at the top of your image (or chins at the bottom), paying with this value might give you better results. It isn't a perfect science, though, and edge-cases abound!
- `detectorAccuracy`: Changes the `CIDetectorAccuracy` used for feature detection. Default is `CIDetectorAccuracyLow`
- `boundingBoxScheme`: How the bounding rectangle is calculated.
    - `BoundingBoxSchemeAll`: All features detected are used. A rectangle that fits all features is created and used. This is the default behavior
    - `BoundingBoxSchemeLargest`: Uses the largest face found. Good for if you have images of crowds with a clear subject.
    - `BoundingBoxSchemeSmallest': Uses the smallest face found. To be honest, I only threw this because it was super easy to implement. I have no idea why you would want to use this. Maybe because everyone loves an underdog?
- `boundingEnabled`: Enabled or disables the detection and bounding. If `NO`, the image is displayed with `UIViewContentModeScaleAspectFill`
- `animated`: To make the transition a little nicer (but only a little, there is room for improvement), this provides a short Core Animation (kCATransitionFade) when the detection has finished. Defaults to `YES`.

## Installation

To manually install KVNBoundedImageView, add KVNBoundedImageView.m and KVNBoundedImageView.h files to your project. Import the CoreImage framework into your project.

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like KVNBoundedImageView in your projects. See the ["Getting Started" guide for more information](https://github.com/AFNetworking/AFNetworking/wiki/Getting-Started-with-AFNetworking).

#### Podfile

```ruby
platform :ios, '7.0'
pod "KVNBoundedImageView",
```

### Requirements
- CoreImage
- iOS 5.0+

## Extending KVNBoundingImageView

This library is designed with extensibility in mind. It is fairly easy to implement your own detection, so long as you do the actual dection leg work yourself (ie: The hard part). Perhaps you have written a dog detector using `OpenCV` and to make an app focus on dogs, without pesky cats getting in the way (A noble calling). To accomplish this, all you have to do is implement `boundingRectangleForImage` in your subclass and return the `CGRect` that you wish to be visible. This rect needs to be in the `UIView` coordinate system (origin is in the upper-left). Keep in mind that `boundingRectangleForImage` may be called on a background queue, so no operations that are unsafe on threads should be done. As a convienence to developers who may be using your subclass, you should also extend `foundFeatures` and return all the rects (stored in `NSValue`) that where detected in the image. 

## Note on Optimization and Caching

This library utilizes a NSCache to store the cropped images for fast recall. The key uses a supplied cache name along with the detection accurancy, bounding box scheme, and current view aspect ratio. This is so the image does not get resused in a view that is won't properly fit.  NSCache responds to OS-level memory warnings to clear space, but if you are worried about memory usage, minimize the different configuration you use or you can just use `setImage:` or pass nil for a cache name and nothing will be cached. This caching designed with use in a UITableView in mind, however it hasn't been extensively tested so proceed with caution.

### Memory Usage

This library uses a bit more memory then one would think, mainly around the usage of CIDetector. CIDetector seems to have a problem with unbounded memory growth. Not reusing the detector, instead instantiating one as needed, mitigates this problem but still doesn't seem to remove it entirely. [OpenRadar](http://openradar.appspot.com/16061776) concerning this issue.

### Animations

The imageview has to recrop the image with every aspect ratio change, so it probably not the best idea to have this component enabled while animating the bounds (center, origin is fine). The recommended way:

```objective-c
UIImage *originalImage = imageView.originalImage;
UIImage *croppedImage = imageView.image;

[imageView setBoundingEnabled:YES];
[imageView setImage:croppedImage];
[UIView animateWithDuration:1.0 animations:^{
    // Mess with bounds
} completion:^(BOOL f) {
    [imageView setImage:originalImage cacheName:@"cacheName"];
    [imageView setBoundingEnabled:YES];
}];
```

## Author

Kevin Donnelly - @donnellyk

## License

KVNBoundedImageView is available under the MIT license. See the LICENSE file for more info.

### Sample Photos

All example photos taken from Flickr licensed under The Creative Commons. Thanks to [Thomas Saito](http://www.flickr.com/photos/thomas-saito), [Franki](http://www.flickr.com/photos/francki), [Ableman](http://www.flickr.com/photos/ableman).