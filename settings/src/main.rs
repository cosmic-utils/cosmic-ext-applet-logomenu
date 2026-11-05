// SPDX-License-Identifier: GPL-3.0-only

mod app;
mod config;

use sysinfo::System;

fn main() -> cosmic::iced::Result {
    if is_running() {
        return Ok(());
    }

    let requested_languages = i18n_embed::DesktopLanguageRequester::requested_languages();
    liblog::init(&requested_languages);

    let settings = cosmic::app::Settings::default().size_limits(
        cosmic::iced::Limits::NONE
            .min_width(360.0)
            .min_height(180.0),
    );

    cosmic::app::run::<app::AppModel>(settings, ())
}

fn is_running() -> bool {
    let current_pid = std::process::id();
    let current_exe = std::env::current_exe()
        .ok()
        .and_then(|p| p.canonicalize().ok());

    let Ok(mut system) = System::new_all() else {
        return false;
    };
    system.refresh_all();
    system.processes().values().any(|process| {
        if process.pid().as_u32() == current_pid {
            return false;
        }

        if let Some(exe_path) = process.exe().and_then(|p| p.canonicalize().ok())
            && current_exe.as_ref() == Some(&exe_path)
        {
            return true;
        }

        false
    })
}
