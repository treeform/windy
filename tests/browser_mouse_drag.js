// Run in the mouse_drag_regression.html fixture after its WASM initializes.
(() => {
  const c = document.querySelector('canvas');
  window.windyMouseEvents = [];
  function mouse(target, type, x, y, buttons = 0) {
    target.dispatchEvent(new MouseEvent(type, {
      clientX: x, clientY: y, button: 0, buttons, bubbles: true
    }));
  }
  mouse(c, 'mouseenter', 100, 100);
  mouse(c, 'mousemove', 100, 100);
  // No preceding move: activation clicks must still use their own coordinates.
  mouse(c, 'mousedown', 220, 180, 1);
  mouse(c, 'mouseleave', 810, 180, 1);
  mouse(document, 'mousemove', 820, 190, 1);
  mouse(document, 'mouseup', 830, 200);
  mouse(c, 'mouseenter', 300, 200);
  mouse(c, 'mousemove', 300, 200);
  const events = window.windyMouseEvents;
  const press = events.find(e => e.kind === 1);
  const release = events.find(e => e.kind === 2);
  const results = {
    pressUsesCurrentPosition: press?.x === 220 && press?.y === 180,
    dragOutsideDelivered: events.some(e => e.kind === 3 && e.x === 820),
    releaseOutsideDelivered: release?.x === 830 && release?.y === 200,
    buttonUpAfterReentry: events.at(-1)?.down === 0
  };
  if (!Object.values(results).every(Boolean)) {
    throw Error(JSON.stringify({results, events}));
  }
  return {results, events};
})()
