#include <assert.h>
#include <stdio.h>
#include "../src/windy/platforms/ios/services.m"

static int actionCount;
static int lastAction = -1;

static void recordAction(int action) {
  // Count only valid, current native menu selections.
  actionCount++;
  lastAction = action;
}

int main(void) {
  // Exercise the real UIKit delegate without presenting over another app.
  @autoreleasepool {
    assert(windyIosShowTextEditMenu(NULL, 1, 2, 3, 4, 15,
      recordAction) == 0);
    if (@available(iOS 16.0, *)) {
      WindyIosEditMenu *menu = [WindyIosEditMenu new];
      UIEditMenuInteraction *interaction = [[UIEditMenuInteraction alloc]
        initWithDelegate:menu];
      menu.bounds = CGRectMake(10, 20, 30, 40);
      menu.actions = 1u | 8u;
      menu.callback = recordAction;
      menu.generation = 7;
      UIEditMenuConfiguration *configuration = [UIEditMenuConfiguration
        configurationWithIdentifier:@7 sourcePoint:CGPointZero];
      UIMenu *actions = [menu editMenuInteraction:interaction
        menuForConfiguration:configuration suggestedActions:@[]];
      assert(actions.children.count == 2);
      assert([((UIAction *)actions.children[0]).title isEqualToString:@"Copy"]);
      assert([((UIAction *)actions.children[1]).title isEqualToString:@"Select All"]);
      assert(CGRectEqualToRect([menu editMenuInteraction:interaction
        targetRectForConfiguration:configuration], menu.bounds));
      [menu performAction:2 generation:7];
      [menu performAction:0 generation:6];
      assert(actionCount == 0);
      [menu performAction:0 generation:7];
      assert(actionCount == 1 && lastAction == 0);
      [menu performAction:0 generation:7];
      assert(actionCount == 1);
      menu.callback = recordAction;
      NSUInteger generation = menu.generation;
      [menu dismiss];
      [menu performAction:3 generation:generation];
      assert(actionCount == 1);
      actions = [menu editMenuInteraction:interaction
        menuForConfiguration:configuration suggestedActions:@[]];
      assert(actions.children.count == 0);
    }
    puts("Native iOS edit menu actions and stale selection checks passed.");
  }
  return 0;
}
