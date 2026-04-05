ARG PG_MAJOR

FROM ghcr.io/loong64/pgvector/pgvector:pg${PG_MAJOR}-trixie AS builder

ARG PG_MAJOR
RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		clang-19 \
		curl \
		gcc \
		git \
		make \
		postgresql-server-dev-${PG_MAJOR} \
		zip; \
	rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:$PATH"
RUN set -eux; \
	curl -sSf https://sh.rustup.rs | sh -s -- -y

ARG TAG
RUN set -eux; \
	git clone --branch ${TAG} --depth 1 https://github.com/tensorchord/VectorChord /opt/vectorchord

WORKDIR /opt/vectorchord
RUN set -eux; \
	mkdir -p /dist; \
	export PGRX_PG_CONFIG_PATH=pg_config PG_CONFIG=pg_config; \
	export SEMVER=${TAG} VERSION=${PG_MAJOR} ARCH=loongarch64 PLATFORM=loong64; \
	mkdir -p ~/.pgrx; \
	touch ~/.pgrx/config.toml; \
	make PG_CONFIG=$PG_CONFIG build; \
	(cd ./build/raw && zip -r /dist/postgresql-${VERSION}-vchord_${SEMVER}_${ARCH}-linux-gnu.zip .); \
	make DESTDIR="./build/deb" install; \
	mkdir -p ./build/deb/DEBIAN; \
	{ \
		echo "Package: postgresql-${VERSION}-vchord"; \
		echo "Version: ${SEMVER}-1"; \
		echo "Depends: postgresql-${VERSION}, libgcc-s1, libc6 (>= 2.35)"; \
		echo "Section: database"; \
		echo "Priority: optional"; \
		echo "Architecture: ${PLATFORM}"; \
		echo "Maintainer: Tensorchord <support@tensorchord.ai>"; \
		echo "Description: Vector database plugin for Postgres, written in Rust, specifically designed for LLM"; \
		echo "Homepage: https://vectorchord.ai/"; \
		echo "License: AGPL-3.0-only or Elastic-2.0"; \
	} > ./build/deb/DEBIAN/control; \
	(cd ./build/deb && find usr -type f -print0 | xargs -0 md5sum) > ./build/deb/DEBIAN/md5sums; \
	dpkg-deb --root-owner-group -Zxz --build ./build/deb/ /dist/postgresql-${VERSION}-vchord_${SEMVER}-1_${PLATFORM}.deb;

FROM scratch
COPY --from=builder /dist /dist
