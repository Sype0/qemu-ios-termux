#!/data/data/com.termux/files/usr/bin/bash
# Boots iPhoneOS 1.0 on the emulated iPod touch 1G.
# Display: SDL when $DISPLAY is set (Termux:X11), otherwise VNC on 127.0.0.1:5900.
# Keys: H = Home button, P = Power button. Touch = mouse/finger on the screen.
set -euo pipefail

BIN="$(dirname "$(readlink -f "$0")")/qemu-system-arm"
DIR="${IPOD_DIR:-$HOME/ipod1g}"
REL=https://github.com/devos50/qemu-ios/releases/download/n45ap_v1

mkdir -p "$DIR"
cd "$DIR"

fetch() {
	[ -s "$1" ] && return
	curl -fL --retry 3 -o "$1.part" "$REL/$1"
	mv "$1.part" "$1"
}

fetch bootrom_s5l8900
fetch iboot_204_n45ap.bin
fetch nor_n45ap.bin
if [ ! -d nand ]; then
	fetch nand_n45ap.zip
	command -v unzip >/dev/null || pkg install -y unzip
	unzip -q nand_n45ap.zip
	rm -rf __MACOSX
	rm nand_n45ap.zip
fi

if [ -n "${DISPLAY:-}" ]; then
	DISP=(-display sdl)
else
	DISP=(-display vnc=127.0.0.1:0)
	echo "VNC: connect a viewer to 127.0.0.1:5900"
fi

# The emulated CPU runs on one host thread; keep it on the fastest cores so
# Android doesn't park it on the little ones.
PIN=()
if command -v taskset >/dev/null; then
	max=0 big=""
	for c in /sys/devices/system/cpu/cpu[0-9]*; do
		f=$(cat "$c/cpufreq/cpuinfo_max_freq" 2>/dev/null) || continue
		n=${c##*cpu}
		if [ "$f" -gt "$max" ]; then max=$f big=$n
		elif [ "$f" -eq "$max" ]; then big+=",$n"; fi
	done
	[ -n "$big" ] && PIN=(taskset -c "$big")
fi

exec "${PIN[@]}" "$BIN" \
	-M iPod-Touch,bootrom=bootrom_s5l8900,iboot=iboot_204_n45ap.bin,nand=nand \
	-cpu max -m 1G \
	-pflash nor_n45ap.bin \
	-serial mon:stdio \
	"${DISP[@]}" \
	"$@"
