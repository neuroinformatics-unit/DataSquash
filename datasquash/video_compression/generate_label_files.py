import argparse

import sleap


def overwrite_video_in_slp_file(
    input_labels_path: str,
    new_video_path: str,
    output_labels_path: str,
) -> None:
    """Overwrite video in SLEAP labels file.

    Parameters
    ----------
    input_labels_path : str
        path to input SLEAP labels file (.slp), with labels defined
        for one video only.
    new_video_path : str
        new video (path or filename) to link to in SLEAP labels file (.slp).
        If only a filename is provided, the video will be first searched in
        the directory where the .slp file is. The video filename needs to have
        an acceptable extension (e.g. "mp4", not "MP4").
    output_labels_path : str
        path to the output SLEAP labels file (.slp)
    """
    # Load slp file with a predefined video search path
    labels = sleap.Labels.load_file(
        input_labels_path,
        new_video_path,
    )

    # Check only one video and correctly assigned
    assert len(labels.videos) == 1
    assert labels.videos[0].filename == new_video_path

    # Save label file
    sleap.Labels.save_file(
        labels,
        output_labels_path,
    )


def argument_parser() -> argparse.Namespace:
    """Generate parser for .slp file generation.

    Returns
    -------
    argparse.Namespace
        parser for CLI arguments
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_slp",
        help=(
            "path to the input SLEAP labels file (.slp) with "
            "labels defined on one video only."
        ),
    )
    parser.add_argument(
        "new_video_path",
        help=(
            "new video path to link to in SLEAP labels file (.slp). "
            "If only a filename is provided, the video will be search in "
            "the directory of the .slp file"
        ),
    )
    parser.add_argument(
        "output_slp",
        help="path to output SLEAP labels file (.slp)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    # parse CLI arguments
    args = argument_parser()  # type: argparse.Namespace

    # Generate new .slp file
    overwrite_video_in_slp_file(
        args.input_slp,
        args.new_video_path,
        args.output_slp,
    )
