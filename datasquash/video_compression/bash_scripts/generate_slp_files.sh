#!/bin/bash

#SBATCH -p gpu # partition
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
INPUT_VIDEOS_JOB_ID="slurm_array.4468021"
INPUT_VIDEOS_DIR="$PROJ_DIR/input-videos/$INPUT_VIDEOS_JOB_ID"
INPUT_VIDEOS_LIST=(
    "$INPUT_VIDEOS_DIR/20190128_113421.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF17.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF34.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF51.mp4"
)

# labels directory
SLEAP_LABELS_DIR="$PROJ_DIR/input-labels/slurm_array.$SLURM_ARRAY_JOB_ID"
SLEAP_LABELS_REF_FILE="$PROJ_DIR/datasets/drosophila-melanogaster-courtship/courtship_labels.slp"
LABELS_REF_FILENAME_NO_EXT="$(basename "$SLEAP_LABELS_REF_FILE" | sed 's/\(.*\)\..*/\1/')"
mkdir -p $SLEAP_LABELS_DIR  # create directory if it doesn't exist

# logs directory
LOG_DIR=$SLEAP_LABELS_DIR/logs
mkdir -p $LOG_DIR  # create if it doesnt exist

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

# Print job ID that generated the input videos
echo "Input videos generated in SLURM job ID $INPUT_VIDEOS_JOB_ID"
echo  "---------"

for i in {1..${SLURM_ARRAY_TASK_COUNT}}
do
    # input video
    INPUT_VIDEO=${INPUT_VIDEOS_LIST[${SLURM_ARRAY_TASK_ID}]}
    VIDEO_FILENAME="$(basename "$INPUT_VIDEO")"
    VIDEO_FILENAME_NO_EXT="$(echo $VIDEO_FILENAME | sed 's/\(.*\)\..*/\1/')"

    echo "Input video: $INPUT_VIDEO"
    echo "--------"

    # output labels file
    OUTPUT_LABELS_FILE="$SLEAP_LABELS_DIR/$LABELS_REF_FILENAME_NO_EXT"_$VIDEO_FILENAME_NO_EXT.slp
    OUTPUT_LABELS_NO_EXT="$(echo $OUTPUT_LABELS_FILE | sed 's/\(.*\)\..*/\1/')"

    # generate labels file for current video
    python "$DATASQUASH_REPO/datasquash/video_compression/generate_label_files.py" \
        $SLEAP_LABELS_REF_FILE \
        $VIDEO_FILENAME \
        $OUTPUT_LABELS_FILE

    # collect status of previous command
    STATUS_GENERATE_SLP_FILE=$?

    # if successful: print to logs
    # TODO: should this be in pytest instead?
    if [[ "$STATUS_GENERATE_SLP_FILE" -eq 0 ]] ; then

        # print to logs
        echo "SLEAP labels file generated for $INPUT_VIDEO: $OUTPUT_LABELS_FILE"
        echo "--------"

        # get filename from sleap-inspect output
        SLEAP_INSPECT_OUTPUT=$(sleap-inspect $OUTPUT_LABELS_FILE)

        # TODO: refactor this section
        SLEAP_INSPECT_OUTPUT=$(sleap-inspect "$OUTPUT_LABELS_FILE")
        VIDEO_FILENAME_FROM_INSPECT=$(grep -A1 "Video files" <<< $SLEAP_INSPECT_OUTPUT)
        VIDEO_FILENAME_FROM_INSPECT=$(tail -n 1 <<< $VIDEO_FILENAME_FROM_INSPECT)  # get line after "Video files"
        VIDEO_FILENAME_FROM_INSPECT="$(echo $VIDEO_FILENAME_FROM_INSPECT | sed 's/ //g')"  # remove spaces

        # print check
        if [[ "$VIDEO_FILENAME_FROM_INSPECT" == "$VIDEO_FILENAME" ]]; then
            echo "Output from sleap-inspect matches input filename $VIDEO_FILENAME_FROM_INSPECT"
        else
            echo "Output from sleap-inspect ($VIDEO_FILENAME_FROM_INSPECT) DOES NOT match input filename ($VIDEO_FILENAME)"
        fi
    else
        echo "Generation of .slp files FAILED for $INPUT_VIDEO"
    fi

    # move logs
    for ext in err out
        do
            mv slurm_array.$SLURMD_NODENAME.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext \
            /$LOG_DIR/$(basename "$OUTPUT_LABELS_NO_EXT").slurm_array.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext
        done



done
