#!/bin/bash

#SBATCH -p gpu # partitions: cpu, gpu, fast, medium
#SBATCH -N 1   # number of nodes
#SBATCH --mem 64G # memory pool for all cores
#SBATCH -n 2 # number of cores
#SBATCH -t 3-00:00 # time (D-HH:MM)
#SBATCH --gres gpu:0 # request NO GPUs
#SBATCH -o slurm_array.%N.%A-%a.out
#SBATCH -e slurm_array.%N.%A-%a.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s.minano@ucl.ac.uk
#SBATCH --array=0-2%4


# NOTE on SBATCH command for array jobs
# with "SBATCH --array=0-n%m" ---> runs n separate jobs, but not more than m at a time.
# the number of array jobs should match the number of input files

# Refs:
# - https://sleap.ai/help.html#does-my-data-need-to-be-in-a-particular-format


# -----------------------------
# Error settings for bash
# -----------------------------
# see https://wizardzines.com/comics/bash-errors/
set -e  # do not continue after errors
set -u  # throw error if variable is unset
set -o pipefail  # make the pipe fail if any part of it fails


# ----------------------
# Input & output data
# ----------------------
PROJ_DIR=/ceph/neuroinformatics/neuroinformatics/sminano/video-compression/

# input videos
INPUT_VIDEO=$PROJ_DIR/input-videos/20190128_113421.mp4

# output directory (location of reencoded videos)
REENCODED_VIDEOS_DIR=$PROJ_DIR/input-videos/slurm_array.$SLURM_ARRAY_JOB_ID
mkdir -p $REENCODED_VIDEOS_DIR # create if it doesnt exist

# logs directory
LOG_DIR=$REENCODED_VIDEOS_DIR/logs
mkdir -p $LOG_DIR  # create if it doesnt exist

# whether to copy the raw video to the output directory
FLAG_COPY_RAW_TO_REENCODED_DIR=true

# ----------------------
# Encoding parameters
# ----------------------
CRF_VALUES=($(seq 17 17 51))


# ----------------------
# Input data checks
# ----------------------
# Check len(list of input crf values) matches max SLURM_ARRAY_TASK_COUNT
# if not, exit
if [[ $SLURM_ARRAY_TASK_COUNT -ne ${#CRF_VALUES[@]} ]]; then
    echo "The number of array tasks does not match the number of crf inputs"
    exit 1
fi


# ----------------------------------------------------
# Compress input video with different values of crf
# ----------------------------------------------------
for i in {1..${SLURM_ARRAY_TASK_COUNT}}
do
    # Input video
    echo "Input video: $INPUT_VIDEO"
    echo "--------"

    # Path to reencoded video
    FILENAME_NO_EXT="$(basename "$INPUT_VIDEO" | sed 's/\(.*\)\..*/\1/')" # filename without extension
    FILENAME_OUT_NO_EXT="$FILENAME_NO_EXT"_CRF"${CRF_VALUES[${SLURM_ARRAY_TASK_ID}]}"
    REENCODED_VIDEO_PATH_MP4="$REENCODED_VIDEOS_DIR/$FILENAME_OUT_NO_EXT".mp4  # must be .mp4

    # Print current node
    echo "SLURM node: $SLURMD_NODENAME"
    echo "--------"

    # Print ffmpeg version to logs
    ffmpeg -version

    # Print ffprobe to logs
    # TODO: check/extract properties of initial video (8-bit vs 10-bit, rgb vs greyscale)
    ffprobe -v error -show_streams $INPUT_VIDEO

    # Run compression with the corresponding CRF value
    # - c:v: specify codec for the video stream
    #   (decoder if used in front of input, encoder if used in front of output).
    # - libx264: sets the video compression to use H264. If RGB, use libx264rgb
    # - preset superfast: sets a number of parameters that pressumably enable reliable seeking
    # - c:a # keep audio stream as is if present
    ffmpeg -i "$INPUT_VIDEO" \
    -c:v libx264 \
    -pix_fmt yuv420p \
    -preset superfast \
    -crf "${CRF_VALUES[${SLURM_ARRAY_TASK_ID}]}" \
    -c:a copy \
    "$REENCODED_VIDEO_PATH_MP4"

    # collect status of previous command
    STATUS_FFMPEG_COMPRESS=$?


    # print only if previous command is successful
    if [[ "$STATUS_FFMPEG_COMPRESS" -eq 0 ]] ; then
        echo "Reencoded video: $REENCODED_VIDEO_PATH_MP4"
        echo "--------"
    else
        echo "ERROR reencoding video: $REENCODED_VIDEO_PATH_MP4"
        echo "--------"
    fi

    # Move logs across
    for ext in err out
        do
            mv slurm_array.$SLURMD_NODENAME.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext \
            /$LOG_DIR/"$FILENAME_OUT_NO_EXT".slurm_array.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext
        done

done

# ----------------------------------------------------
# Copy input video to output directoy if required
# ----------------------------------------------------
if [ "$FLAG_COPY_RAW_TO_REENCODED_DIR" = true ]; then
    cp $INPUT_VIDEO $REENCODED_VIDEOS_DIR/
fi
