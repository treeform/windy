// Supply the browser platform queried when the WASM backend initializes.
globalThis.navigator ??= {platform: 'Linux'};
require('./test_browser_inputs.cjs');
