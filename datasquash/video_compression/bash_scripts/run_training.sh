#!/bin/bash

#SBATCH -p gpu # partition
#SBATCH -N 1   # number of nodes
#SBATCH --mem 64G # memory pool for all cores
#SBATCH -n 2 # number of cores
#SBATCH -t 3-00:00 # time (D-HH:MM)
#SBATCH --gres gpu:1 # request 1 GPU (of any kind) -- select a specific one?
#SBATCH -o slurm_array.%N.%A-%a.out
#SBATCH -e slurm_array.%N.%A-%a.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=s.minano@ucl.ac.uk
#SBATCH --array=0-2%4

# Refs:
# - https://sleap.ai/notebooks/Training_and_inference_on_an_example_dataset.html
# - https://sleap.ai/notebooks/Model_evaluation.html
# - https://sleap.ai/guides/cli.html#sleap-train

# For an interactive node: srun -p gpu --gres=gpu:1 --pty bash -i
# To request a specific node: srun -p gpu --gres=gpu:rtx5000:1 --pty bash -i

# -------------------------------
# Load most recent sleap module
# ------------------------------
module load SLEAP

# ----------------------
# Input & output data
# ----------------------
# TODO: get all video files in one directory?
PROJ_DIR=/ceph/neuroinformatics/neuroinformatics/sminano/video-compression/
# REENCODED_VIDEOS_DIR=$PROJ_DIR/reencoded-videos
INPUT_VIDEOS_LIST=(
    "$PROJ_DIR/datasets/drosophila-melanogaster-courtship/20190128_113421.mp4"
    "$PROJ_DIR/reencoded-videos/20190128_113421_CRF17.mp4"
    "$PROJ_DIR/reencoded-videos/20190128_113421_CRF34.mp4"
    "$PROJ_DIR/reencoded-videos/20190128_113421_CRF51.mp4"
)

# Check len(list of input data) matches max SLURM_ARRAY_TASK_COUNT
# if not, exit
if [[ $SLURM_ARRAY_TASK_COUNT -ne ${#INPUT_VIDEOS_LIST[@]} ]]; then
    echo "The number of array tasks does not match the number of inputs"
    exit 1
fi

# ----------------------------------------
# Run training for each reencoded video
# ----------------------------------------
# - for a top-down pipeline, you’ll have a different profile for each of the models: 
#   centroid.json and centered_instance.json,
# - for a bottom-up pipeline approach: multi_instance.json 

for i in {1..${SLURM_ARRAY_TASK_COUNT}}
do
    INPUT_VIDEO=${INPUT_VIDEOS_LIST[${SLURM_ARRAY_TASK_ID}]}
    # filename_no_ext="$(basename "$INPUT_VIDEO" | sed 's/\(.*\)\..*/\1/')"
    echo "Input video: $INPUT_VIDEO"

    # train sleap model
    # OJO! vide-path is only checked if the video specified in .slp file is not accesible!
    sleap-train \
        multi_instance.json \  # training_job_path
        "dataset/drosophila-melanogaster-courtship/courtship_labels.slp" \  # labels
        --video-paths "$INPUT_VIDEO"
        --run_name
        --prefix
        --suffix
        --tensorboard

    echo "Reencoded video: $OUTPUT_DIR/$OUTPUT_SUBDIR/$filename_no_ext.mp4"
    echo "---"
done

# # bottom up
# # multi_instance.json \  #----> ok?
# sleap-train \
#     multi_instance.json \
#     "dataset/drosophila-melanogaster-courtship/courtship_labels.slp" \
#     --run_name "courtship.centroid" \
#     --video-paths "dataset/drosophila-melanogaster-courtship/20190128_113421.mp4"


# # centroid model
# sleap-train \
#     baseline.centroid.json \
#     "dataset/drosophila-melanogaster-courtship/courtship_labels.slp" \
#     --run_name "courtship.centroid" \
#     --video-paths "dataset/drosophila-melanogaster-courtship/20190128_113421.mp4"


# # centred instance model
# sleap-train \
#     baseline_medium_rf.topdown.json \
#     "dataset/drosophila-melanogaster-courtship/courtship_labels.slp" \
#     --run_name "courtship.topdown_confmaps" \
#     --video-paths "dataset/drosophila-melanogaster-courtship/20190128_113421.mp4"