use std::{
    env, fs,
    path::{Path, PathBuf},
};

use xdgen::{App, Context, FluentString};

const APP_ID: &str = "dev.cappsy.CosmicExtAppletLogoMenu";

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let metadata_dir = manifest_dir.join("../metadata");
    let i18n_dir = metadata_dir.join("i18n");

    let ctx = Context::new(&i18n_dir, "app").expect("failed to load metadata translations");

    let applet_desktop = App::new(FluentString("metadata-app-title"))
        .keywords(FluentString("metadata-desktop-keywords"))
        .expand_desktop(metadata_dir.join("app.desktop"), &ctx)
        .expect("failed to generate applet desktop entry");

    let settings_desktop = App::new(FluentString("metadata-settings-title"))
        .comment(FluentString("metadata-settings-summary"))
        .keywords(FluentString("metadata-settings-keywords"))
        .expand_desktop(metadata_dir.join("settings.desktop"), &ctx)
        .expect("failed to generate settings desktop entry");

    let metainfo = App::new(FluentString("metadata-app-title"))
        .comment(FluentString("metadata-app-summary"))
        .expand_metainfo(metadata_dir.join("app.metainfo.xml"), &ctx)
        .expect("failed to generate metainfo");

    let output = target_dir(&manifest_dir).join("xdgen");
    fs::create_dir_all(&output).expect("failed to create xdgen output directory");

    fs::write(output.join(format!("{APP_ID}.desktop")), applet_desktop)
        .expect("failed to write applet desktop entry");
    fs::write(
        output.join(format!("{APP_ID}.Settings.desktop")),
        settings_desktop,
    )
    .expect("failed to write settings desktop entry");
    fs::write(output.join(format!("{APP_ID}.metainfo.xml")), metainfo)
        .expect("failed to write metainfo");

    println!("cargo:rerun-if-changed={}", metadata_dir.display());
    println!("cargo:rerun-if-changed={}", i18n_dir.display());
}

fn target_dir(manifest_dir: &Path) -> PathBuf {
    if let Some(target_dir) = env::var_os("CARGO_TARGET_DIR") {
        let target_dir = PathBuf::from(target_dir);
        return if target_dir.is_absolute() {
            target_dir
        } else {
            // Relative CARGO_TARGET_DIR is relative to the workspace root.
            manifest_dir.join("..").join(target_dir)
        };
    }

    // OUT_DIR is <target>/<profile>/build/<package>-<hash>/out.
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    out_dir
        .ancestors()
        .nth(4)
        .expect("failed to determine target directory")
        .to_path_buf()
}
