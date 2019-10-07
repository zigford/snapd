# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

EGO_PN="github.com/kardianos/govendor"

inherit golang-build golang-vcs-snapshot

ARCHIVE_URI="https://github.com/rsc/goversion/archive/v${PV}.tar.gz -> ${P}.tar.gz"
KEYWORDS="~amd64"

DESCRIPTION="Print version used to build Go executables"
HOMEPAGE="https://${EGO_PN}"
SRC_URI="https://${EGO_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
IUSE=""

src_compile() {
	pushd src/${EGO_PN} || die
	GOPATH="${S}" go build -o "${PN}" . || die
	popd || die
}

src_install() {
	dobin "src/${EGO_PN}/${PN}"
}
