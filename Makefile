.PHONY: test-native test-linux-cpu test-linux-combined
test-native:
	nim r tests/test_native_input.nim
	nim r tests/test_linux_framebuffer.nim
test-linux-cpu:
	WINDY_TEST_BACKENDS=x11 nim r tests/test_linux_display.nim
test-linux-combined:
	WINDY_TEST_BACKENDS=x11,fbdev,drm nim r tests/test_linux_display.nim
