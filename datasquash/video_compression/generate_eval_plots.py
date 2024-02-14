import csv
import re
from pathlib import Path

import matplotlib.pyplot as plt
import sleap


def get_crf_from_model_name(model_str: str) -> int:
    out = re.findall(r"CRF(.*?)\_", model_str)
    return int(out[0]) if len(out) > 0 else 0


def generate_sizes_dict(size_file: str) -> dict:
    map_video_to_size = {}
    with open(size_file, "r") as f:
        reader = csv.reader(f)
        for rows in reader:
            map_video_to_size[rows[0]] = rows[1]
    return map_video_to_size


def generate_models_dict(list_models_paths: list, sizes_file: str) -> dict:
    """Map video name to dict containing:
    - type of model,
    - video crf and
    - trained model metrics

    Parameters
    ----------
    list_models_paths : list
        _description_
    sizes_file

    Returns
    -------
    dict
        _description_
    """
    models_dict: dict = {}
    sizes_dict = generate_sizes_dict(sizes_file)
    for md in list_models_paths:
        ky = str(md.stem)

        out_crf = re.findall(r"(.*?CRF.*\d)\_", ky)
        out_no_crf = re.findall(r"(.*\d)\_", ky)
        ky_sz_root = out_crf[0] if len(out_crf) > 0 else out_no_crf[0]
        ky_sizes = ky_sz_root + ".mp4"

        models_dict[ky] = {}
        models_dict[ky]["type"] = (
            "centroid" if "centroid" in ky else "centered_instance"
        )
        models_dict[ky]["crf"] = get_crf_from_model_name(md.stem)
        models_dict[ky]["metrics"] = sleap.load_metrics(
            md,
            split="val",
        )

        models_dict[ky]["size_mb"] = float(sizes_dict[ky_sizes]) / 1e06

    return models_dict


def plot_eval_metrics_vs_x(
    models_dict: dict,
    list_metrics_to_plot: list[str],
    x_axis_variable: str,
    *,
    flag_show_plots: bool = False,
    flag_save_fig: bool = True,
):
    # sort by key (for plotting)
    models_dict_sorted_kys = sorted(
        models_dict,
        key=lambda ky: (
            "centroid" not in ky,
            models_dict[ky][x_axis_variable],
        ),
    )

    #
    for metric_str in list_metrics_to_plot:
        plt.figure()
        plt.scatter(
            x=[models_dict[ky][x_axis_variable] for ky in models_dict_sorted_kys],
            y=[models_dict[ky]["metrics"][metric_str] for ky in models_dict_sorted_kys],
            c=[models_dict[ky]["type"] == "centroid" for ky in models_dict_sorted_kys],
        )
        plt.colorbar()
        plt.xlabel(x_axis_variable)
        plt.ylabel(metric_str)

        if flag_save_fig:
            Path("output_plots").mkdir(parents=True, exist_ok=True)
            plt.savefig(
                f"output_plots/{metric_str}_vs_{x_axis_variable}.png",
                bbox_inches="tight",
            )

        if flag_show_plots:
            plt.show()


def main():
    # input data
    project_path = "/Users/sofia/swc/project_DataSquash_video/slurm_array.4469301/"
    sizes_file = "/Users/sofia/swc/project_DataSquash_video/files_size.txt"

    # list models paths
    p = Path(project_path).glob("*")
    list_models_paths = [x for x in p if x.is_dir() and not str(x).endswith("/logs")]

    # collect models data into dict
    models_dict = generate_models_dict(list_models_paths, sizes_file)

    # plot eval metrics vs crf and color by type of model
    list_metrics_to_plot = ["oks_voc.mAP", "pck_voc.mAP", "dist.avg", "dist.p50"]
    plot_eval_metrics_vs_x(
        models_dict, list_metrics_to_plot, "crf", flag_save_fig=True  # save plots
    )

    # plot eval metrics vs size
    plot_eval_metrics_vs_x(
        models_dict, list_metrics_to_plot, "size_mb", flag_save_fig=True  # save plots
    )


if __name__ == "__main__":
    main()
