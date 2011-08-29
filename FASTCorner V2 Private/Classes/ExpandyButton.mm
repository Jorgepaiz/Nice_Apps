/*****************************************************************************
 
 FAST Corner 2.0
 January 2011
 (c) Copyright 2011, Success Software Solutions
 See LICENSE.txt for license information.
 
 *****************************************************************************/

#import "ExpandyButton.h"
#import <QuartzCore/QuartzCore.h>

// Measurements

const CGFloat frameHeight = 32.f;
const CGFloat titleXOrigin = 8.f;
const CGFloat titleYOrigin = 9.f;
const CGFloat titleHeight = 16.f;
const CGFloat titleWidth = 64.f;
const CGFloat buttonHeight = 26.f;
const CGFloat labelHeight = 39.f;
const CGFloat labelXOrigin = titleWidth + 10;
const CGFloat labelYOrigin = -3.f;
const CGFloat defaultButtonWidth = 40.f;
const CGFloat width = labelXOrigin + 10;
const CGFloat fontSize = 14.f;

// HUD Appearance
const CGFloat layerWhite = 1.f;
const CGFloat layerAlpha = .5f;
const CGFloat borderWhite = .0f;
const CGFloat borderAlpha = 1.f;
const CGFloat borderWidth = 1.f;


@interface ExpandyButton ()

@property (nonatomic,assign) BOOL expanded;
@property (nonatomic,assign) CGRect frameExpanded;
@property (nonatomic,assign) CGRect frameShrunk;
@property (nonatomic,retain) UILabel *titleLabel;
@property (nonatomic,retain) NSArray *labels;

@end

@implementation ExpandyButton

@synthesize expanded = _expanded;
@synthesize frameExpanded = _frameExpanded;
@synthesize frameShrunk = _frameShrunk;
@synthesize buttonWidth = _buttonWidth;
@synthesize titleLabel = _titleLabel;
@synthesize labels = _labels;
@dynamic selectedItem;

- (id)initWithPoint:(CGPoint)point title:(NSString *)title buttonNames:(NSArray *)buttonNames selectedItem:(NSInteger)selectedItem buttonWidth:(CGFloat)buttonWidth
{
    CGRect frameShrunk = CGRectMake(point.x, point.y, width + buttonWidth, frameHeight);
    CGRect frameExpanded = CGRectMake(point.x, point.y, width + buttonWidth * [buttonNames count], frameHeight);
    if ((self = [super initWithFrame:frameShrunk])) {
        [UIView setAnimationsEnabled:NO];
        [self setFrameShrunk:frameShrunk];
        [self setFrameExpanded:frameExpanded];
        [self setButtonWidth:buttonWidth];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(titleXOrigin, titleYOrigin, titleWidth, titleHeight)];
        [titleLabel setText:title];
        [titleLabel setFont:[UIFont systemFontOfSize:fontSize]];
        [titleLabel setTextColor:[UIColor blackColor]];
        [titleLabel setBackgroundColor:[UIColor clearColor]];
        [self addSubview:titleLabel];
        [self setTitleLabel:titleLabel];
        
        NSMutableArray *labels = [[NSMutableArray alloc] initWithCapacity:3];
        NSInteger index = 0;
        UILabel *label;
        for (NSString *buttonName in buttonNames) {
            label = [[UILabel alloc] initWithFrame:CGRectMake(labelXOrigin + (buttonWidth * index), labelYOrigin, buttonWidth, buttonHeight)];
            [label setText:buttonName];
            [label setFont:[UIFont systemFontOfSize:fontSize]];
            [label setTextColor:[UIColor blackColor]];
            [label setBackgroundColor:[UIColor clearColor]];
            [label setTextAlignment:UITextAlignmentCenter];
            [self addSubview:label];
            [labels addObject:label];
            [label release];
            index += 1;
        }
        
        [self setLabels:[labels copy]];
        [labels release];
        
        [self addTarget:self action:@selector(chooseLabel:forEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self setBackgroundColor:[UIColor clearColor]];
        
        CALayer *layer = [self layer];
        [layer setBackgroundColor:[[UIColor colorWithWhite:layerWhite alpha:layerAlpha] CGColor]];
        [layer setBorderWidth:borderWidth];
        [layer setBorderColor:[[UIColor colorWithWhite:borderWhite alpha:borderAlpha] CGColor]];
        [layer setCornerRadius:15.f];
        
        [self setExpanded:YES];
        
        [self setSelectedItem:selectedItem];
        [UIView setAnimationsEnabled:YES];
    }
    return self;    
}

- (id)initWithPoint:(CGPoint)point title:(NSString *)title buttonNames:(NSArray *)buttonNames selectedItem:(NSInteger)selectedItem
{
    return [self initWithPoint:point title:title buttonNames:buttonNames selectedItem:selectedItem buttonWidth:defaultButtonWidth];    
}

- (id)initWithPoint:(CGPoint)point title:(NSString *)title buttonNames:(NSArray *)buttonNames
{
    return [self initWithPoint:point title:title buttonNames:buttonNames selectedItem:0 buttonWidth:defaultButtonWidth];
}

- (void)chooseLabel:(id)sender forEvent:(UIEvent *)event
{
    [UIView beginAnimations:nil context:NULL];
    if ([self expanded] == NO) {
        [self setExpanded:YES];
        
        NSInteger index = 0;
        for (UILabel *label in [self labels]) {
            if (index == [self selectedItem]) {
                [label setFont:[UIFont boldSystemFontOfSize:fontSize]];
            } else {
                [label setTextColor:[UIColor colorWithWhite:0.f alpha:.8f]];
            }
            [label setFrame:CGRectMake(labelXOrigin + ([self buttonWidth] * index), labelYOrigin, [self buttonWidth], labelHeight)];
            index += 1;
        }
        
        [[self layer] setFrame:CGRectMake([self frame].origin.x, [self frame].origin.y, [self frameExpanded].size.width, [self frameExpanded].size.height)];
    } else {
        BOOL inside = NO;
        
        NSInteger index = 0;
        for (UILabel *label in [self labels]) {
            if ([label pointInside:[[[event allTouches] anyObject] locationInView:label] withEvent:event]) {
                [label setFrame:CGRectMake(labelXOrigin, labelYOrigin, [self buttonWidth], labelHeight)];
                inside = YES;
                break;
            }
            index += 1;
        }
        
        if (inside) {
            [self setSelectedItem:index];
        }
		else {
            [self setSelectedItem:[self selectedItem]];
		}

    }
    [UIView commitAnimations];
}

- (NSInteger)selectedItem
{
    return _selectedItem;
}

- (void)setSelectedItem:(NSInteger)selectedItem
{
    if (selectedItem < [[self labels] count]) {
        CGRect leftShrink = CGRectMake(labelXOrigin, labelYOrigin, 0.f, labelHeight);
        CGRect rightShrink = CGRectMake(labelXOrigin + [self buttonWidth], labelYOrigin, 0.f, labelHeight);
        CGRect middleExpanded = CGRectMake(labelXOrigin, labelYOrigin, [self buttonWidth], labelHeight);
        NSInteger count = 0;    
        BOOL expanded = [self expanded];
        
        if (expanded) {
            [UIView beginAnimations:nil context:NULL];
        }
        
        for (UILabel *label in [self labels]) {
            if (count < selectedItem) {
                [label setFrame:leftShrink];
                [label setFont:[UIFont systemFontOfSize:fontSize]];
            } else if (count > selectedItem) {
                [label setFrame:rightShrink];
                [label setFont:[UIFont systemFontOfSize:fontSize]];
            } else if (count == selectedItem) {
                [label setFrame:middleExpanded];
                [label setFont:[UIFont systemFontOfSize:fontSize]];
                [label setTextColor:[UIColor blackColor]];
            }
            count += 1;
        }
        
        if (expanded) {
            [[self layer] setFrame:CGRectMake([self frame].origin.x, [self frame].origin.y, [self frameShrunk].size.width, [self frameShrunk].size.height)];
            [UIView commitAnimations];
            [self setExpanded:NO];
        }
        
        if (_selectedItem != selectedItem) {
            _selectedItem = selectedItem;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }        
    }
}

- (void)dealloc {
    [self setTitleLabel:nil];
    [self setLabels:nil];
    [super dealloc];
}


@end
