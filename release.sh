#!/usr/bin/env bash
# Construit l'archive binaire Linux x86_64 dans un conteneur Ubuntu 22.04,
# y joint les licences, rassemble les sources (GPL), puis teste l'archive
# une fois extraite ailleurs. Résultat dans dist/.
set -euo pipefail

IMAGE=ubuntu:22.04
BINUTILS=binutils-2.47
GCC=gcc-15.3.0
NAME=i686-elf-gcc-15.3.0-binutils-2.47-linux-x86_64
INFRA=https://gcc.gnu.org/pub/gcc/infrastructure
ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"

die() { echo "release.sh: $*" >&2; exit 1; }

# Partie lancée dans le conteneur, depuis /work.
inside() {
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	apt-get install -y -qq --no-install-recommends \
		build-essential m4 curl ca-certificates xz-utils bzip2 >/dev/null
	trap 'chown -R "$HOST_UID:$HOST_GID" src dist 2>/dev/null || true' EXIT
	PREFIX=/opt/i686-elf-gcc ./build.sh

	# GMP, MPFR, MPC, ISL et gettext sont compilés avec GCC : on garde leurs
	# sources, avec la liste et les sommes SHA-512 fournies par GCC.
	tar -C src -xf src/$GCC.tar.xz --strip-components=2 $GCC/contrib/prerequisites.sha512
	local prereqs
	prereqs=$(awk '{print $2}' src/prerequisites.sha512)
	for f in $prereqs; do
		[ -f "src/$f" ] || curl -fsSL --proto '=https' -o "src/$f" "$INFRA/$f"
	done
	(cd src && sha512sum -c --quiet prerequisites.sha512)

	# Textes des licences livrés avec les binaires, comme le demande la GPL.
	local lic=/opt/i686-elf-gcc/share/licenses isl
	isl=$(printf '%s\n' $prereqs | grep '^isl-')
	mkdir -p $lic/gcc $lic/binutils $lic/isl
	tar -C $lic/gcc -xf src/$GCC.tar.xz --strip-components=1 --wildcards "$GCC/COPYING*"
	tar -C $lic/binutils -xf src/$BINUTILS.tar.xz --strip-components=1 --wildcards "$BINUTILS/COPYING*"
	tar -C $lic/isl -xf "src/$isl" --strip-components=1 "${isl%.tar.bz2}/LICENSE"

	tar -C /opt --sort=name --owner=0 --group=0 --numeric-owner \
		-cJf "dist/$NAME.tar.xz" i686-elf-gcc
	mkdir dist/sources
	cp src/$BINUTILS.tar.xz src/$GCC.tar.xz dist/sources/
	for f in $prereqs; do cp "src/$f" dist/sources/; done
}

if [ "${1:-}" = --inside ]; then
	inside
	exit 0
fi

command -v docker >/dev/null || die "docker introuvable"
rm -rf "$DIST"
mkdir -p "$DIST"

# Chemins neutres dans le conteneur (/work, /opt) : rien de la machine hôte
# ne se retrouve dans les binaires. Les fichiers créés sont rendus à l'hôte.
docker run --rm -v "$ROOT:/work" -w /work \
	-e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
	"$IMAGE" ./release.sh --inside

cd "$DIST"
sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256"

# Contrôles sur l'hôte : licences présentes, pas de chemin local embarqué,
# puis make check avec la toolchain extraite ailleurs (archive relogeable).
mkdir check
tar -C check -xf "$NAME.tar.xz"
for f in gcc/COPYING3 gcc/COPYING.RUNTIME binutils/COPYING3 isl/LICENSE; do
	[ -f "check/i686-elf-gcc/share/licenses/$f" ] || die "licence absente : $f"
done
! grep -rqF "$HOME" check || die "chemin de l'hôte trouvé dans l'archive"
make -C "$ROOT/test" clean check CROSS="$DIST/check/i686-elf-gcc/bin/i686-elf-"
make -C "$ROOT/test" clean
rm -rf check

ls -lh "$DIST" "$DIST/sources"
cat "$NAME.tar.xz.sha256"
