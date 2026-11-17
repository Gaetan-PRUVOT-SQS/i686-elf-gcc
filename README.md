# i686-elf-gcc

English · [Français](README.fr.md)

`i686-elf` (32-bit) and `x86_64-elf` (64-bit) cross-compilers for OS
development: GCC, binutils and libgcc. Two ways to install them:

- **download the Linux x86_64 binary** from the Releases, ready in a minute;
- **build it** with `build.sh`, for another machine or another target.

The repository also provides two check kernels: a 32-bit Multiboot kernel
that boots in QEMU, and a 64-bit kernel that checks the red-zone-free
libgcc.

| Component | Version |
|-----------|---------|
| GCC       | 15.3.0 (C only) |
| binutils  | 2.47 |
| libgcc    | the one from GCC 15.3.0; on x86_64, a regular one and a red-zone-free one |

## Why a cross-compiler

The distribution `gcc` targets Linux: it assumes a libc, system headers,
an ABI and an output format designed for user programs. For a kernel you
want a compiler that knows nothing about the host:

- no Linux headers or libraries sneak into the build;
- the code comes out as 32 or 64-bit ELF without stacking `-m32` and
  workaround options;
- `libgcc` is provided for the target: in 32 bits, a `uint64_t` division
  becomes a call to `__udivdi3`, which only libgcc can resolve;
- in 64 bits, a kernel builds with `-mno-red-zone`: an interrupt would
  overwrite the 128 bytes the ABI lets functions use below the stack
  pointer. `x86_64-elf-gcc` ships a libgcc built without the red zone as
  well, picked automatically by that option.

## Install the binary

For Linux x86_64 with glibc 2.38 or newer (Ubuntu 24.04+, Debian 13+,
Fedora 39+, Arch...). Each archive is about 42 MB, 175 to 180 MB once
extracted.

```sh
TARGET=x86_64-elf        # or i686-elf
NAME=$TARGET-gcc-15.3.0-binutils-2.47-linux-x86_64.tar.xz
URL=https://github.com/Gaetan-PRUVOT-SQS/i686-elf-gcc/releases/latest/download
curl -fLO "$URL/$NAME"
curl -fLO "$URL/$NAME.sha256"
sha256sum -c "$NAME.sha256"
mkdir -p ~/.local/opt
tar -C ~/.local/opt -xf "$NAME"
```

Then add the toolchain to the `PATH`, putting this line in `~/.bashrc`
or `~/.zshrc` to keep it:

```sh
export PATH="$HOME/.local/opt/x86_64-elf-gcc/bin:$HOME/.local/opt/i686-elf-gcc/bin:$PATH"
```

Check:

```sh
x86_64-elf-gcc --version
x86_64-elf-gcc -print-multi-lib     # must print no-red-zone;@mno-red-zone
i686-elf-gcc --version
```

The archives are relocatable: extract them anywhere else (`/opt`,
`~/tools`...), just put their `bin` folder in the `PATH`. Each one
contains:

```
$TARGET-gcc/
├── bin/                   $TARGET-gcc, $TARGET-ld, $TARGET-objdump...
├── libexec/gcc/           cc1 and the GCC internal tools
├── lib/gcc/$TARGET/       libgcc.a (and no-red-zone/ on x86_64), freestanding headers
├── $TARGET/               binutils under their short names (as, ld...)
└── share/licenses/        license texts of GCC, binutils and ISL
```

## Build from source

Pick this for another host architecture (ARM, macOS), an older glibc, or
to avoid depending on any third-party binary.

### Prerequisites

You need a host C/C++ compiler, `make`, `m4`, `curl`, `tar`, `xz` and
`bzip2`. GMP, MPFR, MPC and ISL do not need to be installed: the script
downloads them and GCC builds them along with itself.

```sh
sudo dnf install gcc gcc-c++ make m4 curl xz bzip2           # Fedora
sudo apt install build-essential m4 curl xz-utils bzip2      # Debian / Ubuntu
sudo pacman -S base-devel curl xz bzip2                      # Arch
```

Expect about 4 GB of free space during the build (sources and build
folders, removed at the end) and 175 to 180 MB per installed toolchain.

### Run the build

```sh
git clone https://github.com/Gaetan-PRUVOT-SQS/i686-elf-gcc.git
cd i686-elf-gcc
./build.sh                          # i686-elf
TARGET=x86_64-elf ./build.sh        # x86_64-elf, in the same prefix
export PATH="$HOME/.local/opt/cross/bin:$PATH"
```

By default everything installs in `~/.local/opt/cross`, without sudo. On
an 8-thread laptop (2019 Core i5), expect about 35 minutes per target,
download included.

For `x86_64-elf`, the script adds a second libgcc built with
`-mno-red-zone` (the OSDev wiki patch `t-x86_64-elf`, "Libgcc without red
zone") and stops if the patch does not apply.

The script checks the SHA-256 sum of every GNU archive before using it.
The archives stay in `src/`: a second run downloads nothing again.

### Options

Everything is set through environment variables:

| Variable   | Default                   | Role |
|------------|---------------------------|------|
| `TARGET`   | `i686-elf`                | GNU target (`i686-elf` or `x86_64-elf`) |
| `PREFIX`   | `~/.local/opt/cross`      | install folder |
| `JOBS`     | `nproc`                   | number of `make` jobs |
| `SRC_DIR`  | `./src`                   | downloaded archives and build folders |
| `MIRROR`   | `https://ftp.gnu.org/gnu` | GNU mirror (https required) |
| `LINK_DIR` | empty                     | if set, symlinks of the `$TARGET-*` binaries into this folder |
| `DESTDIR`  | empty                     | if set, installs into `$DESTDIR$PREFIX` (for an archive, no root) |

```sh
LINK_DIR=~/.local/bin ./build.sh        # binaries available without touching the PATH
PREFIX=/opt/cross ./build.sh            # writable folder
MIRROR=https://mirrors.kernel.org/gnu ./build.sh
./build.sh --help
```

## Test the toolchain

The tests live in the repository, so it must be cloned first.

### i686-elf

You need `qemu-system-i386` (package `qemu-system-x86`) and, optionally,
`grub-file` or `grub2-file` (package `grub-common` or `grub2-tools`).

```sh
cd test
make check
make check CROSS=$HOME/.local/opt/i686-elf-gcc/bin/i686-elf-
```

Expected output:

```
ELF32 OK
libgcc OK
multiboot OK
boot OK
```

`make check` builds the kernel with `-Wall -Wextra -Werror`, checks that
it is a 32-bit ELF, that `__udivdi3` comes from libgcc (64-bit division
in `kernel.c`) and that the Multiboot header is valid (skipped without
`grub-file`), then boots the kernel in QEMU, which writes `kmain OK` on
the COM1 serial port. Other targets: `make run`, `make debug` (gdb
attached at `kmain`), `make clean`.

### x86_64-elf

```sh
cd test/x86_64
make check
make check CROSS=$HOME/.local/opt/x86_64-elf-gcc/bin/x86_64-elf-
```

Expected output:

```
ELF64 OK
multilib no-red-zone OK
red-zone-free libgcc linked OK
libgcc OK
higher half OK
```

The kernel does a 128-bit division (`__udivti3`) and links with
`-mcmodel=kernel` at `0xffffffff80000000`. `make check` verifies the
64-bit ELF, the presence of the red-zone-free libgcc, that the link step
actually picked it, that the division comes from libgcc and that the
kernel sits at the top of memory. It is not booted: QEMU does not load a
64-bit ELF directly, you need a loader such as Limine.

## Use the toolchain in a project

In 32 bits:

```make
CC      = i686-elf-gcc
CFLAGS  = -std=gnu11 -ffreestanding -O2 -Wall -Wextra \
          -fno-stack-protector -fno-pic -mno-sse -mno-mmx -mno-80387
LDFLAGS = -T linker.ld -ffreestanding -nostdlib
LIBS    = -lgcc
```

In 64 bits:

```make
CC      = x86_64-elf-gcc
CFLAGS  = -std=gnu11 -ffreestanding -O2 -Wall -Wextra -fno-stack-protector \
          -fno-pic -mno-red-zone -mcmodel=kernel -mgeneral-regs-only
LDFLAGS = -T linker.ld -ffreestanding -nostdlib -mno-red-zone -mcmodel=kernel \
          -Wl,-z,max-page-size=0x1000
LIBS    = -lgcc
```

- `-ffreestanding`: no libc is assumed, only the freestanding headers
  (`stdint.h`, `stddef.h`, `stdbool.h`, `stdarg.h`, `limits.h`...) are
  available.
- `-nostdlib` then `-lgcc` at the end of the link line: everything is
  removed except libgcc, which the compiler may need at any time.
- `-mno-red-zone` at link time too: it is what makes the linker pick the
  red-zone-free libgcc.
- `-mcmodel=kernel`: kernel linked in the last 2 GiB of the address
  space (`0xffffffff80000000`).
- `-mno-sse -mno-mmx -mno-80387` or `-mgeneral-regs-only`: no
  floating-point instructions while the kernel does not save those
  registers.
- Link with `gcc` rather than `ld` directly, so it finds the right
  libgcc by itself.

The `test/` and `test/x86_64/` folders are a starting point.

## Repository contents

```
build.sh                        downloads, checks and builds binutils then GCC
release.sh                      produces a binary archive, its licenses and its sources
.github/workflows/release.yml   builds both archives and publishes the release of a tag
test/                           32-bit Multiboot kernel (boot.S, kernel.c, serial.c, linker.ld)
test/x86_64/                    64-bit check kernel for the red-zone-free libgcc
```

## Produce the archives

The Release archives are built by GitHub Actions: pushing a `v*` tag
runs `.github/workflows/release.yml`. For each target, on an Ubuntu 24.04
runner (about 17 minutes, both targets in parallel), it runs `release.sh`,
then publishes the release with both archives, their SHA-256 sums and the
sources. Run manually (Actions tab, "Run workflow"), it builds the
archives without publishing anything.

`release.sh` also works locally:

```sh
TARGET=x86_64-elf ./release.sh
```

- `build.sh` installs the toolchain with the `/opt/$TARGET-gcc` prefix
  inside a working folder (`DESTDIR`): no root, no container;
- source paths are rewritten (`-ffile-prefix-map`) and the binaries have
  no debug info left: no path from the machine remains;
- licenses are added, and the official source archives of everything
  that gets built (GCC, binutils, GMP, MPFR, MPC, ISL, gettext) are
  copied in and checked against their sums;
- the archive is extracted elsewhere, the script checks that no `$HOME`
  path is embedded, then runs the target kernel `make check` against
  that copy.

Result in `dist/$TARGET/`. The archive needs a glibc at least as recent
as the one on the machine that built it.

## Change version

Versions and their SHA-256 sums are at the top of `build.sh` (and in the
archive name of `release.sh`). To move to another version, fetch the
archive and its signature, check the signature with the GNU keyring, then
report the sum:

```sh
curl -fLO https://ftp.gnu.org/gnu/gcc/gcc-15.3.0/gcc-15.3.0.tar.xz
curl -fLO https://ftp.gnu.org/gnu/gcc/gcc-15.3.0/gcc-15.3.0.tar.xz.sig
curl -fLO https://ftp.gnu.org/gnu/gnu-keyring.gpg
gpgv --keyring ./gnu-keyring.gpg gcc-15.3.0.tar.xz.sig gcc-15.3.0.tar.xz
sha256sum gcc-15.3.0.tar.xz
```

Same thing for binutils in `https://ftp.gnu.org/gnu/binutils/`. GMP, MPFR,
MPC, ISL and gettext are checked by `contrib/download_prerequisites`,
which compares their SHA-512 sums with the ones shipped with GCC.

## Troubleshooting

- **`GLIBC_2.38 not found`** with the binary: the distribution is too
  old, build with `build.sh`.
- **`cannot execute binary file: Exec format error`**: the machine is not
  x86_64 (ARM, Apple Silicon...), build with `build.sh`.
- **`x86_64-elf-gcc: command not found`**: the `bin` folder is not in the
  `PATH` of the current shell. Reopen the terminal after editing
  `~/.bashrc`, or use `LINK_DIR` with `build.sh`.
- **`-print-multi-lib` without `no-red-zone`**: the `x86_64-elf` toolchain
  comes from somewhere else (distribution package, Homebrew). Rebuild it
  with `TARGET=x86_64-elf ./build.sh`.
- **`missing tools: ...`**: install the packages listed in the
  prerequisites.
- **`... corrupted, delete it and run again`**: download cut short or a
  mirror serving another file. Delete the archive in `src/` and run
  again.
- **Build very slow or killed**: the machine probably lacks RAM, run
  again with fewer jobs, for example `JOBS=2 ./build.sh`.
- **`undefined reference to __udivdi3`** (or `__udivti3` in 64 bits):
  `-lgcc` is missing or not at the end of the link command.
- **`boot KO`**: run `make run` to see the serial output, or `make debug`
  to follow the boot in gdb.

## License

The scripts and the test kernel code are released under the MIT license
(see `LICENSE`).

The binary archives in the Releases contain third-party software, under
their own licenses, whose texts are in `share/licenses/`:

- GCC and binutils: GPL v3 or later;
- libgcc: GPL v3 with the GCC Runtime Library Exception. A kernel linked
  with `-lgcc` therefore does not have to be under the GPL;
- GMP, MPFR and MPC (built into the compiler): LGPL v3 or later;
- ISL (built into the compiler): MIT.

The corresponding sources, unmodified official archives, are attached to
each Release.
