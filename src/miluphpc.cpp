#include "../include/miluphpc.h"

Miluphpc::Miluphpc(integer numParticles, integer numNodes) : numParticles(numParticles), numNodes(numNodes) {

    gpuErrorcheck(cudaMalloc((void**)&d_mutex, sizeof(integer)));
    particleHandler = new ParticleHandler(numParticles, numNodes);
    subDomainKeyTreeHandler = new SubDomainKeyTreeHandler();
    treeHandler = new TreeHandler(numParticles, numNodes);

}

Miluphpc::~Miluphpc() {

    delete particleHandler;
    delete subDomainKeyTreeHandler;
    delete treeHandler;

}

void Miluphpc::initDistribution(ParticleDistribution::Type particleDistribution) {

    switch(particleDistribution) {
        case ParticleDistribution::disk:
            diskModel();
            break;
        case ParticleDistribution::plummer:
            //
            break;
        default:
            diskModel();
    }

    particleHandler->distributionToDevice();
}

void Miluphpc::diskModel() {

    real a = 1.0;
    real pi = 3.14159265;
    std::default_random_engine generator;
    std::uniform_real_distribution<real> distribution(1.5, 12.0);
    std::uniform_real_distribution<real> distribution_theta(0.0, 2 * pi);

    real solarMass = 100000;

    // loop through all particles
    for (int i = 0; i < numParticles; i++) {

        real theta = distribution_theta(generator);
        real r = distribution(generator);

        // set mass and position of particle
        if (subDomainKeyTreeHandler->h_subDomainKeyTree->rank == 0) {
            if (i == 0) {
                particleHandler->h_particles->mass[i] = 2 * solarMass / numParticles; //solarMass; //100000; 2 * solarMass / numParticles;
                particleHandler->h_particles->x[i] = 0;
                particleHandler->h_particles->y[i] = 0;
                particleHandler->h_particles->z[i] = 0;
            } else {
                particleHandler->h_particles->mass[i] = 2 * solarMass / numParticles;
                particleHandler->h_particles->x[i] = r * cos(theta);
                //y[i] = r * sin(theta);
                particleHandler->h_particles->z[i] = r * sin(theta);

                if (i % 2 == 0) {
                    particleHandler->h_particles->y[i] = i * 1e-7;//z[i] = i * 1e-7;
                } else {
                    particleHandler->h_particles->y[i] = i * -1e-7;//z[i] = i * -1e-7;
                }
            }
        }
        else {
            particleHandler->h_particles->mass[i] = 2 * solarMass / numParticles;
            particleHandler->h_particles->x[i] = (r + subDomainKeyTreeHandler->h_subDomainKeyTree->rank * 1.1e-1) *
                    cos(theta) + 1.0e-2*subDomainKeyTreeHandler->h_subDomainKeyTree->rank;
            //y[i] = (r + h_subDomainHandler->rank * 1.3e-1) * sin(theta) + 1.1e-2*h_subDomainHandler->rank;
            particleHandler->h_particles->z[i] = (r + subDomainKeyTreeHandler->h_subDomainKeyTree->rank * 1.3e-1) *
                    sin(theta) + 1.1e-2*subDomainKeyTreeHandler->h_subDomainKeyTree->rank;

            if (i % 2 == 0) {
                //z[i] = i * 1e-7 * h_subDomainHandler->rank + 0.5e-7*h_subDomainHandler->rank;
                particleHandler->h_particles->y[i] = i * 1e-7 * subDomainKeyTreeHandler->h_subDomainKeyTree->rank +
                        0.5e-7*subDomainKeyTreeHandler->h_subDomainKeyTree->rank;
            } else {
                //z[i] = i * -1e-7 * h_subDomainHandler->rank + 0.4e-7*h_subDomainHandler->rank;
                particleHandler->h_particles->y[i] = i * -1e-7 * subDomainKeyTreeHandler->h_subDomainKeyTree->rank
                        + 0.4e-7*subDomainKeyTreeHandler->h_subDomainKeyTree->rank;
            }
        }


        // set velocity of particle
        real rotation = 1;  // 1: clockwise   -1: counter-clockwise
        real v = sqrt(solarMass / (r));

        if (i == 0) {
            particleHandler->h_particles->vx[0] = 0.0;
            particleHandler->h_particles->vy[0] = 0.0;
            particleHandler->h_particles->vz[0] = 0.0;
        }
        else{
            particleHandler->h_particles->vx[i] = rotation*v*sin(theta);
            //y_vel[i] = -rotation*v*cos(theta);
            particleHandler->h_particles->vz[i] = -rotation*v*cos(theta);
            //z_vel[i] = 0.0;
            particleHandler->h_particles->vy[i] = 0.0;
        }

        // set acceleration to zero
        particleHandler->h_particles->ax[i] = 0.0;
        particleHandler->h_particles->ay[i] = 0.0;
        particleHandler->h_particles->az[i] = 0.0;
    }

}

void Miluphpc::run() {

    real time;

    Logger(INFO) << "Starting ...";

    Logger(INFO) << "initialize particle distribution ...";
    initDistribution();

    for (int i=0; i<numParticles; i++) {
        if (i % 10000 == 0) {
            printf("host: x[%i] = (%f, %f, %f)\n", i, particleHandler->h_x[i], particleHandler->h_y[i],
                   particleHandler->h_z[i]);
        }
    }

    time = ParticlesNS::Kernel::Launch::test(particleHandler->d_particles, true);
    Logger(TIME) << "test: " << time << " ms";
    //treeHandler->toHost();
    //treeHandler->toDevice();

    Logger(INFO) << "resetting (device) arrays ...";
    time = Kernel::Launch::resetArrays(treeHandler->d_tree, particleHandler->d_particles, d_mutex, numParticles,
                                       numNodes, true);
    Logger(TIME) << "resetArrays: " << time << " ms";

    Logger(INFO) << "computing bounding box ...";
    //TreeNS::computeBoundingBoxKernel(treeHandler->d_tree, particleHandler->d_particles, d_mutex, numNodes, 256);
    time = TreeNS::Kernel::Launch::computeBoundingBox(treeHandler->d_tree, particleHandler->d_particles, d_mutex,
                                                           numParticles, 256, true);
    Logger(TIME) << "computeBoundingBox: " << time << " ms";

    treeHandler->toHost();
    printf("min/max: x = (%f, %f), y = (%f, %f), z = (%f, %f)\n", *treeHandler->h_minX, *treeHandler->h_maxX,
           *treeHandler->h_minY, *treeHandler->h_maxY, *treeHandler->h_minZ, *treeHandler->h_maxZ);

    treeHandler->globalizeBoundingBox(Execution::device);
    treeHandler->toHost();
    printf("min/max: x = (%f, %f), y = (%f, %f), z = (%f, %f)\n", *treeHandler->h_minX, *treeHandler->h_maxX,
           *treeHandler->h_minY, *treeHandler->h_maxY, *treeHandler->h_minZ, *treeHandler->h_maxZ);

    Logger(INFO) << "building tree ...";
    time = TreeNS::Kernel::Launch::buildTree(treeHandler->d_tree, particleHandler->d_particles, numParticles,
                                             numParticles, true);
    Logger(TIME) << "buildTree: " << time << " ms";

    Logger(INFO) << "center of mass ...";
    time = TreeNS::Kernel::Launch::centerOfMass(treeHandler->d_tree, particleHandler->d_particles,
                                                numParticles, true);
    Logger(TIME) << "centerOfMass: " << time << " ms";

    Logger(INFO) << "sorting ...";
    time = TreeNS::Kernel::Launch::sort(treeHandler->d_tree, numParticles, numNodes, true);
    Logger(TIME) << "sort: " << time << " ms";

}