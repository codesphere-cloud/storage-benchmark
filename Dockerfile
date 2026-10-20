FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG SMALLFILE_REF=aa2519de5bf0b3b383db2c31eacbf8ac4328e19c

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        fio \
        git \
        jq \
        python3 \
        time \
        util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/distributed-system-analysis/smallfile.git /opt/smallfile \
    && git -C /opt/smallfile checkout "${SMALLFILE_REF}" \
    && printf '%s\n' "${SMALLFILE_REF}" > /opt/smallfile-version \
    && rm -rf /opt/smallfile/.git \
    && groupadd --gid 1010 appusers \
    && useradd --uid 1501 --gid 1010 --create-home --home-dir /home/user user \
    && mkdir -p /home/user/app \
    && chown 1501:1010 /home/user/app

COPY benchmark.sh /usr/local/bin/storage-benchmark
COPY scripts/check-tools.sh /usr/local/bin/check-storage-benchmark-tools
RUN chmod 0755 /usr/local/bin/storage-benchmark /usr/local/bin/check-storage-benchmark-tools

WORKDIR /home/user/app
USER 1501:1010

CMD ["bash"]
