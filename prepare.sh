set -eux; \
	apt-get update; \
	apt-get install -y \
		bzip2 \
		curl \
		gcc \
		gnupg dirmngr \
		make \
		patch \
		bc \
		cpio \
		dpkg-dev \
		file \
		g++ \
		perl \
		python3 \
		rsync \
		unzip \
		wget \
	; \
	rm -rf /var/lib/apt/lists/*

gpg --batch --keyserver keyserver.ubuntu.com --recv-keys AB07D806D2CE741FB886EE50B025BA8B59C36319
BUILDROOT_VERSION=2022.02.1

set -eux; \
	tarball="buildroot-${BUILDROOT_VERSION}.tar.xz"; \
	curl -fL -o buildroot.tar.xz "https://buildroot.org/downloads/$tarball"; \
	curl -fL -o buildroot.tar.xz.sign "https://buildroot.org/downloads/$tarball.sign"; \
	gpg --batch --decrypt --output buildroot.tar.xz.txt buildroot.tar.xz.sign; \
	awk '$1 == "SHA1:" && $2 ~ /^[0-9a-f]+$/ && $3 == "'"$tarball"'" { print $2, "*buildroot.tar.xz" }' buildroot.tar.xz.txt > buildroot.tar.xz.sha1; \
	test -s buildroot.tar.xz.sha1; \
	sha1sum -c buildroot.tar.xz.sha1; \
	mkdir -p /usr/src/buildroot; \
	tar -xf buildroot.tar.xz -C /usr/src/buildroot --strip-components 1; \
	rm buildroot.tar.xz*

set -eux; \
	\
	cd /usr/src/buildroot; \
	\
	setConfs='
		BR2_STATIC_LIBS=y
		BR2_TOOLCHAIN_BUILDROOT_UCLIBC=y
	'; \
	\
	unsetConfs='
		BR2_SHARED_LIBS
	'; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	case "$dpkgArch" in \
		amd64) \
			setConfs="$setConfs
				BR2_x86_64=y
			"; \
			;; \
			\
		arm64) \
			setConfs="$setConfs
				BR2_aarch64=y
			"; \
			;; \
			\
		armel) \
			setConfs="$setConfs
				BR2_arm=y
				BR2_arm926t=y
				BR2_ARM_EABI=y
				BR2_ARM_INSTRUCTIONS_THUMB=y
				BR2_ARM_SOFT_FLOAT=y
			"; \
			;; \
			\
		armhf) \
			setConfs="$setConfs
				BR2_arm=y
				BR2_cortex_a9=y
				BR2_ARM_EABIHF=y
				BR2_ARM_ENABLE_VFP=y
				BR2_ARM_FPU_VFPV3D16=y
				BR2_ARM_INSTRUCTIONS_THUMB2=y
			"; \
			unsetConfs="$unsetConfs BR2_ARM_SOFT_FLOAT"; \
			;; \
			\
		i386) \
			setConfs="$setConfs
				BR2_i386=y
			"; \
			;; \
			\
		mips64el) \
			setConfs="$setConfs
				BR2_mips64el=y
				BR2_mips_64r2=y
				BR2_MIPS_NABI64=y
			"; \
			unsetConfs="$unsetConfs
				BR2_MIPS_SOFT_FLOAT
			"; \
			;; \
			\
		riscv64) \
			setConfs="$setConfs
				BR2_riscv=y
				BR2_RISCV_64=y
			"; \
			;; \
			\
		*) \
			echo >&2 "error: unsupported architecture '$dpkgArch'!"; \
			exit 1; \
			;; \
	esac; \
	if [ "$dpkgArch" != 'i386' ]; then \
		unsetConfs="$unsetConfs BR2_i386"; \
	fi; \
	\
	make defconfig; \
	\
	for conf in $unsetConfs; do \
		sed -i \
			-e "s!^$conf=.*\$!# $conf is not set!" \
			.config; \
	done; \
	\
	for confV in $setConfs; do \
		conf="${confV%=*}"; \
		sed -i \
			-e "s!^$conf=.*\$!$confV!" \
			-e "s!^# $conf is not set\$!$confV!" \
			.config; \
		if ! grep -q "^$confV\$" .config; then \
			echo "$confV" >> .config; \
		fi; \
	done; \
	\
	make oldconfig < /dev/null; \
	\
	for conf in $unsetConfs; do \
		! grep -q "^$conf=" .config; \
	done; \
	for confV in $setConfs; do \
		grep -q "^$confV\$" .config; \
	done;

set -eux; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	make -C /usr/src/buildroot \
		HOST_GMP_CONF_OPTS="--build='"$gnuArch"'" \
		FORCE_UNSAFE_CONFIGURE=1 \
		-j "$(nproc)" \
		toolchain
PATH=/usr/src/buildroot/output/host/usr/bin:$PATH

gpg --batch --keyserver keyserver.ubuntu.com --recv-keys C9E9416F76E610DBD09D040F47B70C55ACC9965B

BUSYBOX_VERSION=1.34.1
BUSYBOX_SHA256=415fbd89e5344c96acf449d94a6f956dbed62e18e835fc83e064db33a34bd549

set -eux; \
	tarball="busybox-${BUSYBOX_VERSION}.tar.bz2"; \
	curl -fL -o busybox.tar.bz2.sig "https://busybox.net/downloads/$tarball.sig"; \
	curl -fL -o busybox.tar.bz2 "https://busybox.net/downloads/$tarball"; \
	echo "$BUSYBOX_SHA256 *busybox.tar.bz2" | sha256sum -c -; \
	gpg --batch --verify busybox.tar.bz2.sig busybox.tar.bz2; \
	mkdir -p /usr/src/busybox; \
	tar -xf busybox.tar.bz2 -C /usr/src/busybox --strip-components 1; \
	rm busybox.tar.bz2*

cd /usr/src/busybox

set -eux; \
	\
	setConfs='
		CONFIG_HUSH=y
		CONFIG_SHELL_HUSH=y
		CONFIG_SH_IS_HUSH=y
		CONFIG_BASH_IS_NONE=y
		CONFIG_STATIC=y
		CONFIG_TIMEOUT=y
	'; \
	\
	unsetConfs='
		CONFIG_SHELL_ASH
		CONFIG_SH_IS_ASH
	'; \
	\
	make allnoconfig; \
	\
	for conf in $unsetConfs; do \
		sed -i \
			-e "s!^$conf=.*\$!# $conf is not set!" \
			.config; \
	done; \
	\
	for confV in $setConfs; do \
		conf="${confV%=*}"; \
		sed -i \
			-e "s!^$conf=.*\$!$confV!" \
			-e "s!^# $conf is not set\$!$confV!" \
			.config; \
		if ! grep -q "^$confV\$" .config; then \
			echo "$confV" >> .config; \
		fi; \
	done; \
	\
	make oldconfig < /dev/null ; \
	\
	for conf in $unsetConfs; do \
		! grep -q "^$conf=" .config; \
	done; \
	for confV in $setConfs; do \
		grep -q "^$confV\$" .config; \
	done

set -eux; \
	nproc="$(nproc)"; \
	CROSS_COMPILE="$(basename /usr/src/buildroot/output/host/usr/*-buildroot-linux-uclibc*)"; \
	export CROSS_COMPILE="$CROSS_COMPILE-"; \
	make -j "$nproc" busybox; \
	mkdir -p rootfs/bin; \
	ln -vL busybox rootfs/bin/; \
	ln -s busybox rootfs/bin/sh; \
	ln -s busybox rootfs/bin/timeout; \
	tar cC rootfs . | xz -T0 -z9 > /host/busybox.tar.xz
