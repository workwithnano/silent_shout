//
//  Constants.m
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 12/6/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import "Constants.h"

#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#define RGB_INTENSITY(__NUMBER__) ((__NUMBER__) / 255.0)

@implementation Constants

  // FONTS
  NSString * const FONT_HIGHLIGHTER = @"GraffitiPaintBrush";  // Font #
  NSString * const FONT_MARKER = @"Journal";                  // Font #
  NSString * const FONT_KEYBOARD = @"Helvetica";              // Font 2
  NSString * const FONT_QUILL = @"Scriptina";                 // Font #
  NSString * const FONT_PENCIL = @"Later On";                 // Font 0
  NSString * const FONT_PAINTBRUSH = @"DJ Gross";             // Font #
  NSString * const FONT_DRYERASE = @"Kristi";                 // Font 1

+ (NSString *) getFontNameFromSavedFontNumber:(int)fontNumber {
  
  switch (fontNumber) {
    case 0:
      return FONT_PENCIL;
      break;
    case 1:
      return FONT_DRYERASE;
      break;
    case 2:
      return FONT_KEYBOARD;
      break;
    case 3:
      return FONT_KEYBOARD;
      break;
    case 4:
      return FONT_PENCIL;
      break;
    case 5:
      return FONT_MARKER;
      break;
    default:
      return FONT_PAINTBRUSH;
      break;
  }
  
}

+ (UIColor *)getUIColorForFontName:(NSString *)theFontName {
  
  if (theFontName == FONT_PAINTBRUSH)
    return UIColorFromRGB(0xA91515);
  else if (theFontName == FONT_DRYERASE)
    return UIColorFromRGB(0xE93232);
  else if (theFontName == FONT_HIGHLIGHTER)
    return UIColorFromRGB(0xE7FF20);
  else if (theFontName == FONT_MARKER)
    return UIColorFromRGB(0x272720);
  else {
    return UIColorFromRGB(0x000000);
  }
  
}

@end
