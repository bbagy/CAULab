#!/usr/bin/env bash
set -euo pipefail

# Resolve the launcher path so invocation through a symlink also finds common/.
_CONTAINER_SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
_CONTAINER_DIR="$(cd "$(dirname "$_CONTAINER_SELF")" && pwd -P)"
_CONTAINER_HELPER="$_CONTAINER_DIR/../common/container.sh"
[ -f "$_CONTAINER_HELPER" ] || _CONTAINER_HELPER="$_CONTAINER_DIR/common/container.sh"
source "$_CONTAINER_HELPER"
set -- ${CONTAINER_ARGS[@]+"${CONTAINER_ARGS[@]}"}


usage(){
  echo "Usage: $0 [--container docker|apptainer] [--container-image IMAGE_OR_SIF] -i FASTQ_DIR -o OUTPUT_DIR -n NUCLEOTIDE_DB -p PROTEIN_DB [-b METAPHLAN_DB] [-I METAPHLAN_INDEX] [-u UTILITY_MAPPING_DB] [-s SNAKEDIR] [-c CORES] [-j JOBS] [-t THREADS] [-m IMAGE] [-x] [-K] [--run-musicc] [--skip-gene-norm] [--skip-path-split] [--skip-pathcoverage]"
  echo "  Recommended MetaPhlAn input: -b /path/to/metaphlan_db_dir -I mpa_vJun23_CHOCOPhlAnSGB_202307"
  echo "  Backward-compatible shortcut: -b /path/to/mpa_vJun23_CHOCOPhlAnSGB_202307.pkl"
  echo "  KO tables need -u: HUMAnN utility_mapping folder containing map_ko_uniref90/50.txt.gz"
  exit 1
}

abs_path(){
  local p="$1"
  if [ -d "$p" ]; then
    (cd "$p" && pwd -P)
  elif [ -e "$p" ]; then
    (cd "$(dirname "$p")" && printf "%s/%s\n" "$(pwd -P)" "$(basename "$p")")
  else
    return 1
  fi
}

FASTQ_DIR=""
OUTPUT_DIR=""
NUCLEOTIDE_DB=""
PROTEIN_DB=""
METAPHLAN_DB=""
METAPHLAN_INDEX=""
UTILITY_DB=""
SNAKEDIR=""
CORES=8
JOBS=4
THREADS=4
IMAGE="${KPARK_HUMANN_IMAGE:-humann:kpark}"
DRYRUN=0
KEEP_GOING=0
RUN_GENE_NORM=1
RUN_PATH_SPLIT=1
RUN_PATHCOVERAGE=1
RUN_MUSICC=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -i)
      FASTQ_DIR="${2:-}"
      shift 2
      ;;
    -o)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    -n)
      NUCLEOTIDE_DB="${2:-}"
      shift 2
      ;;
    -p)
      PROTEIN_DB="${2:-}"
      shift 2
      ;;
    -b)
      METAPHLAN_DB="${2:-}"
      shift 2
      ;;
    -I|--metaphlan-index)
      METAPHLAN_INDEX="${2:-}"
      shift 2
      ;;
    -u)
      UTILITY_DB="${2:-}"
      shift 2
      ;;
    -s)
      SNAKEDIR="${2:-}"
      shift 2
      ;;
    -c)
      CORES="${2:-}"
      shift 2
      ;;
    -j)
      JOBS="${2:-}"
      shift 2
      ;;
    -t)
      THREADS="${2:-}"
      shift 2
      ;;
    -m)
      IMAGE="${2:-}"
      shift 2
      ;;
    -x)
      DRYRUN=1
      shift
      ;;
    -K)
      KEEP_GOING=1
      shift
      ;;
    --run-musicc)
      RUN_MUSICC=1
      shift
      ;;
    --skip-gene-norm)
      RUN_GENE_NORM=0
      shift
      ;;
    --skip-path-split)
      RUN_PATH_SPLIT=0
      shift
      ;;
    --skip-pathcoverage)
      RUN_PATHCOVERAGE=0
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[ -z "$FASTQ_DIR" ] && usage
[ -z "$OUTPUT_DIR" ] && usage
NUCLEOTIDE_DB="${NUCLEOTIDE_DB:-${KPARK_HUMANN_CHOCOPHLAN:-}}"
PROTEIN_DB="${PROTEIN_DB:-${KPARK_HUMANN_UNIREF:-}}"
METAPHLAN_DB="${METAPHLAN_DB:-${KPARK_HUMANN_METAPHLAN:-}}"
METAPHLAN_INDEX="${METAPHLAN_INDEX:-${KPARK_METAPHLAN_INDEX:-}}"
UTILITY_DB="${UTILITY_DB:-${KPARK_HUMANN_UTILITY:-}}"
[ -z "$NUCLEOTIDE_DB" ] && usage
[ -z "$PROTEIN_DB" ] && usage

FASTQ_DIR_ABS="$(abs_path "$FASTQ_DIR")" || { echo "[Humannake] FASTQ_DIR not found: $FASTQ_DIR"; exit 1; }
NUCLEOTIDE_DB_ABS="$(abs_path "$NUCLEOTIDE_DB")" || { echo "[Humannake] NUCLEOTIDE_DB not found: $NUCLEOTIDE_DB"; exit 1; }
PROTEIN_DB_ABS="$(abs_path "$PROTEIN_DB")" || { echo "[Humannake] PROTEIN_DB not found: $PROTEIN_DB"; exit 1; }

SCRIPT_DIR="$_CONTAINER_DIR"
PIPELINE_DIR="$SCRIPT_DIR"
if [ -n "$SNAKEDIR" ]; then
  [ -d "$SNAKEDIR" ] || { echo "[Humannake] SNAKEDIR not found: $SNAKEDIR"; exit 1; }
  PIPELINE_DIR="$(cd "$SNAKEDIR" && pwd -P)"
fi

SNAKEFILE_NAME="Go_Humann.smk"
if [ ! -f "$PIPELINE_DIR/$SNAKEFILE_NAME" ] && [ -f "$PIPELINE_DIR/Go_Humann_V1.smk" ]; then
  SNAKEFILE_NAME="Go_Humann_V1.smk"
fi
if [ ! -f "$PIPELINE_DIR/$SNAKEFILE_NAME" ]; then
  echo "[Humannake][FATAL] Snakefile not found: $PIPELINE_DIR/$SNAKEFILE_NAME"
  exit 1
fi

container_require_image "$IMAGE" || exit 1

WORKDIR="$(pwd)"
CONTAINER_HOME="/work/.humann_home"

CONTAINER_RUN_ARGS=(
  container_run --rm
  -u "$(id -u):$(id -g)"
  -v "$WORKDIR":/work
  -v "$PIPELINE_DIR":/pipeline:ro
  -v "$FASTQ_DIR_ABS":/fastq:ro
  -v "$NUCLEOTIDE_DB_ABS":/db/nucleotide:ro
  -v "$PROTEIN_DB_ABS":/db/protein:ro
  -e HOME="$CONTAINER_HOME"
  -e XDG_CACHE_HOME="$CONTAINER_HOME/.cache"
  -w /work
)

if [ -n "$METAPHLAN_DB" ]; then
  METAPHLAN_DB_ABS="$(abs_path "$METAPHLAN_DB")" || { echo "[Humannake] METAPHLAN_DB not found: $METAPHLAN_DB"; exit 1; }
  if [ -f "$METAPHLAN_DB_ABS" ]; then
    case "$METAPHLAN_DB_ABS" in
      *.pkl)
        if [ -z "$METAPHLAN_INDEX" ]; then
          METAPHLAN_INDEX="$(basename "$METAPHLAN_DB_ABS" .pkl)"
        fi
        METAPHLAN_DB_ABS="$(dirname "$METAPHLAN_DB_ABS")"
        ;;
      *)
        echo "[Humannake] METAPHLAN_DB file must be a MetaPhlAn .pkl index file: $METAPHLAN_DB"
        exit 1
        ;;
    esac
  fi
  CONTAINER_RUN_ARGS+=(-v "$METAPHLAN_DB_ABS":/db/metaphlan:ro)
  CONTAINER_RUN_ARGS+=(-e METAPHLAN_DB_DIR=/db/metaphlan)
fi

if [ "$RUN_GENE_NORM" -eq 1 ]; then
  UTILITY_DB_ABS="$(abs_path "${UTILITY_DB:-.missing}")" || UTILITY_DB_ABS=""
  # humann_databases extracts into DIR/utility_mapping; accept either level.
  if [ -n "$UTILITY_DB_ABS" ] && ! compgen -G "$UTILITY_DB_ABS/map_ko_uniref*.txt.gz" >/dev/null && compgen -G "$UTILITY_DB_ABS/utility_mapping/map_ko_uniref*.txt.gz" >/dev/null; then
    UTILITY_DB_ABS="$UTILITY_DB_ABS/utility_mapping"
  fi
  if [ -z "$UTILITY_DB_ABS" ] || ! compgen -G "$UTILITY_DB_ABS/map_ko_uniref*.txt.gz" >/dev/null; then
    echo "[Humannake][FATAL] KO tables need map_ko_uniref90/50.txt.gz (HUMAnN utility_mapping full): ${UTILITY_DB:-not set}"
    echo "  Download: download_databases.sh --db-root \"$HOME/kpark-db\" --tools humann-utility  (or set -u / KPARK_HUMANN_UTILITY)"
    echo "  Skip KO tables: --skip-gene-norm"
    exit 1
  fi
  CONTAINER_RUN_ARGS+=(-v "$UTILITY_DB_ABS":/db/utility:ro)
fi

run(){
  "${CONTAINER_RUN_ARGS[@]}" "$IMAGE" "$@"
}

mkdir -p "$WORKDIR/.humann_home/.cache"

BASE_ARGS=(
  snakemake
  --snakefile "/pipeline/$SNAKEFILE_NAME"
  --config
  fastq_dir=/fastq
  output_dir="$OUTPUT_DIR"
  nucleotide_db=/db/nucleotide
  protein_db=/db/protein
  metaphlan_db="${METAPHLAN_DB:+/db/metaphlan}"
  metaphlan_index="$METAPHLAN_INDEX"
  utility_mapping_db="${UTILITY_DB_ABS:+/db/utility}"
  humann_threads="$THREADS"
  run_musicc="$RUN_MUSICC"
  run_gene_norm="$RUN_GENE_NORM"
  run_path_split="$RUN_PATH_SPLIT"
  run_pathcoverage_merge="$RUN_PATHCOVERAGE"
  --cores "$CORES"
  --jobs "$JOBS"
  --latency-wait 60
  --rerun-incomplete
)
if [ "$DRYRUN" -eq 1 ]; then
  BASE_ARGS+=(--dry-run)
fi
if [ "$KEEP_GOING" -eq 1 ]; then
  BASE_ARGS+=(--keep-going)
fi

set +e
run "${BASE_ARGS[@]}" 2>&1 | tee humann.log
rc=${PIPESTATUS[0]}
set -e

if [ "$rc" -ne 0 ] && grep -qiE "lock|unlock|LockException|cannot be locked" humann.log; then
  echo "[Humannake] Detected lock issue -> running --unlock then retry..."
  run "${BASE_ARGS[@]}" --unlock
  set +e
  run "${BASE_ARGS[@]}" 2>&1 | tee -a humann.log
  rc=${PIPESTATUS[0]}
  set -e
fi

exit "$rc"
