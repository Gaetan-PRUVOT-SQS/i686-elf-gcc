# i686-elf-gcc

Cross-compilateurs `i686-elf` (32 bits) et `x86_64-elf` (64 bits) pour le
développement d'OS : GCC, binutils et libgcc. Deux façons de les installer :

- **télécharger le binaire** Linux x86_64 des Releases, prêt en une minute ;
- **le compiler** avec `build.sh`, pour une autre machine ou une autre cible.

Le dépôt fournit aussi deux noyaux de contrôle : un noyau Multiboot 32 bits
qui démarre dans QEMU, et un noyau 64 bits qui vérifie la libgcc sans red
zone.

| Composant | Version |
|-----------|---------|
| GCC       | 15.3.0 (C uniquement) |
| binutils  | 2.47 |
| libgcc    | celle de GCC 15.3.0 ; en x86_64, une normale et une sans red zone |

## Pourquoi un cross-compilateur

Le `gcc` de la distribution vise Linux : il suppose une libc, des en-têtes
système, un ABI et un format de sortie pensés pour des programmes utilisateur.
Pour un noyau, on veut un compilateur qui ne sait rien de l'hôte :

- pas d'en-têtes ni de bibliothèques Linux qui se glissent dans le build ;
- le code est en ELF 32 ou 64 bits sans empiler `-m32` et des options de
  contournement ;
- `libgcc` est fournie pour la cible : en 32 bits, une division `uint64_t`
  devient un appel à `__udivdi3`, que seule libgcc sait résoudre ;
- en 64 bits, un noyau se compile avec `-mno-red-zone` : une interruption
  écraserait les 128 octets que l'ABI laisse aux fonctions sous le pointeur
  de pile. `x86_64-elf-gcc` fournit une libgcc compilée elle aussi sans red
  zone, choisie automatiquement avec cette option.

## Installer le binaire

Pour Linux x86_64 avec glibc 2.38 ou plus récente (Ubuntu 24.04+, Debian 13+,
Fedora 39+, Arch...). Chaque archive fait environ 42 Mo, 175 à 180 Mo une
fois extraite.

```sh
TARGET=x86_64-elf        # ou i686-elf
NAME=$TARGET-gcc-15.3.0-binutils-2.47-linux-x86_64.tar.xz
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
export PATH="$HOME/.local/opt/x86_64-elf-gcc/bin:$HOME/.local/opt/i686-elf-gcc/bin:$PATH"
```

Vérification :

```sh
x86_64-elf-gcc --version
x86_64-elf-gcc -print-multi-lib     # doit afficher no-red-zone;@mno-red-zone
i686-elf-gcc --version
```

Les archives sont relogeables : on peut les extraire ailleurs (`/opt`,
`~/tools`...), il suffit de mettre leur dossier `bin` dans le `PATH`. Chacune
contient :

```
$TARGET-gcc/
├── bin/                   $TARGET-gcc, $TARGET-ld, $TARGET-objdump...
├── libexec/gcc/           cc1 et les outils internes de GCC
├── lib/gcc/$TARGET/       libgcc.a (et no-red-zone/ en x86_64), en-têtes freestanding
├── $TARGET/               binutils sous leur nom court (as, ld...)
└── share/licenses/        textes des licences de GCC, binutils et ISL
```

## Compiler depuis les sources

À choisir pour une autre architecture hôte (ARM, macOS), une glibc plus
ancienne ou pour ne dépendre d'aucun binaire tiers.

### Prérequis

Il faut un compilateur C/C++ hôte, `make`, `m4`, `curl`, `tar`, `xz` et `bzip2`.
GMP, MPFR, MPC et ISL n'ont pas besoin d'être installés : le script les
télécharge et GCC les compile avec lui.

```sh
sudo dnf install gcc gcc-c++ make m4 curl xz bzip2           # Fedora
sudo apt install build-essential m4 curl xz-utils bzip2      # Debian / Ubuntu
sudo pacman -S base-devel curl xz bzip2                      # Arch
```

Compter environ 4 Go libres pendant la compilation (sources et dossiers de
build, supprimés à la fin) et 175 à 180 Mo par toolchain installée.

### Lancer le build

```sh
git clone https://github.com/Gaetan-PRUVOT-SQS/i686-elf-gcc.git
cd i686-elf-gcc
./build.sh                          # i686-elf
TARGET=x86_64-elf ./build.sh        # x86_64-elf, dans le même préfixe
export PATH="$HOME/.local/opt/cross/bin:$PATH"
```

Par défaut tout s'installe dans `~/.local/opt/cross`, sans sudo. Sur un
portable à 8 threads (Core i5 de 2019), comptez environ 35 minutes par cible,
téléchargement compris.

Pour `x86_64-elf`, le script ajoute une seconde libgcc compilée avec
`-mno-red-zone` (correctif `t-x86_64-elf` du wiki OSDev, « Libgcc without red
zone ») et s'arrête si le correctif ne s'applique pas.

Le script vérifie la somme SHA-256 de chaque archive GNU avant de l'utiliser.
Les archives restent dans `src/` : un second lancement ne retélécharge rien.

### Options

Tout se règle par variables d'environnement :

| Variable   | Défaut                    | Rôle |
|------------|---------------------------|------|
| `TARGET`   | `i686-elf`                | cible GNU (`i686-elf` ou `x86_64-elf`) |
| `PREFIX`   | `~/.local/opt/cross`      | dossier d'installation |
| `JOBS`     | `nproc`                   | nombre de jobs `make` |
| `SRC_DIR`  | `./src`                   | archives téléchargées et dossiers de build |
| `MIRROR`   | `https://ftp.gnu.org/gnu` | miroir GNU (https obligatoire) |
| `LINK_DIR` | vide                      | si défini, liens symboliques des binaires `$TARGET-*` dans ce dossier |
| `DESTDIR`  | vide                      | si défini, installe dans `$DESTDIR$PREFIX` (pour une archive, sans root) |

```sh
LINK_DIR=~/.local/bin ./build.sh        # binaires accessibles sans toucher au PATH
PREFIX=/opt/cross ./build.sh            # dossier accessible en écriture
MIRROR=https://mirrors.kernel.org/gnu ./build.sh
./build.sh --help
```

## Tester la toolchain

Les tests sont dans le dépôt, il faut donc l'avoir cloné.

### i686-elf

Il faut `qemu-system-i386` (paquet `qemu-system-x86`) et, en option,
`grub-file` ou `grub2-file` (paquet `grub-common` ou `grub2-tools`).

```sh
cd test
make check
make check CROSS=$HOME/.local/opt/i686-elf-gcc/bin/i686-elf-
```

Sortie attendue :

```
ELF32 OK
libgcc OK
multiboot OK
boot OK
```

`make check` compile le noyau avec `-Wall -Wextra -Werror`, vérifie que c'est
un ELF 32 bits, que `__udivdi3` vient de libgcc (division 64 bits dans
`kernel.c`) et que l'en-tête Multiboot est valide (sauté sans `grub-file`),
puis démarre le noyau dans QEMU, qui écrit `kmain OK` sur le port série COM1.
Autres cibles : `make run`, `make debug` (gdb branché sur `kmain`),
`make clean`.

### x86_64-elf

```sh
cd test/x86_64
make check
make check CROSS=$HOME/.local/opt/x86_64-elf-gcc/bin/x86_64-elf-
```

Sortie attendue :

```
ELF64 OK
multilib no-red-zone OK
libgcc sans red zone liée OK
libgcc OK
higher half OK
```

Le noyau fait une division 128 bits (`__udivti3`) et se lie en
`-mcmodel=kernel` à `0xffffffff80000000`. `make check` vérifie l'ELF 64 bits,
la présence de la libgcc sans red zone, que le lien l'a bien choisie, que la
division vient de libgcc et que le noyau est en haut de la mémoire. Il n'est
pas démarré : QEMU ne charge pas directement un ELF 64 bits, il faut un
chargeur comme Limine.

## Utiliser la toolchain dans un projet

En 32 bits :

```make
CC      = i686-elf-gcc
CFLAGS  = -std=gnu11 -ffreestanding -O2 -Wall -Wextra \
          -fno-stack-protector -fno-pic -mno-sse -mno-mmx -mno-80387
LDFLAGS = -T linker.ld -ffreestanding -nostdlib
LIBS    = -lgcc
```

En 64 bits :

```make
CC      = x86_64-elf-gcc
CFLAGS  = -std=gnu11 -ffreestanding -O2 -Wall -Wextra -fno-stack-protector \
          -fno-pic -mno-red-zone -mcmodel=kernel -mgeneral-regs-only
LDFLAGS = -T linker.ld -ffreestanding -nostdlib -mno-red-zone -mcmodel=kernel \
          -Wl,-z,max-page-size=0x1000
LIBS    = -lgcc
```

- `-ffreestanding` : pas de libc supposée, seuls les en-têtes freestanding
  (`stdint.h`, `stddef.h`, `stdbool.h`, `stdarg.h`, `limits.h`...) sont
  disponibles.
- `-nostdlib` puis `-lgcc` à la fin de la ligne de lien : on retire tout sauf
  libgcc, dont le compilateur peut avoir besoin à tout moment.
- `-mno-red-zone` aussi au lien : c'est lui qui fait choisir la libgcc sans
  red zone.
- `-mcmodel=kernel` : noyau lié dans les 2 derniers Gio de l'espace
  d'adresses (`0xffffffff80000000`).
- `-mno-sse -mno-mmx -mno-80387` ou `-mgeneral-regs-only` : pas
  d'instructions flottantes tant que le noyau ne sauvegarde pas ces registres.
- Lier avec `gcc` plutôt qu'avec `ld` directement, pour qu'il trouve la bonne
  libgcc tout seul.

Les dossiers `test/` et `test/x86_64/` servent de point de départ.

## Contenu du dépôt

```
build.sh                        télécharge, vérifie et compile binutils puis GCC
release.sh                      produit une archive binaire, ses licences et ses sources
.github/workflows/release.yml   construit les deux archives et publie la release d'un tag
test/                           noyau Multiboot 32 bits (boot.S, kernel.c, serial.c, linker.ld)
test/x86_64/                    noyau 64 bits de contrôle de la libgcc sans red zone
```

## Produire les archives

Les archives des Releases sont construites par GitHub Actions : pousser un tag
`v*` lance `.github/workflows/release.yml`. Pour chaque cible, sur un runner
Ubuntu 24.04 (environ 17 minutes, les deux cibles en parallèle), il lance
`release.sh`, puis publie la release avec les deux archives, leurs sommes
SHA-256 et les sources. Lancé à la main (onglet
Actions, « Run workflow »), il construit les archives sans rien publier.

`release.sh` marche aussi en local :

```sh
TARGET=x86_64-elf ./release.sh
```

- `build.sh` installe la toolchain avec le préfixe `/opt/$TARGET-gcc` dans un
  dossier de travail (`DESTDIR`) : ni root ni conteneur ;
- les chemins des sources sont réécrits (`-ffile-prefix-map`) et les binaires
  n'ont plus d'infos de debug : aucun chemin de la machine ne reste ;
- les licences sont ajoutées, les archives sources officielles de tout ce qui
  est compilé (GCC, binutils, GMP, MPFR, MPC, ISL, gettext) sont copiées et
  vérifiées par leurs sommes ;
- l'archive est extraite ailleurs, le script vérifie qu'aucun chemin du
  `$HOME` n'est embarqué, puis lance `make check` du noyau de la cible avec
  cette copie.

Résultat dans `dist/$TARGET/`. L'archive demande une glibc au moins aussi
récente que celle de la machine qui l'a construite.

## Changer de version

Les versions et leurs sommes SHA-256 sont en tête de `build.sh` (et dans le
nom de l'archive de `release.sh`). Pour passer à une autre version, récupérer
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
MPC, ISL et gettext sont vérifiés par `contrib/download_prerequisites`, qui
compare leurs sommes SHA-512 à celles livrées avec GCC.

## Dépannage

- **`GLIBC_2.38 not found`** avec le binaire : la distribution est trop
  ancienne, compiler avec `build.sh`.
- **`cannot execute binary file: Exec format error`** : la machine n'est pas en
  x86_64 (ARM, Apple Silicon...), compiler avec `build.sh`.
- **`x86_64-elf-gcc: command not found`** : le dossier `bin` n'est pas dans le
  `PATH` du shell courant. Rouvrir le terminal après avoir modifié
  `~/.bashrc`, ou utiliser `LINK_DIR` avec `build.sh`.
- **`-print-multi-lib` sans `no-red-zone`** : la toolchain `x86_64-elf` vient
  d'ailleurs (paquet de distribution, Homebrew). La reconstruire avec
  `TARGET=x86_64-elf ./build.sh`.
- **`outils manquants : ...`** : installer les paquets listés dans les
  prérequis.
- **`... corrompu, supprime-le puis relance`** : téléchargement coupé ou
  miroir qui sert un autre fichier. Supprimer l'archive dans `src/` et relancer.
- **Build très lent ou tué** : la machine manque sans doute de RAM, relancer
  avec moins de jobs, par exemple `JOBS=2 ./build.sh`.
- **`undefined reference to __udivdi3`** (ou `__udivti3` en 64 bits) :
  `-lgcc` manque ou n'est pas à la fin de la commande de lien.
- **`boot KO`** : lancer `make run` pour voir la sortie série, ou `make debug`
  pour suivre le démarrage dans gdb.

## Licence

Les scripts et le code des noyaux de test sont sous licence MIT (voir
`LICENSE`).

Les archives binaires des Releases contiennent des logiciels tiers, sous leurs
propres licences, dont les textes sont dans `share/licenses/` :

- GCC et binutils : GPL v3 ou ultérieure ;
- libgcc : GPL v3 avec la GCC Runtime Library Exception. Un noyau lié avec
  `-lgcc` n'a donc pas à être sous GPL ;
- GMP, MPFR et MPC (intégrés au compilateur) : LGPL v3 ou ultérieure ;
- ISL (intégré au compilateur) : MIT.

Les sources correspondantes, archives officielles non modifiées, sont jointes à
chaque Release.
