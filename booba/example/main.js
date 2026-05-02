const loading = document.getElementById("loading");

function waitForBridge() {
  return new Promise((resolve) => {
    function check() {
      if (
        globalThis.bubbletea_resize !== undefined &&
        globalThis.bubbletea_read !== undefined &&
        globalThis.bubbletea_write !== undefined
      ) {
        resolve();
      } else {
        console.log("waiting for bubbletea bridge…");
        setTimeout(check, 500);
      }
    }
    check();
  });
}

function initTerminal() {
  const term = new Terminal({ cursorBlink: true });
  const fitAddon = new FitAddon.FitAddon();
  term.loadAddon(fitAddon);
  term.open(document.getElementById("terminal-container"));

  fitAddon.fit();
  window.addEventListener("resize", () => fitAddon.fit());

  term.focus();

  // Send initial size to Go
  bubbletea_resize(term.cols, term.rows);

  // Poll Go output and write to terminal
  setInterval(() => {
    const data = bubbletea_read();
    if (data && data.length > 0) {
      term.write(data);
    }
  }, 16);

  // Forward resize events to Go
  term.onResize((size) => bubbletea_resize(size.cols, size.rows));

  // Forward key/paste input to Go
  term.onData((data) => bubbletea_write(data));
}

async function main() {
  const go = new Go();
  const result = await WebAssembly.instantiateStreaming(
    fetch("./booba.wasm"),
    go.importObject
  );

  // Run the WASM module (does not await — it runs until the program exits)
  go.run(result.instance).then(() => console.log("wasm finished"));

  // Wait until go-booba registers the JS bridge globals
  await waitForBridge();

  // Hide the loading overlay
  loading.classList.add("hidden");

  initTerminal();
}

main().catch(console.error);
