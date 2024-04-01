EAPI=8

inherit meson git-r3

DESCRIPTION="A dynamic tiling Wayland compositor that doesn't sacrifice on its looks"
HOMEPAGE="https://github.com/hyprwm/Hyprland"
EGIT_REPO_URI="https://github.com/hyprwm/Hyprland.git"

S="${WORKDIR}/${P}"

KEYWORDS=""
LICENSE="BSD"
SLOT="0"
IUSE=""

WLROOTS_RDEPEND="
	>=dev-libs/libinput-1.14.0:=
	dev-libs/libliftoff
	>=dev-libs/wayland-1.22
	media-libs/libdisplay-info
	media-libs/libglvnd
	media-libs/mesa[egl(+),gles2]
	sys-apps/hwdata:=
	sys-auth/seatd:=
	>=x11-libs/libdrm-2.4.114
	x11-libs/libxkbcommon
	>=x11-libs/pixman-0.42.0
	virtual/libudev:=
"

WLROOTS_DEPEND="
	>=dev-libs/wayland-protocols-1.32
"

WLROOTS_BDEPEND="
	dev-util/glslang
	dev-util/wayland-scanner
"

RDEPEND="
	${WLROOTS_RDEPEND}
	dev-libs/glib:2
	x11-libs/cairo
	x11-libs/libdrm
	x11-libs/pango
"

DEPEND="
	${RDEPEND}
	${WLROOTS_DEPEND}
	dev-libs/hyprland-protocols
	>=dev-libs/wayland-protocols-1.25
"

BDEPEND="
	${WLROOTS_BDEPEND}
	app-misc/jq
	dev-util/cmake
	virtual/pkgconfig
"

src_prepare() {
	default
}

src_configure() {
	meson_src_configure
}

src_install() {
	meson_src_install --skip-subprojects wlroots
}
