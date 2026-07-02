FROM mambaorg/micromamba:1.5.10

LABEL author="Heekuk Park"
LABEL project="KBracken"

ENV ENV_NAME=kbracken
ENV CONDA_OVERRIDE_ARCHSPEC=x86_64
ENV MAMBA_OVERRIDE_ARCHSPEC=x86_64

RUN micromamba create -y -n ${ENV_NAME} \
    -c conda-forge -c bioconda  -c  defaults \
    python=3.11 \
    snakemake=8.25.3 \
    kraken2=2.1.3 \
    bracken=2.9 \
    pandas \
    numpy \
    pigz \
    coreutils \
    && micromamba clean --all --yes

ENV PATH=/opt/conda/envs/${ENV_NAME}/bin:$PATH
ENV CONDA_DEFAULT_ENV=${ENV_NAME}

WORKDIR /work
CMD ["bash"]
