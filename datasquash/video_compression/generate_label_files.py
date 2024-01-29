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
        path to input SLEAP labels file (.slp).
    new_video_path : str
        new video path to link to in SLEAP labels file (.slp). If only a
        filename is provided, the video will be search in the directory of
        the .slp file
    output_labels_path : str
        path to output SLEAP labels file (.slp)
    """
    # Load slp file with predefined video search path
    labels = sleap.Labels.load_file(
        input_labels_path,
        new_video_path,  # if I specify filename it will look for this file
    )

    # Save label file
    sleap.Labels.save_file(
        labels,
        output_labels_path,
    )


def argument_parser() -> argparse.ArgumentParser:
    """Generate argument parser for .slp file generation.

    Returns
    -------
    argparse.ArgumentParser
        parser for CLI arguments
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "input_slp",
        help="path to the input SLEAP labels file (.slp)",
    )
    parser.add_argument(
        "new_video_path",
        nargs="*",
        help=(
            "new video path to link to in SLEAP labels file (.slp). "
            "If only a filename is provided, the video will be search in "
            "the directory of the .slp file",
        ),
    )
    parser.add_argument(
        "output_slp",
        help="path to output SLEAP labels file (.slp)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    # parse CLI arguments
    args = argument_parser()

    # Generate new .slp file
    overwrite_video_in_slp_file(
        args.input_slp,
        args.new_video_path,
        args.output_slp,
    )
