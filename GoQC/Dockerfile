FROM python:3.11-slim-bookworm

LABEL author="Heekuk Park"
LABEL project="CAULab-GoQC"

ENV DEBIAN_FRONTEND=noninteractive

RUN for i in 1 2 3 4 5; do \
      apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update && break; \
      echo "apt-get update failed, retry ${i}/5"; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
      if [ "$i" = 5 ]; then \
        echo "FATAL: apt-get update failed inside Docker. Check Docker Desktop network/DNS/proxy."; \
        exit 1; \
      fi; \
    done

RUN apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
      bash \
      bowtie2 \
      ca-certificates \
      coreutils \
      fastp \
      pigz \
      procps \
      samtools \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir snakemake==8.25.3

WORKDIR /work
CMD ["bash"]
