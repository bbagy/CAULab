FROM python:3.11-slim-bookworm

LABEL author="Heekuk Park"
LABEL project="K-Park Lab-GoQC"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
