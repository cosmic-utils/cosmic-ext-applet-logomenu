# Metadata templates

These files are templates consumed by [`xdgen`](https://github.com/pop-os/xdgen) from
`applet/build.rs`:

- `app.desktop` and `settings.desktop` are expanded into localized desktop entries.
- `app.metainfo.xml` is expanded into a localized AppStream metainfo file.

Do not add localized keys (`Name[xx]`, `Comment[xx]`, `Keywords[xx]`,
`<name xml:lang="xx">`, `<summary xml:lang="xx">`) to these templates. Add the
translations to `i18n/<lang>/app.ftl` instead.

The supported message keys are:

- `metadata-app-title`
- `metadata-app-summary`
- `metadata-desktop-keywords`
- `metadata-settings-title`
- `metadata-settings-summary`
- `metadata-settings-keywords`

The generated files are written to `target/xdgen/` and are installed by the
`justfile` and the Flatpak manifest.
