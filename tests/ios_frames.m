#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#include "../src/windy/platforms/ios/frames.m"

static int frames;
static int remaining;
static BOOL renewing;
static NSTimeInterval lastRenewal;
static NSTimeInterval shortestRenewal;

static void frame(void) {
  // Count real one-shot callbacks without creating a GPU renderer.
  frames++;
  if (remaining > 0) {
    remaining--;
    windyIosRequestFrame(20);
  }
  if (renewing) {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (lastRenewal > 0) shortestRenewal = MIN(shortestRenewal, now - lastRenewal);
    lastRenewal = now;
    windyIosRequestFrame(0);
  }
}

static void waitFor(double seconds) {
  // Let Foundation fire the same timers used by UIKit's main run loop.
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
  NSTimer *sentinel = [NSTimer scheduledTimerWithTimeInterval:seconds
    repeats:NO block:^(NSTimer *timer) {}];
  while (deadline.timeIntervalSinceNow > 0) {
    [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:deadline];
  }
  [sentinel invalidate];
}

int main(void) {
  @autoreleasepool {
    puts("Testing an on-demand activation draws once then sleeps.");
    windyIosConfigureFrames(frame, 1);
    waitFor(0.05);
    assert(frames == 1);
    int before = frames;
    waitFor(1.0);
    assert(frames == before);
    puts("Idle callback count over one second: 0");

    puts("Testing later requests do not postpone an existing deadline.");
    windyIosRequestFrame(100);
    windyIosRequestFrame(1000);
    waitFor(0.03);
    assert(frames == before);
    waitFor(0.15);
    assert(frames == before + 1);

    puts("Testing callbacks may renew animation and later return to sleep.");
    before = frames;
    remaining = 2;
    windyIosRequestFrame(0);
    waitFor(0.15);
    assert(frames == before + 3);
    waitFor(0.1);
    assert(frames == before + 3);

    puts("Testing immediate requests coalesce and replace delayed work.");
    before = frames;
    windyIosRequestFrame(1000);
    for (int i = 0; i < 100; i++) windyIosRequestFrame(0);
    waitFor(0.05);
    assert(frames == before + 1);
    waitFor(0.1);
    assert(frames == before + 1);

    puts("Testing worker completions wake the main application callback.");
    before = frames;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
      windyIosRequestFrame(0);
    });
    waitFor(0.1);
    assert(frames == before + 1);

    puts("Testing deactivation cancels pending callbacks until reactivation.");
    before = frames;
    windyIosRequestFrame(40);
    windyIosConfigureFrames(frame, 0);
    windyIosRequestFrame(0);
    waitFor(0.1);
    assert(frames == before && windyFrameTimer == nil);
    windyIosConfigureFrames(frame, 1);
    waitFor(0.05);
    assert(frames == before + 1);

    puts("Testing immediate animation renewals retain the 60 Hz frame bound.");
    before = frames;
    renewing = YES;
    lastRenewal = 0;
    shortestRenewal = INFINITY;
    NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
    windyIosRequestFrame(0);
    waitFor(0.5);
    NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - start;
    renewing = NO;
    int animationFrames = frames - before;
    printf("Immediate animation callbacks in %.3f seconds: %d\n", elapsed,
      animationFrames);
    assert(animationFrames >= 5 && animationFrames <= ceil(elapsed * 60) + 1);
    assert(shortestRenewal >= 0.015);
    windyIosConfigureFrames(NULL, 0);
    assert(windyFrameTimer == nil);
    puts("Native iOS frame scheduling checks passed.");
  }
}
