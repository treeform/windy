#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>
#include <string.h>

/* Referencing these protocols emits the SDK metadata needed by Nim classes. */
void *windyIosNativeProtocol(const char *name) {
    if (strcmp(name, "UIApplicationDelegate") == 0) {
        return (__bridge void *)@protocol(UIApplicationDelegate);
    }
    if (strcmp(name, "UIWindowSceneDelegate") == 0) {
        return (__bridge void *)@protocol(UIWindowSceneDelegate);
    }
    if (strcmp(name, "MTKViewDelegate") == 0) {
        return (__bridge void *)@protocol(MTKViewDelegate);
    }
    if (strcmp(name, "UIKeyInput") == 0) {
        return (__bridge void *)@protocol(UIKeyInput);
    }
    return NULL;
}
