# MyApp

A cross-platform GUI application in Rust (egui/eframe): Windows, macOS, Linux, FreeBSD and the web.

## Build and run

```sh
cargo run -p myapp                      # desktop app
cargo xtask ci                          # every quality gate CI runs
cd apps/myapp-web && trunk serve        # web version on http://127.0.0.1:8080
```

A release's `myapp-web-<version>.zip` is a static website: serve the unpacked folder over HTTP
(`python3 -m http.server 8000 --bind 127.0.0.1`, then <http://127.0.0.1:8000>) or upload it to a
static host; opened as a local file it stays blank. `README-web.md` in the zip has the details.

Linux needs the windowing headers first, e.g. on Debian/Ubuntu:

```sh
sudo apt-get install libxkbcommon-dev libwayland-dev libx11-dev libxrandr-dev libxi-dev libgl1-mesa-dev libgtk-3-dev
```

## Layout

| Path | What |
|---|---|
| `crates/core` | engine, no GUI dependencies, builds for wasm32 |
| `crates/ui` | egui shell shared by desktop and web |
| `apps/myapp` | desktop binary (wgpu, OpenGL fallback) |
| `apps/myapp-web` | browser binary (trunk) |
| `xtask` | `cargo xtask version`, `ci`, `wasm`, `deny` |
| `packaging/` | installers for every platform |

## Releasing

`cargo xtask version set X.Y.Z`, merge to `main`, fast-forward `release` and push: the Release
workflow drafts a GitHub Release with every installer.

## Licence

MIT OR Apache-2.0.
