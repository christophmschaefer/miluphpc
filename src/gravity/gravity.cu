#include "../../include/gravity/gravity.cuh"
#include "../../include/cuda_utils/cuda_launcher.cuh"

namespace Gravity {

    namespace Kernel {

        __global__ void prepareLowestDomainExchange(Particles *particles, DomainList *lowestDomainList,
                                                    Helper *helper, Entry::Name entry) {

            integer bodyIndex = threadIdx.x + blockIdx.x*blockDim.x;
            integer stride = blockDim.x*gridDim.x;
            integer offset = 0;
            integer index;
            integer lowestDomainIndex;

            //copy x, y, z, mass of lowest domain list nodes into arrays
            //sorting using cub (not here)
            while ((bodyIndex + offset) < *lowestDomainList->domainListIndex) {
                lowestDomainIndex = lowestDomainList->domainListIndices[bodyIndex + offset];
                if (lowestDomainIndex >= 0) {
                    switch (entry) {
                        case Entry::x:
                            helper->realBuffer[bodyIndex + offset] = particles->x[lowestDomainIndex];
                            break;
#if DIM > 1
                        case Entry::y:
                            helper->realBuffer[bodyIndex + offset] = particles->x[lowestDomainIndex];
                            break;
#if DIM == 3
                        case Entry::z:
                            helper->realBuffer[bodyIndex + offset] = particles->x[lowestDomainIndex];
                            break;
#endif
#endif
                        case Entry::mass:
                            helper->realBuffer[bodyIndex + offset] = particles->mass[lowestDomainIndex];
                            break;
                        default:
                            helper->realBuffer[bodyIndex + offset] = particles->mass[lowestDomainIndex];
                            break;
                    }
                }
                offset += stride;
            }
        }

        __global__ void updateLowestDomainListNodes(Particles *particles, DomainList *lowestDomainList,
                                                    Helper *helper, Entry::Name entry) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            integer originalIndex = -1;

            while ((bodyIndex + offset) < *lowestDomainList->domainListIndex) {
                for (int i = 0; i < *lowestDomainList->domainListIndex; i++) {
                    if (lowestDomainList->sortedDomainListKeys[bodyIndex + offset] ==
                        lowestDomainList->domainListKeys[i]) {
                        originalIndex = i;
                        //break;
                    }
                }

                if (originalIndex == -1) {
                    printf("ATTENTION: originalIndex = -1 (index = %i)!\n",
                           lowestDomainList->sortedDomainListKeys[bodyIndex + offset]);
                }

                switch (entry) {
                    case Entry::x:
                        particles->x[lowestDomainList->domainListIndices[originalIndex]] =
                                helper->realBuffer[bodyIndex + offset];
                        break;
#if DIM > 1
                    case Entry::y:
                        particles->y[lowestDomainList->domainListIndices[originalIndex]] =
                                helper->realBuffer[bodyIndex + offset];
                        break;
#if DIM == 3
                    case Entry::z:
                        particles->z[lowestDomainList->domainListIndices[originalIndex]] =
                                helper->realBuffer[bodyIndex + offset];
                        break;
#endif
#endif
                    case Entry::mass:
                        particles->mass[lowestDomainList->domainListIndices[originalIndex]] =
                                helper->realBuffer[bodyIndex + offset];
                        break;
                    default:
                        particles->mass[lowestDomainList->domainListIndices[originalIndex]] =
                                helper->realBuffer[bodyIndex + offset];
                        break;
                }

                offset += stride;
            }
        }

        __global__ void compLowestDomainListNodes(Particles *particles, DomainList *lowestDomainList) {

            integer bodyIndex = threadIdx.x + blockIdx.x*blockDim.x;
            integer stride = blockDim.x*gridDim.x;
            integer offset = 0;
            integer lowestDomainIndex;

            while ((bodyIndex + offset) < *lowestDomainList->domainListIndex) {

                lowestDomainIndex = lowestDomainList->domainListIndices[bodyIndex + offset];

                if (particles->mass[lowestDomainIndex] != 0) {
                    particles->x[lowestDomainIndex] /= particles->mass[lowestDomainIndex];
#if DIM > 1
                    particles->y[lowestDomainIndex] /= particles->mass[lowestDomainIndex];
#if DIM == 3
                    particles->z[lowestDomainIndex] /= particles->mass[lowestDomainIndex];
#endif
#endif
                }
                offset += stride;
            }
        }

        __global__ void compLocalPseudoParticles(Tree *tree, Particles *particles, DomainList *domainList, int n) {
            integer bodyIndex = threadIdx.x + blockIdx.x*blockDim.x;
            integer stride = blockDim.x*gridDim.x;
            integer offset = 0;
            bool isDomainList;
            //note: most of it already done within buildTreeKernel

            bodyIndex += n;

            while (bodyIndex + offset < *tree->index) {
                isDomainList = false;

                for (integer i=0; i<*domainList->domainListIndex; i++) {
                    if ((bodyIndex + offset) == domainList->domainListIndices[i]) {
                        isDomainList = true; // hence do not insert
                        break;
                    }
                }

                if (particles->mass[bodyIndex + offset] != 0 && !isDomainList) {
                    particles->x[bodyIndex + offset] /= particles->mass[bodyIndex + offset];
#if DIM > 1
                    particles->y[bodyIndex + offset] /= particles->mass[bodyIndex + offset];
#if DIM == 3
                    particles->z[bodyIndex + offset] /= particles->mass[bodyIndex + offset];
#endif
#endif
                }

                offset += stride;
            }
        }

        __global__ void compDomainListPseudoParticles(Tree *tree, Particles *particles, DomainList *domainList,
                                                      DomainList *lowestDomainList, int n) {
            //calculate position (center of mass) and mass for domain list nodes
            //Problem: start with "deepest" nodes
            integer bodyIndex = threadIdx.x + blockIdx.x*blockDim.x;
            integer stride = blockDim.x*gridDim.x;
            integer offset;

            integer domainIndex;
            integer level = MAX_LEVEL; // max level
            bool compute;

            // go from max level to level=0
            while (level >= 0) {
                offset = 0;
                compute = true;
                while ((bodyIndex + offset) < *domainList->domainListIndex) {
                    compute = true;
                    domainIndex = domainList->domainListIndices[bodyIndex + offset];
                    for (int i=0; i<*lowestDomainList->domainListIndex; i++) {
                        if (domainIndex == lowestDomainList->domainListIndices[i]) {
                            compute = false;
                        }
                    }
                    if (compute && domainList->domainListLevels[bodyIndex + offset] == level) {
                        // do the calculation
                        for (int i=0; i<POW_DIM; i++) {
                            particles->x[domainIndex] += particles->x[tree->child[POW_DIM*domainIndex + i]] *
                                    particles->mass[tree->child[POW_DIM*domainIndex + i]];
#if DIM > 1
                            particles->y[domainIndex] += particles->y[tree->child[POW_DIM*domainIndex + i]] *
                                    particles->mass[tree->child[POW_DIM*domainIndex + i]];
#if DIM == 3
                            particles->z[domainIndex] += particles->z[tree->child[POW_DIM*domainIndex + i]] *
                                    particles->mass[tree->child[POW_DIM*domainIndex + i]];
#endif
#endif
                            particles->mass[domainIndex] += particles->mass[tree->child[POW_DIM*domainIndex + i]];
                        }

                        if (particles->mass[domainIndex] != 0) {
                            particles->x[domainIndex] /= particles->mass[domainIndex];
#if DIM > 1
                            particles->y[domainIndex] /= particles->mass[domainIndex];
#if DIM == 3
                            particles->z[domainIndex] /= particles->mass[domainIndex];
#endif
#endif
                        }
                    }
                    offset += stride;
                }
                __syncthreads();
                level--;
            }
        }

        __global__ void computeForces(Tree *tree, Particles *particles, integer n, integer m, integer blockSize,
                                      integer warp, integer stackSize) {

            integer bodyIndex = threadIdx.x + blockIdx.x*blockDim.x;
            integer stride = blockDim.x*gridDim.x;
            integer offset = 0;

            //__shared__ float depth[stackSize * blockSize/warp];
            // stack controlled by one thread per warp
            //__shared__ int   stack[stackSize * blockSize/warp];
            extern __shared__ real buffer[];

            real* depth = (real*)buffer;
            real* stack = (real*)&depth[stackSize* blockSize/warp];

            real x_radius = 0.5*(*tree->maxX - (*tree->minX));
#if DIM > 1
            real y_radius = 0.5*(*tree->maxY - (*tree->minY));
#if DIM == 3
            real z_radius = 0.5*(*tree->maxZ - (*tree->minZ));
#endif
#endif

#if DIM == 1
            real radius = x_radius;
#elif DIM == 2
            real radius = fmaxf(x_radius, y_radius);
#else
            real radius_max = fmaxf(x_radius, y_radius);
            real radius = fmaxf(radius_max, z_radius);
#endif

            // in case that one of the first 8 children are a leaf
            integer jj = -1;
            for (integer i=0; i<POW_DIM; i++) {
                if (tree->child[i] != -1) {
                    jj++;
                }
            }

            integer counter = threadIdx.x % warp;
            integer stackStartIndex = stackSize*(threadIdx.x / warp);

            while ((bodyIndex + offset) < m) {

                integer sortedIndex = tree->sorted[bodyIndex + offset];

                real pos_x = particles->x[sortedIndex];
#if DIM > 1
                real pos_y = particles->y[sortedIndex];
#if DIM == 3
                real pos_z = particles->z[sortedIndex];
#endif
#endif

                real acc_x = 0.0;
#if DIM > 1
                real acc_y = 0.0;
#if DIM == 3
                real acc_z = 0.0;
#endif
#endif

                // initialize stack
                integer top = jj + stackStartIndex;

                if (counter == 0) {

                    integer temp = 0;

                    for (int i=0; i<POW_DIM; i++) {
                        // if child is not locked
                        if (tree->child[i] != -1) {
                            stack[stackStartIndex + temp] = tree->child[i];
                            depth[stackStartIndex + temp] = radius*radius/theta;
                            temp++;
                        }
                    }
                }
                __syncthreads();

                // while stack is not empty / more nodes to visit
                while (top >= stackStartIndex) {

                    integer node = stack[top];
                    //debug
                    //if (node > n && node < m) {
                    //    printf("PARALLEL FORCE! (node = %i x = (%f, %f, %f) m = %f)\n", node, x[node], y[node], z[node],
                    //        mass[node]);
                    //}
                    //end: debug
                    real dp = 0.25*depth[top]; // float dp = depth[top];

                    for (integer i=0; i<8; i++) {

                        integer ch = tree->child[8*node + i];
                        //__threadfence();

                        if (ch >= 0) {

                            real dx = particles->x[ch] - pos_x;
#if DIM > 1
                            real dy = particles->y[ch] - pos_y;
#if DIM == 3
                            real dz = particles->z[ch] - pos_z;
#endif
#endif

                            real r = dx*dx;
#if DIM > 1
                            r += dy*dy;
#if DIM == 3
                            r += dz*dz; /*+ eps_squared*/;
#endif
#endif

                            //unsigned activeMask = __activemask();

                            //if (ch < n /*is leaf node*/ || !__any_sync(activeMask, dp > r)) {
                            if (ch < n /*is leaf node*/ || __all_sync(__activemask(), dp <= r)) {

                                /*//debug
                                key = getParticleKeyPerParticle(x[ch], y[ch], z[ch], minX, maxX, minY, maxY,
                                                                minZ, maxZ, 21);
                                if (key2proc(key, s) != s->rank) {
                                    printf("Parallel force! child = %i x = (%f, %f, %f) mass = %f\n", ch, x[ch], y[ch], z[ch], mass[ch]);
                                }
                                //end: debug*/

                                // calculate interaction force contribution
                                r = rsqrt(r);
                                real f = particles->mass[ch] * r * r * r;

                                acc_x += f*dx;
#if DIM > 1
                                acc_y += f*dy;
#if DIM == 3
                                acc_z += f*dz;
#endif
#endif
                            }
                            else {
                                // if first thread in warp: push node's children onto iteration stack
                                if (counter == 0) {
                                    stack[top] = ch;
                                    depth[top] = dp; // depth[top] = 0.25*dp;
                                }
                                top++; // descend to next tree level
                                //__threadfence();
                            }
                        }
                        else { /*top = max(stackStartIndex, top-1); */}
                    }
                    top--;
                }
                // update body data
                particles->ax[sortedIndex] = acc_x;
#if DIM > 1
                particles->ay[sortedIndex] = acc_y;
#if DIM == 3
                particles->az[sortedIndex] = acc_z;
#endif
#endif

                offset += stride;

                __syncthreads();
            }

        }

        __global__ void update(Particles *particles, integer n, real dt, real d) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            while (bodyIndex + offset < n) {

                // calculating/updating the velocities
                particles->vx[bodyIndex + offset] += dt * particles->ax[bodyIndex + offset];
#if DIM > 1
                particles->vy[bodyIndex + offset] += dt * particles->ay[bodyIndex + offset];
#if DIM == 3
                particles->vz[bodyIndex + offset] += dt * particles->az[bodyIndex + offset];
#endif
#endif

                // calculating/updating the positions
                particles->x[bodyIndex + offset] += d * dt * particles->vx[bodyIndex + offset];
#if DIM > 1
                particles->y[bodyIndex + offset] += d * dt * particles->vy[bodyIndex + offset];
#if DIM == 3
                particles->z[bodyIndex + offset] += d * dt * particles->vz[bodyIndex + offset];
#endif
#endif
                offset += stride;
            }
        }

        __global__ void createKeyHistRanges(Helper *helper, integer bins) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            keyType max_key = 1UL << 63;

            while ((bodyIndex + offset) < bins) {

                helper->keyTypeBuffer[bodyIndex + offset] = (bodyIndex + offset) * (max_key/bins);
                //printf("keyHistRanges[%i] = %lu\n", bodyIndex + offset, keyHistRanges[bodyIndex + offset]);

                if ((bodyIndex + offset) == (bins - 1)) {
                    helper->keyTypeBuffer[bins-1] = KEY_MAX;
                }
                offset += stride;
            }
        }

        __global__ void keyHistCounter(Tree *tree, Particles *particles, SubDomainKeyTree *subDomainKeyTree,
                                       Helper *helper,
                                       /*keyType *keyHistRanges, integer *keyHistCounts,*/ int bins, int n,
                                       Curve::Type curveType) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            keyType key;

            while ((bodyIndex + offset) < n) {

                key = tree->getParticleKey(particles, bodyIndex + offset, MAX_LEVEL);

                switch (curveType) {
                    case Curve::lebesgue: {
                        for (int i = 0; i < (bins); i++) {
                            if (key >= helper->keyTypeBuffer[i] && key < helper->keyTypeBuffer[i + 1]) {
                                //keyHistCounts[i] += 1;
                                atomicAdd(&helper->integerBuffer[i], 1);
                                break;
                            }
                        }
                        break;
                    }
                    case Curve::hilbert: {
                        //TODO: Hilbert change
                        printf("Attention: not implemented yet!\n");
                        /*unsigned long hilbert = Lebesgue2Hilbert(key, 21);
                        for (int i = 0; i < (bins); i++) {
                            if (hilbert >= keyHistRanges[i] && hilbert < keyHistRanges[i + 1]) {
                                //keyHistCounts[i] += 1;
                                atomicAdd(&keyHistCounts[i], 1);
                                break;
                            }
                        }
                        break;*/
                    }
                    default:
                        printf("Not available!\n");
                }

                offset += stride;
            }

        }

        //TODO: resetting helper (buffers)?!
        __global__ void calculateNewRange(SubDomainKeyTree *subDomainKeyTree, Helper *helper,
                                          /*keyType *keyHistRanges, integer *keyHistCounts,*/ int bins, int n,
                                          Curve::Type curveType) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            integer sum;
            keyType newRange;

            while ((bodyIndex + offset) < (bins-1)) {

                sum = 0;
                for (integer i=0; i<(bodyIndex+offset); i++) {
                    sum += helper->integerBuffer[i];
                }

                for (integer i=1; i<subDomainKeyTree->numProcesses; i++) {
                    if ((sum + helper->integerBuffer[bodyIndex + offset]) >= (i*n) && sum < (i*n)) {
                        printf("[rank %i] new range: %lu\n", subDomainKeyTree->rank,
                               helper->keyTypeBuffer[bodyIndex + offset]);
                        subDomainKeyTree->range[i] = helper->keyTypeBuffer[bodyIndex + offset];
                    }
                }


                //printf("[rank %i] keyHistCounts[%i] = %i\n", s->rank, bodyIndex+offset, keyHistCounts[bodyIndex+offset]);
                atomicAdd(helper->integerVal, helper->integerBuffer[bodyIndex+offset]);
                offset += stride;
            }

        }

        real Launch::prepareLowestDomainExchange(Particles *particles, DomainList *lowestDomainList,
                                                 Helper *helper, Entry::Name entry) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::prepareLowestDomainExchange, particles,
                                lowestDomainList, helper, entry);
        }

        real Launch::updateLowestDomainListNodes(Particles *particles, DomainList *lowestDomainList,
                                                 Helper *helper, Entry::Name entry) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::updateLowestDomainListNodes, particles,
                                lowestDomainList, helper, entry);

        }

        real Launch::compLowestDomainListNodes(Particles *particles, DomainList *lowestDomainList) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::compLowestDomainListNodes, particles,
                                lowestDomainList);
        }

        real Launch::compLocalPseudoParticles(Tree *tree, Particles *particles, DomainList *domainList, int n) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::compLocalPseudoParticles, tree, particles,
                                domainList, n);
        }

        real Launch::compDomainListPseudoParticles(Tree *tree, Particles *particles, DomainList *domainList,
                                                   DomainList *lowestDomainList, int n) {
            ExecutionPolicy executionPolicy(256, 1);
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::compDomainListPseudoParticles, tree,
                                particles, domainList, lowestDomainList, n);
        }

        real Launch::computeForces(Tree *tree, Particles *particles, integer n, integer m, integer blockSize,
                                   integer warp, integer stackSize) {

            size_t sharedMemory = (sizeof(real)+sizeof(integer))*stackSize*blockSize/warp;
            ExecutionPolicy executionPolicy(256, 256, sharedMemory);
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::computeForces, tree, particles, n, m,
                                blockSize, warp, stackSize);
        }

        real Launch::update(Particles *particles, integer n, real dt, real d) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::update, particles, n, dt, d);
        }

        real Launch::createKeyHistRanges(Helper *helper, integer bins) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::createKeyHistRanges, helper, bins);
        }

        real Launch::keyHistCounter(Tree *tree, Particles *particles, SubDomainKeyTree *subDomainKeyTree,
                            Helper *helper, int bins, int n, Curve::Type curveType) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::keyHistCounter, tree, particles,
                                subDomainKeyTree, helper, bins, n, curveType);
        }

        real Launch::calculateNewRange(SubDomainKeyTree *subDomainKeyTree, Helper *helper, int bins, int n,
                               Curve::Type curveType) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::Gravity::Kernel::calculateNewRange, subDomainKeyTree, helper,
                                bins, n, curveType);
        }

    }
}