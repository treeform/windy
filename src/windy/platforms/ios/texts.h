#ifndef WINDY_IOS_TEXTS_H
#define WINDY_IOS_TEXTS_H
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

static NSUInteger windyUtf16Offset(NSString *text, intptr_t runes) {
  // Windy offsets count Unicode scalar values rather than UTF-16 code units.
  NSUInteger offset = 0;
  for (intptr_t i = 0; i < runes && offset < text.length; i++) {
    unichar value = [text characterAtIndex:offset++];
    if (CFStringIsSurrogateHighCharacter(value) && offset < text.length &&
        CFStringIsSurrogateLowCharacter([text characterAtIndex:offset])) offset++;
  }
  return offset;
}

static intptr_t windyRuneOffset(NSString *text, NSUInteger utf16) {
  // Clamp offsets from UIKit before converting a half-open selection range.
  NSUInteger limit = MIN(utf16, text.length);
  intptr_t count = 0;
  for (NSUInteger i = 0; i < limit; count++) {
    unichar value = [text characterAtIndex:i++];
    if (CFStringIsSurrogateHighCharacter(value) && i < limit &&
        CFStringIsSurrogateLowCharacter([text characterAtIndex:i])) i++;
  }
  return count;
}

static void windyTextDifference(NSString *before, NSString *after,
                                NSRange *oldRange, NSRange *newRange) {
  // Compute a minimal edit without splitting UTF-16 surrogate pairs.
  NSUInteger prefix = 0;
  NSUInteger limit = MIN(before.length, after.length);
  while (prefix < limit &&
         [before characterAtIndex:prefix] == [after characterAtIndex:prefix]) prefix++;
  // Keep each diff boundary outside a surrogate pair.
  if (prefix && prefix < before.length &&
      CFStringIsSurrogateHighCharacter([before characterAtIndex:prefix - 1])) prefix--;
  NSUInteger oldEnd = before.length;
  NSUInteger newEnd = after.length;
  while (oldEnd > prefix && newEnd > prefix &&
         [before characterAtIndex:oldEnd - 1] == [after characterAtIndex:newEnd - 1]) {
    oldEnd--;
    newEnd--;
  }
  if (oldEnd < before.length && oldEnd > prefix &&
      CFStringIsSurrogateLowCharacter([before characterAtIndex:oldEnd])) {
    oldEnd++;
    newEnd++;
  }
  *oldRange = NSMakeRange(prefix, oldEnd - prefix);
  *newRange = NSMakeRange(prefix, newEnd - prefix);
}
#endif
