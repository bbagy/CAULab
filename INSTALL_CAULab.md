# CAULab Installation Notes

The CAULab copy is intended to be path-neutral. Do not hard-code workstation paths inside Snakefiles. Keep lab-specific paths in local shell variables or in `config/lab_paths.yaml`, then pass them to wrapper scripts.

## General Mac Install

Install into the current user's home directory:

```bash
cd /path/to/CAULab
./install_mac.sh --build-core
source "$HOME/caulab-pipelines/caulab.env"
```

If the install directory already exists, use it:

```bash
source "$HOME/caulab-pipelines/caulab.env"
caulab_usage.sh
```

Update an existing install from a refreshed clone:

```bash
cd /path/to/CAULab
git pull
./install_mac.sh --update --build-core
source "$HOME/caulab-pipelines/caulab.env"
```

For Apple Silicon Mac, if the normal Docker build fails while solving Bioconda packages:

```bash
cd /path/to/CAULab
./install_mac.sh --build-core --platform linux/amd64
source "$HOME/caulab-pipelines/caulab.env"
```

Install somewhere else:

```bash
./install_mac.sh --prefix /Volumes/Analysis/caulab-pipelines --build-core
source /Volumes/Analysis/caulab-pipelines/caulab.env
```

After install, edit:

```bash
$CAULAB_PIPELINES/config/lab_paths.yaml
```

Print command examples:

```bash
caulab_usage.sh
```

## Recommended Layout

```text
$HOME/caulab-pipelines/
  bin/
    Go_QC.sh
    Go_KBracken.sh
    Go_Humann.sh
    caulab_usage.sh
  GoQC/
  KBracken/
  Humann/
  config/lab_paths.yaml
  caulab_usage.sh
```

Any install root is valid. The important rule is that data and database paths are provided at run time.

## Docker Build on Mac

If not using `install_mac.sh --build-core`, build the core images manually:

```bash
cd "$CAULAB_PIPELINES/GoQC"
docker build -t goqc:caulab .
cd "$CAULAB_PIPELINES/KBracken"
docker build -t kbracken:caulab .
cd "$CAULAB_PIPELINES/Humann"
docker build -t humann:caulab .
```

On Apple Silicon Mac, if Bioconda cannot solve packages for `linux/arm64`, use amd64 emulation:

```bash
cd "$CAULAB_PIPELINES/GoQC"
docker build --platform linux/amd64 -t goqc:caulab .
cd "$CAULAB_PIPELINES/KBracken"
docker build --platform linux/amd64 -t kbracken:caulab .
cd "$CAULAB_PIPELINES/Humann"
docker build --platform linux/amd64 -t humann:caulab .
export DOCKER_PLATFORM=linux/amd64
```

## Examples

```bash
PIPELINES="$CAULAB_PIPELINES"
DB_ROOT=/data/db

Go_KBracken.sh \
  -i /data/projects/ProjectA/fastq \
  -o ProjectA_kbracken \
  -d "$DB_ROOT/kraken2/k2_pluspfp_16gb" \
  -m kbracken:caulab \
  -K

Go_QC.sh \
  -i /data/projects/ProjectA/fastq \
  -o ProjectA_QC \
  -d "$DB_ROOT/host/hg38/bowtie2/hg38" \
  -m goqc:caulab \
  -K

Go_Humann.sh \
  -i ProjectA_QC/host_filtered_fastq \
  -o ProjectA_humann \
  -n "$DB_ROOT/humann/chocophlan" \
  -p "$DB_ROOT/humann/uniref" \
  -b "$DB_ROOT/humann/metaphlan4" \
  -I mpa_vJan25_CHOCOPhlAnSGB_202503 \
  -m humann:caulab \
  -K
```

`source "$CAULAB_PIPELINES/caulab.env"` adds `$CAULAB_PIPELINES/bin` to `PATH`, so the three wrappers can be run from any working directory.

`GoQC/Go_QC.sh` follows the same structure as `KBracken/Go_KBracken.sh`: the wrapper lives next to its Dockerfile and versioned Snakefile, and it resolves `Go_QC.smk` first, then `Go_QC_V1.smk`.

`Humann/Go_Humann.sh` follows the same structure: the wrapper lives next to `Dockerfile` and `Go_Humann_V1.smk`, and it resolves `Go_Humann.smk` first, then `Go_Humann_V1.smk`.

## Path Rules

- Use absolute host paths for FASTQ and DB inputs.
- Wrapper scripts mount host paths into containers as stable internal paths such as `/fastq`, `/db`, `/pipeline`, and `/report_assets`.
- Reference databases are not versioned in this repository.
- Keep generated outputs outside the pipeline install root.
- Avoid workstation names, user home directories, and lab names inside Snakefiles.
