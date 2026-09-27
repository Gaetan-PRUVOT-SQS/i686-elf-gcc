#!/usr/bin/env bash
# Construit un cross-compilateur $TARGET (i686-elf par défaut) :
# binutils, gcc (C seulement) et libgcc, installés dans $PREFIX.
set -euo pipefail

BINUTILS=binutils-2.47
GCC=gcc-15.3.0
# Sommes des archives officielles, vérifiées contre les signatures GPG GNU.
BINUTILS_SHA256=154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff
GCC_SHA256=fa59c1beef8995f27c4d71c1df227587189315d3e6faff1bb4306e61b0c530eb

TARGET="${TARGET:-i686-elf}"
PREFIX="${PREFIX:-$HOME/.local/opt/cross}"
JOBS="${JOBS:-$(nproc)}"
MIRROR="${MIRROR:-https://ftp.gnu.org/gnu}"
LINK_DIR="${LINK_DIR:-}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${SRC_DIR:-$ROOT/src}"

die() { echo "build.sh: $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage : ./build.sh [-h]

Variables (valeur par défaut) :
  TARGET    cible GNU            ($TARGET)
  PREFIX    dossier d'install    ($PREFIX)
  JOBS      jobs make en //      ($JOBS)
  SRC_DIR   archives et build    ($SRC_DIR)
  MIRROR    miroir GNU, https    ($MIRROR)
  LINK_DIR  si défini, lien de chaque binaire \$TARGET-* dans ce dossier
EOF
}

case "${1:-}" in
	-h|--help) usage; exit 0 ;;
	"") ;;
	*) usage >&2; exit 2 ;;
esac

missing=()
for tool in curl tar xz bzip2 make gcc g++ m4 sha256sum sha512sum; do
	command -v "$tool" >/dev/null || missing+=("$tool")
done
[ ${#missing[@]} -eq 0 ] || die "outils manquants : ${missing[*]}"

# Télécharge une archive si besoin, puis vérifie sa somme dans tous les cas.
fetch() {
	local file=$1 url=$2 sum=$3
	if [ ! -f "$file" ]; then
		curl -fL --proto '=https' --tlsv1.2 -o "$file.part" "$url"
		mv "$file.part" "$file"
	fi
	echo "$sum  $file" | sha256sum -c --quiet - \
		|| die "$file corrompu, supprime-le puis relance"
}

mkdir -p "$SRC_DIR" "$PREFIX"
cd "$SRC_DIR"
fetch $BINUTILS.tar.xz "$MIRROR/binutils/$BINUTILS.tar.xz" $BINUTILS_SHA256
fetch $GCC.tar.xz "$MIRROR/gcc/$GCC/$GCC.tar.xz" $GCC_SHA256

# Extraction propre à chaque lancement : une extraction coupée laisserait un arbre incomplet.
rm -rf $BINUTILS $GCC build-binutils build-gcc
tar xf $BINUTILS.tar.xz
tar xf $GCC.tar.xz
# gmp, mpfr, mpc et isl sont compilés avec gcc (sommes sha512 vérifiées par le script).
(cd $GCC && ./contrib/download_prerequisites)

export PATH="$PREFIX/bin:$PATH"
mkdir build-binutils build-gcc

(cd build-binutils \
	&& ../$BINUTILS/configure --target="$TARGET" --prefix="$PREFIX" \
		--with-sysroot --disable-nls --disable-werror \
	&& make -j"$JOBS" MAKEINFO=true \
	&& make install MAKEINFO=true)

# --without-headers : pas de libc pour la cible, on reste en freestanding.
(cd build-gcc \
	&& ../$GCC/configure --target="$TARGET" --prefix="$PREFIX" \
		--disable-nls --enable-languages=c --without-headers --disable-multilib \
	&& make -j"$JOBS" all-gcc all-target-libgcc MAKEINFO=true \
	&& make install-gcc install-target-libgcc MAKEINFO=true)

rm -rf $BINUTILS $GCC build-binutils build-gcc

if [ -n "$LINK_DIR" ]; then
	mkdir -p "$LINK_DIR"
	ln -sf "$PREFIX/bin/$TARGET-"* "$LINK_DIR/"
fi

"$PREFIX/bin/$TARGET-gcc" --version | head -1
"$PREFIX/bin/$TARGET-ld" --version | head -1
echo "Toolchain prête dans $PREFIX/bin"
