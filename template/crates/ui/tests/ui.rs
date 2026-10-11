//! Headless UI tests (egui_kittest): no window and no GPU needed.

use egui_kittest::Harness;
use egui_kittest::kittest::Queryable;

// A group of its own: rustfmt sorts imports only within a group, so this stays put whatever the
// project's crate name sorts like after new-project.sh renames it.
use myapp_ui::MainApp;

#[test]
fn shows_the_status_of_an_opened_file() {
    let mut h = Harness::builder().with_size(egui::vec2(800.0, 600.0)).build_eframe(|_cc| {
        let mut app = MainApp::default();
        app.open_bytes("notes.txt", b"one\ntwo");
        app
    });
    h.run_steps(2);
    h.get_by_label("notes.txt: 7 bytes, 2 lines");
}

#[test]
fn reports_an_empty_file_instead_of_failing() {
    let mut h = Harness::builder().build_eframe(|_cc| {
        let mut app = MainApp::default();
        app.open_bytes("empty.txt", b"");
        app
    });
    h.run_steps(2);
    h.get_by_label("empty.txt: input is empty");
}
