import numpy as np
import matplotlib.pyplot as plt
import matplotlib
import h5py
import os
import re
import argparse
import glob

" based on https://github.com/jammartin/ParaLoBstar/blob/main/tools/conservation/main.py"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plot position of particles.")
    parser.add_argument("--data", "-d", metavar="str", type=str, help="input directory",
                        nargs="?", default="output")
    parser.add_argument("--output", "-o", metavar="str", type=str, help="output directory",
                        nargs="?", default="output")
    parser.add_argument("--globalmaxmin", "-f", metavar="str", type=str, help="find global max and min from data - set to yes if needed",
                        nargs="?", default="yes")

    args = parser.parse_args()

    i = 0
    _min = 0.95
    _max = 1.05

if(args.globalmaxmin == "yes"):
    for h5file in sorted(glob.glob(os.path.join(args.data, "*.h5")), key=os.path.basename):
        data = h5py.File(h5file, 'r')
        density = np.array(data["rho"][:])
        min, max = np.amin(density), np.amax(density)
        if(min < _min):
            _min = min
        if(max > _max):
            _max = max

    print("global Maximum: ", _max, "global Minimun: ", _min)

for h5file in sorted(glob.glob(os.path.join(args.data, "*.h5")), key=os.path.basename):
    print("Processing ", h5file, " ...")
    data = h5py.File(h5file, 'r')
    time = re.findall(r'(\d+)*.h5', h5file)

    positions = np.array(data["x"][:])

    density = np.array(data["rho"][:])

    print("...plotting timestep figure {} ".format(i))
    fig = plt.figure(dpi=500)
    ax = fig.add_subplot()  # projection='3d' for 3D plot

    p = ax.scatter(positions[:, 0], positions[:, 1], c=density, marker="o", s=0.005, vmin=_min,
                   vmax=_max)  # , r[:, 2] for 3d, vmin, vmax set the min/max for the colorbar
    ax.set_xlabel('X')
    ax.set_ylabel('Y')

    # ax.set_zlabel('Z')
    # to compare different timesteps
    # ax.set_xlim3d(-10, 10)
    # ax.set_ylim3d(-10, 10)
    # ax.set_zlim3d(-10, 10)″

    # set ax limits
    # for rings from origin
    ax.set_xlim(-14, 14)
    ax.set_ylim(-7, 7)  # (-8, 8)
    # rings in the 2nd quadrant
    # ax.set_xlim(-3, 25)
    # ax.set_ylim(-1, 13)
    # rings in the first quadrant
    # ax.set_xlim(-25, 3)
    # ax.set_ylim(-1, 13)
    # ax.set_title('Timestep: {}'.format(time[i][0]))
    ax.set_title("Density")

    fig.colorbar(p, label="$\\rho$")

    plt.savefig("{0:}/Position_and_Density_at_ts{1:06d}.png".format(args.output, i))
    plt.close()
    i = i + 1
