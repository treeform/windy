/*

gcc -pthread -I/usr/include/gtk-3.0 -I/usr/include/at-spi2-atk/2.0 -I/usr/include/at-spi-2.0 -I/usr/include/dbus-1.0 -I/usr/lib/x86_64-linux-gnu/dbus-1.0/include -I/usr/include/gtk-3.0 -I/usr/include/gio-unix-2.0 -I/usr/include/cairo -I/usr/include/pango-1.0 -I/usr/include/harfbuzz -I/usr/include/pango-1.0 -I/usr/include/fribidi -I/usr/include/harfbuzz -I/usr/include/atk-1.0 -I/usr/include/cairo -I/usr/include/pixman-1 -I/usr/include/uuid -I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include/gdk-pixbuf-2.0 -I/usr/include/libpng16 -I/usr/include/x86_64-linux-gnu -I/usr/include/libmount -I/usr/include/blkid -I/usr/include/glib-2.0 -I/usr/lib/x86_64-linux-gnu/glib-2.0/include helloworld.c -lgtk-3 -lgdk-3 -lpangocairo-1.0 -lpango-1.0 -lharfbuzz -latk-1.0 -lcairo-gobject -lcairo -lgdk_pixbuf-2.0 -lgio-2.0 -lgobject-2.0 -lglib-2.0 -ohelloworld


*/

#include <gtk/gtk.h>
#include <stdbool.h>

void configure_callback(GtkWindow *window, GdkEvent *event, gpointer data)
{
    int x = event->configure.x;
    int y = event->configure.y;
    int w = event->configure.width;
    int h = event->configure.height;
    printf("configure_callback: %d, %d, %d, %d\n", x, y, w, h);
}

static bool on_motion_notify(GtkWindow *window, GdkEventMotion *event, gpointer data)
{
    int x = event->x;
    int y = event->y;
    printf("on_motion_notify: %d, %d\n", x, y);
    return false;
}

static bool on_scroll(GtkWidget *widget, GdkEventScroll *event)
{
    switch (event->direction)
    {
    case GDK_SCROLL_UP:
        printf("view_y_decrease\n");
        break;
    case GDK_SCROLL_DOWN:
        printf("view_y_increase\n");
        break;
    case GDK_SCROLL_LEFT:
        printf("view_x_decrease\n");
        break;
    case GDK_SCROLL_RIGHT:
        printf("view_x_increase\n");
        break;
    default:
        break;
    }

    return false;
}

static bool on_button_press(GtkWidget *widget, GdkEventButton *event)
{
    printf("Button press %i\n", event->button);
    return false;
}

static bool on_button_release(GtkWidget *widget, GdkEventButton *event)
{
    printf("Button release %i\n", event->button);
    return false;
}

static bool on_key_press(GtkWidget *widget, GdkEventKey *event, gpointer user_data)
{
    printf("key pressed: %i\n", event->keyval);
    return FALSE;
}

static bool on_key_release(GtkWidget *widget, GdkEventKey *event, gpointer user_data)
{
    printf("key release: %i\n", event->keyval);
    return FALSE;
}

static bool on_delete(GtkWidget *widget, GdkEvent  *event, gpointer user_data)
{
    printf("window closed\n");
    return FALSE;
}

static bool on_window_state(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{

    printf("on_window_state min: %i max: %i viz: %i full: %i\n",
        (event->new_window_state & GDK_WINDOW_STATE_ICONIFIED) != 0,
        (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0,
        (event->new_window_state & GDK_WINDOW_STATE_WITHDRAWN) != 0,
        (event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN) != 0
    );

    return TRUE;
}

int main(int argc, char **argv)
{
    // Initialize GTK:
    if (!gtk_init_check(NULL, NULL))
    {
        printf("Could not initialize GTK\n");
        return false;
    }

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "My Helloworld test.");
    gtk_widget_show_all(window);

    g_signal_connect(window, "delete-event", G_CALLBACK(on_delete), NULL);

    g_signal_connect(window, "window-state-event", G_CALLBACK(on_window_state), NULL);

    g_signal_connect(window, "configure-event", G_CALLBACK(configure_callback), NULL);

    gtk_widget_add_events(window, GDK_POINTER_MOTION_MASK);
    g_signal_connect(window, "motion-notify-event", G_CALLBACK(on_motion_notify), NULL);

    gtk_widget_add_events(window, GDK_SCROLL_MASK);
    g_signal_connect(window, "scroll-event", G_CALLBACK(on_scroll), NULL);

    gtk_widget_add_events(window, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(window, "button-press-event", G_CALLBACK(on_button_press), NULL);

    gtk_widget_add_events(window, GDK_BUTTON_RELEASE_MASK);
    g_signal_connect(window, "button-release-event", G_CALLBACK(on_button_release), NULL);

    g_signal_connect(window, "key_press_event", G_CALLBACK(on_key_press), NULL);
    g_signal_connect(window, "key_release_event", G_CALLBACK(on_key_release), NULL);

    //gtk_main();
    while (true) {
        //printf("tick\n");
        while (gtk_events_pending()){
            gtk_main_iteration();
        }
    }

    return true;
}
