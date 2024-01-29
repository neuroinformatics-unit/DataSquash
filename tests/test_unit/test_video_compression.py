from pathlib import Path

import sleap

from datasquash.video_compression.generate_label_files import \
    overwrite_video_in_slp_file


def test_overwrite_video_in_slp_file(tmp_path: Path):
    # input data
    input_labels_path = str(
        Path(__file__).parents[1] / "data" / "courtship_labels.slp",
    )
    new_video_path = "TEST_VIDEO.mp4"
    output_labels_path = str(tmp_path / "courtship_labels_OUT.slp")

    # overwrite video in labels file
    overwrite_video_in_slp_file(
        input_labels_path,
        new_video_path,
        output_labels_path,
    )

    # check output labels file
    original_labels = sleap.Labels.load_file(str(input_labels_path))
    updated_labels = sleap.Labels.load_file(str(output_labels_path))

    # read sleap video from path for comparison
    sleap_video_from_file = sleap.Video.from_filename(new_video_path)
    sleap_video_from_file.backend._detect_grayscale = False

    # assert labelled frames are the same
    for lf_original, lf_update in zip(
        original_labels.labeled_frames,
        updated_labels.labeled_frames,
    ):
        # assert video backend
        assert all(
            getattr(lf_update.video.backend, x)
            == getattr(sleap_video_from_file.backend, x)
            for x in sleap_video_from_file.backend.__dict__
        )

        # assert frame idx
        assert lf_original.frame_idx == lf_update.frame_idx

        # assert labelled instances (they include links to the video)
        for ins_original, ins_update in zip(
            lf_original.instances,
            lf_update.instances,
        ):
            assert all(
                getattr(ins_update.video.backend, x)
                == getattr(sleap_video_from_file.backend, x)
                for x in sleap_video_from_file.backend.__dict__
            )

            assert ins_original.frame_idx == ins_update.frame_idx
            assert ins_original.points == ins_update.points
            assert ins_original.track == ins_update.track
