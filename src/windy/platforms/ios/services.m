#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <string.h>
#include "services.h"
#include "texts.h"

static const NSUInteger WindyClipboardByteLimit = 64 * 1024 * 1024;
static const double WindyClipboardPixelLimit = 16 * 1024 * 1024;

int windyIosClipboardImage(void **bytes, size_t *length) {
  // The caller owns the returned copy independently of the autorelease pool.
  *bytes = NULL;
  *length = 0;
  @autoreleasepool {
    UIImage *image = UIPasteboard.generalPasteboard.image;
    if (!image) return 0;
    double width = image.size.width * image.scale;
    double height = image.size.height * image.scale;
    if (width * height > WindyClipboardPixelLimit) return -1;
    NSData *data = UIImagePNGRepresentation(image);
    if (!data || data.length > WindyClipboardByteLimit) return -1;
    void *copy = malloc(data.length);
    if (!copy) return -1;
    memcpy(copy, data.bytes, data.length);
    *bytes = copy;
    *length = data.length;
    return 1;
  }
}

int windyIosSetClipboardImage(const void *bytes, size_t length) {
  // UIKit retains its own decoded image after this function returns.
  @autoreleasepool {
    if (!bytes || !length || length > WindyClipboardByteLimit) return 0;
    NSData *data = [NSData dataWithBytes:bytes length:length];
    UIImage *image = [UIImage imageWithData:data];
    if (!image) return 0;
    UIPasteboard.generalPasteboard.image = image;
    return 1;
  }
}

int windyIosHasClipboardImage(void) {
  // Querying types avoids an unnecessary protected clipboard read.
  return UIPasteboard.generalPasteboard.hasImages;
}

void windyIosFreeClipboardImage(void *bytes) {
  // Matches the allocation returned by windyIosClipboardImage.
  free(bytes);
}

@interface WindyIosTextView : UITextView <UITextViewDelegate>
@property(nonatomic, copy) NSString *fieldIdentity;
@property(nonatomic, copy) NSString *publishedText;
@property(nonatomic, copy) NSString *committedText;
@property(nonatomic) NSRange publishedSelection;
@property(nonatomic) NSRange committedSelection;
@property(nonatomic) BOOL synchronizing;
@property(nonatomic) BOOL publishing;
@property(nonatomic) BOOL keyboardWanted;
@property(nonatomic) BOOL updatingMarkedText;
@property(nonatomic) WindyIosTextEdit editCallback;
@property(nonatomic) WindyIosTextKey keyCallback;
@property(nonatomic) CGRect keyboardFrame;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *routedKeys;
- (void)publishChanges;
- (void)sendControlKey:(int)usage;
@end

static WindyIosTextView *windyTextView;
static void (*windyKeyboardChanged)(void);

@implementation WindyIosTextView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)container {
  // Use UIKit's complete UITextInput implementation for IME and dictation.
  self = [super initWithFrame:frame textContainer:container];
  if (self) {
    self.delegate = self;
    self.backgroundColor = UIColor.clearColor;
    self.textColor = UIColor.clearColor;
    self.tintColor = UIColor.clearColor;
    // Hide multicolored emoji without disabling the native responder.
    self.layer.opacity = 0;
    self.scrollEnabled = NO;
    self.textContainerInset = UIEdgeInsetsZero;
    self.textContainer.lineFragmentPadding = 0;
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    self.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.smartQuotesType = UITextSmartQuotesTypeNo;
    self.smartDashesType = UITextSmartDashesTypeNo;
    self.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    self.spellCheckingType = UITextSpellCheckingTypeNo;
    self.accessibilityElementsHidden = YES;
    self.isAccessibilityElement = NO;
    self.fieldIdentity = @"";
    self.publishedText = @"";
    self.committedText = @"";
    self.routedKeys = [NSMutableSet set];
    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification
      object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
      selector:@selector(keyboardHidden:) name:UIKeyboardWillHideNotification
      object:nil];
  }
  return self;
}

- (void)dealloc {
  // Release notification subscriptions with the native input responder.
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  // Custom-rendered Windy controls continue receiving all pointer touches.
  return NO;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  // Never expose secure text through UIKit's copy, cut, or selection menus.
  if (self.secureTextEntry && (action == @selector(copy:) ||
      action == @selector(cut:) || action == @selector(select:) ||
      action == @selector(selectAll:))) return NO;
  return [super canPerformAction:action withSender:sender];
}

- (void)keyboardChanged:(NSNotification *)notification {
  // Retain screen coordinates so rotations and host movement remain correct.
  self.keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  [self.superview setNeedsLayout];
  if (windyKeyboardChanged) windyKeyboardChanged();
}

- (void)keyboardHidden:(NSNotification *)notification {
  // A dismissed keyboard no longer occludes application content.
  self.keyboardFrame = CGRectZero;
  [self.superview setNeedsLayout];
  if (windyKeyboardChanged) windyKeyboardChanged();
}

- (void)publishChanges {
  // Never echo application publications or incomplete marked-text composition.
  if (self.synchronizing || self.publishing || !self.editCallback ||
      !self.keyboardWanted || !self.fieldIdentity.length ||
      self.updatingMarkedText || self.markedTextRange) return;
  self.publishing = YES;
  NSString *identity = self.fieldIdentity;
  WindyIosTextEdit edit = self.editCallback;
  NSString *before = self.committedText ?: @"";
  NSString *after = self.text ?: @"";
  NSRange selection = self.selectedRange;
  BOOL changed = ![before isEqualToString:after];
  BOOL selectionChanged = !NSEqualRanges(self.committedSelection, selection);
  self.committedText = after;
  self.committedSelection = selection;
  if (changed) {
    NSRange oldRange, newRange;
    windyTextDifference(before, after, &oldRange, &newRange);
    NSString *replacement = [after substringWithRange:newRange];
    NSData *bytes = [replacement dataUsingEncoding:NSUTF8StringEncoding];
    intptr_t start = windyRuneOffset(before, oldRange.location);
    intptr_t length = windyRuneOffset(before, NSMaxRange(oldRange)) - start;
    self.editCallback(0, bytes.bytes, bytes.length, start, length);
  }
  if ((changed || selectionChanged) && self.editCallback == edit &&
      [self.fieldIdentity isEqualToString:identity]) {
    intptr_t start = windyRuneOffset(after, selection.location);
    intptr_t end = windyRuneOffset(after, NSMaxRange(selection));
    self.editCallback(1, NULL, 0, start, end - start);
  }
  self.publishing = NO;
}

- (void)textViewDidChange:(UITextView *)textView {
  // Includes keyboard insertion, paste, replacement, and dictation.
  [self publishChanges];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  // Native selection requests follow any pending text change in order.
  [self publishChanges];
}

- (void)unmarkText {
  // Some input methods finish composition without another delegate change.
  [super unmarkText];
  [self publishChanges];
}

- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange {
  // UIKit can issue delegate callbacks before its marked range is installed.
  self.updatingMarkedText = YES;
  [super setMarkedText:markedText selectedRange:selectedRange];
  self.updatingMarkedText = NO;
  [self publishChanges];
}

- (void)sendControlKey:(int)usage {
  // Software keyboard controls use the same Windy buttons as desktop input.
  WindyIosTextKey key = self.keyCallback;
  if (key) {
    key(usage, 1, UINTPTR_MAX);
    key(usage, 0, UINTPTR_MAX);
  }
}

- (void)insertText:(NSString *)text {
  // Preserve the application's Return and Tab commands outside composition.
  if (!self.markedTextRange && ([text isEqualToString:@"\n"] ||
      [text isEqualToString:@"\r"] || [text isEqualToString:@"\t"])) {
    [self sendControlKey:[text isEqualToString:@"\t"] ? 0x2b : 0x28];
    return;
  }
  [super insertText:text];
  [self publishChanges];
}

- (void)deleteBackward {
  // UIKit deletes complete grapheme clusters and honors native selections.
  [super deleteBackward];
  [self publishChanges];
}

- (NSSet<UIPress *> *)forwardedPresses:(NSSet<UIPress *> *)presses pressed:(BOOL)pressed {
  // Application shortcuts remain available while UIKit owns text editing.
  NSMutableSet<UIPress *> *forwarded = [NSMutableSet set];
  for (UIPress *press in presses) {
    UIKey *key = press.key;
    BOOL shortcut = key && (key.modifierFlags &
      (UIKeyModifierCommand | UIKeyModifierControl)) != 0;
    BOOL modifier = key && key.keyCode >= 0xe0 && key.keyCode <= 0xe7;
    BOOL navigation = key && key.keyCode >= 0x4a && key.keyCode <= 0x52 &&
      key.keyCode != 0x4c && key.keyCode != 0x4f && key.keyCode != 0x50;
    BOOL returnKey = key && !self.markedTextRange &&
      (key.keyCode == 0x28 || key.keyCode == 0x58);
    BOOL control = key && (key.keyCode == UIKeyboardHIDUsageKeyboardEscape ||
      key.keyCode == UIKeyboardHIDUsageKeyboardTab);
    BOOL release = key && !pressed &&
      [self.routedKeys containsObject:@(key.keyCode)];
    if ((shortcut || control || modifier || navigation || returnKey || release) &&
        self.keyCallback) {
      if (pressed) [self.routedKeys addObject:@(key.keyCode)];
      else [self.routedKeys removeObject:@(key.keyCode)];
      self.keyCallback((int)key.keyCode, pressed, key.modifierFlags);
    } else {
      [forwarded addObject:press];
    }
  }
  return forwarded;
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  // Unhandled hardware keys use native text and selection behavior.
  NSSet *forwarded = [self forwardedPresses:presses pressed:YES];
  if (forwarded.count) [super pressesBegan:forwarded withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  // Report shortcut releases without producing duplicate text insertion.
  NSSet *forwarded = [self forwardedPresses:presses pressed:NO];
  if (forwarded.count) [super pressesEnded:forwarded withEvent:event];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
  // Cancelled hardware shortcuts must not retain a held Windy button.
  NSSet *forwarded = [self forwardedPresses:presses pressed:NO];
  if (forwarded.count) [super pressesCancelled:forwarded withEvent:event];
}
@end

void windyIosSetTextInputState(void *host, const char *identity,
                              const char *text, size_t textLength,
                              intptr_t selectionStart, intptr_t selectionEnd,
                              double x, double y, double width, double height,
                              int multiline, int password,
                              WindyIosTextEdit edit, WindyIosTextKey key) {
  // Mirror the editor while keeping UIKit in charge of marked-text lifetime.
  @autoreleasepool {
    UIView *view = (__bridge UIView *)host;
    NSString *field = identity ? [NSString stringWithUTF8String:identity] : @"";
    if (!view || !field.length) {
      windyTextView.synchronizing = YES;
      [windyTextView resignFirstResponder];
      windyTextView.fieldIdentity = @"";
      windyTextView.text = @"";
      windyTextView.publishedText = @"";
      windyTextView.committedText = @"";
      windyTextView.publishedSelection = NSMakeRange(0, 0);
      windyTextView.committedSelection = NSMakeRange(0, 0);
      windyTextView.editCallback = NULL;
      windyTextView.keyCallback = NULL;
      windyTextView.synchronizing = NO;
      return;
    }
    if (!windyTextView) {
      windyTextView = [[WindyIosTextView alloc] initWithFrame:CGRectZero textContainer:nil];
    }
    if (windyTextView.superview != view) [view addSubview:windyTextView];
    windyTextView.synchronizing = YES;
    BOOL traitsChanged = windyTextView.secureTextEntry != (password != 0);
    windyTextView.secureTextEntry = password != 0;
    BOOL changedField = ![windyTextView.fieldIdentity isEqualToString:field];
    NSString *value = [[NSString alloc] initWithBytes:text length:textLength encoding:NSUTF8StringEncoding];
    if (!value) value = @"";
    NSUInteger start = windyUtf16Offset(value, selectionStart);
    NSUInteger end = windyUtf16Offset(value, MAX(selectionStart, selectionEnd));
    NSRange selection = NSMakeRange(start, end - start);
    BOOL changedModel = ![windyTextView.publishedText isEqualToString:value] ||
      !NSEqualRanges(windyTextView.publishedSelection, selection);
    // Identical snapshots preserve composition; explicit model edits replace it.
    if (changedField || (changedModel && !windyTextView.publishing)) {
      [windyTextView unmarkText];
      windyTextView.fieldIdentity = field;
      if (![windyTextView.text isEqualToString:value]) windyTextView.text = value;
      windyTextView.selectedRange = selection;
      windyTextView.committedText = value;
      windyTextView.committedSelection = selection;
      windyTextView.publishedText = value;
      windyTextView.publishedSelection = selection;
    }
    windyTextView.editCallback = edit;
    windyTextView.keyCallback = key;
    windyTextView.frame = CGRectMake(x, y, MAX(width, 1), MAX(height, 1));
    windyTextView.returnKeyType = multiline ? UIReturnKeyDefault : UIReturnKeyDone;
    windyTextView.synchronizing = NO;
    if (traitsChanged && windyTextView.isFirstResponder) [windyTextView reloadInputViews];
  }
}

int windyIosSetTextKeyboardVisible(int visible) {
  // Return whether a published editor owns the keyboard request.
  windyTextView.keyboardWanted = visible != 0;
  if (!windyTextView.fieldIdentity.length) return 0;
  if (visible && !windyTextView.isFirstResponder) [windyTextView becomeFirstResponder];
  else if (!visible && windyTextView.isFirstResponder) [windyTextView resignFirstResponder];
  return 1;
}

double windyIosKeyboardInset(void *host) {
  // A floating keyboard does not shorten the entire application viewport.
  UIView *view = (__bridge UIView *)host;
  if (!view.window || CGRectIsEmpty(windyTextView.keyboardFrame)) return 0;
  CGRect keyboard = [view convertRect:windyTextView.keyboardFrame
    fromCoordinateSpace:view.window.screen.coordinateSpace];
  CGRect overlap = CGRectIntersection(view.bounds, keyboard);
  if (CGRectIsNull(overlap) || CGRectGetMaxY(overlap) < CGRectGetMaxY(view.bounds) - 1 ||
      overlap.size.width < view.bounds.size.width * 0.8) return 0;
  return overlap.size.height;
}

void windyIosWakeEvents(void) {
  // Posting to the main queue is safe from worker threads and wakes UIKit.
  dispatch_async(dispatch_get_main_queue(), ^{});
}

void windyIosObserveKeyboard(void (*changed)(void)) {
  // Register before any responder presents the keyboard, including UIKeyInput.
  windyKeyboardChanged = changed;
  if (!windyTextView) {
    windyTextView = [[WindyIosTextView alloc] initWithFrame:CGRectZero textContainer:nil];
  }
}
