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

# For an interactive node: srun -p gpu --gres=gpu:1 --pty bash -i
# To request a specific node: srun -p gpu --gres=gpu:rtx5000:1 --pty bash -i

# -------------------------------
# Load most recent sleap module
# ------------------------------
module load SLEAP

# ----------------------
# Input & output data
# ----------------------
PROJ_DIR=/ceph/neuroinformatics/neuroinformatics/sminano/video-compression/
INPUT_VIDEOS_LIST=(
    "$PROJ_DIR/input-videos/20190128_113421.mp4"
    "$PROJ_DIR/input-videos/20190128_113421_CRF17.mp4"
    "$PROJ_DIR/input-videos/20190128_113421_CRF34.mp4"
    "$PROJ_DIR/input-videos/20190128_113421_CRF51.mp4"
)

SLEAP_LABELS_REF_FILE="$PROJ_DIR/datasets/drosophila-melanogaster-courtship/courtship_labels.slp"
SLEAP_LABELS_DIR="$PROJ_DIR/input-labels"
mkdir -p $SLEAP_LABELS_DIR  # create if it doesnt exist

DATASQUASH_REPO="/ceph/scratch/sminano/DataSquash"

# Check len(list of input data) matches max SLURM_ARRAY_TASK_COUNT
# if not, exit
if [[ $SLURM_ARRAY_TASK_COUNT -ne ${#INPUT_VIDEOS_LIST[@]} ]]; then
    echo "The number of array tasks does not match the number of inputs"
    exit 1
fi

# -----------------------------------------------------
# Generate SLEAP label files linked to each video
# -----------------------------------------------------

labels_filename_no_ext="$(basename "$SLEAP_LABELS_REF_FILE" | sed 's/\(.*\)\..*/\1/')"

for i in {1..${SLURM_ARRAY_TASK_COUNT}}
do
    INPUT_VIDEO=${INPUT_VIDEOS_LIST[${SLURM_ARRAY_TASK_ID}]}
    video_filename="$(basename "$INPUT_VIDEO")"

    video_filename_no_ext="$(basename "$INPUT_VIDEO" | sed 's/\(.*\)\..*/\1/')"
    OUTPUT_LABELS_FILE="$labels_filename_no_ext"_$video_filename_no_ext.slp

    python -m "$DATASQUASH_REPO/video_compression/generate_label_files.py" \
        $SLEAP_LABELS_REF_FILE \
        $video_filename \
        $OUTPUT_LABELS_FILE

    # check .slp file and print to logs
    sleap-inspect "$OUTPUT_LABELS_FILE"

done


# # ----------------------------------------
# # Run training for each reencoded video
# # ----------------------------------------
# # - for a top-down pipeline, you’ll have a different profile for each of the models:
# #   centroid.json and centered_instance.json,
# # - for a bottom-up pipeline approach: multi_instance.json

# for i in {1..${SLURM_ARRAY_TASK_COUNT}}
# do
#     INPUT_VIDEO=${INPUT_VIDEOS_LIST[${SLURM_ARRAY_TASK_ID}]}
#     video_filename_no_ext="$(basename "$INPUT_VIDEO" | sed 's/\(.*\)\..*/\1/')"
#     echo "Input video: $INPUT_VIDEO"

#     # train sleap model
#     # OJO! vide-path is only checked if the video specified in .slp file is not accesible!

#     # centroid model
#     sleap-train \
#         baseline.centroid.json \
#         "$labels_filename_no_ext"_$video_filename_no_ext.slp \
#         --video-paths "$INPUT_VIDEO" \
#         --run_name $video_filename_no_ext \
#         --suffix "_centroid_model" \
#         --tensorboard

#     # centred instance model
#     sleap-train \
#         "$labels_filename_no_ext"_$video_filename_no_ext.slp \
#         --video-paths "$INPUT_VIDEO" \
#         --run_name $video_filename_no_ext \
#         --suffix "_centered_instance_model" \
#         --tensorboard

#     echo "Model trained on video: $OUTPUT_DIR/$OUTPUT_SUBDIR/$filename_no_ext.mp4"
#     echo "---"
# done
