#!/bin/bash

#SBATCH -p gpu # partition: cpu, gpu, fast, medium
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

# ----------------------
# Input & output data
# ----------------------
PROJ_DIR=/ceph/neuroinformatics/neuroinformatics/sminano/video-compression/
INPUT_VIDEO=$PROJ_DIR/datasets/drosophila-melanogaster-courtship/20190128_113421.mp4
OUTPUT_SUBDIR=reencoded-videos

CRF_VALUES=($(seq 17 17 51))
# Check len(list of input crf values) matches max SLURM_ARRAY_TASK_COUNT
# if not, exit
if [[ $SLURM_ARRAY_TASK_COUNT -ne ${#CRF_VALUES[@]} ]]; then
    echo "The number of array tasks does not match the number of crf inputs"
    exit 1
fi


# location of SLURM logs
LOG_DIR=$PROJ_DIR/logs
mkdir -p $LOG_DIR  # create if it doesnt exist

# set location of reencoded videos 
REENCODED_VIDEOS_DIR=$PROJ_DIR/$OUTPUT_SUBDIR
mkdir -p $REENCODED_VIDEOS_DIR # create if it doesnt exist


# ----------------------------------------
# Compress with different values of crf
# --------------------------------------------
for i in {1..${SLURM_ARRAY_TASK_COUNT}}
do
    # Input video
    SAMPLE=$INPUT_VIDEO
    echo "Input video: $SAMPLE"
    echo "--------"

    # Reencode video following SLEAP's recommendations
    # https://sleap.ai/help.html#does-my-data-need-to-be-in-a-particular-format
    echo "Rencoding ...."

    # Path to reencoded video
    filename_no_ext="$(basename "$SAMPLE" | sed 's/\(.*\)\..*/\1/')" # filename without extension
    filename_out_no_ext="$filename_no_ext"_CRF"${CRF_VALUES[${SLURM_ARRAY_TASK_ID}]}"  
    REENCODED_VIDEO_PATH_MP4="$REENCODED_VIDEOS_DIR/$filename_out_no_ext".mp4  # must be .mp4?

    # Print ffmpeg version to logs
    ffmpeg -version 

    # Print ffprobe to logs, check properties of initial video?
    ffprobe -v error -show_streams $SAMPLE

    # Run ffmpeg with the corresponding crf value
    # - y: Overwrite output files without asking.
    # - c:v codec for the video stream (decoder if used in front of input, encoder if used in front of output). 
    # - libx264: Sets the video compression to use H264. If RGB, use libx264rgb
    # - preset superfast: Sets a number of parameters that enable reliable seeking
    # - c:a # keep audio as is if present
    ffmpeg -y -i "$SAMPLE" \
    -c:v libx264 \
    -pix_fmt yuv420p \
    -preset superfast \
    -crf "${CRF_VALUES[${SLURM_ARRAY_TASK_ID}]}" \
    -c:a copy \
    $REENCODED_VIDEO_PATH_MP4


    echo "Reencoded video: $REENCODED_VIDEO_PATH_MP4"
    echo "--------"


    # Reencoded videos log
    # copy .err file to go with reencoded video too if required
    # filename: {reencoded video name}.{slurm_array}.{slurm_job_id}
    # TODO: make a nicer log
    for ext in err out
    do
    cp slurm_array.$SLURMD_NODENAME.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext \
    /$REENCODED_VIDEOS_SUBDIR/"$filename_out_no_ext".slurm_array.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext
    done

    # Frame extraction logs
    # Move logs for this job to subdir with extracted frames
    mv slurm_array.$SLURMD_NODENAME.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.{err,out} /$LOG_DIR

done