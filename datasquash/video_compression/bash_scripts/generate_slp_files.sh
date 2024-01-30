#!/bin/bash

#SBATCH -p cpu # partition
#SBATCH -N 1   # number of nodes
#SBATCH --mem 64G # memory pool for all cores
#SBATCH -n 2 # number of cores
#SBATCH -t 3-00:00 # time (D-HH:MM)
#SBATCH -o slurm_array.%N.%A-%a.out
#SBATCH -e slurm_array.%N.%A-%a.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s.minano@ucl.ac.uk
#SBATCH --array=0-3%4


# -----------------------------
# Error settings for bash
# -----------------------------
# see https://wizardzines.com/comics/bash-errors/
set -e  # do not continue after errors
set -u  # throw error if variable is unset
set -o pipefail  # make the pipe fail if any part of it fails

# -------------------------------
# Load most recent sleap module
# ------------------------------
module load SLEAP

# ----------------------
# Input & output data
# ----------------------
PROJ_DIR=/ceph/neuroinformatics/neuroinformatics/sminano/video-compression/

# input videos
INPUT_VIDEOS_DIR="$PROJ_DIR/input-videos"
INPUT_VIDEOS_LIST=(
    "$INPUT_VIDEOS_DIR/20190128_113421.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF17.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF34.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF51.mp4"
)

# labels directory
SLEAP_LABELS_DIR="$PROJ_DIR/input-labels"
SLEAP_LABELS_REF_FILE="$PROJ_DIR/datasets/drosophila-melanogaster-courtship/courtship_labels.slp"
labels_ref_filename_no_ext="$(basename "$SLEAP_LABELS_REF_FILE" | sed 's/\(.*\)\..*/\1/')"
mkdir -p $SLEAP_LABELS_DIR  # create directory if it doesn't exist

# repository location
DATASQUASH_REPO="/ceph/scratch/sminano/DataSquash"

# ----------------------
# Input data checks
# ----------------------
# Check len(list of input data) matches max SLURM_ARRAY_TASK_COUNT
# if not, exit
if [[ $SLURM_ARRAY_TASK_COUNT -ne ${#INPUT_VIDEOS_LIST[@]} ]]; then
    echo "The number of array tasks does not match the number of input videos"
    exit 1
fi

# ---------------------------------------------
# Generate SLEAP label files for each video
# ----------------------------------------------

for i in {1..${SLURM_ARRAY_TASK_COUNT}}
do
    # input video
    INPUT_VIDEO=${INPUT_VIDEOS_LIST[${SLURM_ARRAY_TASK_ID}]}
    video_filename="$(basename "$INPUT_VIDEO")"

    # output labels file
    video_filename_no_ext="$(echo $video_filename | sed 's/\(.*\)\..*/\1/')"
    OUTPUT_LABELS_FILE="$SLEAP_LABELS_DIR/$labels_ref_filename_no_ext"_$video_filename_no_ext.slp

    # generate labels file for current video
    python "$DATASQUASH_REPO/datasquash/video_compression/generate_label_files.py" \
        $SLEAP_LABELS_REF_FILE \
        $video_filename \
        $OUTPUT_LABELS_FILE

    # check .slp file and print to logs
    sleap-inspect "$OUTPUT_LABELS_FILE"

    # check if successful

done