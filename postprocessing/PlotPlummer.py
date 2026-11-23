#!/usr/bin/env python3

import argparse
import glob
import os
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import h5py
import csv

"""
Based on https://github.com/jammartin/ParaLoBstar/blob/main/tools/conservation/main.py
"""

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Plot conservation of energy and angular momentum for Plummer test case.")
    parser.add_argument("--data", "-d", metavar="str", type=str, help="input directory",
                        nargs="?", default="../output")
    parser.add_argument("--output", "-o", metavar="str", type=str, help="output directory",
                        nargs="?", default="../output")
    parser.add_argument("--angular_momentum", "-L", action="store_true", help="plot angular momentum (defaul: energy and mass)")
    parser.add_argument("--mass_quantiles", "-Q", action="store_true", help="plot 10, 50 and 90 percent mass quantiles (default: energy and mass)")
    parser.add_argument("--spatial", "-R", action="store_true", help="plot spatial position of particles (x vs y)")


    args = parser.parse_args()

    time = []
    energy = []
    mass = []
    angular_momentum = []
    mass_quantiles = []

    for h5file in sorted(glob.glob(os.path.join(args.data, "*.h5")), key=os.path.basename):
        print("Processing ", h5file, " ...")
        data = h5py.File(h5file, 'r')
        if "time" in data:
            time.append(data["time"][0])
        else:
            print(f"No 'time' dataset in file: {h5file}")
        # energy.append(data["E_tot"][()])

        if args.angular_momentum:
            print("... reading angular momentum ...")
            try:
                angular_momentum.append(np.array(data["L_tot"][:]))
            except KeyError:
                print(f"Warning: 'L_tot' not found in file {h5file}. Skipping angular momentum for this file.")


        elif args.mass_quantiles:
            print("... computing mass quantiles ...")
            vecs2com = data["x"][:] - data["COM"][:]
            radii = np.linalg.norm(vecs2com, axis=1)
            radii.sort()
            numParticles = len(data["m"])
            # print("NOTE: Only works for equal mass particle distributions!")
            mass_quantiles.append(np.array([
                radii[int(np.ceil(.1 * numParticles))],
                radii[int(np.ceil(.5 * numParticles))],
                radii[int(np.ceil(.9 * numParticles))]]))
        else:
            print("... computing mass and reading energy ...")
            mass.append(np.sum(data["m"][:]))
            #energy.append(data["E_tot"][()])
        
        print("... done.")

    # font = {'family': 'normal', 'weight': 'bold', 'size': 18}
    # font = {'family': 'normal', 'size': 18}
    font = {'size': 18}
    matplotlib.rc('font', **font)

    # plt.style.use("dark_background")
    fig, ax1 = plt.subplots(figsize=(12, 9), dpi=200)
    # fig.patch.set_facecolor("black")
    ax1.set_xlabel("Time")

    if args.angular_momentum:
        ax1.set_title("Angular momentum")
        try:
            angMom = np.array(angular_momentum)
            if angMom.ndim != 2 or angMom.shape[1] != 3:
                raise ValueError("angular_momentum array does not have shape (N,3)")
            ax1.plot(time, angMom[:, 0], label="L_x")
            ax1.plot(time, angMom[:, 1], label="L_y")
            ax1.plot(time, angMom[:, 2], label="L_z")
            plt.legend(loc="best")
            fig.tight_layout()
            plt.savefig(f"{args.output}angular_momentum.png")
        except Exception as e:
            print(f"Error plotting angular momentum: {e}")
            print("Skipping angular momentum plot.")


    elif args.mass_quantiles:
        ax1.set_title("Radii containing percentage of total mass")

        quantiles = np.array(mass_quantiles)

        color = "k"  # "darkgrey"
        ax1.plot(time, quantiles[:, 0], label="10%", color=color, linestyle="dotted", linewidth=2.0)
        ax1.plot(time, quantiles[:, 1], label="50%", color=color, linestyle="dashed", linewidth=2.0)
        ax1.plot(time, quantiles[:, 2], label="90%", color=color, linestyle="dashdot", linewidth=2.0)
        ax1.legend(loc="best")
        ax1.set_ylabel("Radius")
        ax1.set_ylim([0.01, 0.7])

        fig.tight_layout()
        plt.savefig("{}mass_quantiles.png".format(args.output))

        with open("{}mass_quantiles.csv".format(args.output), 'w', newline='') as csv_file:
            csv_writer = csv.writer(csv_file, delimiter=";")
            header = ["time", "quantiles_0", "quantiles_1", "quantiles_2"]
            csv_writer.writerow(header)
            csv_writer.writerow(time)
            csv_writer.writerow(quantiles[:, 0])
            csv_writer.writerow(quantiles[:, 1])
            csv_writer.writerow(quantiles[:, 2])

    elif args.spatial:
        print("Creating spatial plots for each snapshot in", args.data)
        h5files = sorted(glob.glob(os.path.join(args.data, "ts*.h5")), key=os.path.basename)

        for h5file in h5files:
            print(f"  -> Plotting: {h5file}")
            with h5py.File(h5file, "r") as data:
                x = data["x"][:, 0]
                y = data["x"][:, 1]
                z = data["x"][:, 2]
                if "rho" in data:
                    rho = data["rho"][:]
                else:
                    rho = np.ones_like(x)

                # # 2D Scatterplot (x vs y)
                # fig, ax = plt.subplots(figsize=(8, 8), dpi=150)
                # scatter = ax.scatter(x, y, c=rho, cmap="viridis", s=1.0)
                # ax.set_title(f"{os.path.basename(h5file)} (2D spatial)")
                # ax.set_xlabel("x")
                # ax.set_ylabel("y")
                # ax.set_aspect("equal", adjustable="box")
                # cbar = fig.colorbar(scatter, ax=ax)
                # cbar.set_label("Density" if "rho" in data else "Uniform weight")
                # fig.tight_layout()
                # plt.savefig(os.path.join(args.output, f"{os.path.splitext(os.path.basename(h5file))[0]}_spatial2D.png"))
                # plt.close(fig)

                # 3D Scatterplot (x, y, z)
                fig3d = plt.figure(figsize=(8, 8), dpi=150)
                ax3d = fig3d.add_subplot(111, projection='3d')  # 3D automatisch aktiviert
                sc3d = ax3d.scatter(x, y, z, c=rho, cmap="viridis", s=1)
                ax3d.set_title(f"{os.path.basename(h5file)} (3D spatial)")
                ax3d.set_xlabel("x")
                ax3d.set_ylabel("y")
                ax3d.set_zlabel("z")
                cbar3d = fig3d.colorbar(sc3d, ax=ax3d, shrink=0.6, label="Density" if "rho" in data else "Uniform weight")
                fig3d.tight_layout()
                plt.savefig(os.path.join(args.output, f"{os.path.splitext(os.path.basename(h5file))[0]}_spatial3D.png"))
                plt.close(fig3d)
    else:

        ax1.set_title("Total energy and mass")
        ax1.set_ylabel("Energy")
    
        # ax1.plot(time, energy, "r-", label="E_tot")

        ax2 = ax1.twinx()
        ax2.plot(time, mass, "b-", label="M")
        ax2.set_ylabel("Mass")

        fig.tight_layout()
        fig.legend()
        plt.savefig("{}energy_mass.png".format(args.output))
