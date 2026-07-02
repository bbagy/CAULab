#!/usr/bin/env bash
set -euo pipefail

usage(){
  echo "Usage: $0 -i FASTQ_DIR -o OUTPUT_DIR [-d HOST_BT2_INDEX_PREFIX] [-s SNAKEDIR] [-c CORES] [-j JOBS] [-m IMAGE] [-n] [-K]"
  echo "       If -d is omitted, CAULAB_HOST_BT2_PREFIX from config/lab_paths.sh is used."
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

abs_target_path(){
  local p="$1"
  local parent base
  if [[ "$p" = /* ]]; then
    parent="$(dirname "$p")"
    base="$(basename "$p")"
  else
    parent="$(pwd -P)/$(dirname "$p")"
    base="$(basename "$p")"
  fi
  [ -d "$parent" ] || { echo "[GoQC] OUTPUT_DIR parent not found: $parent" >&2; return 1; }
  parent="$(cd "$parent" && pwd -P)"
  printf '%s/%s\n' "$parent" "$base"
}

bt2_prefix_parent(){
  local p="$1"
  local d
  d="$(dirname "$p")"
  if [ -d "$d" ]; then
    (cd "$d" && pwd -P)
  else
    return 1
  fi
}

bt2_prefix_base(){
  basename "$1"
}

bt2_prefix_exists(){
  local p="$1"
  compgen -G "${p}*.bt2" >/dev/null || compgen -G "${p}*.bt2l" >/dev/null
}

script_dir(){
  local source="$1"
  local dir target
  while [ -L "$source" ]; do
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    target="$(readlink "$source")"
    case "$target" in
      /*) source="$target" ;;
      *) source="$dir/$target" ;;
    esac
  done
  cd -P "$(dirname "$source")" && pwd
}

FASTQ_DIR=""
OUTPUT_DIR=""
HOST_DB=""
SNAKEDIR=""
CORES=8
JOBS=4
IMAGE="${CAULAB_GOQC_IMAGE:-goqc:caulab}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-}"
DRYRUN=0
KEEP_GOING=0

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
    -d)
      HOST_DB="${2:-}"
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
    -m)
      IMAGE="${2:-}"
      shift 2
      ;;
    -n)
      DRYRUN=1
      shift
      ;;
    -K)
      KEEP_GOING=1
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
if [ -z "$HOST_DB" ]; then
  HOST_DB="${CAULAB_HOST_BT2_PREFIX:-}"
fi
[ -z "$HOST_DB" ] && usage

FASTQ_DIR_ABS="$(abs_path "$FASTQ_DIR")" || { echo "[GoQC] FASTQ_DIR not found: $FASTQ_DIR"; exit 1; }
OUTPUT_DIR_ABS="$(abs_target_path "$OUTPUT_DIR")" || exit 1
OUTPUT_PARENT="$(dirname "$OUTPUT_DIR_ABS")"
OUTPUT_BASENAME="$(basename "$OUTPUT_DIR_ABS")"
RUN_LOG="${OUTPUT_DIR_ABS}/logs/goqc.log"
HOST_DB_PARENT="$(bt2_prefix_parent "$HOST_DB")" || { echo "[GoQC] HOST_DB parent not found: $HOST_DB"; exit 1; }
HOST_DB_PREFIX="$(bt2_prefix_base "$HOST_DB")"
HOST_DB_ABS="${HOST_DB_PARENT}/${HOST_DB_PREFIX}"

if ! bt2_prefix_exists "$HOST_DB_ABS"; then
  echo "[GoQC][FATAL] Bowtie2 index files not found for prefix: $HOST_DB_ABS"
  echo "[GoQC] Expected files like: ${HOST_DB_ABS}.1.bt2 or ${HOST_DB_ABS}.1.bt2l"
  exit 1
fi

SCRIPT_DIR="$(script_dir "$0")"
PIPELINE_DIR="$SCRIPT_DIR"
if [ -n "$SNAKEDIR" ]; then
  [ -d "$SNAKEDIR" ] || { echo "[GoQC] SNAKEDIR not found: $SNAKEDIR"; exit 1; }
  PIPELINE_DIR="$(cd "$SNAKEDIR" && pwd -P)"
fi

SNAKEFILE_NAME="Go_QC.smk"
if [ ! -f "$PIPELINE_DIR/$SNAKEFILE_NAME" ] && [ -f "$PIPELINE_DIR/Go_QC_V1.smk" ]; then
  SNAKEFILE_NAME="Go_QC_V1.smk"
fi
if [ ! -f "$PIPELINE_DIR/$SNAKEFILE_NAME" ]; then
  echo "[GoQC][FATAL] Snakefile not found: $PIPELINE_DIR/$SNAKEFILE_NAME"
  exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "[GoQC][FATAL] Docker image not found locally: $IMAGE"
  echo "[GoQC] Build example:"
  echo "  cd \"$SCRIPT_DIR\" && docker build -t goqc:caulab ."
  exit 1
fi

WORKDIR="$(pwd)"

run(){
  local -a docker_args=(docker run --rm)
  if [ -n "$DOCKER_PLATFORM" ]; then
    docker_args+=(--platform "$DOCKER_PLATFORM")
  fi
  "${docker_args[@]}" \
    -u "$(id -u):$(id -g)" \
    -v "$WORKDIR":/work \
    -v "$PIPELINE_DIR":/pipeline:ro \
    -v "$FASTQ_DIR_ABS":/fastq:ro \
    -v "$HOST_DB_PARENT":/host_db:ro \
    -v "$OUTPUT_PARENT":/out \
    -w /work \
    "$IMAGE" \
    "$@"
}

BASE_ARGS=(
  snakemake
  --snakefile "/pipeline/$SNAKEFILE_NAME"
  --config
  fastq_dir=/fastq
  output_dir="/out/$OUTPUT_BASENAME"
  host_db="/host_db/$HOST_DB_PREFIX"
  paired=2
  threads="$CORES"
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
mkdir -p "$(dirname "$RUN_LOG")"
run "${BASE_ARGS[@]}" 2>&1 | tee "$RUN_LOG"
rc=${PIPESTATUS[0]}
set -e

if [ "$rc" -ne 0 ] && grep -qiE "lock|unlock|LockException|cannot be locked" "$RUN_LOG"; then
  echo "[GoQC] Detected lock issue -> running --unlock then retry..."
  run "${BASE_ARGS[@]}" --unlock
  set +e
  run "${BASE_ARGS[@]}" 2>&1 | tee -a "$RUN_LOG"
  rc=${PIPESTATUS[0]}
  set -e
fi

exit "$rc"
