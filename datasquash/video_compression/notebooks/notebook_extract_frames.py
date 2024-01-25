# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Ref: https://github.com/talmolab/sleap/blob/60a441fc1d4fc60533ddb0296cab56165cd3e664/sleap/io/format/deeplabcut.py
import re
from pathlib import Path

import pandas as pd

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Input data
project_path = "/Users/sofia/swc/project_DataSquash_video/datasets/reachingvideo1"
labels_filename = "CollectedData_Mackenzie.csv"
video_ext = "avi"

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Read dataframe
# assuming single animal labels only
df = pd.read_csv(Path(project_path, labels_filename), header=[1, 2])


# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
## Extract list of videos and frames from dataframe
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


# %%# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
## Build map of videos to extracted frames
for vid_str in list_videos:
    # extract list of corresponding frames
    rows_with_vid_str = df.index[
        df.iloc[:, input_data_first_col].str.contains(vid_str)
    ].tolist()

    # path to video mapped to list frames
    map_videos_to_extracted_frames = {
        Path(
            project_path,
            Path(vid_str).with_suffix(video_ext),
        ): [list_frame_idcs[r] for r in rows_with_vid_str],
    }


# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Fix DLC Reaching data csv
# input data
df = pd.read_csv(Path(project_path, labels_filename), header=[1, 2])
output_file = Path(project_path, "CollectedData_Mackenzie_FIX.csv")

# frames to fix
y_offset = 747 - 470
list_row_idcs_to_fix = [6, 9, 10, 13, 23, 27, 29, 31, 33, 35, 37, 40, 45, 51, 53]
list_row_idcs_to_fix = [id - 1 for id in list_row_idcs_to_fix]

# fix dataframe
list_bdprts = list(set(df.columns.get_level_values(0)[1:]))
df_xfix = df.copy()

for id in list_row_idcs_to_fix:
    for bdprt in list_bdprts:
        df_xfix.loc[id, (bdprt, "y")] = df.loc[id, (bdprt, "y")] + y_offset

# export
df_xfix.to_csv(
    output_file,
    index=False,
)

# paste DLC header
header = ["scorer"] + ["Mackenzie"] * (len(df.columns) - 1)
with Path.open(output_file) as f:
    temp = f.read()
with Path.open(output_file, "w") as f:
    for h in header:
        f.write(h + ",")
    f.write("\n")
    f.write(temp)
