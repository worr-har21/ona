# Android GKI 6.6 Kernel — KernelSU-Next + SUSFS + Docker/LXC

Custom kernel build based on `android15-6.6.102_r00` (AOSP GKI common kernel) with:

- **KernelSU-Next** (`rifsxd/KernelSU-Next`) — kernel-level root via syscall hooks
- **SUSFS** (`simonpunk/susfs4ksu`, branch `gki-android15-6.6`) — filesystem spoofing for root detection bypass
- **Docker/LXC support** — namespaces, cgroups, overlayfs, virtual networking

## Target

Generic GKI `arm64` image (`Image.gz`). Designed to replace the `boot.img` kernel on devices running Android 15 with a 6.6 GKI kernel (e.g. Pixel 10 / muzel once vendor sources are published).

## Repository layout

```
patches/
  0001-susfs-gki-android15-6.6.patch          # SUSFS hooks into kernel fs/include/security
  0002-kernelsu-next-susfs-integration.patch   # SUSFS wiring into KernelSU-Next driver
kernel/arch/arm64/configs/
  docker_lxc.fragment                          # Docker/LXC config fragment
  gki_ksu_defconfig                            # Combined defconfig reference
build_kernel.sh                                # Reproducible build script
```

## Build

### Prerequisites

```bash
sudo apt-get install -y \
  gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
  clang-18 lld-18 llvm-18 \
  libssl-dev libelf-dev bc bison flex python3 cpio pahole

sudo ln -sf /usr/bin/ld.lld-18 /usr/local/bin/ld.lld
sudo ln -sf /usr/bin/llvm-ar-18 /usr/local/bin/llvm-ar
sudo ln -sf /usr/bin/llvm-nm-18 /usr/local/bin/llvm-nm
sudo ln -sf /usr/bin/llvm-objcopy-18 /usr/local/bin/llvm-objcopy
sudo ln -sf /usr/bin/llvm-strip-18 /usr/local/bin/llvm-strip
```

### Clone sources

```bash
# Kernel
git clone --depth=1 --branch android15-6.6.102_r00 \
  https://android.googlesource.com/kernel/common kernel

# KernelSU-Next
cd kernel
curl -LSs https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh | bash -s next

# SUSFS
git clone --depth=1 --branch gki-android15-6.6 \
  https://gitlab.com/simonpunk/susfs4ksu.git ../susfs4ksu
```

### Apply patches

```bash
cd kernel

# SUSFS kernel patches
patch -p1 < ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-android15-6.6.patch
cp ../susfs4ksu/kernel_patches/fs/susfs.c fs/
cp ../susfs4ksu/kernel_patches/include/linux/susfs.h include/linux/
cp ../susfs4ksu/kernel_patches/include/linux/susfs_def.h include/linux/

# KernelSU-Next SUSFS integration
patch -p1 -d KernelSU-Next < ../patches/0002-kernelsu-next-susfs-integration.patch
```

### Configure

```bash
cd kernel
export ARCH=arm64 CC=clang-18 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1

make gki_defconfig
scripts/kconfig/merge_config.sh -m .config arch/arm64/configs/docker_lxc.fragment

# KernelSU + SUSFS options
cat >> .config << 'EOF'
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
EOF

make olddefconfig
```

### Build

```bash
./build_kernel.sh
# Output: out/Image.gz
```

## Flashing

Use `magiskboot` or `Android Image Kitchen` to repack the stock `boot.img` with the new `Image.gz`, then flash via fastboot:

```bash
fastboot flash boot boot_new.img
```

## Config highlights

| Feature | Config |
|---|---|
| KernelSU-Next | `CONFIG_KSU=y` |
| SUSFS | `CONFIG_KSU_SUSFS=y` |
| User namespaces | `CONFIG_USER_NS=y` |
| PID/Net/IPC/UTS namespaces | enabled |
| Overlayfs (container layers) | `CONFIG_OVERLAY_FS=y` |
| cgroup v1 pids/devices/memory | enabled |
| veth / bridge / macvlan | enabled |
| iptables / NAT / conntrack | enabled |
| Seccomp filters | `CONFIG_SECCOMP_FILTER=y` |
