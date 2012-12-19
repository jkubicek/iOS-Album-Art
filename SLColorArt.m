#import "SLColorArt.h"

#define kColorThresholdMinimumPercentage 0.01

UIColor* CGImageColorAtXY(CGImageRef image, NSInteger x, NSInteger y) {

    return [UIColor blackColor];
}

typedef struct gs_pixel {
    uint8_t a;
    uint8_t r;
    uint8_t g;
    uint8_t b;
} gs_pixel;

uint8_t gs_pixel_avg (gs_pixel * p) {
    int16_t a = (p->r + p->g + p->b)/3;
    //clip result to 0xFF to avoid wraparound
    return (uint8_t)(a > 0xFF)?0xFF:a;
}

UIColor *dataColorAtXY(const gs_pixel *imgData, int pixelsPerRow, int x, int y)
{
    gs_pixel pixel = imgData[y*pixelsPerRow + x];
    UIColor *color = [UIColor colorWithRed:pixel.r/255.f green:pixel.g/255.f blue:pixel.b/255.f alpha:pixel.a/255.f];
    return color;
}


@interface UIColor (DarkAddition)

- (BOOL)pc_isDarkColor;
- (BOOL)pc_isDistinct:(UIColor *)compareColor;
- (UIColor *)pc_colorWithMinimumSaturation:(CGFloat)saturation;
- (BOOL)pc_isBlackOrWhite;
- (BOOL)pc_isContrastingColor:(UIColor *)color;

@end


@interface PCCountedColor : NSObject

@property (assign) NSUInteger count;
@property (strong) UIColor *color;

- (id)initWithColor:(UIColor *)color count:(NSUInteger)count;

@end



@interface SLColorArt ()

@property CGSize scaledSize;
@property(retain,readwrite) UIColor *backgroundColor;
@property(retain,readwrite) UIColor *primaryColor;
@property(retain,readwrite) UIColor *secondaryColor;
@property(retain,readwrite) UIColor *detailColor;
@property(strong) NSData *imgData;

@end

@implementation SLColorArt

- (id)initWithImage:(UIImage *)image
{
    return [self initWithImage:image scaledSize:CGSizeZero];
}

- (id)initWithImage:(UIImage *)image scaledSize:(CGSize)size
{
    if (!image) return nil;
    self = [super init];
    if (self)
    {
        
        if (CGSizeEqualToSize(size, CGSizeZero) || CGSizeEqualToSize(size, image.size)) {
            self.scaledSize = image.size;
            self.scaledImage = image;
        } else {
            self.scaledSize = size;
            UIImage *finalImage = [self scaleImage:image size:size];
            self.scaledImage = finalImage;
        }

        [self extractDataFromImage:self.scaledImage];
        [self analyzeImage:image];
    }

    return self;
}


- (void)extractDataFromImage:(UIImage *)image {
    CGColorSpaceRef d_colorSpace = CGColorSpaceCreateDeviceRGB();
    size_t bytesPerRow = image.size.width * 4;
    NSUInteger len = image.size.height*bytesPerRow;
    gs_pixel *data = malloc(len);
    self.imgData = [NSData dataWithBytesNoCopy:data length:len freeWhenDone:YES];

    CGContextRef context =  CGBitmapContextCreate(data, image.size.width,
                                                  image.size.height,
                                                  8, bytesPerRow,
                                                  d_colorSpace,
                                                  kCGImageAlphaNoneSkipFirst);

    UIGraphicsPushContext(context);
    CGContextTranslateCTM(context, 0.0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    [image drawInRect:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
    UIGraphicsPopContext();

    CGContextRelease(context);
    CGColorSpaceRelease(d_colorSpace);
}


- (UIImage *)scaleImage:(UIImage *)image size:(CGSize)targetSize
{
    UIImage *sourceImage = image;
    UIImage *newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);

    if (CGSizeEqualToSize(imageSize, targetSize) == NO)
    {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;

        if (widthFactor > heightFactor)
        {
            scaleFactor = widthFactor; // scale to fit height
        }
        else
        {
            scaleFactor = heightFactor; // scale to fit width
        }

        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;

        // center the image
        if (widthFactor > heightFactor)
        {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        }
        else
        {
            if (widthFactor < heightFactor)
            {
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
        }
    }

    UIGraphicsBeginImageContext(targetSize); // this will crop

    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;

    [sourceImage drawInRect:thumbnailRect];

    newImage = UIGraphicsGetImageFromCurrentImageContext();

    if(newImage == nil)
    {
        NSLog(@"could not scale image");
    }

    //pop the context to get back to the default
    UIGraphicsEndImageContext();
    
    return newImage;
}


- (void)analyzeImage:(UIImage *)anImage
{
    NSCountedSet *imageColors = nil;
	UIColor *backgroundColor = [self imageColors:&imageColors];
	UIColor *primaryColor = nil;
	UIColor *secondaryColor = nil;
	UIColor *detailColor = nil;
	BOOL darkBackground = [backgroundColor pc_isDarkColor];

    CGFloat red, green, blue, alpha;
    [backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];

	[self findTextColors:imageColors primaryColor:&primaryColor secondaryColor:&secondaryColor detailColor:&detailColor backgroundColor:backgroundColor];

	if ( primaryColor == nil )
	{
		NSLog(@"missed primary");
		if ( darkBackground )
			primaryColor = [UIColor whiteColor];
		else
			primaryColor = [UIColor blackColor];
	}

	if ( secondaryColor == nil )
	{
		NSLog(@"missed secondary");
		if ( darkBackground )
			secondaryColor = [UIColor whiteColor];
		else
			secondaryColor = [UIColor blackColor];
	}

	if ( detailColor == nil )
	{
		NSLog(@"missed detail");
		if ( darkBackground )
			detailColor = [UIColor whiteColor];
		else
			detailColor = [UIColor blackColor];
	}

    self.backgroundColor = backgroundColor;
    self.primaryColor = primaryColor;
	self.secondaryColor = secondaryColor;
    self.detailColor = detailColor;
}

- (UIColor*)imageColors:(NSCountedSet**)colors
{
	NSInteger pixelsWide = self.scaledImage.size.width;
	NSInteger pixelsHigh = self.scaledImage.size.height;

	NSCountedSet *imageColors = [[NSCountedSet alloc] initWithCapacity:pixelsWide * pixelsHigh];
	NSCountedSet *leftEdgeColors = [[NSCountedSet alloc] initWithCapacity:pixelsHigh];

    NSUInteger x, y;
    x = y = 0;
    while (x < pixelsWide)
	{
        while (y < pixelsHigh)
		{
			UIColor *color = dataColorAtXY(self.imgData.bytes, self.scaledSize.width, x, y);

			if ( x == 0 )
			{
				[leftEdgeColors addObject:color];
			}

			[imageColors addObject:color];
            y += 2;
		}
        x += 2;
	}

	*colors = imageColors;


	NSEnumerator *enumerator = [leftEdgeColors objectEnumerator];
	UIColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[leftEdgeColors count]];

	while ( (curColor = [enumerator nextObject]) != nil )
	{
		NSUInteger colorCount = [leftEdgeColors countForObject:curColor];

        NSInteger randomColorsThreshold = (NSInteger)(pixelsHigh * kColorThresholdMinimumPercentage);
        
		if ( colorCount <= randomColorsThreshold ) // prevent using random colors, threshold based on input image height
			continue;

		PCCountedColor *container = [[PCCountedColor alloc] initWithColor:curColor count:colorCount];

		[sortedColors addObject:container];
	}

	[sortedColors sortUsingSelector:@selector(compare:)];


	PCCountedColor *proposedEdgeColor = nil;

	if ( [sortedColors count] > 0 )
	{
		proposedEdgeColor = [sortedColors objectAtIndex:0];

		if ( [proposedEdgeColor.color pc_isBlackOrWhite] ) // want to choose color over black/white so we keep looking
		{
			for ( NSInteger i = 1; i < [sortedColors count]; i++ )
			{
				PCCountedColor *nextProposedColor = [sortedColors objectAtIndex:i];

				if (((double)nextProposedColor.count / (double)proposedEdgeColor.count) > .3 ) // make sure the second choice color is 30% as common as the first choice
				{
					if ( ![nextProposedColor.color pc_isBlackOrWhite] )
					{
						proposedEdgeColor = nextProposedColor;
						break;
					}
				}
				else
				{
					// reached color threshold less than 40% of the original proposed edge color so bail
					break;
				}
			}
		}
	}

	return proposedEdgeColor.color;
}


- (void)findTextColors:(NSCountedSet*)colors primaryColor:(UIColor**)primaryColor secondaryColor:(UIColor**)secondaryColor detailColor:(UIColor**)detailColor backgroundColor:(UIColor*)backgroundColor
{
	NSEnumerator *enumerator = [colors objectEnumerator];
	UIColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[colors count]];
	BOOL findDarkTextColor = ![backgroundColor pc_isDarkColor];

	while ( (curColor = [enumerator nextObject]) != nil )
	{
		curColor = [curColor pc_colorWithMinimumSaturation:.15];

		if ( [curColor pc_isDarkColor] == findDarkTextColor )
		{
			NSUInteger colorCount = [colors countForObject:curColor];

			PCCountedColor *container = [[PCCountedColor alloc] initWithColor:curColor count:colorCount];

			[sortedColors addObject:container];
		}
	}

	[sortedColors sortUsingSelector:@selector(compare:)];

	for ( PCCountedColor *curContainer in sortedColors )
	{
		curColor = curContainer.color;

		if ( *primaryColor == nil )
		{
			if ( [curColor pc_isContrastingColor:backgroundColor] )
				*primaryColor = curColor;
		}
		else if ( *secondaryColor == nil )
		{
			if ( ![*primaryColor pc_isDistinct:curColor] || ![curColor pc_isContrastingColor:backgroundColor] )
				continue;

			*secondaryColor = curColor;
		}
		else if ( *detailColor == nil )
		{
			if ( ![*secondaryColor pc_isDistinct:curColor] || ![*primaryColor pc_isDistinct:curColor] || ![curColor pc_isContrastingColor:backgroundColor] )
				continue;
            
			*detailColor = curColor;
			break;
		}
	}
}

@end


@implementation UIColor (DarkAddition)

- (BOOL)pc_isDarkColor
{
	CGFloat r, g, b, a;

	[self getRed:&r green:&g blue:&b alpha:&a];

	CGFloat lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;

	if ( lum < .5 )
	{
		return YES;
	}

	return NO;
}


- (BOOL)pc_isDistinct:(UIColor*)compareColor
{
	CGFloat r, g, b, a;
	CGFloat r1, g1, b1, a1;

	[self getRed:&r green:&g blue:&b alpha:&a];
	[compareColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1];

	CGFloat threshold = .25; //.15

	if ( fabs(r - r1) > threshold ||
		fabs(g - g1) > threshold ||
		fabs(b - b1) > threshold ||
		fabs(a - a1) > threshold )
    {
        // check for grays, prevent multiple gray colors

        if ( fabs(r - g) < .03 && fabs(r - b) < .03 )
        {
            if ( fabs(r1 - g1) < .03 && fabs(r1 - b1) < .03 )
                return NO;
        }

        return YES;
    }

	return NO;
}


- (UIColor*)pc_colorWithMinimumSaturation:(CGFloat)minSaturation
{
	if ( self != nil )
	{
		CGFloat hue = 0.0;
		CGFloat saturation = 0.0;
		CGFloat brightness = 0.0;
		CGFloat alpha = 0.0;

		[self getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

		if ( saturation < minSaturation )
		{
            return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
		}
	}

	return self;
}


- (BOOL)pc_isBlackOrWhite
{
//	UIColor *tempColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	if ( self != nil )
	{
		CGFloat r, g, b, a;

		[self getRed:&r green:&g blue:&b alpha:&a];

		if ( r > .91 && g > .91 && b > .91 )
			return YES; // white

		if ( r < .09 && g < .09 && b < .09 )
			return YES; // black
	}

	return NO;
}


- (BOOL)pc_isContrastingColor:(UIColor*)color
{
	if ( self != nil && color != nil )
	{
		CGFloat br, bg, bb, ba;
		CGFloat fr, fg, fb, fa;

		[self getRed:&br green:&bg blue:&bb alpha:&ba];
		[color getRed:&fr green:&fg blue:&fb alpha:&fa];

		CGFloat bLum = 0.2126 * br + 0.7152 * bg + 0.0722 * bb;
		CGFloat fLum = 0.2126 * fr + 0.7152 * fg + 0.0722 * fb;

		CGFloat contrast = 0.;

		if ( bLum > fLum )
			contrast = (bLum + 0.05) / (fLum + 0.05);
		else
			contrast = (fLum + 0.05) / (bLum + 0.05);

		//return contrast > 3.0; //3-4.5 W3C recommends 3:1 ratio, but that filters too many colors
		return contrast > 1.6;
	}

	return YES;
}


@end


@implementation PCCountedColor

- (id)initWithColor:(UIColor*)color count:(NSUInteger)count
{
	self = [super init];

	if ( self )
	{
		self.color = color;
		self.count = count;
	}

	return self;
}

- (NSComparisonResult)compare:(PCCountedColor*)object
{
	if ( [object isKindOfClass:[PCCountedColor class]] )
	{
		if ( self.count < object.count )
		{
			return NSOrderedDescending;
		}
		else if ( self.count == object.count )
		{
			return NSOrderedSame;
		}
	}
    
	return NSOrderedAscending;
}


@end
