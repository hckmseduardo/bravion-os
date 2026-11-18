ARG TARGETPLATFORM
FROM --platform=$TARGETPLATFORM debian@sha256:268fb24c39bca92d326dd83ea3abebe4a3f7751c804ffef23bb6d857dd343ff8
RUN printf 'Acquire::ForceIPv4 "true";\n' >/etc/apt/apt.conf.d/99-ipv4 \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential bison gawk texinfo python3 python3-bs4 wget curl ca-certificates \
    xz-utils file patch perl rsync git bc libssl-dev flex libelf-dev dosfstools \
    e2fsprogs fdisk kmod cpio qemu-system-arm qemu-system-x86 qemu-utils qemu-efi-aarch64 ovmf procps \
    libclang-14-dev libclang-common-14-dev libarchive-tools pkg-config zstd \
    python3-pip python3-setuptools python3-wheel libffi-dev libudev-dev \
 && printf 'precedence ::ffff:0:0/96 100\n' >>/etc/gai.conf
COPY . /workspace
CMD ["sleep", "infinity"]
