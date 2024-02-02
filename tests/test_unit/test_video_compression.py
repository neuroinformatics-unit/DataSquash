from pathlib import Path

from sleap.io.dataset import Labels

from datasquash.video_compression.generate_label_files import (
    overwrite_video_in_slp_file,
)


def test_overwrite_video_in_slp_file(
    tmp_path: Path,
):
    """Check if we overwrite correctly the video file in an slp file.

    Parameters
    ----------
    tmp_path : Path
        Pytest fixture providing a temporary path
    """
    # input reference labels file
    input_labels_path = str(
        Path(__file__).parents[1] / "data" / "courtship_labels.slp",
    )

    # video to overwrite with
    new_video_filename = "TEST_VIDEO.mp4"

    # output labels file
    output_labels_path = str(tmp_path / "courtship_labels_OUT.slp")

    # overwrite video
    overwrite_video_in_slp_file(
        input_labels_path,
        new_video_filename,
        output_labels_path,
    )

    # inspect output labels file
    labels_dict = {}
    for labels_str, labels_path in zip(
        ["old", "new"],
        [input_labels_path, output_labels_path],
    ):
        labels_dict[labels_str] = Labels.load_file(
            labels_path,
            video_search=Labels.make_video_callback(
                [str(Path(labels_path).parent)],
            ),
        )

    # check one video in new labels
    assert len(labels_dict["new"].videos) == 1

    # check video is set to the desired value
    assert labels_dict["new"].videos[0].filename == new_video_filename

    # check same number of labelled frames as before
    list_lfs_new = labels_dict["new"].find(labels_dict["new"].videos[0])
    list_lfs_old = labels_dict["old"].find(labels_dict["old"].videos[0])
    assert len(list_lfs_new) == len(list_lfs_old)

    # check annotations at each labelled frame
    for lf_new, lf_old in zip(list_lfs_new, list_lfs_old):
        for annot_new, annot_old in zip(
            lf_new.instances,
            lf_old.instances,
        ):
            # check frame_idx, points, track are the same
            assert annot_new.video.filename == new_video_filename
            assert annot_new.frame_idx == annot_old.frame_idx
            assert annot_new.points == annot_old.points
            assert annot_new.track == annot_old.track
