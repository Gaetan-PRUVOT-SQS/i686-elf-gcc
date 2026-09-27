# i686-elf-gcc

Cross-compilateur `i686-elf` (GCC, binutils et libgcc) pour le développement
d'OS en 32 bits. Deux façons de l'installer :

- **télécharger le binaire** Linux x86_64 des Releases, prêt en une minute ;
- **le compiler** avec `build.sh`, pour une autre machine ou une autre cible.

Le dépôt fournit aussi un petit noyau Multiboot qui vérifie que la toolchain
produit un binaire qui démarre vraiment dans QEMU.

| Composant | Version |
|-----------|---------|
| GCC       | 15.3.0 (C uniquement) |
| binutils  | 2.47 |
| libgcc    | celle de GCC 15.3.0 |

## Pourquoi un cross-compilateur

Le `gcc` de la distribution vise Linux : il suppose une libc, des en-têtes
système, un ABI et un format de sortie pensés pour des programmes utilisateur.
Pour un noyau, on veut un compilateur qui ne sait rien de l'hôte. Avec
`i686-elf-gcc` :

- pas d'en-têtes ni de bibliothèques Linux qui se glissent dans le build ;
- le code est en ELF 32 bits sans avoir à empiler `-m32` et des options de
  contournement ;
- `libgcc` est fournie pour la cible, ce qui compte en 32 bits : une division
  `uint64_t` devient un appel à `__udivdi3`, que seule libgcc sait résoudre.

## Installer le binaire

Pour Linux x86_64 avec glibc 2.34 ou plus récente (Ubuntu 22.04+, Debian 12+,
Fedora 35+, RHEL 9+, Arch...). L'archive fait 42 Mo, 175 Mo une fois extraite.

```sh
NAME=i686-elf-gcc-15.3.0-binutils-2.47-linux-x86_64.tar.xz
URL=https://github.com/Gaetan-PRUVOT-SQS/i686-elf-gcc/releases/latest/download
curl -fLO "$URL/$NAME"
curl -fLO "$URL/$NAME.sha256"
sha256sum -c "$NAME.sha256"
mkdir -p ~/.local/opt
tar -C ~/.local/opt -xf "$NAME"
```

Puis ajouter la toolchain au `PATH`, en mettant cette ligne dans `~/.bashrc`
ou `~/.zshrc` pour la garder :

```sh
export PATH="$HOME/.local/opt/i686-elf-gcc/bin:$PATH"
```

Vérification :

```sh
i686-elf-gcc --version
i686-elf-ld --version
```

L'archive est relogeable : on peut l'extraire ailleurs (`/opt`, `~/tools`...),
il suffit de mettre son dossier `bin` dans le `PATH`. Elle contient :

```
i686-elf-gcc/
├── bin/                   i686-elf-gcc, i686-elf-ld, i686-elf-objdump...
├── libexec/gcc/           cc1 et les outils internes de GCC
├── lib/gcc/i686-elf/      libgcc.a et les en-têtes freestanding
├── i686-elf/              binutils sous leur nom court (as, ld...)
└── share/licenses/        textes des licences de GCC, binutils et ISL
```

## Compiler depuis les sources

À choisir pour une autre architecture hôte (ARM, macOS), une glibc plus
ancienne, une autre cible (`x86_64-elf`...) ou pour ne dépendre d'aucun binaire
tiers.

### Prérequis

Il faut un compilateur C/C++ hôte, `make`, `m4`, `curl`, `tar`, `xz` et `bzip2`.
GMP, MPFR, MPC et ISL n'ont pas besoin d'être installés : le script les
télécharge et GCC les compile avec lui.

```sh
sudo apt install build-essential m4 curl xz-utils bzip2      # Debian / Ubuntu
sudo dnf install gcc gcc-c++ make m4 curl xz bzip2           # Fedora
sudo pacman -S base-devel curl xz bzip2                      # Arch
```

Compter environ 4 Go libres pendant la compilation (sources et dossiers de
build, supprimés à la fin) et 175 Mo pour la toolchain installée.

### Lancer le build

```sh
git clone https://github.com/Gaetan-PRUVOT-SQS/i686-elf-gcc.git
cd i686-elf-gcc
./build.sh
export PATH="$HOME/.local/opt/cross/bin:$PATH"
```

Par défaut tout s'installe dans `~/.local/opt/cross`, sans sudo. Sur une
machine à 8 threads, le build prend environ 25 minutes, téléchargement compris.

Le script vérifie la somme SHA-256 de chaque archive GNU avant de l'utiliser.
Les archives restent dans `src/` : un second lancement ne retélécharge rien.

### Options

Tout se règle par variables d'environnement :

| Variable   | Défaut                    | Rôle |
|------------|---------------------------|------|
| `TARGET`   | `i686-elf`                | cible GNU (par exemple `x86_64-elf`) |
| `PREFIX`   | `~/.local/opt/cross`      | dossier d'installation |
| `JOBS`     | `nproc`                   | nombre de jobs `make` |
| `SRC_DIR`  | `./src`                   | archives téléchargées et dossiers de build |
| `MIRROR`   | `https://ftp.gnu.org/gnu` | miroir GNU (https obligatoire) |
| `LINK_DIR` | vide                      | si défini, liens symboliques des binaires `$TARGET-*` dans ce dossier |

```sh
LINK_DIR=~/.local/bin ./build.sh        # binaires accessibles sans toucher au PATH
PREFIX=/opt/cross ./build.sh            # dossier accessible en écriture
TARGET=x86_64-elf ./build.sh            # toolchain 64 bits dans le même préfixe
MIRROR=https://mirrors.kernel.org/gnu ./build.sh
./build.sh --help
```

Pour `x86_64-elf`, libgcc est compilée avec la red zone. Un noyau 64 bits qui
utilise `-mno-red-zone` doit alors construire une libgcc sans red zone
(voir la page « Libgcc without red zone » du wiki OSDev).

## Tester la toolchain

Les tests sont dans le dépôt, il faut donc l'avoir cloné. Ils demandent
`qemu-system-i386` (paquet `qemu-system-x86` sous Debian/Ubuntu) et,
en option, `grub-file` (paquet `grub-pc-bin` ou `grub2-tools`).

```sh
cd test
# toolchain dans le PATH
make check
# ou chemin explicite, par exemple pour le binaire des Releases
make check CROSS=$HOME/.local/opt/i686-elf-gcc/bin/i686-elf-
```

Sortie attendue :

```
ELF32 OK
libgcc OK
multiboot OK
boot OK
```

Ce que vérifie `make check` :

1. le noyau se compile et se lie avec `-Wall -Wextra -Werror` ;
2. le binaire est un ELF 32 bits ;
3. `__udivdi3` est bien lié depuis libgcc (division 64 bits dans `kernel.c`) ;
4. l'en-tête Multiboot est valide (sauté si `grub-file` est absent) ;
5. QEMU démarre le noyau, qui écrit `kmain OK` sur le port série COM1.

Autres cibles : `make run` (fenêtre QEMU, sortie série dans le terminal),
`make debug` (QEMU arrêté au démarrage et gdb branché sur `kmain`),
`make clean`.

## Utiliser la toolchain dans un projet

Options de base pour du code noyau :

```make
CC      = i686-elf-gcc
CFLAGS  = -std=gnu11 -ffreestanding -O2 -Wall -Wextra \
          -fno-stack-protector -fno-pic -mno-sse -mno-mmx -mno-80387
LDFLAGS = -T linker.ld -ffreestanding -nostdlib
LIBS    = -lgcc
```

- `-ffreestanding` : pas de libc supposée, seuls les en-têtes freestanding
  (`stdint.h`, `stddef.h`, `stdbool.h`, `stdarg.h`, `limits.h`...) sont
  disponibles.
- `-nostdlib` puis `-lgcc` à la fin de la ligne de lien : on retire tout sauf
  libgcc, dont le compilateur peut avoir besoin à tout moment.
- `-mno-sse -mno-mmx -mno-80387` : pas d'instructions flottantes tant que le
  noyau ne sauvegarde pas le contexte FPU.
- Lier avec `i686-elf-gcc` plutôt qu'avec `i686-elf-ld` directement, pour
  qu'il trouve libgcc tout seul.

Le dossier `test/` sert de point de départ : `boot.S` pose une pile et appelle
`kmain`, `linker.ld` charge le noyau à 1 Mio.

## Contenu du dépôt

```
build.sh        télécharge, vérifie et compile binutils puis GCC
release.sh      produit l'archive binaire publiée dans les Releases
test/           noyau Multiboot de contrôle (boot.S, kernel.c, linker.ld)
test/Makefile   build du noyau et contrôles (make check)
```

## Produire l'archive binaire

```sh
./release.sh
```

Le script demande Docker. Il lance `build.sh` dans un conteneur Ubuntu 22.04,
avec `/opt/i686-elf-gcc` comme préfixe, pour deux raisons :

- les binaires sont liés à une glibc ancienne (ils demandent la 2.34), ils
  tournent donc sur les distributions plus récentes ;
- aucun chemin de la machine qui construit ne se retrouve dans les binaires.

Il ajoute les textes des licences dans l'archive et copie dans `dist/sources/`
les archives sources officielles de tout ce qui est compilé (GCC, binutils,
GMP, MPFR, MPC, ISL, gettext), vérifiées par leurs sommes.

Ensuite, sur l'hôte, il extrait l'archive dans un autre dossier, contrôle les
licences, vérifie qu'aucun chemin du `$HOME` n'est embarqué, puis lance
`make check` avec cette copie. Ça prouve que l'archive fonctionne une fois
déplacée. Résultat : l'archive et sa somme SHA-256 dans `dist/`.

## Changer de version

Les versions et leurs sommes SHA-256 sont en tête de `build.sh` (et le nom de
l'archive dans `release.sh`). Pour passer à une autre version, récupérer
l'archive et sa signature, vérifier la signature avec le trousseau GNU, puis
reporter la somme :

```sh
curl -fLO https://ftp.gnu.org/gnu/gcc/gcc-15.3.0/gcc-15.3.0.tar.xz
curl -fLO https://ftp.gnu.org/gnu/gcc/gcc-15.3.0/gcc-15.3.0.tar.xz.sig
curl -fLO https://ftp.gnu.org/gnu/gnu-keyring.gpg
gpgv --keyring ./gnu-keyring.gpg gcc-15.3.0.tar.xz.sig gcc-15.3.0.tar.xz
sha256sum gcc-15.3.0.tar.xz
```

Même chose pour binutils dans `https://ftp.gnu.org/gnu/binutils/`. GMP, MPFR,
MPC et ISL sont vérifiés par `contrib/download_prerequisites`, qui compare leurs
sommes SHA-512 à celles livrées avec GCC.

## Dépannage

- **`GLIBC_2.34 not found`** avec le binaire : la distribution est trop
  ancienne, compiler avec `build.sh`.
- **`cannot execute binary file: Exec format error`** : la machine n'est pas en
  x86_64 (ARM, Apple Silicon...), compiler avec `build.sh`.
- **`i686-elf-gcc: command not found`** : le dossier `bin` n'est pas dans le
  `PATH` du shell courant. Rouvrir le terminal après avoir modifié
  `~/.bashrc`, ou utiliser `LINK_DIR` avec `build.sh`.
- **`outils manquants : ...`** : installer les paquets listés dans les
  prérequis.
- **`... corrompu, supprime-le puis relance`** : téléchargement coupé ou
  miroir qui sert un autre fichier. Supprimer l'archive dans `src/` et relancer.
- **Build très lent ou tué** : la machine manque sans doute de RAM, relancer
  avec moins de jobs, par exemple `JOBS=2 ./build.sh`.
- **`undefined reference to __udivdi3`** (ou `__moddi3`, `__divdi3`) : `-lgcc`
  manque ou n'est pas à la fin de la commande de lien.
- **`boot KO`** : lancer `make run` pour voir la sortie série, ou `make debug`
  pour suivre le démarrage dans gdb.

## Licence

Les scripts et le code du noyau de test sont sous licence MIT (voir `LICENSE`).

L'archive binaire des Releases contient des logiciels tiers, sous leurs propres
licences, dont les textes sont dans `share/licenses/` :

- GCC et binutils : GPL v3 ou ultérieure ;
- libgcc : GPL v3 avec la GCC Runtime Library Exception. Un noyau lié avec
  `-lgcc` n'a donc pas à être sous GPL ;
- GMP, MPFR et MPC (intégrés au compilateur) : LGPL v3 ou ultérieure ;
- ISL (intégré au compilateur) : MIT.

Les sources correspondantes, archives officielles non modifiées, sont jointes à
chaque Release.
