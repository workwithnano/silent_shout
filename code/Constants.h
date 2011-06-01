//
//  Constants.h
//  Silent Shout (Utility)
//
//  Created by Neil Anderson on 12/6/10.
//  Copyright 2010 Nano LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Constants : NSObject {
  
}

+ (NSString *) getFontNameFromSavedFontNumber:(int)fontNumber;
+ (UIColor *) getUIColorForFontName:(NSString *)theFontName;

extern NSString * const FONT_HIGHLIGHTER;
extern NSString * const FONT_MARKER;
extern NSString * const FONT_PAINTBRUSH;
extern NSString * const FONT_PENCIL;
extern NSString * const FONT_QUILL;
extern NSString * const FONT_KEYBOARD;
extern NSString * const FONT_DRYERASE;

@end
