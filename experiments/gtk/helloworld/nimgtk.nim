import opengl, math

const libgtk3 = "libgtk-3.so(|0)"
const libgobject2 = "libgobject-2.0.so"

const
  GTK_WINDOW_TOPLEVEL: cint = 0

  GDK_WINDOW_STATE_WITHDRAWN        : cint = 1 shl 0
  GDK_WINDOW_STATE_ICONIFIED        : cint = 1 shl 1
  GDK_WINDOW_STATE_MAXIMIZED        : cint = 1 shl 2
  GDK_WINDOW_STATE_FULLSCREEN       : cint = 1 shl 4

type
  GtkWidget = pointer

{.push, cdecl, dynlib: libgtk3, importc.}

proc gtk_init_check(a, b: pointer): bool
proc gtk_events_pending(): bool
proc gtk_main_iteration()
proc gtk_window_new(level: cint): GtkWidget
proc gtk_widget_show_all(window: GtkWidget)
proc gtk_window_set_title(window: GtkWidget, title: cstring)
proc gtk_widget_add_events(window: GtkWidget, mask: cint)
proc gtk_gl_area_new(): GtkWidget
proc gtk_container_add(window: GtkWidget, widget: GtkWidget)
proc gtk_gl_area_make_current(widget: GtkWidget)
proc gtk_gl_area_queue_render(widget: GtkWidget)
proc gdk_window_end_paint(window: GtkWidget)

{.pop.}

type
  GdkEventType = cint
  GdkModifierType = cint
  GdkScrollDirection = cint
  GdkDevice = pointer

  GdkEventWindowState = object
    `type`: GdkEventType
    window: GtkWidget
    send_event: int8
    changed_mask: cint
    new_window_state: cint

  GdkEventConfigure = object
    `type`: GdkEventType
    window: GtkWidget
    send_event: int8
    x, y: cint
    width: cint
    height: cint

  GdkEventMotion = object
    `type`: GdkEventType
    window: GtkWidget
    send_event: int8
    time: uint32
    x: float64
    y: float64
    axes: ptr float64
    state: GdkModifierType
    is_hint: int16
    device: GdkDevice
    x_root: float64
    y_root: float64

  GdkEventScroll = object
    `type`: GdkEventType
    window: GtkWidget
    send_event: int8
    time: uint32
    x: float64
    y: float64
    state: cuint
    direction: GdkScrollDirection
    device: GdkDevice
    x_root, y_root: float64
    delta_x: float64
    delta_y: float64

  GdkEventKey = object
    `type`: GdkEventType
    window: GtkWidget
    send_event: int8
    time: uint32
    state: cuint
    keyval: cuint
    length: cint
    `string`: cstring
    hardware_keycode: uint16
    group: uint8
    is_modifier: cuint

  GdkEventButton = object
    `type`: GdkEventType
    window: GtkWidget
    send_event: int8
    time: uint32
    x: float64
    y: float64
    axes: ptr float64
    state: GdkModifierType
    button: cuint
    device: GdkDevice
    x_root: float64
    y_root: float64

  cb = proc() {.cdecl.}

const
  GDK_POINTER_MOTION_MASK: cint = 1 shl 2
  GDK_SCROLL_MASK: cint = 1 shl 21
  GDK_BUTTON_PRESS_MASK: cint = 1 shl 8

{.push, cdecl, dynlib: libgobject2, importc.}

proc g_signal_connect_data (
  instance: GtkWidget,
  detailed_signal: cstring,
  c_handler: cb,
  data: pointer,
  destroy_data: cint = 0,
  connect_flags: cint = 0
)

{.pop.}

var f: float32 = 0.0

echo gtk_init_check(nil, nil)

var window = gtk_window_new(GTK_WINDOW_TOPLEVEL);

var glArea: GtkWidget = gtk_gl_area_new()
gtk_container_add(window, glArea)
proc on_realize(window: GtkWidget) {.cdecl.} =
  echo "on_realize"
  # Make current:
  gtk_gl_area_make_current(glArea)

  loadExtensions()
  echo "GL_VERSION: ", cast[cstring](glGetString(GL_VERSION))
  echo "GL_VENDOR: ", cast[cstring](glGetString(GL_VENDOR))
  echo "GL_RENDERER: ", cast[cstring](glGetString(GL_RENDERER))

  # // Enable depth buffer:
  # gtk_gl_area_set_has_depth_buffer(glarea, TRUE);

  # glClearColor(0, 0, 0.5 + sin(f)/2, 1)
  # f += 0.01
  # glClear(GL_COLOR_BUFFER_BIT)

  gtk_gl_area_queue_render(glArea)


g_signal_connect_data(glArea, "realize", cast[cb](on_realize), nil);


proc on_render(window: GtkWidget) {.cdecl.} =
  echo "on_render"


  glClearColor(0.5 + sin(f)/2, 0, 0, 1)
  f += 0.01
  glClear(GL_COLOR_BUFFER_BIT)


  gtk_gl_area_queue_render(glArea)

  # gdk_window_end_paint(window)


g_signal_connect_data(glArea, "render", cast[cb](on_render), nil);

gtk_window_set_title(window, "My Helloworld test.");
gtk_widget_show_all(window);

proc on_delete(window: GtkWidget) {.cdecl.} =
  echo "on_delete"
  quit()
g_signal_connect_data(window, "delete-event", cast[cb](on_delete), nil);

proc on_motion_notify(window: GtkWidget, event: GdkEventMotion, data: pointer) {.cdecl.} =
  echo "on_motion_notify ", event.x, " ", event.y
gtk_widget_add_events(window, GDK_POINTER_MOTION_MASK);
g_signal_connect_data(window, "motion-notify-event", cast[cb](on_motion_notify), nil);

proc on_configure(window: GtkWidget, event: GdkEventConfigure, data: pointer) {.cdecl.} =
  echo "on_configure ", event.x, " ", event.y, " ", event.width, " ", event.height
g_signal_connect_data(window, "configure-event", cast[cb](on_configure), nil);

proc on_window_state(window: GtkWidget, event: GdkEventWindowState, data: pointer) {.cdecl.} =
  echo "on_window_state:"
  if (event.new_window_state and GDK_WINDOW_STATE_ICONIFIED) != 0:
    echo " GDK_WINDOW_STATE_ICONIFIED"
  if (event.new_window_state and GDK_WINDOW_STATE_MAXIMIZED) != 0:
    echo " GDK_WINDOW_STATE_MAXIMIZED"
  if (event.new_window_state and GDK_WINDOW_STATE_WITHDRAWN) != 0:
    echo " GDK_WINDOW_STATE_WITHDRAWN"
  if (event.new_window_state and GDK_WINDOW_STATE_FULLSCREEN) != 0:
    echo " GDK_WINDOW_STATE_FULLSCREEN"
g_signal_connect_data(window, "window-state-event", cast[cb](on_window_state), nil);

proc on_scroll(window: GtkWidget, event: GdkEventScroll, data: pointer) {.cdecl.} =
  echo "on_scroll ", event.delta_x, " ", event.delta_y, " ", event.direction
gtk_widget_add_events(window, GDK_SCROLL_MASK);
g_signal_connect_data(window, "scroll-event", cast[cb](on_scroll), nil);

proc on_key_press(window: GtkWidget, event: GdkEventKey, data: pointer) {.cdecl.} =
  echo "on_key_press ", event.keyval, " ", event.`string`
g_signal_connect_data(window, "key_press_event", cast[cb](on_key_press), nil);

proc on_key_release(window: GtkWidget, event: GdkEventKey, data: pointer) {.cdecl.} =
  echo "on_key_release ", event.keyval, " ", event.`string`
g_signal_connect_data(window, "key_release_event", cast[cb](on_key_release), nil);

proc onButtonPress(window: GtkWidget, event: GdkEventButton, data: pointer) {.cdecl.} =
  echo "window: ", event
  echo "onButtonPress ", event.button
# gtk_widget_add_events(window, GDK_BUTTON_PRESS_MASK);
g_signal_connect_data(window, "button-press-event", cast[cb](onButtonPress), nil);

proc onButtonRelease(window: GtkWidget, event: GdkEventButton, data: pointer) {.cdecl.} =
  echo "onButtonRelease ", event.button
g_signal_connect_data(window, "button-release-event", cast[cb](onButtonRelease), nil);

while true:


  # glClearColor(0, 0.5 + sin(f)/2, 0, 1)
  # f += 0.01
  #glClear(GL_COLOR_BUFFER_BIT)


  while gtk_events_pending():
    gtk_main_iteration()

  # glFlush();
