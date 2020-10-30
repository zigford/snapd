# Copyright 1999-2020 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit bash-completion-r1 golang-base linux-info systemd

DESCRIPTION="Service and tools for management of snap packages"
HOMEPAGE="http://snapcraft.io/"

MY_S="${S}/src/github.com/snapcore/${PN}"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/snapcore/${PN}.git"
	EGIT_BRANCH="master"
	EGIT_CHECKOUT_DIR="${MY_S}"
	LIVE_DEPEND="dev-go/govendor"
	KEYWORDS=""
else
	inherit golang-vcs-snapshot
	SRC_URI="https://github.com/snapcore/${PN}/releases/download/${PV}/${PN}_${PV}.vendor.tar.xz -> ${P}.tar.xz"
	MY_PV=${PV}
	KEYWORDS="~amd64"
fi

LICENSE="GPL-3"
SLOT="0"
IUSE="systemd -doc +man"
RESTRICT="primaryuri strip"

PKG_LINGUAS="am bs ca cs da de el en_GB es fi fr gl hr ia id it ja lt ms nb oc pt_BR pt ru sv tr ug zh_CN"

CONFIG_CHECK="	CGROUPS \
		CGROUP_DEVICE \
		CGROUP_FREEZER \
		NAMESPACES \
		SQUASHFS \
		SQUASHFS_ZLIB \
		SQUASHFS_LZO \
		SQUASHFS_XZ \
		BLK_DEV_LOOP \
		SECCOMP \
		SECCOMP_FILTER \
		SECURITY_APPARMOR"

export GOPATH="${S}"

EGO_PN="github.com/snapcore/${PN}"

RDEPEND="!sys-apps/snap-confine
	sys-libs/libseccomp[static-libs]
	sys-apps/apparmor
	dev-libs/glib
	sys-fs/squashfs-tools:*[lzo]
	sec-policy/apparmor-profiles"

BDEPEND="${LIVE_DEPEND}
	>=dev-lang/go-1.9
	sys-fs/xfsprogs
	man? ( dev-python/docutils )
	sys-devel/gettext"

REQUIRED_USE="systemd"

src_unpack() {
	if [[ ${PV} == 9999 ]]
	then
		git-r3_src_unpack
		cd "${MY_S}"
		govendor sync || die "Cannot update vendor"
	else
		golang-vcs-snapshot_src_unpack
	fi
}

src_configure() {
	[[ ${PV} == 9999 ]] && MY_PV=$(date +%Y.%m.%d)
	debug-print-function $FUNCNAME "$@"

	cd "${MY_S}"
	./mkversion.sh "${PV}" 2> /dev/null
	cd cmd

	test -f configure.ac	# Sanity check, are we in the right directory?
	rm -f config.status
	autoreconf -i -f	# Regenerate the build system
	econf --libdir="/usr/$(get_libdir)" \
		--libexecdir="/usr/$(get_libdir)/snapd" \
		--enable-maintainer-mode \
		--disable-silent-rules \
		--enable-apparmor \
		--enable-nvidia-biarch
}

src_compile() {
	debug-print-function $FUNCNAME "$@"

	C="${MY_S}/cmd/"
	emake LIBEXECDIR="/usr/$(get_libdir)" -C "${MY_S}/data/"
	emake -C "${C}"

	# Generate snapd-apparmor systemd unit
	emake -C "${MY_S}/data/systemd"

	VX="-v -x" # or "-v -x" for verbosity
	for I in snapctl snap-exec snap snapd snap-seccomp snap-update-ns; do
		einfo "go building: ${I}"
		go install --ldflags '-extldflags "-Wl,--build-id=sha1"' \
		    $VX "github.com/snapcore/${PN}/cmd/${I}"
		test -f "${S}/bin/${I}" || die "Building ${I} failed"
	done
	if use man ; then
		"${S}/bin/snap" help --man > "${C}/snap/snap.1"
		rst2man.py "${C}/snap-confine/"snap-confine.{rst,1}
		rst2man.py "${C}/snap-discard-ns/"snap-discard-ns.{rst,5}
	fi

	for I in ${PKG_LINGUAS};do
		einfo "go building: ${I}"
		msgfmt -v --output-file="${MY_S}/po/${I}.mo" "${MY_S}/po/${I}.po"
	done

	# Generate apparmor profile
	sed -e "s,[@]LIBEXECDIR[@],/usr/$(get_libdir)/snapd,g" \
		-e 's,[@]SNAP_MOUNT_DIR[@],/snap,' \
		-e "/snap-device-helper/s/lib/$(get_libdir)/" \
		-e 's/libtinfo/libtinfo{,w}/' \
		"${C}/snap-confine/snap-confine.apparmor.in" \
		> "${C}/snap-confine/usr.lib.snapd.snap-confine.real"
}

src_install() {
	debug-print-function $FUNCNAME "$@"

	C="${MY_S}/cmd"
	DS="${MY_S}/data/systemd"

	if use man ; then
		doman \
			"${C}/snap-confine/snap-confine.1" \
			"${C}/snap/snap.1" \
			"${C}/snap-discard-ns/snap-discard-ns.5"
	fi

	systemd_dounit \
		"${DS}/snapd.service" \
		"${DS}/snapd.socket" \
		"${DS}/snapd.apparmor.service"

	cd "${MY_S}"
	dodir  \
		"/etc/profile.d" \
		"/usr/lib64/snapd" \
		"/usr/share/dbus-1/services" \
		"/usr/share/polkit-1/actions"
	keepdir	"/var/lib/snapd/apparmor/snap-confine"

	exeinto "/usr/$(get_libdir)/${PN}"

	# bash completions
	doexe \
			data/completion/bash/etelpmoc.sh \
			data/completion/bash/complete.sh

	# zsh completions
	insinto /usr/share/zsh/site-functions
	doins data/completion/zsh/_snap

	insinto "/usr/share/selinux/targeted/include/snapd/"
	doins \
			data/selinux/snappy.if \
			data/selinux/snappy.te \
			data/selinux/snappy.fc
	doexe "${C}"/decode-mount-opts/decode-mount-opts
	doexe "${C}"/snap-discard-ns/snap-discard-ns

	insinto "/usr/share/dbus-1/services/"
	doins data/dbus/io.snapcraft.Launcher.service
	insinto "/usr/share/polkit-1/actions/"
	doins data/polkit/io.snapcraft.snapd.policy
	doexe "${S}/bin"/snapd
	doexe "${S}/bin"/snap-exec
	doexe "${S}/bin"/snapctl
	doexe "${S}/bin"/snap-update-ns
	doexe "${S}/bin"/snap-seccomp ### missing libseccomp
	doexe "${MY_S}/cmd/snapd-apparmor/snapd-apparmor"

	insinto "/usr/$(get_libdir)/snapd/"
	doins "${MY_S}/data/info"
	insinto "/etc/profile.d/"
	doins data/env/snapd.sh
	insinto "/etc/apparmor.d"
	doins "${C}/snap-confine/usr.lib.snapd.snap-confine.real"
	
	if use doc ; then
		dodoc \
			"${MY_S}/packaging/ubuntu-16.04"/{copyright,changelog}
	fi

	dobin "${S}/bin"/{snap,snapctl}

	dobashcomp data/completion/bash/snap

	domo "${MY_S}/po"/*.mo

	doexe "${C}"/snap-confine/snap-device-helper
	exeopts -m 6755
	doexe "${C}"/snap-confine/snap-confine
	dosym "${EPREFIX}/usr/$(get_libdir)/snapd" /usr/lib/snapd
}

pkg_postinst() {
	CMDLINE=$(cat /proc/cmdline) 
	if [[ $CMDLINE == *"apparmor=1"* ]] && [[ $CMDLINE == *"security=apparmor"* ]]; then
	    apparmor_parser -r /etc/apparmor.d/usr.lib.snapd.snap-confine.real
		einfo "Enable snapd snapd.socket and snapd.apparmor service, then reload the apparmor service to start using snapd"
	else 
		einfo ""
		einfo "Apparmor needs to be enabled and configured as the default security"
		einfo "Ensure /etc/default/grub is updated to include:"
		einfo "GRUB_CMDLINE_LINIX_DEFAULT=\"apparmor=1 security=apparmor\""
		einfo "Then update grub, enable snapd, snapd.socket and snapd.apparmor and reboot"
		einfo ""
	fi
}
