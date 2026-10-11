# AI instructions: a new Rust GUI project from this template

Template: the `RustGuiSpec` repository that contains this file
(<https://github.com/cpCr4zy/RustGuiSpec>). Throughout this document `<template>` stands for the
absolute path of a local checkout (e.g. `~/myprojects/RustGuiSpec`). Without one, clone it first:
`git clone https://github.com/cpCr4zy/RustGuiSpec.git ~/myprojects/RustGuiSpec`.

## Prompt to paste

Copy this into a new chat with an AI agent, replacing `<template>` with that path, and describe
the application:

```text
Create a new Rust GUI project from the template at <template>.
First read and follow <template>/AI-INSTRUCTIONS.md.

Application: <what it does, 2–5 sentences>
Directory: <e.g. ~/myprojects/notecraft>
Crate name: <notecraft>   Display name: <NoteCraft>
App ID: <com.acme.notecraft>   GitHub: <owner/repo>   Publisher: <Acme Ltd>
```

The agent asks for any field left empty (step 1).

---

## Instructions for the agent

You are creating a new project from a template. The template is the source of truth: don't
reinvent the layout, dependency versions or CI; take them from here and change only what the
application needs.

### 0. Read the template

In the template directory read `README.md`, `SPEC.md`, `CICD.md` and `template/AGENTS.md`.
When the template is a git repository, check that it is clean and current: `git -C <template>
status --short` and `git -C <template> log -1 --oneline`. If there are uncommitted changes, tell
the user and ask whether to use them. A template that is not a git repository has no commit to
record, and the new project's `docs/template-origin.txt` then says `commit: unknown`; say so in
the final report instead of guessing a revision.

### 1. Collect the parameters

Six values are needed. Ask for whatever the request lacks in a single question covering every
missing field, with sensible defaults:

| Parameter | Rule | Example |
|---|---|---|
| directory | must not exist | `~/myprojects/notecraft` |
| crate | `^[a-z][a-z0-9-]*$`, the binary name | `notecraft` |
| display name | anything, spaces allowed | `NoteCraft` |
| app id | reverse-DNS, at least 2 segments | `com.acme.notecraft` |
| GitHub | `owner/repo` (may not exist yet) | `acme/notecraft` |
| publisher | for MSI, deb/rpm, AppStream | `Acme Ltd` |

Don't derive the app id or publisher from unrelated data. If the user doesn't know, suggest
`io.github.<owner>.<crate>` and their GitHub name.

### 2. Check the environment

```bash
cargo --version && rustup target list --installed
```

- Rust ≥ **1.95** (the MSRV of egui/eframe 0.36) and the `wasm32-unknown-unknown` target. Without
  Rust, ask the user whether to install it with the official rustup:
  `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --target wasm32-unknown-unknown`.
  Rust then lives in `~/.cargo/bin`; if `cargo` isn't found, add it to `PATH` for your commands.
- `python3` (the generator) and `git` are required. For the full check: `cargo-deny`
  (`cargo install --locked cargo-deny`), `trunk` 0.21.14 (the prebuilt binary from GitHub
  Releases `trunk-rs/trunk`; `cargo install trunk` may fail to build) and `zip`.
- Linux: the system packages in SPEC §4.4 (usually already present on an Arch/CachyOS desktop).

### 3. Create the project

```bash
<template>/new-project.sh <directory> <crate> "<Name>" <app.id> <owner/repo> "<Publisher>"
```

The script copies `template/`, fills in the names, renames files, generates the MSI GUIDs, writes
placeholder icons, copies `SPEC.md`/`CICD.md` into `docs/` and writes `docs/template-origin.txt`.
**Don't edit the template** for a specific project: make every change in the new directory.

### 4. Make sure the skeleton is green, before any change

```bash
cd <directory>
git init -b main
cargo generate-lockfile
cargo xtask ci
```

`cargo xtask ci` runs fmt, clippy `-D warnings`, tests, the wasm32 check and cargo-deny. Without
cargo-deny installed that step prints `SKIPPED`; tell the user. If anything fails on the untouched
skeleton, that is a template bug: tell the user what and where, fix it in the new project and
offer to carry the fix back to the template.

Run the app and look at the window (`cargo run -p <crate>`; take a screenshot if a tool is
available), then make the first commit: `Initial project from RustGuiSpec template <template commit>`.
If git has no author name/email configured, ask the user; don't make one up.

### 5. Adapt it to the application

In this order:

1. Logic in `crates/core` (no GUI, must build for wasm32). New library crates go in `crates/`,
   with `[lints] workspace = true` and the `*.workspace = true` fields; if the browser build uses
   them, add them to the `wasm` command in `xtask/src/main.rs`.
2. Interface in `crates/ui` (`MainApp`). Replace the demo code (`summarize`, `open_bytes`) with the
   real thing, keeping: settings restore, `save()`, no panics, separate wasm32 behaviour.
3. Dependencies through `[workspace.dependencies]`. Before using a new crate's API, open its
   source in `~/.cargo/registry/src/` (the egui/eframe API changes between versions: in 0.36 it is
   `App::ui(&mut self, ui, frame)`, `egui::Panel::top(..).show(ui, ..)`, and `DroppedFile` is a
   trait with `path()`/`bytes()`).
4. Tests: unit tests in the crates, `egui_kittest` UI tests in `crates/ui/tests/`, `proptest`
   property tests for everything that parses external input.
5. After each step: `cargo xtask ci`, then commit the green state.

Code rules and prohibitions are in the new project's `AGENTS.md` (imported by `CLAUDE.md`).
Extend it with a section on the application's domain, but don't weaken the general rules.

### 6. Platform integration (as needed)

| Need | Where |
|---|---|
| opening the app's own file types | `packaging/linux/*.desktop` (`MimeType=`) + a MIME XML, `packaging/macos/Info.plist.in` (`CFBundleDocumentTypes`), `packaging/windows/<crate>.wxs` (ProgID, OpenWithProgids) |
| file access in Flatpak | `finish-args` in `packaging/linux/flatpak/*.yml`: minimal, with a comment |
| network (updates and the like) | `ureq` + `rustls-native-certs` (SPEC §4.3); `deny.toml` checks the licences |
| a CLI beside the GUI | a new `apps/<crate>-cli`, added to packaging and to the checks in `release.yml` |
| macOS entitlements | `packaging/macos/entitlements.plist`: only with a comment giving the reason |

After changing `packaging/` or `.github/`, check the syntax (`bash -n`, `xmllint`,
`desktop-file-validate`, `appstreamcli validate`; CI does this in `packaging-lint.yml`).

### 7. Before the first release, remind the user to

- Replace the placeholder icons in `assets/app-icon/` (hicolor PNG set, `.ico`, `.icns`, SVG, `icon-256.png`).
- Fill in the description and URLs in `packaging/linux/*.metainfo.xml.in`, the categories in the
  `.desktop` file, and the default maintainer address (`<CRATE>_MAINTAINER`) in `packaging/linux/package.sh`.
- Set up GitHub: the `release` branch, the `release` Environment, signing secrets (all optional),
  ARM runners for a private repo (`CICD.md` §6).
- Do a test release run: `gh workflow run release.yml --ref <branch> -f version=0.1.0-rc.1`.

### Never without the user's explicit consent

- Create a remote repository, push, open a PR, push to `release`, publish a release.
- Add secrets to GitHub.
- Change the `RustGuiSpec` template itself (only propose it, with a ready diff).
- Change the global git config, or install system packages with `sudo`.

### Final report

The project directory, the parameters, the template commit (`unknown` when the template is not a
git repository), the `cargo xtask ci` result (with any skipped steps), what was run and looked
at, what remains to do (from step 7) and any template problems found.
