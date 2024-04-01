EAPI=8

DESCRIPTION="A video wallpaper program for wlroots based wayland compositors"
HOMEPAGE="https://github.com/GhostNaN/mpvpaper"

inherit meson git-r3

EGIT_REPO_URI="https://github.com/GhostNaN/mpvpaper.git"

case "${PV}" in
    9999)
        ;;
    *)
        EGIT_COMMIT="f65700a"
        SRC_URI=""
        KEYWORDS="~amd64"
esac

LICENSE="GPL-3"
SLOT="0"

RESTRICT="mirror test"

RDEPEND="
    media-video/mpv[libmpv]
    gui-libs/wlroots
"
DEPEND="${RDEPEND}"
