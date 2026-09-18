# AI Guidelines: Browser Testing (Interactive DoD)

**Goal:** Verify *interactive* front-end behaviour in a real browser — panel toggles, drag-resize with clamps, keyboard operability, `localStorage` persistence, responsive stacking, and shared header/footer collapse — rather than only reading the code.

## 1. Confirm the toolchain on THIS machine first (do not assume)

Availability is **per-machine** — not every computer has these installed. Before the first browser test, probe what is present and install whatever is missing. Treat any versions you observe (e.g. "Playwright 1.62 + Edge 153") as one machine's state, **not a fixed requirement**.

- **Python + pip** — `python --version` and `pip --version`. Needed to install and run Playwright.
- **Playwright (Python)** — `python -m pip show playwright`. If absent: `python -m pip install playwright`. It bundles its own driver, so **no Node.js is required**.
- **A Chromium-based browser** — Playwright can drive any one of these; pick whichever the machine has:
  - Microsoft Edge → `channel="msedge"` (common on Windows)
  - Google Chrome → `channel="chrome"`
  - Playwright's own build → `python -m playwright install chromium` (a download; use when no system browser is present)

Pre-flight check (run once per machine before the suite):

    python -c "import playwright; print('playwright OK')"
    # launch smoke-test with the browser you intend to use:
    python -c "from playwright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(channel='msedge', headless=True); b.close(); p.stop()"

If that launch fails, fall back to the next channel in turn; if none exist, install Chromium. Headless by default (`headless=True`); set `headless=False` to watch it run.

## 2. Run it with the host shell, not the sandbox

- **Use `shell_command` with the host `python`**, not the `run_python` tool. The `run_python` sandbox is isolated — no host filesystem, no network, cannot reach `localhost` — so it cannot start the app or drive it.
- Keep the test script and its screenshots in the **scratchpad** so the repo stays clean.

## 3. Recipe (start server → drive → assert → clean up)

1. Start the app from the build output (the folder that holds `<App>.dll` and its `wwwroot/`): `dotnet <App>.dll` with `ASPNETCORE_ENVIRONMENT=Development` and `ASPNETCORE_URLS=http://localhost:<port>`.
2. Poll a cheap endpoint until it returns 200 (bounded timeout) before touching the browser.
3. `page.goto(url, wait_until="networkidle")`.
4. Drive it with `page.click(...)`, `page.keyboard.press("Enter" | "Space")`, and `page.mouse.move(...)/down()/up(...)` for drag-resize.
5. Assert with computed styles (`getComputedStyle`), `get_attribute(sel, "aria-expanded")`, `localStorage.getItem(key)`, and `document.documentElement.scrollWidth <= window.innerWidth` (no horizontal overflow).
6. `page.set_viewport_size({...})` to exercise responsive breakpoints; `page.screenshot(...)` for a visual check.
7. **Terminate the server in a `finally`** so no process is left running.

## 4. Gotchas (learned the hard way)

- **A collapsed-by-default panel measures 0.** `getBoundingClientRect().width` of a `display:none` element is `0`. To verify the width of a panel that *starts closed*, **open it first, then measure** — the stored `localStorage` value is the source of truth. (This is a *test* bug, not an app bug.)
- **Drag with `page.mouse`, not a one-shot `.drag_to()`.** Move to the resizer's centre, `down()`, move in steps, `up()` — this fires the real `mousemove`/`mouseup` the handlers listen for.
- **Settle before asserting.** Some layouts re-fit on the `window resize` event or a CSS transition; a short `page.wait_for_timeout(...)` after a toggle keeps height assertions from racing the animation.
- **Static assets vs compiled views.** CSS/JS are served from the source `wwwroot` (always current), but Razor views are compiled at build time — **rebuild before re-verifying a `.cshtml` change**, or you will test a stale view.
- **Version string gotcha.** `import playwright; playwright.__version__` raises `AttributeError`; use `pip show playwright` for the version.

## 5. Verifying rendered output, not state

A toggle whose flags flip is not a toggle whose effect is visible. On DiGi.GIS.WebAPI.UI#43 every state
assertion (`renderer.shadowMap.enabled`, `light.castShadow`, `getEnvironmentState()`) passed while no shade
had ever reached the screen; the screenshot statistic was the only check that could have failed.

- **Assert a pixel statistic.** Crop a region of `page.screenshot()` (PIL + numpy), compare the mean
  luminance across the toggle: off must differ from on by more than the noise floor, and on → off → on must
  restore the original within ~1 unit. A WebGL canvas cannot be read back through `toDataURL` unless
  `preserveDrawingBuffer` is set, but the compositor screenshot always works.
- **Pixel-minimum across parameter values isolates parameter-independent artefacts.** To find shading that
  ignores the sun, take the same pose under three sun positions and the effect-off frame, then
  `min(off - shot_i)` per pixel: anything left is darkening present under *every* parameter value. One
  image showed the winding bug that a dozen single screenshots had not.
- **GPU cost is not rAF cadence.** The interval between `requestAnimationFrame` callbacks is CPU submit
  time; wrap `renderer.render` in `EXT_disjoint_timer_query_webgl2` (`beginQuery`/`endQuery`, drain when
  `QUERY_RESULT_AVAILABLE`, discard on `GPU_DISJOINT_EXT`) for the GPU time. Launch **headed** so the real
  GPU is used, with `--disable-frame-rate-limit --disable-gpu-vsync` so nothing is vsync-capped. Headless
  `--use-angle=swiftshader` does not keep a rAF cadence and produced unusable numbers — do not report it.
  On a fast GPU everything is sub-millisecond: report the *ranking* between variants, not the absolutes.
- **Folded cards measure nothing and cannot be clicked.** Side-panel cards start collapsed
  (`.gltf-card-collapsed`); `Locator.click` on a checkbox inside one times out and looks like a missing
  control. Click the card's `.gltf-card-title` first (same rule as the collapsed panel in §4).

## 6. When NOT to use it

- Pure server-side / C# logic — use xUnit (see [Coding - Automatic Tests](Coding%20-%20Automatic%20Tests.md)).
- A one-off "does it render" check — a `curl` of the endpoint is enough. Spin up the browser for *interactive* DoD items (toggle / drag / keyboard / persistence / responsive).

## 7. DoD → Playwright assertion map

| Interactive DoD item | Playwright assertion |
|---|---|
| Panel open/closed default | `offsetWidth > 0` vs `display === none`, plus `aria-expanded` |
| Toggle flips state | click → `aria-expanded` flips, modifier class added/removed, resizer shows/hides |
| Drag-resize with clamp | `page.mouse` drag → width within min/max, `localStorage` key set |
| Widths persist across reload | reload → (open the panel if it defaults closed) → width restored from `localStorage` |
| Keyboard operable | `focus()` + `keyboard.press("Enter")` / `("Space")` → state toggles |
| Responsive stacking | `set_viewport_size(<1100px)` → `flex-direction: column`, resizers `display:none`, no horizontal overflow |
| Shared header/footer collapse | click the layout toggle → `body` class toggles, viewport height grows |
| Visual effect on/off (shade, fog, highlight) | screenshot region mean luminance differs across the toggle and restores after toggling back (§5) |
