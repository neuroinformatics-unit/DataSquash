import re
from pathlib import Path

import matplotlib.pyplot as plt
import sleap


def get_crf_from_model_name(model_str: str) -> int:
    out = re.findall(r"CRF(.*?)\_", model_str)
    return int(out[0]) if len(out) > 0 else 0


def generate_models_dict(
    list_models_paths: list,
) -> dict:
    models_dict: dict = {}
    for md in list_models_paths:
        models_dict[str(md.stem)] = {}
        models_dict[str(md.stem)]["type"] = (
            "centroid" if "centroid" in str(md.stem) else "centered_instance"
        )
        models_dict[str(md.stem)]["crf"] = get_crf_from_model_name(md.stem)
        models_dict[str(md.stem)]["metrics"] = sleap.load_metrics(
            md,
            split="val",
        )

    return models_dict


def plot_eval_metrics_vs_crf(
    models_dict: dict,
    list_metrics_to_plot: list[str],
    *,
    flag_show_plots: bool = False,
    flag_save_fig: bool = True,
):
    # sort by key (for plotting)
    models_dict_sorted_kys = sorted(
        models_dict,
        key=lambda ky: (
            "centroid" not in ky,
            models_dict[ky]["crf"],
        ),
    )

    #
    for metric_str in list_metrics_to_plot:
        plt.figure()
        plt.scatter(
            x=[models_dict[ky]["crf"] for ky in models_dict_sorted_kys],
            y=[models_dict[ky]["metrics"][metric_str] for ky in models_dict_sorted_kys],
            c=[models_dict[ky]["type"] == "centroid" for ky in models_dict_sorted_kys],
        )
        plt.colorbar()
        plt.xlabel("crf")
        plt.ylabel(metric_str)

        if flag_save_fig:
            Path("output_plots").mkdir(parents=True, exist_ok=True)
            plt.savefig(f"output_plots/{metric_str}.png", bbox_inches="tight")

        if flag_show_plots:
            plt.show()


def main():
    # input data
    project_path = "/Users/sofia/swc/project_DataSquash_video/slurm_array.4469301/"

    # list models paths
    p = Path(project_path).glob("*")
    list_models_paths = [x for x in p if x.is_dir() and not str(x).endswith("/logs")]

    # collect models data into dict
    models_dict = generate_models_dict(list_models_paths)

    # plot eval metrics vs crf and color by type of model
    list_metrics_to_plot = ["oks_voc.mAP", "pck_voc.mAP", "dist.avg", "dist.p50"]
    plot_eval_metrics_vs_crf(
        models_dict, list_metrics_to_plot, flag_save_fig=True  # save plots
    )


if __name__ == "__main__":
    main()
