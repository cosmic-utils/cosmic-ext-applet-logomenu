export APPID1 := 'dev.cappsy.CosmicExtAppletLogoMenu'
export APPID2 := 'dev.cappsy.CosmicExtAppletLogoMenu.Settings'

name1 := 'cosmic-ext-applet-logomenu'
name2 := 'cosmic-ext-logomenu-settings'
summary := 'A customisable menu applet for the COSMIC desktop.'
dev_name := 'Jonathan Capps'
email := 'cappsy@gmail.com'

version := `sed -En 's/version[[:space:]]*=[[:space:]]*"([^"]+)"/\1/p' applet/Cargo.toml | head -1`

rootdir := ''
prefix := '/usr'
flatpak-prefix := '/app'

base-dir := absolute_path(clean(rootdir / prefix))
flatpak-base-dir := absolute_path(clean(rootdir / flatpak-prefix))

export INSTALL_DIR := base-dir / 'share'

bin-src1 := 'target' / 'release' / name1
bin-src2 := 'target' / 'release' / name2
bin-dst1 := base-dir / 'bin' / name1
bin-dst2 := base-dir / 'bin' / name2
flatpak-bin-dst1 := flatpak-base-dir / 'bin' / name1
flatpak-bin-dst2 := flatpak-base-dir / 'bin' / name2

desktop1 := APPID1 + '.desktop'
desktop2 := APPID2 + '.desktop'
desktop-src1 := 'target' / 'xdgen' / desktop1
desktop-src2 := 'target' / 'xdgen' / desktop2
desktop-dst1 := clean(rootdir / prefix) / 'share' / 'applications' / desktop1
desktop-dst2 := clean(rootdir / prefix) / 'share' / 'applications' / desktop2
flatpak-desktop-dst1 := flatpak-base-dir / 'share' / 'applications' / desktop1
flatpak-desktop-dst2 := flatpak-base-dir / 'share' / 'applications' / desktop2

metainfo := APPID1 + '.metainfo.xml'
metainfo-src := 'target' / 'xdgen' / metainfo
metainfo-dst := clean(rootdir / prefix) / 'share' / 'metainfo' / metainfo
flatpak-metainfo-dst := flatpak-base-dir / 'share' / 'metainfo' / metainfo

icons-src := 'res' / 'icons' / 'hicolor'
icons-dst := clean(rootdir / prefix) / 'share' / 'icons' / 'hicolor'
flatpak-icons-dst := flatpak-base-dir / 'share' / 'icons' / 'hicolor' / 'scalable'

# Default recipe which runs `just build-release`
default: build-release

# Combines all cleaning
clean-all:
    cargo clean
    rm -rf .cargo vendor vendor.tar *.rpm *.deb .flatpak-builder flatpak-out repo

# Runs `cargo clean`
clean:
    cargo clean

# Removes vendored dependencies
clean-vendor:
    rm -rf .cargo vendor vendor.tar

# `cargo clean` and removes vendored dependencies
clean-dist: clean clean-vendor

# Compiles with debug profile
build-debug *args:
    (cd applet && cargo build {{args}})
    (cd settings && cargo build {{args}})

# Compiles with release profile
build-release *args: (build-debug '--release' args)

# Compiles release profile with vendored dependencies
build-vendored *args: vendor-extract (build-release '--frozen --offline' args)

# Runs a clippy check
check *args:
    cargo clippy --all-features {{args}} -- -W clippy::pedantic

# Runs a clippy check with JSON message format
check-json: (check '--message-format=json')

dev *args:
    cargo fmt
    just run {{args}}

# Installs files
install:
    install -Dm0755 {{bin-src1}} {{bin-dst1}}
    install -Dm0755 {{bin-src2}} {{bin-dst2}}
    install -Dm0644 {{desktop-src1}} {{desktop-dst1}}
    install -Dm0644 {{desktop-src2}} {{desktop-dst2}}
    install -Dm0644 {{metainfo-src}} {{metainfo-dst}}
    install -Dm0644 "{{icons-src}}/scalable/apps/{{APPID1}}.svg" "{{icons-dst}}/scalable/apps/{{APPID1}}.svg"; \

# Build flatpak locally
flatpak-builder:
    flatpak-builder \
        --force-clean \
        --verbose \
        --ccache \
        --user \
        --disable-rofiles-fuse \
        --install \
        --install-deps-from=flathub \
        --repo=repo \
        flatpak-out \
        dev.cappsy.CosmicExtAppletLogoMenu.json

# Update flatpak cargo-sources.json
flatpak-cargo-sources:
    python3 ./flatpak/flatpak-cargo-generator.py ./Cargo.lock -o ./flatpak/cargo-sources.json

# Installs files for flatpak
flatpak-install:
    install -Dm0755 {{bin-src1}} {{flatpak-bin-dst1}}
    install -Dm0755 {{bin-src2}} {{flatpak-bin-dst2}}
    install -Dm0644 {{desktop-src1}} {{flatpak-desktop-dst1}}
    install -Dm0644 {{desktop-src2}} {{flatpak-desktop-dst2}}
    install -Dm0644 {{metainfo-src}} {{flatpak-metainfo-dst}}
    install -Dm0644 "{{icons-src}}/scalable/apps/{{APPID1}}.svg" "{{flatpak-icons-dst}}/apps/{{APPID1}}.svg"; \

# Uninstalls installed files
uninstall:
    rm {{bin-dst1}}
    rm {{bin-dst2}}
    rm {{desktop-dst1}}
    rm {{desktop-dst2}}
    rm {{metainfo-dst}}
    rm "{{icons-dst}}/scalable/apps/{{APPID1}}.svg"; \

# Vendor dependencies locally
vendor:
    #!/usr/bin/env bash
    mkdir -p .cargo
    cargo vendor --sync Cargo.toml | head -n -1 > .cargo/config.toml
    echo 'directory = "vendor"' >> .cargo/config.toml
    echo >> .cargo/config.toml
    echo '[env]' >> .cargo/config.toml
    if [ -n "${SOURCE_DATE_EPOCH}" ]
    then
        source_date="$(date -d "@${SOURCE_DATE_EPOCH}" "+%Y-%m-%d")"
        echo "VERGEN_GIT_COMMIT_DATE = \"${source_date}\"" >> .cargo/config.toml
    fi
    if [ -n "${SOURCE_GIT_HASH}" ]
    then
        echo "VERGEN_GIT_SHA = \"${SOURCE_GIT_HASH}\"" >> .cargo/config.toml
    fi
    tar pcf vendor.tar .cargo vendor
    rm -rf .cargo vendor

# Extracts vendored dependencies
vendor-extract:
    rm -rf vendor
    tar pxf vendor.tar

# Deb install
deb_arch := if arch() == "x86_64" { "amd64" } else { arch() }
debname1 := name1+'_'+version+'_'+deb_arch
debname2 := name2+'_'+version+'_'+deb_arch
debdir1 := debname1 / 'DEBIAN'
debdir2 := debname2 / 'DEBIAN'
debcontrol1 := debdir1 / 'control'
debcontrol2 := debdir2 / 'control'

deb:
    strip {{bin-src1}}
    install -D {{bin-src1}} {{debname1}}{{bin-dst1}}
    install -D {{desktop-src1}} {{debname1}}{{desktop-dst1}}
    install -D "{{icons-src}}/scalable/apps/{{APPID1}}.svg" "{{debname1}}{{icons-dst}}/scalable/apps/{{APPID1}}.svg"; \
    mkdir -p {{debdir1}}
    echo "Package: {{name1}}" > {{debcontrol1}}
    echo "Version: {{version}}" >> {{debcontrol1}}
    echo "Architecture: {{deb_arch}}" >> {{debcontrol1}}
    echo "Maintainer: {{dev_name}} <{{email}}>" >> {{debcontrol1}}
    echo "Description: {{summary}}" >> {{debcontrol1}}
    dpkg-deb --build --root-owner-group {{debname1}}
    rm -Rf {{debname1}}/

    strip {{bin-src2}}
    install -D {{bin-src2}} {{debname2}}{{bin-dst2}}
    install -D {{desktop-src2}} {{debname2}}{{desktop-dst2}}
    mkdir -p {{debdir2}}
    echo "Package: {{name2}}" > {{debcontrol2}}
    echo "Version: {{version}}" >> {{debcontrol2}}
    echo "Architecture: {{deb_arch}}" >> {{debcontrol2}}
    echo "Maintainer: {{dev_name}} <{{email}}>" >> {{debcontrol2}}
    echo "Description: {{summary}}" >> {{debcontrol2}}
    dpkg-deb --build --root-owner-group {{debname2}}
    rm -Rf {{debname2}}/


# RPM install

rpmarch := arch()
rpmname1 := name1 + '-' + version + '-1.' + rpmarch
rpmname2 := name2 + '-' + version + '-1.' + rpmarch
rpmdir1 := rpmname1 / 'BUILDROOT'
rpmdir2 := rpmname2 / 'BUILDROOT'
rpminstall1 := rpmdir1 / prefix
rpminstall2 := rpmdir2 / prefix
rpm_bin_dst1 := rpminstall1 / 'bin' / name1
rpm_bin_dst2 := rpminstall2 / 'bin' / name2
rpm_desktop_dst1 := rpminstall1 / 'share' / 'applications' / desktop1
rpm_desktop_dst2 := rpminstall2 / 'share' / 'applications' / desktop2
rpm_metainfo_dst := rpminstall1 / 'share' / 'metainfo' / metainfo
rpm_icons_dst := rpminstall1 / 'share' / 'icons' / 'hicolor' / 'scalable' / 'apps'

rpm:
    strip {{bin-src1}}
    install -D {{bin-src1}} {{rpm_bin_dst1}}
    install -D {{desktop-src1}} {{rpm_desktop_dst1}}
    install -D {{metainfo-src}} {{rpm_metainfo_dst}}
    install -D "{{icons-src}}/scalable/apps/{{APPID1}}.svg" "{{rpm_icons_dst}}/{{APPID1}}.svg"; \

    mkdir -p {{rpmname1}}
    echo "Name: {{name1}}" > {{rpmname1}}/spec.spec
    echo "Version: {{version}}" >> {{rpmname1}}/spec.spec
    echo "Release: 1%{?dist}" >> {{rpmname1}}/spec.spec
    echo "Summary: {{summary}}" >> {{rpmname1}}/spec.spec
    echo "" >> {{rpmname1}}/spec.spec
    echo "License: GPLv3" >> {{rpmname1}}/spec.spec
    echo "Group: Applications/Utilities" >> {{rpmname1}}/spec.spec
    echo "%description" >> {{rpmname1}}/spec.spec
    echo "{{summary}}" >> {{rpmname1}}/spec.spec
    echo "" >> {{rpmname1}}/spec.spec
    echo "%files" >> {{rpmname1}}/spec.spec
    echo "%defattr(-,root,root,-)" >> {{rpmname1}}/spec.spec
    echo "{{prefix}}/bin/{{name1}}" >> {{rpmname1}}/spec.spec
    echo "{{prefix}}/share/applications/{{desktop1}}" >> {{rpmname1}}/spec.spec
    echo "{{prefix}}/share/metainfo/{{metainfo}}" >> {{rpmname1}}/spec.spec
    echo "{{prefix}}/share/icons/hicolor/scalable/apps/*.svg" >> {{rpmname1}}/spec.spec

    rpmbuild -bb --buildroot="$(pwd)/{{rpmdir1}}" {{rpmname1}}/spec.spec \
        --define "_rpmdir $(pwd)" \
        --define "_topdir $(pwd)/{{rpmname1}}" \
        --define "_buildrootdir $(pwd)/{{rpmdir1}}"

    rm -rf {{rpmname1}} {{rpmdir1}}
    mv x86_64/* .
    rmdir x86_64

    strip {{bin-src2}}
    install -D {{bin-src2}} {{rpm_bin_dst2}}
    install -D {{desktop-src2}} {{rpm_desktop_dst2}}

    mkdir -p {{rpmname2}}
    echo "Name: {{name2}}" > {{rpmname2}}/spec.spec
    echo "Version: {{version}}" >> {{rpmname2}}/spec.spec
    echo "Release: 1%{?dist}" >> {{rpmname2}}/spec.spec
    echo "Summary: {{summary}}" >> {{rpmname2}}/spec.spec
    echo "" >> {{rpmname2}}/spec.spec
    echo "License: GPLv3" >> {{rpmname2}}/spec.spec
    echo "Group: Applications/Utilities" >> {{rpmname2}}/spec.spec
    echo "%description" >> {{rpmname2}}/spec.spec
    echo "{{summary}}" >> {{rpmname2}}/spec.spec
    echo "" >> {{rpmname2}}/spec.spec
    echo "%files" >> {{rpmname2}}/spec.spec
    echo "%defattr(-,root,root,-)" >> {{rpmname2}}/spec.spec
    echo "{{prefix}}/bin/{{name2}}" >> {{rpmname2}}/spec.spec
    echo "{{prefix}}/share/applications/{{desktop2}}" >> {{rpmname2}}/spec.spec

    rpmbuild -bb --buildroot="$(pwd)/{{rpmdir2}}" {{rpmname2}}/spec.spec \
        --define "_rpmdir $(pwd)" \
        --define "_topdir $(pwd)/{{rpmname2}}" \
        --define "_buildrootdir $(pwd)/{{rpmdir2}}"

    rm -rf {{rpmname2}} {{rpmdir2}}
    mv x86_64/* .
    rmdir x86_64
