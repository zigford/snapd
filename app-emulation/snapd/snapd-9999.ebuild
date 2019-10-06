# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit bash-completion-r1 golang-base linux-info systemd git-r3

DESCRIPTION="Service and tools for management of snap packages"
HOMEPAGE="http://snapcraft.io/"
MY_S="${S}/src/github.com/snapcore/${PN}"
EGIT_REPO_URI="https://github.com/snapcore/${PN}.git"
EGIT_BRANCH="master"
EGIT_CHECKOUT_DIR="${MY_S}"
EGIT_SUBMODULES=( '*' )

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
IUSE="systemd"
RESTRICT="primaryuri"

EGO_VENDOR=(
	"github.com/coreos/go-systemd 39ca1b05acc7ad1220e09f133283b8859a8b71ab"
	"github.com/godbus/dbus 4481cbc300e2df0c0b3cecc18b6c16c6c0bb885d"
	"github.com/gorilla/mux d83b6ffe499a29cc05fc977988d0392851779620"
	"github.com/jessevdk/go-flags 7309ec74f752d05ce2c62b8fd5755c4a2e3913cb"
	"github.com/juju/ratelimit 59fac5042749a5afb9af70e813da1dd5474f0167"
	"github.com/kr/pretty 73f6ac0b30a98e433b289500d779f50c1a6f0712"
	"github.com/kr/text e2ffdb16a802fe2bb95e2e35ff34f0e53aeef34f"
	"github.com/mvo5/goconfigparser 26426272dda20cc76aa1fa44286dc743d2972fe8"
	"github.com/mvo5/libseccomp-golang f4de83b52afb3c19190eb65cc92429feaaf0e8b6"
	"github.com/snapcore/bolt 9eca199504ee1299394669820724322b5bfc070a"
	"github.com/snapcore/go-gettext 6598fb28bb07cb32298324b4958677c2f00cacd9"
	"github.com/snapcore/squashfuse 319f6d41a0419465a55d9dcb848d2408b97764f9"
	"golang.org/x/crypto 5ef0053f77724838734b6945dd364d3847e5de1d github.com/golang/crypto"
	"golang.org/x/crypto a19fa444682e099bed1a53260e1d755754cd098a github.com/golang/crypto"
	"golang.org/x/net c81e7f25cb61200d8bf0ae971a0bac8cb638d5bc github.com/golang/net"
	"gopkg.in/check.v1 788fd78401277ebd861206a03c884797c6ec5541 github.com/go-check/check"
	"gopkg.in/macaroon.v1 ab3940c6c16510a850e1c2dd628b919f0f3f1464 github.com/go-macaroon/macaroon"
	"gopkg.in/mgo.v2 3f83fa5005286a7fe593b055f0d7771a7dce4655 github.com/go-mgo/mgo"
	"gopkg.in/retry.v1 c09f6b86ba4d5d2cf5bdf0665364aec9fd4815db github.com/go-retry/retry"
	"gopkg.in/tomb.v2 d5d1b5820637886def9eef33e03a27a9f166942c github.com/go-tomb/tomb"
	"gopkg.in/tylerb/graceful.v1 50a48b6e73fcc75b45e22c05b79629a67c79e938 github.com/tylerb/graceful"
	"gopkg.in/yaml.v2 86f5ed62f8a0ee96bd888d2efdfd6d4fb100a4eb github.com/go-yaml/yaml" )

inherit golang-vcs-snapshot
SRC_URI="${EGO_VENDOR_URI}"

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

export GOPATH="${S}/${PN}"

EGO_PN="github.com/snapcore/${PN}"

RDEPEND="!sys-apps/snap-confine
	sys-libs/libseccomp[static-libs]
	sys-apps/apparmor
	dev-libs/glib
	sys-fs/squashfs-tools:*
	sec-policy/apparmor-profiles"
DEPEND="${RDEPEND}
	>=dev-lang/go-1.9
	dev-python/docutils
	sys-devel/gettext
	sys-fs/xfsprogs
	app-misc/jq"

REQUIRED_USE="systemd"

src_unpack() {
	git-r3_src_unpack
#	EGO_VENDOR=$(
#	    jq -r '.package | .[] | .path + " " + .revision' \
#			"${MY_S}/vendor/vendor.json" |
#			tail -n +2
#	)
	golang-vcs-snapshot_src_unpack
}
src_configure() {
	debug-print-function $FUNCNAME "$@"

	cd "${MY_S}/cmd/"
	cat <<EOF > "${MY_S}/cmd/version_generated.go"
package cmd

func init() {
        Version = "$(date +%Y.%m.%d)"
}
EOF
	echo "$(date +%Y.%m.%d)" > "${MY_S}/cmd/VERSION"
	echo "VERSION=$(date +%Y.%m.%d)" > "${MY_S}/data/info"

	test -f configure.ac	# Sanity check, are we in the right directory?
	rm -f config.status
	autoreconf -i -f	# Regenerate the build system
	econf --libdir="/usr/$(get_libdir)" \
		--libexecdir="/usr/$(get_libdir)/snapd" \
		--enable-maintainer-mode \
		--disable-silent-rules \
		--enable-apparmor
}

src_compile() {
	debug-print-function $FUNCNAME "$@"

	C="${MY_S}/cmd/"
	emake LIBEXECDIR="/usr/$(get_libdir)" -C "${MY_S}/data/"
	emake -C "${C}"

	# Generate snapd-apparmor systemd unit
	emake -C "${MY_S}/data/systemd"

	export GOPATH="${S}/"
	VX="-v -x" # or "-v -x" for verbosity
	for I in snapctl snap-exec snap snapd snap-seccomp snap-update-ns; do
		einfo "go building: ${I}"
		go install --ldflags '-extldflags "-Wl,--build-id=sha1"' \
		    $VX "github.com/snapcore/${PN}/cmd/${I}"
		test -f "${S}/bin/${I}" || die "Building ${I} failed"
	done
	"${S}/bin/snap" help --man > "${C}/snap/snap.1"
	rst2man.py "${C}/snap-confine/"snap-confine.{rst,1}
	rst2man.py "${C}/snap-discard-ns/"snap-discard-ns.{rst,5}

	for I in ${PKG_LINGUAS};do
		einfo "go building: ${I}"
		msgfmt -v --output-file="${MY_S}/po/${I}.mo" "${MY_S}/po/${I}.po"
	done

	# Generate apparmor profile
	sed -e "s,[@]LIBEXECDIR[@],/usr/$(get_libdir)/snapd,g" \
		-e 's,[@]SNAP_MOUNT_DIR[@],/snap,' \
		-e "/snap-device-helper/s/lib/$(get_libdir)/" \
		"${C}/snap-confine/snap-confine.apparmor.in" \
		> "${C}/snap-confine/usr.lib.snapd.snap-confine.real"
}

src_install() {
	debug-print-function $FUNCNAME "$@"

	C="${MY_S}/cmd"
	DS="${MY_S}/data/systemd"

	doman \
		"${C}/snap-confine/snap-confine.1" \
		"${C}/snap/snap.1" \
		"${C}/snap-discard-ns/snap-discard-ns.5"

	systemd_dounit \
		"${DS}/snapd.service" \
		"${DS}/snapd.socket" \
		"${DS}/snapd.apparmor.service"

	cd "${MY_S}"
	dodir  \
		"/etc/profile.d" \
		"/usr/lib64/snapd" \
		"/usr/share/dbus-1/services" \
		"/usr/share/polkit-1/actions" \
		"/var/lib/snapd/apparmor/snap-confine"

	exeinto "/usr/$(get_libdir)/${PN}"
	doexe \
			data/completion/etelpmoc.sh \
			data/completion/complete.sh
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
	
	dodoc	"${MY_S}/packaging/ubuntu-14.04"/copyright \
		"${MY_S}/packaging/ubuntu-16.04"/changelog

	dobin "${S}/bin"/{snap,snapctl}

	dobashcomp data/completion/snap

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
