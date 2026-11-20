#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>
#include <assert.h>
#include <stdio.h>
#include "../src/windy/platforms/ios/frames.m"

static MTKView *view;
static int frames;
static BOOL renewing;

static void drawFrame(void) {
  // Use the same explicit MetalKit draw as Windy's on-demand callback.
  [view draw];
}

static void after(double seconds, void (^callback)(void)) {
  // Observe actual callbacks while UIKit owns an otherwise idle main loop.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC),
    dispatch_get_main_queue(), callback);
}

@interface FrameDelegate : UIResponder <UIWindowSceneDelegate, MTKViewDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation FrameDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
    options:(UISceneConnectionOptions *)options {
  // Start with the backend's default continuous rendering policy.
  self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
  UIViewController *controller = [UIViewController new];
  view = [[MTKView alloc] initWithFrame:self.window.bounds
    device:MTLCreateSystemDefaultDevice()];
  view.delegate = self;
  view.preferredFramesPerSecond = 60;
  view.enableSetNeedsDisplay = NO;
  view.paused = NO;
  controller.view = view;
  self.window.rootViewController = controller;
  [self.window makeKeyAndVisible];
  after(0.3, ^{
    int initial = frames;
    after(1.0, ^{
      int continuous = frames - initial;
      printf("Continuous idle MetalKit callbacks in 1 second: %d\n", continuous);
      assert(continuous >= 10);
      view.paused = YES;
      windyIosConfigureFrames(drawFrame, 1);
      after(0.1, ^{
        int idleStart = frames;
        after(1.0, ^{
          printf("On-demand idle MetalKit callbacks in 1 second: %d\n",
            frames - idleStart);
          assert(frames == idleStart);
          windyIosRequestFrame(100);
          windyIosRequestFrame(1000);
          after(0.2, ^{
            assert(frames == idleStart + 1);
            puts("Delayed request: exactly 1 MetalKit callback");
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
              windyIosRequestFrame(0);
            });
            after(0.1, ^{
              assert(frames == idleStart + 2);
              puts("Worker wake: exactly 1 MetalKit callback");
              windyIosRequestFrame(40);
              windyIosConfigureFrames(drawFrame, 0);
              after(0.1, ^{
                assert(frames == idleStart + 2);
                puts("Deactivation: pending MetalKit callback cancelled");
                windyIosConfigureFrames(drawFrame, 1);
                after(0.1, ^{
                  assert(frames == idleStart + 3);
                  int animationStart = frames;
                  NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
                  renewing = YES;
                  windyIosRequestFrame(0);
                  after(0.5, ^{
                    renewing = NO;
                    NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - start;
                    int animationFrames = frames - animationStart;
                    printf("Immediate animation MetalKit callbacks in %.3f seconds: %d\n",
                      elapsed, animationFrames);
                    assert(animationFrames >= 5 && animationFrames <= ceil(elapsed * 60) + 1);
                    windyIosConfigureFrames(NULL, 0);
                    puts("Actual MetalKit on-demand callback checks passed.");
                    exit(0);
                  });
                });
              });
            });
          });
        });
      });
    });
  });
}

- (void)drawInMTKView:(MTKView *)metalView {
  // Count application entry without acquiring or presenting a GPU drawable.
  frames++;
  if (renewing) windyIosRequestFrame(0);
}

- (void)mtkView:(MTKView *)metalView drawableSizeWillChange:(CGSize)size {}
@end

@interface FrameApplication : UIResponder <UIApplicationDelegate>
@end
@implementation FrameApplication
- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)session
    options:(UISceneConnectionOptions *)options {
  UISceneConfiguration *configuration = [[UISceneConfiguration alloc]
    initWithName:@"Frames" sessionRole:session.role];
  configuration.delegateClass = FrameDelegate.class;
  return configuration;
}
@end

int main(int argc, char **argv) {
  @autoreleasepool {
    setbuf(stdout, NULL);
    return UIApplicationMain(argc, argv, nil, NSStringFromClass(FrameApplication.class));
  }
}
