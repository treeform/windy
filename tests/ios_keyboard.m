#include <assert.h>
#include <stdio.h>
#include "../src/windy/platforms/ios/services.m"

@interface TestTextView : WindyIosTextView
@property(nonatomic) BOOL responder;
@property(nonatomic) BOOL retainResponder;
@property(nonatomic) NSUInteger rejectedAcquisitions;
@property(nonatomic) NSUInteger acquisitions;
@property(nonatomic) NSUInteger resignations;
@end

@implementation TestTextView
- (BOOL)isFirstResponder {
  // Simulate UIKit retaining its responder flag across scene suspension.
  return self.responder;
}
- (BOOL)becomeFirstResponder {
  // Reject a controlled number of requests without opening a real keyboard.
  self.acquisitions++;
  if (self.rejectedAcquisitions) {
    self.rejectedAcquisitions--;
    return NO;
  }
  self.responder = YES;
  return YES;
}
- (BOOL)resignFirstResponder {
  // Keep stale ownership when the test models an interrupted transition.
  self.resignations++;
  if (self.retainResponder) return NO;
  self.responder = NO;
  return YES;
}
@end

static TestTextView *newEditor(void) {
  // Replace the singleton so an old queued request cannot target a new editor.
  [windyTextView invalidateKeyboardRequest];
  TestTextView *view = [[TestTextView alloc] initWithFrame:CGRectZero
    textContainer:nil];
  view.fieldIdentity = @"composer";
  view.text = @"café draft";
  view.selectedRange = NSMakeRange(2, 3);
  windyTextView = view;
  windyIosSetTextInputActive(1);
  view.acquisitions = 0;
  view.resignations = 0;
  return view;
}

static void drainMainQueue(void) {
  // Run until the queue reaches a sentinel after all existing acquisition work.
  __block BOOL complete = NO;
  dispatch_async(dispatch_get_main_queue(), ^{ complete = YES; });
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
  while (!complete && deadline.timeIntervalSinceNow > 0) {
    [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
      beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  }
  assert(complete);
}

static void publishEditor(UIView *host, const char *identity) {
  // Publish through the real bridge to test replacement and clearing semantics.
  windyIosSetTextInputState((__bridge void *)host, identity, "draft", 5,
    1, 3, 0, 0, 100, 40, 1, 0, NULL, NULL);
}

int main(void) {
  // Exercise native responder recovery without presenting UI over another app.
  @autoreleasepool {
    puts("Testing a rejected acquisition retries only once.");
    TestTextView *view = newEditor();
    view.rejectedAcquisitions = 1;
    assert(windyIosSetTextKeyboardVisible(1) == 1);
    assert(view.acquisitions == 1 && !view.isFirstResponder);
    for (int i = 0; i < 10; i++) windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 1);
    drainMainQueue();
    assert(view.acquisitions == 2 && view.isFirstResponder);
    for (int i = 0; i < 10; i++) windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 2);

    puts("Testing a later request can recover after both initial attempts fail.");
    view = newEditor();
    view.rejectedAcquisitions = 3;
    windyIosSetTextKeyboardVisible(1);
    drainMainQueue();
    assert(view.acquisitions == 2 && !view.isFirstResponder);
    windyIosSetTextKeyboardVisible(1);
    drainMainQueue();
    assert(view.acquisitions == 3 && !view.isFirstResponder);
    windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 4 && view.isFirstResponder);

    puts("Testing activation reacquires stale ownership without losing selection.");
    view = newEditor();
    windyIosSetTextKeyboardVisible(1);
    view.retainResponder = YES;
    view.keyboardFrame = CGRectMake(0, 200, 400, 300);
    windyIosSetTextInputActive(0);
    assert(view.isFirstResponder);
    assert(CGRectIsEmpty(view.keyboardFrame));
    windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 1);
    windyIosSetTextInputActive(1);
    windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 2 && view.resignations == 2);
    assert([view.text isEqualToString:@"café draft"]);
    assert(NSEqualRanges(view.selectedRange, NSMakeRange(2, 3)));
    for (int i = 0; i < 10; i++) windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 2 && view.resignations == 2);

    puts("Testing stale ownership and two failed attempts can still recover.");
    view = newEditor();
    windyIosSetTextKeyboardVisible(1);
    view.retainResponder = YES;
    view.rejectedAcquisitions = 2;
    windyIosSetTextInputActive(0);
    windyIosSetTextInputActive(1);
    windyIosSetTextKeyboardVisible(1);
    drainMainQueue();
    assert(view.acquisitions == 3 && view.isFirstResponder);
    assert(view.keyboardAcquisitionFailed && view.resignations == 3);
    windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 4 && !view.keyboardAcquisitionFailed);
    assert(view.resignations == 3);

    puts("Testing hidden and inactive editors cancel queued retries.");
    for (int inactive = 0; inactive < 2; inactive++) {
      view = newEditor();
      view.rejectedAcquisitions = 1;
      windyIosSetTextKeyboardVisible(1);
      if (inactive) windyIosSetTextInputActive(0);
      else windyIosSetTextKeyboardVisible(0);
      drainMainQueue();
      assert(view.acquisitions == 1 && !view.isFirstResponder);
    }

    puts("Testing field replacement and clearing cancel old retries.");
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    for (int clear = 0; clear < 2; clear++) {
      view = newEditor();
      [host addSubview:view];
      view.rejectedAcquisitions = 1;
      windyIosSetTextKeyboardVisible(1);
      publishEditor(host, clear ? "" : "replacement");
      drainMainQueue();
      assert(view.acquisitions == 1 && !view.isFirstResponder);
      if (clear) {
        assert(view.fieldIdentity.length == 0 && !view.keyboardWanted);
      } else {
        assert([view.fieldIdentity isEqualToString:@"replacement"]);
        windyIosSetTextKeyboardVisible(1);
        assert(view.acquisitions == 2 && view.isFirstResponder);
      }
    }

    puts("Testing a new scene invalidates a retry queued before suspension.");
    view = newEditor();
    view.rejectedAcquisitions = 1;
    windyIosSetTextKeyboardVisible(1);
    windyIosSetTextInputActive(0);
    windyIosSetTextInputActive(1);
    windyIosSetTextKeyboardVisible(1);
    assert(view.acquisitions == 2);
    drainMainQueue();
    assert(view.acquisitions == 2);
    puts("Native iOS keyboard recovery checks passed.");
  }
  return 0;
}
