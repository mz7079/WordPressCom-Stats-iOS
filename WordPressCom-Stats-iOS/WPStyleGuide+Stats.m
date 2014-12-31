#import "WPStyleGuide+Stats.h"
#import <WPFontManager.h>

@implementation WPStyleGuide (Stats)

+ (UIFont *)axisLabelFont {
    return [WPFontManager openSansRegularFontOfSize:8.0];
}

+ (UIColor *)statsLighterOrange
{
    return [UIColor colorWithRed:0.965 green:0.718 blue:0.494 alpha:1]; /*#f6b77e*/
}

+ (UIColor *)statsLighterOrangeTransparent
{
    return [UIColor colorWithRed:0.965 green:0.718 blue:0.494 alpha:0.3]; /*#f6b77e*/
}

+ (UIColor *)statsDarkerOrange
{
    return [self jazzyOrange];
}

+ (UIFont *)subtitleFontBoldItalic
{
    return [WPFontManager openSansBoldItalicFontOfSize:12.0];
}

@end
