#!/data/data/com.termux/files/usr/bin/bash
# Runs inside termux/termux-docker:aarch64. Builds devos50/qemu-ios
# (iPod touch 1G, arm-softmmu) against Termux's own libraries.
set -euxo pipefail

WS=/data/data/com.termux/files/home/ws
INSTALL_PREFIX="$PREFIX/opt/qemu-ios"

export DEBIAN_FRONTEND=noninteractive
APT="apt-get -y -o Dpkg::Options::=--force-confnew"
$APT update
$APT upgrade
$APT install x11-repo
$APT update
$APT install clang lld make ninja pkg-config python meson git binutils \
	glib libpixman sdl2 openssl zlib libandroid-shmem libandroid-glob

cd "$WS/src"
mkdir -p build
cd build

# clang 16+ turns these into hard errors; the 6.2-era fork code trips them.
EXTRA_CFLAGS="-Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion"
EXTRA_CFLAGS+=" -Wno-error=implicit-function-declaration -Wno-error=implicit-int"

../configure \
	--prefix="$INSTALL_PREFIX" \
	--cc=clang --cxx=clang++ --objcc=clang --host-cc=clang \
	--meson=meson \
	--with-git-submodules=ignore \
	--target-list=arm-softmmu \
	--without-default-features \
	--enable-sdl \
	--enable-vnc \
	--enable-fdt=internal \
	--disable-capstone \
	--disable-slirp \
	--disable-docs \
	--disable-werror \
	--extra-cflags="$EXTRA_CFLAGS" \
	--extra-ldflags="-lcrypto -landroid-shmem -landroid-glob -llog"

make -j"$(nproc)"
make install

cp "$WS/run-ipod.sh" "$INSTALL_PREFIX/bin/"
chmod +x "$INSTALL_PREFIX/bin/run-ipod.sh"
"$INSTALL_PREFIX/bin/qemu-system-arm" -machine help | grep -i ipod

mkdir -p "$WS/out"
tar -C "$PREFIX/opt" -cJf "$WS/out/qemu-ios-1g-termux-aarch64.tar.xz" qemu-ios
