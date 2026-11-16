#ifndef WINDY_IOS_SERVICES_H
#define WINDY_IOS_SERVICES_H
#include <stddef.h>
#include <stdint.h>
typedef void (*WindyIosTextEdit)(int kind, const char *text, size_t textLength,
                              intptr_t start, intptr_t length);
typedef void (*WindyIosTextKey)(int usage, int pressed, uintptr_t modifiers);
int windyIosClipboardImage(void **bytes, size_t *length);
int windyIosSetClipboardImage(const void *bytes, size_t length);
int windyIosHasClipboardImage(void);
void windyIosFreeClipboardImage(void *bytes);
void windyIosSetTextInputState(void *host, const char *identity,
                              const char *text, size_t textLength,
                              intptr_t selectionStart, intptr_t selectionEnd,
                              double x, double y, double width, double height,
                              int multiline, int password,
                              WindyIosTextEdit edit, WindyIosTextKey key);
int windyIosSetTextKeyboardVisible(int visible);
double windyIosKeyboardInset(void *host);
void windyIosObserveKeyboard(void (*changed)(void));
void windyIosWakeEvents(void);
#endif
