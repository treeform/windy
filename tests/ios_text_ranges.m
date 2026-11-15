#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#include "../src/windy/platforms/ios/texts.h"

static void verifyEdit(NSString *before, NSString *after, intptr_t start,
                       intptr_t length, NSString *replacement) {
  // Check the actual native diff as scalar offsets and as a string operation.
  NSRange oldRange, newRange;
  windyTextDifference(before, after, &oldRange, &newRange);
  assert(windyRuneOffset(before, oldRange.location) == start);
  assert(windyRuneOffset(before, NSMaxRange(oldRange)) - start == length);
  assert([[after substringWithRange:newRange] isEqualToString:replacement]);
  assert([[before stringByReplacingCharactersInRange:oldRange
    withString:replacement] isEqualToString:after]);
}

int main(void) {
  // These native helpers can run on macOS without UIKit or a simulator.
  @autoreleasepool {
    verifyEdit(@"a😀b", @"a🧪b", 1, 1, @"🧪");
    verifyEdit(@"a界b", @"a界😀b", 2, 0, @"😀");
    verifyEdit(@"a😀界b", @"a界b", 1, 1, @"");
    verifyEdit(@"a𐐀b", @"a𠀀b", 1, 1, @"𠀀");
    verifyEdit(@"café", @"café", 3, 2, @"é");
    verifyEdit(@"", @"你好\n😀", 0, 0, @"你好\n😀");
    verifyEdit(@"😀", @"", 0, 1, @"");
    NSArray<NSString *> *parts = @[@"", @"a", @"界", @"😀", @"𐐀", @"𠀀", @"é", @"👨‍👩‍👧"];
    for (NSString *left in parts) {
      for (NSString *right in parts) {
        NSString *before = [left stringByAppendingString:right];
        intptr_t runes = windyRuneOffset(before, before.length);
        for (intptr_t i = 0; i <= runes; i++) {
          assert(windyRuneOffset(before, windyUtf16Offset(before, i)) == i);
        }
        assert(windyUtf16Offset(before, -1) == 0);
        assert(windyUtf16Offset(before, runes + 10) == before.length);
        assert(windyRuneOffset(before, before.length + 10) == runes);
        for (NSString *replacement in parts) {
          NSString *after = [right stringByAppendingString:replacement];
          NSRange oldRange, newRange;
          windyTextDifference(before, after, &oldRange, &newRange);
          NSString *inserted = [after substringWithRange:newRange];
          assert([[before stringByReplacingCharactersInRange:oldRange
            withString:inserted] isEqualToString:after]);
          assert([inserted dataUsingEncoding:NSUTF8StringEncoding] != nil);
          assert(windyUtf16Offset(before, windyRuneOffset(before, oldRange.location)) == oldRange.location);
          assert(windyUtf16Offset(before, windyRuneOffset(before, NSMaxRange(oldRange))) == NSMaxRange(oldRange));
        }
      }
    }
  }
  puts("iOS native Unicode ranges and edits passed");
  return 0;
}
