// C boundary: the COM provider owns its memory; edits run on Windy's UI thread.
#ifndef WINDY_ACCESSIBILITY_BRIDGE_H
#define WINDY_ACCESSIBILITY_BRIDGE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef int (*WindyTextEdit)(void *, int, int, int, const uint16_t *);
void *windyTextRootCreate(intptr_t hwnd);
void windyTextRootDestroy(void *root);
void *windyTextCreate(void *root, const uint16_t *id);
void windyTextDestroy(void *provider);
void windyTextPublish(void *provider, const uint16_t *text, int first, int last, int visibleFirst,
                      int visibleLast, double x, double y, double width, double height,
                      int editable, int focused);
intptr_t windyTextObject(void *provider, intptr_t wparam, intptr_t lparam);
intptr_t windyTextRequest(void *provider, intptr_t request, WindyTextEdit edit, void *context);
#ifdef __cplusplus
}
#endif
#endif
