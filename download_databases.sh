#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./download_databases.sh --db-root DB_ROOT --tools host,kraken2,humann [options]

Examples:
  ./download_databases.sh --db-root $HOME/caulab-db --tools host
  ./download_databases.sh --db-root $HOME/caulab-db --tools kraken2 --threads 8
  ./download_databases.sh --db-root $HOME/caulab-db --tools humann --threads 8
  ./download_databases.sh --db-root $HOME/caulab-db --tools all --threads 8

Options:
  --db-root DIR             Root directory for downloaded databases.
  --tools LIST              Comma-separated: host,kraken2,humann,all.
  --threads N               Threads for Kraken2/Bracken build. Default: 8.
  --bracken-read-len N      Bracken read length. Default: 100.
  --kraken2-16gb NAME       Prebuilt Kraken2 16GB DB family. Default: k2_pluspfp_16gb.
  --host-index-name NAME    Host Bowtie2 index basename. Default: chm13v2.0.
  --host-index-url URL      Host Bowtie2 index zip URL.
  --humann-uniref NAME      HUMAnN protein DB: uniref90_diamond or uniref50_diamond. Default: uniref90_diamond.
  --metaphlan-index NAME    MetaPhlAn index name. Default: mpa_vJun23_CHOCOPhlAnSGB_202307.
  --prefix INSTALL_DIR      CAULab install root to update lab_paths.sh. Default: $CAULAB_PIPELINES or $HOME/caulab-pipelines.
  --platform PLATFORM       Docker platform, e.g. linux/amd64.
  -h, --help                Show this help.

Notes:
  - Docker must be installed and running.
  - Kraken2 standard DB and HUMAnN DBs are large; use a disk with enough free space.
  - The script writes local DB paths into PREFIX/config/lab_paths.sh when that file exists.
EOF
  exit "${1:-1}"
}

DB_ROOT=""
TOOLS=""
THREADS=8
BRACKEN_READ_LEN=100
KRAKEN2_16GB="k2_pluspfp_16gb"
HOST_INDEX_NAME="chm13v2.0"
HOST_INDEX_URL="https://genome-idx.s3.amazonaws.com/bt/chm13v2.0.zip"
HUMANN_UNIREF="uniref90_diamond"
METAPHLAN_INDEX="mpa_vJun23_CHOCOPhlAnSGB_202307"
PREFIX="${CAULAB_PIPELINES:-$HOME/caulab-pipelines}"
PLATFORM="${DOCKER_PLATFORM:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --db-root)
      DB_ROOT="${2:-}"
      [ -n "$DB_ROOT" ] || usage
      shift 2
      ;;
    --tools)
      TOOLS="${2:-}"
      [ -n "$TOOLS" ] || usage
      shift 2
      ;;
    --threads)
      THREADS="${2:-}"
      [ -n "$THREADS" ] || usage
      shift 2
      ;;
    --bracken-read-len)
      BRACKEN_READ_LEN="${2:-}"
      [ -n "$BRACKEN_READ_LEN" ] || usage
      shift 2
      ;;
    --kraken2-16gb)
      KRAKEN2_16GB="${2:-}"
      [ -n "$KRAKEN2_16GB" ] || usage
      shift 2
      ;;
    --host-index-name)
      HOST_INDEX_NAME="${2:-}"
      [ -n "$HOST_INDEX_NAME" ] || usage
      shift 2
      ;;
    --host-index-url)
      HOST_INDEX_URL="${2:-}"
      [ -n "$HOST_INDEX_URL" ] || usage
      shift 2
      ;;
    --humann-uniref)
      HUMANN_UNIREF="${2:-}"
      [ -n "$HUMANN_UNIREF" ] || usage
      shift 2
      ;;
    --metaphlan-index)
      METAPHLAN_INDEX="${2:-}"
      [ -n "$METAPHLAN_INDEX" ] || usage
      shift 2
      ;;
    --prefix)
      PREFIX="${2:-}"
      [ -n "$PREFIX" ] || usage
      shift 2
      ;;
    --platform)
      PLATFORM="${2:-}"
      [ -n "$PLATFORM" ] || usage
      shift 2
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      usage
      ;;
  esac
done

[ -n "$DB_ROOT" ] || usage
[ -n "$TOOLS" ] || usage

case "$HUMANN_UNIREF" in
  uniref90_diamond|uniref50_diamond) ;;
  *)
    echo "[CAULab DB][FATAL] --humann-uniref must be uniref90_diamond or uniref50_diamond"
    exit 1
    ;;
esac

DB_ROOT="${DB_ROOT%/}"
HOST_DIR="$DB_ROOT/host/bowtie2"
HOST_ZIP="$HOST_DIR/${HOST_INDEX_NAME}.zip"
HOST_PREFIX="$HOST_DIR/${HOST_INDEX_NAME}/${HOST_INDEX_NAME}"
KRAKEN2_DIR="$DB_ROOT/kraken2/${KRAKEN2_16GB}_latest"
HUMANN_CHOCO="$DB_ROOT/humann/chocophlan"
HUMANN_UNIREF_DIR="$DB_ROOT/humann/${HUMANN_UNIREF}"
HUMANN_METAPHLAN="$DB_ROOT/humann/metaphlan4"

docker_run_base() {
  if [ -n "$PLATFORM" ]; then
    docker run --rm --platform "$PLATFORM" "$@"
  else
    docker run --rm "$@"
  fi
}

require_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "[CAULab DB][FATAL] Docker is not available. Start the Docker service and rerun."
    exit 1
  fi
}

require_image() {
  local image="$1"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "[CAULab DB][FATAL] Docker image not found: $image"
    echo "[CAULab DB] Build images first:"
    echo "  ./install_docker_env.sh --update --build-core"
    exit 1
  fi
}

has_tool() {
  local needle="$1"
  case ",$TOOLS," in
    *,all,*|*,"$needle",*) return 0 ;;
    *) return 1 ;;
  esac
}

quote_sh() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g; s/^/'/; s/$/'/"
}

set_or_append_export() {
  local file="$1"
  local key="$2"
  local value="$3"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then
    touch "$file"
  fi
  local quoted
  quoted="$(quote_sh "$value")"
  if grep -q "^export ${key}=" "$file"; then
    sed -i.bak "s|^export ${key}=.*|export ${key}=${quoted}|" "$file"
    rm -f "$file.bak"
  else
    printf "export %s=%s\n" "$key" "$quoted" >> "$file"
  fi
}

update_lab_paths() {
  local lab_paths="$PREFIX/config/lab_paths.sh"
  if [ ! -d "$PREFIX/config" ]; then
    echo "[CAULab DB][WARN] install config directory not found, skip lab_paths.sh update: $PREFIX/config"
    return
  fi
  if has_tool host; then
    set_or_append_export "$lab_paths" CAULAB_HOST_BT2_PREFIX "$HOST_PREFIX"
  fi
  if has_tool kraken2; then
    set_or_append_export "$lab_paths" CAULAB_KRAKEN2_DB "$KRAKEN2_DIR"
  fi
  if has_tool humann; then
    set_or_append_export "$lab_paths" CAULAB_HUMANN_CHOCOPHLAN "$HUMANN_CHOCO"
    set_or_append_export "$lab_paths" CAULAB_HUMANN_UNIREF "$HUMANN_UNIREF_DIR"
    set_or_append_export "$lab_paths" CAULAB_HUMANN_METAPHLAN "$HUMANN_METAPHLAN"
    if [ -n "$METAPHLAN_INDEX" ]; then
      set_or_append_export "$lab_paths" CAULAB_METAPHLAN_INDEX "$METAPHLAN_INDEX"
    fi
  fi
  echo "[CAULab DB] Updated local DB paths:"
  echo "  $lab_paths"
}

download_host() {
  mkdir -p "$HOST_DIR"
  if [ -f "${HOST_PREFIX}.1.bt2" ] || [ -f "${HOST_PREFIX}.1.bt2l" ]; then
    echo "[CAULab DB] Host Bowtie2 index already exists: $HOST_PREFIX"
    return
  fi
  echo "[CAULab DB] Downloading human Bowtie2 index to $HOST_DIR"
  curl -L --fail --continue-at - \
    -o "$HOST_ZIP" \
    "$HOST_INDEX_URL"
  unzip -n "$HOST_ZIP" -d "$HOST_DIR"
  if [ ! -f "${HOST_PREFIX}.1.bt2" ] && [ ! -f "${HOST_PREFIX}.1.bt2l" ]; then
    local detected_prefix=""
    detected_prefix="$(find "$HOST_DIR" -type f \( -name '*.1.bt2' -o -name '*.1.bt2l' \) -print | sort | head -n 1 | sed -E 's/\.1\.bt2l?$//')"
    if [ -n "$detected_prefix" ]; then
      HOST_PREFIX="$detected_prefix"
      echo "[CAULab DB] Detected host Bowtie2 prefix: $HOST_PREFIX"
    else
      echo "[CAULab DB][FATAL] Host Bowtie2 index download completed, but no Bowtie2 prefix was found under: $HOST_DIR"
      exit 1
    fi
  fi
}

download_kraken2() {
  require_image "${CAULAB_KBRACKEN_IMAGE:-kbracken:caulab}"
  mkdir -p "$KRAKEN2_DIR"
  if [ -f "$KRAKEN2_DIR/hash.k2d" ] && [ -f "$KRAKEN2_DIR/opts.k2d" ] && [ -f "$KRAKEN2_DIR/taxo.k2d" ]; then
    echo "[CAULab DB] Kraken2 DB already exists: $KRAKEN2_DIR"
  else
    echo "[CAULab DB] Finding latest Kraken2 16GB prebuilt DB: $KRAKEN2_16GB"
    local index_url="https://benlangmead.github.io/aws-indexes/k2"
    local latest_tar
    latest_tar="$(
      curl -fsSL "$index_url" |
        grep -Eo "${KRAKEN2_16GB}_[0-9]{8}\\.tar\\.gz" |
        sort -u |
        tail -n 1
    )"
    if [ -z "$latest_tar" ]; then
      echo "[CAULab DB][FATAL] Could not find latest ${KRAKEN2_16GB}_YYYYMMDD.tar.gz from $index_url"
      exit 1
    fi
    local latest_url="https://genome-idx.s3.amazonaws.com/kraken/${latest_tar}"
    local tarball="$DB_ROOT/kraken2/$latest_tar"
    echo "[CAULab DB] Downloading $latest_url"
    curl -L --fail --continue-at - -o "$tarball" "$latest_url"
    echo "[CAULab DB] Extracting $latest_tar to $KRAKEN2_DIR"
    tar -xzf "$tarball" -C "$KRAKEN2_DIR"
    if [ ! -f "$KRAKEN2_DIR/hash.k2d" ] || [ ! -f "$KRAKEN2_DIR/opts.k2d" ] || [ ! -f "$KRAKEN2_DIR/taxo.k2d" ]; then
      local nested_dir
      nested_dir="$(find "$KRAKEN2_DIR" -mindepth 1 -maxdepth 2 -type f -name hash.k2d -print | head -n 1 | xargs dirname 2>/dev/null || true)"
      if [ -n "$nested_dir" ] && [ "$nested_dir" != "$KRAKEN2_DIR" ]; then
        cp -R "$nested_dir"/. "$KRAKEN2_DIR"/
      fi
    fi
  fi

  if [ -f "$KRAKEN2_DIR/database${BRACKEN_READ_LEN}mers.kmer_distrib" ]; then
    echo "[CAULab DB] Bracken DB already exists for read length $BRACKEN_READ_LEN"
  else
    echo "[CAULab DB] Building Bracken DB for read length $BRACKEN_READ_LEN"
    docker_run_base \
      -v "$KRAKEN2_DIR":/db \
      "${CAULAB_KBRACKEN_IMAGE:-kbracken:caulab}" \
      bash -lc "bracken-build -d /db -t '$THREADS' -k 35 -l '$BRACKEN_READ_LEN'"
  fi
}

download_humann() {
  require_image "${CAULAB_HUMANN_IMAGE:-humann:caulab}"
  mkdir -p "$HUMANN_CHOCO" "$HUMANN_UNIREF_DIR" "$HUMANN_METAPHLAN"

  echo "[CAULab DB] Downloading HUMAnN ChocoPhlAn DB to $HUMANN_CHOCO"
  docker_run_base \
    -v "$HUMANN_CHOCO":/db/chocophlan \
    "${CAULAB_HUMANN_IMAGE:-humann:caulab}" \
    humann_databases --download chocophlan full /db/chocophlan

  echo "[CAULab DB] Downloading HUMAnN $HUMANN_UNIREF DB to $HUMANN_UNIREF_DIR"
  docker_run_base \
    -v "$HUMANN_UNIREF_DIR":/db/uniref \
    "${CAULAB_HUMANN_IMAGE:-humann:caulab}" \
    humann_databases --download uniref "$HUMANN_UNIREF" /db/uniref

  echo "[CAULab DB] Installing MetaPhlAn DB to $HUMANN_METAPHLAN"
  if [ -n "$METAPHLAN_INDEX" ]; then
    docker_run_base \
      -v "$HUMANN_METAPHLAN":/db/metaphlan \
      "${CAULAB_HUMANN_IMAGE:-humann:caulab}" \
      metaphlan --install --bowtie2db /db/metaphlan --index "$METAPHLAN_INDEX"
  else
    docker_run_base \
      -v "$HUMANN_METAPHLAN":/db/metaphlan \
      "${CAULAB_HUMANN_IMAGE:-humann:caulab}" \
      metaphlan --install --bowtie2db /db/metaphlan
  fi
}

TOOLS="$(printf "%s" "$TOOLS" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
require_docker

if has_tool host; then
  download_host
fi
if has_tool kraken2; then
  download_kraken2
fi
if has_tool humann; then
  download_humann
fi

update_lab_paths

cat <<EOF
[CAULab DB] Done.

Next:
  source "$PREFIX/caulab.env"
  caulab_usage.sh
EOF
