#!/bin/bash
# Refs:
# - https://sleap.ai/notebooks/Training_and_inference_on_an_example_dataset.html
# - https://sleap.ai/notebooks/Model_evaluation.html
# - https://sleap.ai/guides/cli.html#sleap-train


# Module load sleap


# Run training for each reencoded video
# - for a top-down pipeline, you’ll have a different profile for each of the models:
#   centroid.json and centered_instance.json,
# - for a bottom-up pipeline approach: multi_instance.json

# bottom up
sleap-train \
    multi_instance.json \  #----> ok?
    "dataset/drosophila-melanogaster-courtship/courtship_labels.slp" \
    --run_name "courtship.centroid" \
    --video-paths "dataset/drosophila-melanogaster-courtship/20190128_113421.mp4"


# centroid model
sleap-train \
    baseline.centroid.json \
    "dataset/drosophila-melanogaster-courtship/courtship_labels.slp" \
    --run_name "courtship.centroid" \
    --video-paths "dataset/drosophila-melanogaster-courtship/20190128_113421.mp4"


# centred instance model
sleap-train \
    baseline_medium_rf.topdown.json \
    "dataset/drosophila-melanogaster-courtship/courtship_labels.slp" \
    --run_name "courtship.topdown_confmaps" \
    --video-paths "dataset/drosophila-melanogaster-courtship/20190128_113421.mp4"
