FROM python:3.11-slim-bookworm

LABEL author="Heekuk Park"
LABEL project="CAULab-GoQC"

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    for i in 1 2 3 4 5; do \
      apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update && break; \
      echo "apt-get update failed, retry ${i}/5"; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
      if [ "$i" = 5 ]; then exit 1; fi; \
    done; \
    apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
      bash \
      bowtie2 \
      ca-certificates \
      coreutils \
      fastp \
      pigz \
      procps \
      samtools; \
    rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir snakemake==8.25.3

WORKDIR /work
CMD ["bash"]
