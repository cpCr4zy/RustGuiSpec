# Rust GUI: specification and project template

A general technical specification and a working template for cross-platform GUI applications in
Rust (Windows, macOS, Linux, FreeBSD, Web), derived from the `pdfcraft` project.

| File | Contents |
|---|---|
| [AI-INSTRUCTIONS.md](AI-INSTRUCTIONS.md) | instructions and a ready-to-paste prompt for an AI agent creating a project from this template |
| [SPEC.md](SPEC.md) | platforms, toolchain, workspace layout, every dependency and feature, system packages, lints, licence policy, application requirements, versioning, signing |
| [CICD.md](CICD.md) | every GitHub Actions workflow, matrices, secrets, release process, repository setup |
| [template/](template/) | a working project skeleton with the placeholders `myapp` / `MyApp` / `com.example.myapp`; it builds as is (`cargo run -p myapp` inside it), placeholder icons included |
| [new-project.sh](new-project.sh) | creates a new project from the template and fills in the names |
| [placeholder-icons.py](placeholder-icons.py) | writes placeholder icons (PNG, ICO, ICNS, SVG); `new-project.sh` runs it, and it made the ones in `template/assets/app-icon/` |

## New project

```bash
./new-project.sh ~/myprojects/notecraft notecraft "NoteCraft" com.acme.notecraft acme/notecraft "Acme Ltd"
```

Arguments: directory, crate/binary name, display name, reverse-DNS ID, GitHub `owner/repo`,
publisher. The script generates the MSI GUIDs once per project.

```bash
cd ~/myprojects/notecraft && git init -b main && cargo generate-lockfile && cargo xtask ci
```

Then follow the checklist in [SPEC.md §12](SPEC.md#12-new-project-checklist) and the GitHub setup
in [CICD.md §6](CICD.md#6-github-repository-setup).

## Specification and AI rules in the new project

`new-project.sh` puts `docs/SPEC.md`, `docs/CICD.md` and `docs/template-origin.txt` (where and from
which template commit the project was made) into the project, along with `AGENTS.md` (rules for
AI agents) and `CLAUDE.md`, which imports it. To have an AI agent create the project, give it the
prompt from [AI-INSTRUCTIONS.md](AI-INSTRUCTIONS.md).

## Verified

On Linux (KDE Wayland), on projects generated with plain and hyphenated crate names and a
display name with spaces:

- `cargo xtask ci` (fmt, clippy `-D warnings`, tests, wasm32 check, cargo-deny) passes on Rust
  1.99.0; the workspace builds on Rust 1.95 (the declared MSRV) and is rejected by 1.94.
- The desktop app runs; the web build (trunk) runs in a browser.
- `packaging/linux/package.sh` builds the AppImage (+ .zsync), deb, rpm and tar.gz, and the
  package checks from `release.yml` pass on them.
- `cargo xtask version set` handles pre-releases and leaves registry dependencies alone.
- shellcheck 0.11, actionlint 1.7.12, the PowerShell 7.4 parser (scripts and inline workflow
  steps), xmllint, desktop-file-validate and appstreamcli report no problems.

Not runnable here, so left to the workflows on GitHub: MSI (WiX needs Windows), DMG, signing and
notarization, Flatpak, riscv64, FreeBSD.

Every pull request is checked by [`.github/workflows/check.yml`](.github/workflows/check.yml): it
generates a project (hyphenated crate name, display name with a space) and runs its `cargo xtask
ci` and cargo-deny, checks that several crate names stay fmt-clean, and lints the scripts,
workflows and packaging metadata of the generated project.

## Taken from pdfcraft, and what was simplified

Taken unchanged: egui/eframe 0.36 versions and features, the wgpu → OpenGL fallback, build
profiles, lints, `deny.toml`, Windows resources (icon, VERSIONINFO, DPI), every package format, all
5 workflows, optional macOS/Windows signing, releases through the `release` branch and a draft.

Removed as pdfcraft-specific: OCR models, craft-fonts, fuzzing, asset and layering checks in
xtask, the CLI and MCP server, single instance, update checks, vendored winit/egui-wgpu patches,
PDF file associations. SPEC marks them as MAY where they might be needed.

## Licence

The specification, the scripts and the template are licensed under either of
[Apache License 2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your option. A generated project
starts with the same dual licence (`template/LICENSE-*`, `license` in `Cargo.toml`); its owner may
change that.
