#!/bin/bash

# ============================================================
# submit_genrp_full_chain_swif2.sh
#
# Submit the full GEnRP analysis chain as ONE swif2 job:
#
#   
============================================================
Adding swif2 job
============================================================
ERROR Bad Request: Option 'input' is missing an argument_GEnRP.C
#       -> SkimGEnRP.C
#       -> GEnRPAnalysis.C
#       -> PlotGEnRP.C
#
# This script:
#   1. Creates the actual swif2 job wrapper script
#   2. Creates the swif2 workflow
#   3. Adds one job with resource requests
#   4. Runs the workflow
#   5. Prints workflow status
# ============================================================

set -e

# ============================================================
# User configuration
# ============================================================

WORKFLOW="genrp_full_chain_PASS1"
JOBNAME="genrp_full_chain"

WORKDIR="/work/halla/sbs/bhasitha/GENRP_ANALYSIS/PASS1/ChExAnalysis"

SCRIPT="${WORKDIR}/run_genrp_full_chain_swif2.sh"

# Resource requests
PARTITION="production"
CORES="1"
DISK="45GB"
RAM="6000MB"

# If your swif2 supports -time and you want to request time, uncomment this.
# TIME="12h"

# Expected output files
SKIM_ROOT="${WORKDIR}/hist/skimh/skim_genrp_PASS1.root"
ANALYSIS_ROOT="${WORKDIR}/hist/skim_genrp_PASS1.root"
FINAL_PDF="${WORKDIR}/pdf/skim_genrp_PASS1.pdf"

# ============================================================
# Basic checks
# ============================================================

if [ ! -d "${WORKDIR}" ]; then
    echo "ERROR: WORKDIR does not exist:"
    echo "  ${WORKDIR}"
    exit 1
fi

cd "${WORKDIR}"

echo "============================================================"
echo "Preparing full-chain swif2 submission"
echo "WORKFLOW = ${WORKFLOW}"
echo "JOBNAME  = ${JOBNAME}"
echo "WORKDIR  = ${WORKDIR}"
echo "SCRIPT   = ${SCRIPT}"
echo "============================================================"

mkdir -p "${WORKDIR}/hist"
mkdir -p "${WORKDIR}/hist/skimh"
mkdir -p "${WORKDIR}/pdf"
mkdir -p "${WORKDIR}/log"

# ============================================================
# Create the wrapper script that runs inside the swif2 job
# ============================================================

cat > "${SCRIPT}" << 'EOF'
#!/bin/bash

echo "============================================================"
echo "Starting full GEnRP chain inside swif2 job"
echo "Host: $(hostname)"
echo "Start time: $(date)"
echo "PWD at start: $(pwd)"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"
echo "SWIF_JOB_WORK_DIR: ${SWIF_JOB_WORK_DIR}"
echo "============================================================"

# ============================================================
# Environment setup
# ============================================================

echo "============================================================"
echo "Setting up environment"
echo "============================================================"

module use /group/halla/modulefiles

# Load ROOT
module load root/6.36.08

# Hall A analyzer
export ANALYZER=/work/halla/sbs/sbs-gen/pass3/ANALYZER/install
source "${ANALYZER}/bin/setup.sh"

# SBS / GEnRP paths
export SBS_REPLAY=/work/halla/sbs/sbs-gen/GENRP/SBS-replay
export SBS=/work/halla/sbs/sbs-gen/GENRP/SBS_OFFLINE/install

# SBS offline environment
source "${SBS}/bin/sbsenv.sh"

# Databases and raw-data paths
export DB_DIR="${SBS_REPLAY}/DB"
export DATA_DIR=/cache/mss/halla/sbs/GEnRP/raw
export ANALYZER_CONFIGPATH="${SBS_REPLAY}/replay"

echo "Environment variables:"
echo "  ANALYZER=${ANALYZER}"
echo "  SBS_REPLAY=${SBS_REPLAY}"
echo "  SBS=${SBS}"
echo "  DB_DIR=${DB_DIR}"
echo "  DATA_DIR=${DATA_DIR}"
echo "  ANALYZER_CONFIGPATH=${ANALYZER_CONFIGPATH}"

echo "ROOT check:"
which root || {
    echo "ERROR: root not found"
    exit 1
}
root-config --version || true

echo "pdfunite check:"
which pdfunite || echo "WARNING: pdfunite not found"

# ============================================================
# Go to analysis directory
# ============================================================

WORKDIR="/work/halla/sbs/bhasitha/GENRP_ANALYSIS/PASS1/ChExAnalysis"

cd "${WORKDIR}" || {
    echo "ERROR: Cannot cd to ${WORKDIR}"
    exit 1
}

echo "Now in WORKDIR:"
pwd

mkdir -p hist
mkdir -p hist/skimh
mkdir -p pdf
mkdir -p log

# ============================================================
# Copy .rootrc
# ============================================================

echo "============================================================"
echo "Copying .rootrc"
echo "============================================================"

ROOTRC_SOURCE="${SBS}/run_replay_here/.rootrc"

if [ -f "${ROOTRC_SOURCE}" ]; then

    if [ -n "${SWIF_JOB_WORK_DIR}" ] && [ -d "${SWIF_JOB_WORK_DIR}" ]; then
        cp "${ROOTRC_SOURCE}" "${SWIF_JOB_WORK_DIR}/.rootrc"
        echo "Copied .rootrc to ${SWIF_JOB_WORK_DIR}/.rootrc"
    else
        echo "WARNING: SWIF_JOB_WORK_DIR is not set or does not exist"
    fi

    cp "${ROOTRC_SOURCE}" "${WORKDIR}/.rootrc"
    echo "Copied .rootrc to ${WORKDIR}/.rootrc"

else
    echo "WARNING: Could not find ${ROOTRC_SOURCE}"
fi

# ============================================================
# Check required macros
# ============================================================

echo "============================================================"
echo "Checking required macros"
echo "============================================================"

ls -lh SkimGEnRP.C || {
    echo "ERROR: SkimGEnRP.C not found"
    exit 1
}

ls -lh GEnRPAnalysis.C || {
    echo "ERROR: GEnRPAnalysis.C not found"
    exit 1
}

ls -lh PlotGEnRP.C || {
    echo "ERROR: PlotGEnRP.C not found"
    exit 1
}

ls -lh run_all_GEnRP.C || {
    echo "ERROR: run_all_GEnRP.C not found"
    exit 1
}

# ============================================================
# Run ROOT chain
# ============================================================

echo "============================================================"
echo "Running ROOT macro: run_all_GEnRP.C"
echo "============================================================"

root -l -b -q run_all_GEnRP.C

RET=$?

echo "============================================================"
echo "ROOT finished"
echo "Exit code: ${RET}"
echo "End time: $(date)"
echo "============================================================"

# ============================================================
# Check outputs
# ============================================================

echo "============================================================"
echo "Checking output files"
echo "============================================================"

echo "Skim output:"
ls -lh hist/skimh/*.root 2>/dev/null || echo "No ROOT files found in hist/skimh"

echo "Analysis output:"
ls -lh hist/*.root 2>/dev/null || echo "No ROOT files found in hist"

echo "PDF output:"
ls -lh pdf/*.pdf 2>/dev/null || echo "No PDF files found in pdf"

exit ${RET}
EOF

chmod +x "${SCRIPT}"

echo "Created swif2 job wrapper:"
ls -lh "${SCRIPT}"

# ============================================================
# Define swif2 input/output strings
# ============================================================

# inputstring=""
# inputstring+=" -input ${WORKDIR}/run_all_GEnRP.C"
# inputstring+=" -input ${WORKDIR}/SkimGEnRP.C"
# inputstring+=" -input ${WORKDIR}/GEnRPAnalysis.C"
# inputstring+=" -input ${WORKDIR}/PlotGEnRP.C"
inputstring=""

# outputstring=""
# outputstring+=" -output ${SKIM_ROOT}"
# outputstring+=" -output ${ANALYSIS_ROOT}"
# outputstring+=" -output ${FINAL_PDF}"
outputstring=""

# ============================================================
# Create swif2 workflow
# ============================================================

echo "============================================================"
echo "Creating swif2 workflow"
echo "============================================================"

swif2 create "${WORKFLOW}" || true

# ============================================================
# Add one swif2 job
# ============================================================

echo "============================================================"
echo "Adding swif2 job"
echo "============================================================"

echo " inputstring: ${inputstring}"

# swif2 add-job -workflow "${WORKFLOW}" \
#     -partition "${PARTITION}" \
#     -name "${JOBNAME}" \
#     -cores "${CORES}" \
#     -disk "${DISK}" \
#     -ram "${RAM}" \
#     ${inputstring} \
#     ${outputstring} \
#     "${SCRIPT}"
swif2 add-job -workflow "${WORKFLOW}" \
    -partition "${PARTITION}" \
    -name "${JOBNAME}" \
    -cores "${CORES}" \
    -disk "${DISK}" \
    -ram "${RAM}" \
    "${SCRIPT}"

# If your swif2 supports -time, use this version instead:
#
# swif2 add-job -workflow "${WORKFLOW}" \
#     -partition "${PARTITION}" \
#     -name "${JOBNAME}" \
#     -cores "${CORES}" \
#     -disk "${DISK}" \
#     -ram "${RAM}" \
#     -time "${TIME}" \
#     ${inputstring} \
#     ${outputstring} \
#     "${SCRIPT}"

# ============================================================
# Run workflow
# ============================================================

echo "============================================================"
echo "Running workflow"
echo "============================================================"

swif2 run "${WORKFLOW}"

# ============================================================
# Show status
# ============================================================

echo "============================================================"
echo "Workflow status"
echo "============================================================"

swif2 status "${WORKFLOW}"

echo "============================================================"
echo "Submission complete"
echo "Workflow: ${WORKFLOW}"
echo "Job name: ${JOBNAME}"
echo "Resources:"
echo "  partition = ${PARTITION}"
echo "  cores     = ${CORES}"
echo "  disk      = ${DISK}"
echo "  ram       = ${RAM}"
echo "Expected outputs:"
echo "  ${SKIM_ROOT}"
echo "  ${ANALYSIS_ROOT}"
echo "  ${FINAL_PDF}"
echo "============================================================"