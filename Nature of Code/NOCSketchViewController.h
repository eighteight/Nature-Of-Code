//
//  WDLViewController.h
//  Nature of Code
//
//  Created by William Lindmeier on 1/30/13.
//  Copyright (c) 2013 wdlindmeier. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface NOCSketchViewController : GLKViewController

@property (nonatomic, strong) IBOutlet UIView *viewControls;
@property (nonatomic, strong) IBOutlet UIButton *buttonHideControls;

- (IBAction)buttonHideControlsPressed:(id)sender;

@end
