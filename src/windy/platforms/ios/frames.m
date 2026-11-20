#import <Foundation/Foundation.h>
#include <math.h>

static NSTimer *windyFrameTimer;
static NSTimeInterval windyFrameDeadline = INFINITY;
static NSTimeInterval windyNextFrame;
static void (*windyFrameCallback)(void);
static BOOL windyFramesEnabled;

static void windyScheduleFrame(int delayMs) {
  // Keep only the earliest requested callback, without a repeating idle timer.
  if (!windyFramesEnabled || !windyFrameCallback) return;
  NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
  NSTimeInterval deadline = MAX(now + MAX(0, delayMs) / 1000.0, windyNextFrame);
  NSTimeInterval delay = MAX(0, deadline - now);
  if (windyFrameTimer && deadline >= windyFrameDeadline) return;
  [windyFrameTimer invalidate];
  windyFrameDeadline = deadline;
  windyFrameTimer = [NSTimer timerWithTimeInterval:delay repeats:NO
    block:^(NSTimer *timer) {
      if (timer != windyFrameTimer) return;
      windyFrameTimer = nil;
      windyFrameDeadline = INFINITY;
      if (windyFramesEnabled && windyFrameCallback) {
        // Explicit MTKView draws bypass preferredFramesPerSecond. Retain the
        // same 60 Hz limit when an animation immediately requests its next frame.
        windyNextFrame = NSProcessInfo.processInfo.systemUptime + 1.0 / 60.0;
        windyFrameCallback();
      }
    }];
  windyFrameTimer.tolerance = MIN(0.01, delay * 0.1);
  [[NSRunLoop mainRunLoop] addTimer:windyFrameTimer forMode:NSRunLoopCommonModes];
}

void windyIosRequestFrame(int delayMs) {
  // Worker completions and native input share the same main-thread wake path.
  if (NSThread.isMainThread) {
    windyScheduleFrame(delayMs);
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{ windyScheduleFrame(delayMs); });
  }
}

void windyIosConfigureFrames(void (*callback)(void), int enabled) {
  // Cancellation releases the timer and prevents drawing after deactivation.
  NSCAssert(NSThread.isMainThread, @"Frame configuration requires the main thread");
  windyFrameCallback = callback;
  BOOL changed = windyFramesEnabled != (enabled != 0);
  windyFramesEnabled = enabled != 0;
  if (!windyFramesEnabled) {
    [windyFrameTimer invalidate];
    windyFrameTimer = nil;
    windyFrameDeadline = INFINITY;
    windyNextFrame = 0;
  } else if (changed) {
    windyScheduleFrame(0);
  }
}
