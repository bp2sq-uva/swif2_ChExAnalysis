#!/bin/bash

# ============================================================
# submit_genrp_split_full_chain_swif2.sh
#
# Usage:
#   ./submit_genrp_split_full_chain_swif2.sh MODE FILES_PER_JOB
#
# Example:
#   ./submit_genrp_split_full_chain_swif2.sh 2 10
#
# This creates:
#   - many skim jobs, each reading FILES_PER_JOB ROOT files
#   - one final merge + analysis + plot job
# ============================================================

set -e

MODE="$1"
FILES_PER_JOB="$4"

if [ -z "${MODE}" ] || [ -z "${FILES_PER_JOB}" ]; then
    echo "Usage:"
    echo "  $0 MODE FILES_PER_JOB"
    echo
    echo "Example:"
    echo "  $0 2 10"
    exit 1
fi

if [ "${MODE}" != "1" ] && [ "${MODE}" != "2" ]; then
    echo "ERROR: MODE must be 1 or 2"
    exit 1
fi

if ! [[ "${FILES_PER_JOB}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: FILES_PER_JOB must be an integer"
    exit 1
fi

if [ "${FILES_PER_JOB}" -le 0 ]; then
    echo "ERROR: FILES_PER_JOB must be > 0"
    exit 1
fi

# ============================================================
# User configuration
# ============================================================

WORKDIR="/work/halla/sbs/bhasitha/GENRP_ANALYSIS/PASS1/ChExAnalysis"

WORKFLOW="genrp_mode${MODE}_split_${FILES_PER_JOB}files_PASS1"

PARTITION="production"

SKIM_CORES="1"
SKIM_DISK="1GB"
SKIM_RAM="1000MB"

FINAL_CORES="1"
FINAL_DISK="30GB"
FINAL_RAM="4000MB"

# Input ROOT search pattern.
# EDIT THIS to match exactly the replay ROOT files you want for mode 1/2.
#
# Example placeholder:
INPUT_SEARCH_DIR="/volatile/halla/sbs/sbs-gen/GENRP_REPLAYS/PASS1/LD2"
INPUT_NAME_PATTERN="*.root"

FILELIST_DIR="${WORKDIR}/filelists/mode${MODE}_${FILES_PER_JOB}files"
CHUNK_DIR="${FILELIST_DIR}/chunks"

SKIM_PART_DIR="${WORKDIR}/hist/skimh_parts/mode${MODE}_${FILES_PER_JOB}files"

FINAL_SKIM="${WORKDIR}/hist/skimh/skim_genrp_PASS1.root"
FINAL_ANALYSIS="${WORKDIR}/hist/skim_genrp_PASS1.root"
FINAL_PDF="${WORKDIR}/pdf/skim_genrp_PASS1.pdf"

SKIM_WRAPPER="${WORKDIR}/run_skim_chunk_swif2.sh"
FINAL_WRAPPER="${WORKDIR}/run_merge_analysis_plot_swif2.sh"

cd "${WORKDIR}" || exit 1

mkdir -p "${FILELIST_DIR}"
mkdir -p "${CHUNK_DIR}"
mkdir -p "${SKIM_PART_DIR}"
mkdir -p "${WORKDIR}/hist/skimh"
mkdir -p "${WORKDIR}/hist"
mkdir -p "${WORKDIR}/pdf"
mkdir -p "${WORKDIR}/log"

echo "============================================================"
echo "Configuration"
echo "============================================================"
echo "MODE          = ${MODE}"
echo "FILES_PER_JOB = ${FILES_PER_JOB}"
echo "WORKFLOW      = ${WORKFLOW}"
echo "WORKDIR       = ${WORKDIR}"
echo "INPUT DIR     = ${INPUT_SEARCH_DIR}"
echo "INPUT PATTERN = ${INPUT_NAME_PATTERN}"
echo "SKIM_PART_DIR = ${SKIM_PART_DIR}"
echo "FINAL_SKIM    = ${FINAL_SKIM}"
echo "============================================================"

# ============================================================
# Create full input ROOT file list
# ============================================================

ALL_FILELIST="${FILELIST_DIR}/all_input_files.txt"

echo "Creating full input file list..."

find "${INPUT_SEARCH_DIR}" \
    -type f \
    -name "${INPUT_NAME_PATTERN}" \
    | sort > "${ALL_FILELIST}"

NFILES=$(wc -l < "${ALL_FILELIST}")

echo "Found ${NFILES} input ROOT files"

if [ "${NFILES}" -le 0 ]; then
    echo "ERROR: no input ROOT files found"
    echo "Check INPUT_SEARCH_DIR and INPUT_NAME_PATTERN in this script."
    exit 1
fi

echo "Checking for duplicate input files..."
NDUP=$(sort "${ALL_FILELIST}" | uniq -d | wc -l)

if [ "${NDUP}" -ne 0 ]; then
    echo "ERROR: duplicate input files found in all_input_files.txt"
    sort "${ALL_FILELIST}" | uniq -d
    exit 1
fi

# ============================================================
# Split file list by FILES_PER_JOB
# ============================================================

echo "Splitting file list..."

rm -f "${CHUNK_DIR}"/input_chunk_*.txt

split -l "${FILES_PER_JOB}" \
      -d \
      --additional-suffix=.txt \
      "${ALL_FILELIST}" \
      "${CHUNK_DIR}/input_chunk_"

NCHUNKS=$(ls "${CHUNK_DIR}"/input_chunk_*.txt 2>/dev/null | wc -l)

echo "Created ${NCHUNKS} chunks"

if [ "${NCHUNKS}" -le 0 ]; then
    echo "ERROR: no chunks created"
    exit 1
fi

echo "Chunk sizes:"
wc -l "${CHUNK_DIR}"/input_chunk_*.txt

echo "Checking no double counting after split..."
N_AFTER_SPLIT=$(cat "${CHUNK_DIR}"/input_chunk_*.txt | wc -l)
NDUP_AFTER_SPLIT=$(cat "${CHUNK_DIR}"/input_chunk_*.txt | sort | uniq -d | wc -l)

echo "Original file count = ${NFILES}"
echo "Split file count    = ${N_AFTER_SPLIT}"
echo "Duplicate count     = ${NDUP_AFTER_SPLIT}"

if [ "${NFILES}" -ne "${N_AFTER_SPLIT}" ]; then
    echo "ERROR: split file count does not match original count"
    exit 1
fi

if [ "${NDUP_AFTER_SPLIT}" -ne 0 ]; then
    echo "ERROR: duplicates found after split"
    cat "${CHUNK_DIR}"/input_chunk_*.txt | sort | uniq -d
    exit 1
fi

# ============================================================
# Create skim wrapper
# ============================================================

cat > "${SKIM_WRAPPER}" << 'EOF'
#!/bin/bash

MODE=$1
CHUNK_ID=$2
FILELIST=$3
OUTFILE=$4

echo "============================================================"
echo "Starting skim chunk job"
echo "Host: $(hostname)"
echo "Start time: $(date)"
echo "MODE=${MODE}"
echo "CHUNK_ID=${CHUNK_ID}"
echo "FILELIST=${FILELIST}"
echo "OUTFILE=${OUTFILE}"
echo "SLURM_JOB_ID=${SLURM_JOB_ID}"
echo "SWIF_JOB_WORK_DIR=${SWIF_JOB_WORK_DIR}"
echo "============================================================"

module use /group/halla/modulefiles
module load root/6.36.08

export ANALYZER=/work/halla/sbs/sbs-gen/pass3/ANALYZER/install
source "${ANALYZER}/bin/setup.sh"

export SBS_REPLAY=/work/halla/sbs/sbs-gen/GENRP/SBS-replay
export SBS=/work/halla/sbs/sbs-gen/GENRP/SBS_OFFLINE/install
source "${SBS}/bin/sbsenv.sh"

export DB_DIR="${SBS_REPLAY}/DB"
export DATA_DIR=/cache/mss/halla/sbs/GEnRP/raw
export ANALYZER_CONFIGPATH="${SBS_REPLAY}/replay"

WORKDIR="/work/halla/sbs/bhasitha/GENRP_ANALYSIS/PASS1/ChExAnalysis"

cd "${WORKDIR}" || exit 1

mkdir -p "$(dirname "${OUTFILE}")"

if [ -f "${SBS}/run_replay_here/.rootrc" ]; then
    cp "${SBS}/run_replay_here/.rootrc" ./.rootrc
fi

echo "ROOT version:"
root-config --version

echo "Chunk file count:"
wc -l "${FILELIST}"

echo "Checking macros:"
ls -lh SkimGEnRP.C run_skim_chunk.C

echo "Running skim chunk..."
/usr/bin/time -v root -l -b -q "run_skim_chunk.C(${MODE},\"${FILELIST}\",\"${OUTFILE}\")"

RET=$?

echo "Skim chunk finished with exit code ${RET}"
echo "Output:"
ls -lh "${OUTFILE}" || true

exit ${RET}
EOF

chmod +x "${SKIM_WRAPPER}"

# ============================================================
# Create final merge + analysis + plot wrapper
# ============================================================

cat > "${FINAL_WRAPPER}" << EOF
#!/bin/bash

echo "============================================================"
echo "Starting final merge + analysis + plot job"
echo "Host: \$(hostname)"
echo "Start time: \$(date)"
echo "SLURM_JOB_ID=\${SLURM_JOB_ID}"
echo "SWIF_JOB_WORK_DIR=\${SWIF_JOB_WORK_DIR}"
echo "============================================================"

module use /group/halla/modulefiles
module load root/6.36.08

export ANALYZER=/work/halla/sbs/sbs-gen/pass3/ANALYZER/install
source "\${ANALYZER}/bin/setup.sh"

export SBS_REPLAY=/work/halla/sbs/sbs-gen/GENRP/SBS-replay
export SBS=/work/halla/sbs/sbs-gen/GENRP/SBS_OFFLINE/install
source "\${SBS}/bin/sbsenv.sh"

export DB_DIR="\${SBS_REPLAY}/DB"
export DATA_DIR=/cache/mss/halla/sbs/GEnRP/raw
export ANALYZER_CONFIGPATH="\${SBS_REPLAY}/replay"

WORKDIR="${WORKDIR}"
SKIM_PART_DIR="${SKIM_PART_DIR}"
FINAL_SKIM="${FINAL_SKIM}"

cd "\${WORKDIR}" || exit 1

mkdir -p hist/skimh
mkdir -p hist
mkdir -p pdf

if [ -f "\${SBS}/run_replay_here/.rootrc" ]; then
    cp "\${SBS}/run_replay_here/.rootrc" ./.rootrc
fi

echo "ROOT version:"
root-config --version

echo "Checking skim parts:"
ls -lh "\${SKIM_PART_DIR}"/skim_part_*.root

NPARTS=\$(ls "\${SKIM_PART_DIR}"/skim_part_*.root 2>/dev/null | wc -l)
echo "Number of skim parts found: \${NPARTS}"

if [ "\${NPARTS}" -le 0 ]; then
    echo "ERROR: no skim parts found"
    exit 1
fi

echo "Merging skim parts into:"
echo "  \${FINAL_SKIM}"

hadd -f "\${FINAL_SKIM}" "\${SKIM_PART_DIR}"/skim_part_*.root

RET=\$?
if [ "\${RET}" -ne 0 ]; then
    echo "ERROR: hadd failed"
    exit "\${RET}"
fi

echo "Merged skim file:"
ls -lh "\${FINAL_SKIM}"

echo "Running final analysis and plotting..."
/usr/bin/time -v root -l -b -q run_merge_analysis_plot.C

RET=\$?

echo "Final analysis/plot finished with exit code \${RET}"
echo "End time: \$(date)"

echo "Final outputs:"
ls -lh "${FINAL_SKIM}" 2>/dev/null || true
ls -lh "${FINAL_ANALYSIS}" 2>/dev/null || true
ls -lh "${FINAL_PDF}" 2>/dev/null || true

exit "\${RET}"
EOF

chmod +x "${FINAL_WRAPPER}"

# ============================================================
# Create SWIF workflow
# ============================================================

echo "Creating SWIF workflow ${WORKFLOW}"
swif2 create "${WORKFLOW}" || true

# ============================================================
# Add skim jobs
# ============================================================

echo "Adding skim jobs..."

i=0
for chunkfile in "${CHUNK_DIR}"/input_chunk_*.txt
do
    chunk_id=$(printf "%03d" "${i}")
    outfile="${SKIM_PART_DIR}/skim_part_${chunk_id}.root"
    jobname="skim_${chunk_id}"

    # swif2 add-job -workflow "${WORKFLOW}" \
    #     -partition "${PARTITION}" \
    #     -name "${jobname}" \
    #     -cores "${SKIM_CORES}" \
    #     -disk "${SKIM_DISK}" \
    #     -ram "${SKIM_RAM}" \
    #     "${SKIM_WRAPPER}" \
    #     "${MODE}" \
    #     "${chunk_id}" \
    #     "${chunkfile}" \
    #     "${outfile}"

    swif2 add-job -workflow "${WORKFLOW}" \
        -partition "${PARTITION}" \
        -phase 1 \
        -name "${jobname}" \
        -cores "${SKIM_CORES}" \
        -disk "${SKIM_DISK}" \
        -ram "${SKIM_RAM}" \
        "${SKIM_WRAPPER}" \
        "${MODE}" \
        "${chunk_id}" \
        "${chunkfile}" \
        "${outfile}"
        

    i=$((i+1))
done

echo "Added ${i} skim jobs"

# ============================================================
# Add final job
# ============================================================
#
# IMPORTANT:
# SWIF2 supports phased ordering / dependencies, but the exact CLI flag can
# vary by installation. If your swif2 has a phase option, set final job to
# phase 2 and skim jobs to phase 1.
#
# Since we already had trouble with site-specific -input/-output syntax,
# the safest first version is to add the final job but NOT run it until
# skim jobs are done.
# ============================================================

FINAL_JOBNAME="merge_analysis_plot"

# swif2 add-job -workflow "${WORKFLOW}" \
#     -partition "${PARTITION}" \
#     -name "${FINAL_JOBNAME}" \
#     -cores "${FINAL_CORES}" \
#     -disk "${FINAL_DISK}" \
#     -ram "${FINAL_RAM}" \
#     "${FINAL_WRAPPER}"

swif2 add-job -workflow "${WORKFLOW}" \
    -partition "${PARTITION}" \
    -phase 2 \
    -name "${FINAL_JOBNAME}" \
    -cores "${FINAL_CORES}" \
    -disk "${FINAL_DISK}" \
    -ram "${FINAL_RAM}" \
    "${FINAL_WRAPPER}"
    
echo "Added final merge-analysis-plot job: ${FINAL_JOBNAME}"

# ============================================================
# Start workflow
# ============================================================

echo "============================================================"
echo "Workflow created."
echo "============================================================"
echo "Recommended safe running:"
echo
echo "  swif2 run ${WORKFLOW}"
echo
echo "Then monitor:"
echo
echo "  swif2 status ${WORKFLOW}"
echo
echo "IMPORTANT:"
echo "  Because the final job has no dependency in this conservative script,"
echo "  you should pause/hold it or add phase/dependency syntax if your swif2 supports it."
echo
echo "Better workflow control:"
echo "  1. Add skim jobs as phase 1"
echo "  2. Add final job as phase 2"
echo "  3. Run phase 1 first"
echo "  4. Run phase 2 after all skims are done"
echo
echo "Check your exact installed syntax with:"
echo "  swif2 add-job -help | grep -i phase"
echo "  swif2 add-job -help | grep -i depend"
echo "============================================================"