#!/bin/bash

#SBATCH -p gpu # partition
#SBATCH -N 1   # number of nodes
#SBATCH --mem 64G # memory pool for all cores
#SBATCH -n 2 # number of cores
#SBATCH -t 3-00:00 # time (D-HH:MM)
#SBATCH --gres gpu:1 # request 1 GPU (of any kind)
#SBATCH -o slurm_array.%N.%A-%a.out
#SBATCH -e slurm_array.%N.%A-%a.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s.minano@ucl.ac.uk
#SBATCH --array=0-5%5


# NOTE on SBATCH command for array jobs
# with "SBATCH --array=0-n%m" ---> runs n separate jobs, but not more than m at a time.
# the number of array jobs should match the number of input files

# ----------------------
# Input & output data
# ----------------------
PROJ_DIR=/ceph/neuroinformatics/neuroinformatics/sminano/video-compression/
INPUT_VIDEO=datasets/drosophila-melanogaster-courtship/20190128_113421.mp4
OUTPUT_SUBDIR=reencoded-videos

CRF_VALUES=($(seq 5 5 25))
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
    REENCODED_VIDEO_PATH="$REENCODED_VIDEOS_DIR/$filename_no_ext"_RE.$reencoded_extension

    # Run ffmpeg with the corresponding crf value
    ffmpeg -version  # print version to logs
    ffmpeg -y -i "$SAMPLE" \
    -c:v libx264 \
    -pix_fmt yuv420p \
    -preset superfast \
    -crf "${CRF_VALUES[${SLURM_ARRAY_TASK_ID}]}" \  #15 \
    $REENCODED_VIDEO_PATH


    echo "Reencoded video: $REENCODED_VIDEO_PATH"
    echo "--------"


    # Reencoded videos log
    # copy .err file to go with reencoded video too if required
    # filename: {reencoded video name}.{slurm_array}.{slurm_job_id}
    # TODO: make a nicer log
    for ext in err out
    do
    cp slurm_array.$SLURMD_NODENAME.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext \
    /$REENCODED_VIDEOS_SUBDIR/"$filename_no_ext"_RE.slurm_array.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.$ext
    done

    # Frame extraction logs
    # Move logs for this job to subdir with extracted frames
    mv slurm_array.$SLURMD_NODENAME.$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID.{err,out} /$LOG_DIR

done