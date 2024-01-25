import logging
import re
from pathlib import Path

import cv2
import pandas as pd


def compute_map_videos_to_frames_DLC(
    project_path: str,
    labels_filename: str,
    video_ext: str,
):
    # Read dataframe
    # assuming single animal labels only
    df = pd.read_csv(Path(project_path, labels_filename), header=[1, 2])

    # Extract list of videos and frames
    is_new_format = df.columns[1][1].startswith("Unnamed")
    input_data_first_col = 1 if is_new_format else 0
    videos_col = 1  # or position in path in old format
    frames_col = 2  # or position in path in old format

    if is_new_format:
        list_videos = list(df.iloc[:, videos_col].unique())
        list_frames_str = list(df.iloc[:, frames_col])
    if not is_new_format:
        list_input_data = df.iloc[:, 0]
        list_videos = [inpt.split("/")[videos_col] for inpt in list_input_data]
        list_frames_str = [inpt.split("/")[frames_col] for inpt in list_input_data]

    # frames as int
    list_frame_idcs = [int(re.findall(r"\d+", f)[0]) for f in list_frames_str]

    # Build map of videos to frames from csv
    for vid_str in list_videos:
        # extract list of corresponding frames
        rows_with_vid_str = df.index[
            df.iloc[:, input_data_first_col].str.contains(vid_str)
        ].tolist()

        # path to video mapped to list frames
        map_videos_to_extracted_frames = {
            str(
                project_path / Path(vid_str).with_suffix(video_ext),
            ): [list_frame_idcs[r] for r in rows_with_vid_str],
        }

    return map_videos_to_extracted_frames


def extract_frames_to_label_from_video(
    map_videos_to_extracted_frames: dict,
    output_dir_path: Path,
):
    """Extract suggested frames for labelling using OpenCV.

    The png files for each frame are named with
    the following format:
    <video_parent_dir>_<video_filename>_frame_<frame_idx>.png

    Parameters
    ----------
    map_videos_to_extracted_frames : dict
        dictionary that maps each video path to a list
        of frames indices extracted for labelling.
        The frame indices are sorted in ascending order.

    output_dir_path : pathlib.Path
        path to directory with extracted frames

    Raises
    ------
    KeyError
        If a frame from a video is not correctly read by openCV
    """
    for vid_str in map_videos_to_extracted_frames:
        # Initialise video capture
        cap = cv2.VideoCapture(vid_str)

        # Check if video capture is opened correctly
        logging.info("---------------------------")
        if cap.isOpened():
            logging.info(f"Processing video {Path(vid_str)}")
        else:
            logging.info(f"Error processing {Path(vid_str)}, skipped....")
            continue

        # Get number of frames
        n_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        # Create output dir
        output_dir_path.mkdir(parents=True, exist_ok=True)

        # Extract each frame
        for frame_idx in map_videos_to_extracted_frames[vid_str]:
            # Read frame (0-based indexing)
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
            success, frame = cap.read()

            # If not read successfully: throw error
            if not success or frame is None:
                msg = f"Unable to load frame {frame_idx} from {vid_str}."
                raise KeyError(msg)

            # If read successfully: save to file
            # file naming format: img00XXX.png
            else:
                file_path = output_dir_path / "img{num:0{width}}.png".format(
                    num=frame_idx,
                    width=len(str(n_frames)),
                )

                img_saved = cv2.imwrite(str(file_path), frame)

                if img_saved:
                    logging.info(
                        f"frame {frame_idx} saved at {file_path}",
                    )
                else:
                    logging.info(
                        f"ERROR saving {Path(vid_str).stem},",  # noqa: G004
                        f" frame {frame_idx}" "...skipping",
                    )
                    continue

        # close video capture
        cap.release()


if __name__ == "__main__":
    # Input data
    # project_path = "/Users/sofia/swc/project_DataSquash_video/datasets/jwaspE_nectar-open-close_control"
    # labels_filename = "CollectedData_Sanna_wasps.csv"
    # video_ext = ".avi"

    project_path = "/Users/sofia/swc/project_DataSquash_video/datasets/reachingvideo1"
    labels_filename = "CollectedData_Mackenzie.csv"
    video_ext = "avi"

    # Why logger not logging?
    # logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))

    # Map videos to extracted frames
    map_videos_to_extracted_frames = compute_map_videos_to_frames_DLC(
        project_path,
        labels_filename,
        video_ext,
    )
    output_subdir_path = Path(project_path)

    # Extract frames
    extract_frames_to_label_from_video(
        map_videos_to_extracted_frames,
        output_subdir_path,
    )
