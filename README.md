# i686-elf-gcc

Script pour construire un cross-compilateur `i686-elf` (GCC + binutils + libgcc)
destiné au développement d'OS en 32 bits, avec un petit noyau Multiboot qui
vérifie que la toolchain produit un binaire qui démarre dans QEMU.

| Composant | Version |
|-----------|---------|
| binutils  | 2.47    |
| GCC       | 15.3.0 (C uniquement) |
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

## Contenu

```
build.sh        télécharge, vérifie et compile binutils puis GCC
test/           noyau Multiboot de contrôle (boot.S, kernel.c, linker.ld)
test/Makefile   build du noyau et contrôles (make check)
```

## Prérequis

Il faut un compilateur C/C++ hôte, `make`, `m4`, `curl`, `tar`, `xz` et `bzip2`.
GMP, MPFR, MPC et ISL n'ont pas besoin d'être installés : le script les
télécharge et GCC les compile avec lui.

Debian / Ubuntu :

```sh
sudo apt install build-essential m4 curl xz-utils bzip2
```

Fedora :

```sh
sudo dnf install gcc gcc-c++ make m4 curl xz bzip2
```

Arch :

```sh
sudo pacman -S base-devel curl xz bzip2
```

Pour lancer les tests : `qemu-system-i386` (paquet `qemu-system-x86` sous
Debian/Ubuntu). `grub-file` (paquet `grub-pc-bin` ou `grub2-tools`) est
optionnel, il sert à vérifier l'en-tête Multiboot.

Compter environ 4 Go libres pendant la compilation (sources et dossiers de
build, supprimés à la fin) et 1,3 Go pour la toolchain installée.

## Installation

```sh
git clone https://github.com/Gaetan-PRUVOT-SQS/i686-elf-gcc.git
cd i686-elf-gcc
./build.sh
```

Par défaut tout s'installe dans `~/.local/opt/cross`, sans sudo. Il reste à
ajouter le dossier `bin` au `PATH` (dans `~/.bashrc` ou `~/.zshrc`) :

```sh
export PATH="$HOME/.local/opt/cross/bin:$PATH"
```

Ou bien laisser le script créer des liens dans un dossier déjà présent dans le
`PATH` :

```sh
LINK_DIR=~/.local/bin ./build.sh
```

Vérification rapide :

```sh
i686-elf-gcc --version
i686-elf-ld --version
```

Sur une machine à 8 threads, le build complet prend environ 25 minutes, téléchargement compris.

## Options

Tout se règle par variables d'environnement :

| Variable   | Défaut                  | Rôle |
|------------|-------------------------|------|
| `TARGET`   | `i686-elf`              | cible GNU (par exemple `x86_64-elf`) |
| `PREFIX`   | `~/.local/opt/cross`    | dossier d'installation |
| `JOBS`     | `nproc`                 | nombre de jobs `make` |
| `SRC_DIR`  | `./src`                 | archives téléchargées et dossiers de build |
| `MIRROR`   | `https://ftp.gnu.org/gnu` | miroir GNU (https obligatoire) |
| `LINK_DIR` | vide                    | si défini, liens symboliques des binaires `$TARGET-*` |

Exemples :

```sh
PREFIX=/opt/cross ./build.sh            # installation système (dossier accessible en écriture)
TARGET=x86_64-elf ./build.sh            # toolchain 64 bits dans le même préfixe
MIRROR=https://mirrors.kernel.org/gnu ./build.sh
./build.sh --help
```

Pour `x86_64-elf`, libgcc est compilée avec la red zone. Un noyau 64 bits qui
utilise `-mno-red-zone` doit alors construire une libgcc sans red zone
(voir la page « Libgcc without red zone » du wiki OSDev).

Les archives restent dans `src/` : un second lancement ne retélécharge rien,
il revérifie seulement les sommes.

## Tester la toolchain

```sh
cd test
make check
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
4. l'en-tête Multiboot est valide (si `grub-file` est installé) ;
5. QEMU démarre le noyau, qui écrit `kmain OK` sur le port série COM1.

Pour tester une toolchain qui n'est pas dans le `PATH` :

```sh
make check CROSS=/opt/cross/bin/i686-elf-
```

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

## Changer de version

Les versions et leurs sommes SHA-256 sont en tête de `build.sh`. Pour passer à
une autre version, récupérer l'archive et sa signature, vérifier la signature
avec le trousseau GNU, puis reporter la somme :

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

- **`outils manquants : ...`** : installer les paquets listés dans les
  prérequis.
- **`... corrompu, supprime-le puis relance`** : téléchargement coupé ou
  miroir qui sert un autre fichier. Supprimer l'archive dans `src/` et relancer.
- **`i686-elf-gcc: command not found`** : le dossier `bin` du préfixe n'est pas
  dans le `PATH` du shell courant. Rouvrir le terminal après avoir modifié
  `~/.bashrc`, ou utiliser `LINK_DIR`.
- **`undefined reference to __udivdi3`** (ou `__moddi3`, `__divdi3`) : `-lgcc`
  manque ou n'est pas à la fin de la commande de lien.
- **`boot KO`** : lancer `make run` pour voir la sortie série, ou `make debug`
  pour suivre le démarrage dans gdb.
- **Build très lent ou tué** : la machine manque sans doute de RAM, relancer
  avec moins de jobs, par exemple `JOBS=2 ./build.sh`.

## Licence

Les scripts et le code de ce dépôt sont sous licence MIT (voir `LICENSE`).
GCC et binutils ne sont pas inclus : ils sont téléchargés depuis les serveurs
GNU au moment du build et restent sous leurs propres licences (GPL).
