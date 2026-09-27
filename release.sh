#!/usr/bin/env bash
# Construit l'archive binaire Linux x86_64 dans un conteneur Ubuntu 22.04
# (glibc 2.35), puis la teste une fois extraite ailleurs. Résultat dans dist/.
set -euo pipefail

IMAGE=ubuntu:22.04
NAME=i686-elf-gcc-15.3.0-binutils-2.47-linux-x86_64
ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"

die() { echo "release.sh: $*" >&2; exit 1; }

command -v docker >/dev/null || die "docker introuvable"
rm -rf "$DIST"
mkdir -p "$DIST"

# Chemins neutres dans le conteneur (/work, /opt) : rien de la machine hôte
# ne se retrouve dans les binaires. Les fichiers créés sont rendus à l'hôte.
docker run --rm -v "$ROOT:/work" -w /work \
	-e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -e NAME="$NAME" \
	"$IMAGE" bash -euo pipefail -c '
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	apt-get install -y -qq --no-install-recommends \
		build-essential m4 curl ca-certificates xz-utils bzip2 >/dev/null
	trap "chown -R $HOST_UID:$HOST_GID /work/src /work/dist 2>/dev/null || true" EXIT
	PREFIX=/opt/i686-elf-gcc ./build.sh
	tar -C /opt --sort=name --owner=0 --group=0 --numeric-owner \
		-cJf "dist/$NAME.tar.xz" i686-elf-gcc
'

cd "$DIST"
sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256"

# Contrôles sur l'hôte : pas de chemin local embarqué, puis make check
# avec la toolchain extraite dans un autre dossier (archive relogeable).
mkdir check
tar -C check -xf "$NAME.tar.xz"
! grep -rqF "$HOME" check || die "chemin de l'hôte trouvé dans l'archive"
make -C "$ROOT/test" clean check CROSS="$DIST/check/i686-elf-gcc/bin/i686-elf-"
make -C "$ROOT/test" clean
rm -rf check

ls -lh "$DIST"
cat "$NAME.tar.xz.sha256"
