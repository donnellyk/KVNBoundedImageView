//
//  ViewController.m
//  BoundedImageExample
//
//  Created by Kevin Donnelly on 2/9/14.
//
//

#import "ViewController.h"
#import "KVNBoundedImageView.h"

@interface ViewController ()

@end

@implementation ViewController
@synthesize pageOneBoundedImageView;
@synthesize pageTwoBoundedImageView;
@synthesize pageThreeBoundedImageView;
@synthesize pageFourBoundedImageView;

@synthesize pageControl;
@synthesize toggleButton;
@synthesize imageScrollView;

- (void)viewDidLoad {
    [super viewDidLoad];
	
    [imageScrollView setContentSize:CGSizeMake(CGRectGetWidth(imageScrollView.bounds) * 4, CGRectGetHeight(imageScrollView.bounds))];
    [self createProgrammicallyCreated];
    [self createLargest];
    [self createRemotelyLoaded];
}

- (void)createProgrammicallyCreated {
    KVNBoundedImageView *imageView = [[KVNBoundedImageView alloc] initWithFrame:CGRectMake(340, 175, 280, 200)];
    [imageView setImage:[UIImage imageNamed:@"guitar.jpg"] cacheName:@"guitar"];
    
    [imageScrollView addSubview:imageView];
    self.pageTwoBoundedImageView = imageView;
}

- (void)createLargest {
    KVNBoundedImageView *imageView = [[KVNBoundedImageView alloc] initWithFrame:CGRectMake(660, 75, 280, 350)];
    [imageView setBoundingBoxScheme:BoundingBoxSchemeLargest];
    [imageView setImage:[UIImage imageNamed:@"mask.jpg"]];
    // Not caching this image, if you tap the disable and then enable again, you can see the speed difference.
    
    [imageScrollView addSubview:imageView];
    self.pageThreeBoundedImageView = imageView;
}

- (void)createRemotelyLoaded {
    KVNBoundedImageView *imageView = [[KVNBoundedImageView alloc] initWithFrame:CGRectMake(980, 175, 280, 100)];
    [imageView setBoundingBoxScheme:BoundingBoxSchemeLargest];
    NSURL *url = [NSURL URLWithString:@"http://farm6.staticflickr.com/5336/7144867897_bc1d3b5277_c.jpg"];
    [imageView setImageFromURL:url placeholder:[UIImage imageNamed:@"placeholder"]];
    
    [imageView setBackgroundColor:[UIColor redColor]];
    
    [imageScrollView addSubview:imageView];
    self.pageFourBoundedImageView = imageView;
}

- (IBAction)toggleTap:(id)sender {
    BOOL enable = !pageFourBoundedImageView.boundingEnabled;
    
    [pageOneBoundedImageView setBoundingEnabled:enable];
    [pageTwoBoundedImageView setBoundingEnabled:enable];
    [pageThreeBoundedImageView setBoundingEnabled:enable];
    [pageFourBoundedImageView setBoundingEnabled:enable];
    
    [toggleButton setTitle:(enable) ? @"Disable" : @"Enable" forState:UIControlStateNormal];
}

- (IBAction)reloadImage:(id)sender {
    [pageFourBoundedImageView removeFromSuperview];
    pageFourBoundedImageView = nil;
    
    [KVNBoundedImageView clearCache];
    [self createRemotelyLoaded];
}

#pragma mark - UIScrollViewDelegate methods
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.pageControl.currentPage = lround(scrollView.contentOffset.x / CGRectGetWidth(scrollView.bounds));
}

@end
