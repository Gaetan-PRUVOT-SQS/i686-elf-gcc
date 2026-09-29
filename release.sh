#!/usr/bin/env bash
# Construit l'archive binaire de $TARGET sur la machine de dev, y joint les
# licences et les sources (GPL), puis la teste une fois extraite ailleurs.
# Résultat dans dist/$TARGET/.
set -euo pipefail

BINUTILS=binutils-2.47
GCC=gcc-15.3.0
TARGET="${TARGET:-i686-elf}"
NAME=$TARGET-gcc-15.3.0-binutils-2.47-linux-x86_64
OPT=/opt/$TARGET-gcc
INFRA=https://gcc.gnu.org/pub/gcc/infrastructure
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
DIST="$ROOT/dist/$TARGET"
STAGE="$DIST/stage"

die() { echo "release.sh: $*" >&2; exit 1; }

case "$TARGET" in
	i686-elf) TESTS="$ROOT/test" ;;
	x86_64-elf) TESTS="$ROOT/test/x86_64" ;;
	*) die "cible non gérée : $TARGET (i686-elf ou x86_64-elf)" ;;
esac

rm -rf "$DIST"
mkdir -p "$STAGE"
# Préfixe neutre /opt/$TARGET-gcc installé dans $STAGE : pas de root,
# et aucun chemin de la machine dans les binaires.
TARGET="$TARGET" PREFIX="$OPT" DESTDIR="$STAGE" SRC_DIR="$SRC" "$ROOT/build.sh"

# GMP, MPFR, MPC, ISL et gettext sont compilés avec GCC : on garde leurs
# sources, avec la liste et les sommes SHA-512 fournies par GCC.
tar -C "$SRC" -xf "$SRC/$GCC.tar.xz" --strip-components=2 "$GCC/contrib/prerequisites.sha512"
mapfile -t prereqs < <(awk '{print $2}' "$SRC/prerequisites.sha512")
for f in "${prereqs[@]}"; do
	[ -f "$SRC/$f" ] || curl -fsSL --proto '=https' -o "$SRC/$f" "$INFRA/$f"
done
(cd "$SRC" && sha512sum -c --quiet prerequisites.sha512)

# Textes des licences livrés avec les binaires, comme le demande la GPL.
lic="$STAGE$OPT/share/licenses"
isl=$(printf '%s\n' "${prereqs[@]}" | grep '^isl-')
mkdir -p "$lic/gcc" "$lic/binutils" "$lic/isl"
tar -C "$lic/gcc" -xf "$SRC/$GCC.tar.xz" --strip-components=1 --wildcards "$GCC/COPYING*"
tar -C "$lic/binutils" -xf "$SRC/$BINUTILS.tar.xz" --strip-components=1 --wildcards "$BINUTILS/COPYING*"
tar -C "$lic/isl" -xf "$SRC/$isl" --strip-components=1 "${isl%.tar.bz2}/LICENSE"

tar -C "$STAGE/opt" --sort=name --owner=0 --group=0 --numeric-owner \
	-cJf "$DIST/$NAME.tar.xz" "$TARGET-gcc"
rm -rf "$STAGE"
mkdir "$DIST/sources"
cp "$SRC/$BINUTILS.tar.xz" "$SRC/$GCC.tar.xz" "$DIST/sources/"
for f in "${prereqs[@]}"; do cp "$SRC/$f" "$DIST/sources/"; done

cd "$DIST"
sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256"

# Contrôles : licences présentes, pas de chemin local embarqué, puis
# make check avec la toolchain extraite ailleurs (archive relogeable).
mkdir check
tar -C check -xf "$NAME.tar.xz"
for f in gcc/COPYING3 gcc/COPYING.RUNTIME binutils/COPYING3 isl/LICENSE; do
	[ -f "check/$TARGET-gcc/share/licenses/$f" ] || die "licence absente : $f"
done
! grep -rqF "$HOME" check || die "chemin de l'hôte trouvé dans l'archive"
make -C "$TESTS" clean check CROSS="$DIST/check/$TARGET-gcc/bin/$TARGET-"
make -C "$TESTS" clean
rm -rf check

ls -lh "$DIST" "$DIST/sources"
cat "$NAME.tar.xz.sha256"
