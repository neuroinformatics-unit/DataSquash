#!/bin/bash

#SBATCH -p gpu # partition
#SBATCH -N 1   # number of nodes
#SBATCH --mem 64G # memory pool for all cores
#SBATCH -n 2 # number of cores
#SBATCH -t 3-00:00 # time (D-HH:MM)
#SBATCH --gres gpu:rtx5000:1 # request 1 GPU RTX5000
#SBATCH -o slurm_array.%N.%A-%a.out
#SBATCH -e slurm_array.%N.%A-%a.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s.minano@ucl.ac.uk
#SBATCH --array=0-3%4

# Refs:
# - https://sleap.ai/notebooks/Training_and_inference_on_an_example_dataset.html
# - https://sleap.ai/notebooks/Model_evaluation.html
# - https://sleap.ai/guides/cli.html#sleap-train


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
INPUT_VIDEOS_JOB_ID="slurm_array.4468024"
INPUT_VIDEOS_DIR="$PROJ_DIR/input-videos/$INPUT_VIDEOS_JOB_ID"
INPUT_VIDEOS_LIST=(
    "$INPUT_VIDEOS_DIR/20190128_113421.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF17.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF34.mp4"
    "$INPUT_VIDEOS_DIR/20190128_113421_CRF51.mp4"
)

# input labels
SLEAP_LABELS_JOB_ID="slurm_array.4468963"
SLEAP_LABELS_DIR="$PROJ_DIR/input-labels/$SLEAP_LABELS_JOB_ID"
SLEAP_LABELS_REF_FILE="$PROJ_DIR/datasets/drosophila-melanogaster-courtship/courtship_labels.slp"
LABELS_REF_FILENAME_NO_EXT="$(basename "$SLEAP_LABELS_REF_FILE" | sed 's/\(.*\)\..*/\1/')"

# output models directory
MODELS_DIR=$PROJ_DIR/models/slurm_array.$SLURM_ARRAY_JOB_ID
mkdir -p $MODELS_DIR  # create if it doesnt exist

# logs directory
LOG_DIR=$MODELS_DIR/logs
mkdir -p $LOG_DIR  # create if it doesnt exist

# ----------------------
# Input data checks
# ----------------------
# Check len(list of input data) matches max SLURM_ARRAY_TASK_COUNT
# if not, exit
if [[ $SLURM_ARRAY_TASK_COUNT -ne ${#INPUT_VIDEOS_LIST[@]} ]]; then
    echo "The number of array tasks does not match the number of inputs"
    exit 1
fi

# Create a directory for the SLEAP output of this run
SLEAP_OUTPUT_TMP_DIR=slurm_array.$SLURM_ARRAY_JOB_ID
mkdir $SLEAP_OUTPUT_TMP_DIR
cd $SLEAP_OUTPUT_TMP_DIR


# ------------------------------------------------------
# Train a topdown SLEAP model for each reencoded video
# ------------------------------------------------------
# Print job ID that generated the compressed videos and labels
echo "Compressed videos were generated in job with ID $INPUT_VIDEOS_JOB_ID"
echo "SLEAP label files were generated in job with ID $SLEAP_LABELS_JOB_ID"
echo  "---------"

for i in {1..${SLURM_ARRAY_TASK_COUNT}}
do
    # input video
    INPUT_VIDEO=${INPUT_VIDEOS_LIST[${SLURM_ARRAY_TASK_ID}]}
    VIDEO_FILENAME_NO_EXT="$(basename "$INPUT_VIDEO" | sed 's/\(.*\)\..*/\1/')"
    echo "Input video: $INPUT_VIDEO"

    # train centroid model
    # TODO: --video-paths maybe "$PROJ_DIR/input-videos/ instead?
    sleap-train \
        baseline.centroid.json \
        "$SLEAP_LABELS_DIR/$LABELS_REF_FILENAME_NO_EXT"_$VIDEO_FILENAME_NO_EXT.slp \
        --video-paths "$INPUT_VIDEO" \
        --run_name $VIDEO_FILENAME_NO_EXT \
        --suffix "_centroid_model" \
        --tensorboard

    # collect status of previous command
    status_sleap_train_centroid=$?

    # print success to logs
    if [[ "$status_sleap_train_centroid" -eq 0 ]] ; then
        echo "Centroid model training complete"
        echo "---"
    else
        echo "ERROR training centroid model"
        echo "---"
    fi


    # train centred instance model
    sleap-train \
        baseline_medium_rf.topdown.json \
        "$SLEAP_LABELS_DIR/$LABELS_REF_FILENAME_NO_EXT"_$VIDEO_FILENAME_NO_EXT.slp \
        --video-paths "$INPUT_VIDEO" \
        --run_name $VIDEO_FILENAME_NO_EXT \
        --suffix "_centered_instance_model" \
        --tensorboard

    # collect status of previous command
    status_sleap_train_centered_instance=$?

    # print success to logs
    if [[ "$status_sleap_train_centered_instance" -eq 0 ]] ; then
        echo "Centered instance model training complete"
        echo "---"
    else
        echo "ERROR training centered instance model"
        echo "---"
    fi


    # move models folder across
    # use rsync to merge each job in array with potentially pre-existing folder
    rsync -a models/ $MODELS_DIR/

    # move logs across
    for ext in err out
        do
            mv slurm_array.$SLURMD_NODENAME.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext \
            /$LOG_DIR/$VIDEO_FILENAME_NO_EXT.slurm_array.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext
        done

done

# Delete SLEAP temporary output directory (ok?)
cd ..
rm -rf $SLEAP_OUTPUT_TMP_DIR
