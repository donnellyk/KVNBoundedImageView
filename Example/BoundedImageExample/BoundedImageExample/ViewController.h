//
//  ViewController.h
//  BoundedImageExample
//
//  Created by Kevin Donnelly on 2/9/14.
//
//

#import <UIKit/UIKit.h>
@class KVNBoundedImageView;

@interface ViewController : UIViewController <UIScrollViewDelegate>
@property (weak, nonatomic) IBOutlet KVNBoundedImageView *pageOneBoundedImageView;
@property (weak, nonatomic) KVNBoundedImageView *pageTwoBoundedImageView;
@property (weak, nonatomic) KVNBoundedImageView *pageThreeBoundedImageView;
@property (weak, nonatomic) KVNBoundedImageView *pageFourBoundedImageView;
@property (weak, nonatomic) IBOutlet UIButton *toggleButton;
@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;
@property (weak, nonatomic) IBOutlet UIScrollView *imageScrollView;

- (IBAction)toggleTap:(id)sender;
- (IBAction)reloadImage:(id)sender;
@end
