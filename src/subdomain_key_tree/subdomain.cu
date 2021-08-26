//
// Created by Michael Staneker on 15.08.21.
//

#include "../../include/subdomain_key_tree/subdomain.cuh"
#include "../../include/cuda_utils/cuda_launcher.cuh"

CUDA_CALLABLE_MEMBER void KeyNS::key2Char(keyType key, integer maxLevel, char *keyAsChar) {
    int level[21];
    for (int i=0; i<maxLevel; i++) {
        level[i] = (int)(key >> (maxLevel*3 - 3*(i+1)) & (int)7);
    }
    for (int i=0; i<=maxLevel; i++) {
        keyAsChar[2*i] = level[i] + '0';
        keyAsChar[2*i+1] = '|';
    }
    keyAsChar[2*maxLevel+3] = '\0';
}

CUDA_CALLABLE_MEMBER integer KeyNS::key2proc(keyType key, SubDomainKeyTree *s, Curve::Type curveType) {
    return s->key2proc(key, curveType);
}

CUDA_CALLABLE_MEMBER SubDomainKeyTree::SubDomainKeyTree() {

}

CUDA_CALLABLE_MEMBER SubDomainKeyTree::SubDomainKeyTree(integer rank, integer numProcesses, keyType *range,
                                                        integer *procParticleCounter) : rank(rank),
                                                        numProcesses(numProcesses), range(range),
                                                        procParticleCounter(procParticleCounter) {

}

CUDA_CALLABLE_MEMBER SubDomainKeyTree::~SubDomainKeyTree() {

}

CUDA_CALLABLE_MEMBER void SubDomainKeyTree::set(integer rank, integer numProcesses, keyType *range,
                                                integer *procParticleCounter) {
    this->rank = rank;
    this->numProcesses = numProcesses;
    this->range = range;
    this->procParticleCounter = procParticleCounter;
}

CUDA_CALLABLE_MEMBER integer SubDomainKeyTree::key2proc(keyType key, Curve::Type curveType) {
    //if (curveType == 0) {
    for (int proc=0; proc<numProcesses; proc++) {
        if (key >= range[proc] && key < range[proc+1]) {
            return proc;
        }
    }
    //}
    //else {
    //    unsigned long hilbert = Lebesgue2Hilbert(k, 21);
    //    for (int proc = 0; proc < s->numProcesses; proc++) {
    //        if (hilbert >= s->range[proc] && hilbert < s->range[proc + 1]) {
    //            return proc;
    //        }
    //    }
    //}
    //printf("ERROR: key2proc(k=%lu): -1!", k);
    return -1; // error
}

CUDA_CALLABLE_MEMBER bool SubDomainKeyTree::isDomainListNode(keyType key, integer maxLevel, integer level,
                                                             Curve::Type curveType) {
    int p1 = key2proc(key, curveType);
    int p2 = key2proc(key | ~(~0UL << DIM*(maxLevel-level)), curveType);
    if (p1 != p2) {
        return true;
    }
    return false;
}

namespace SubDomainKeyTreeNS {

    namespace Kernel {

        __global__ void set(SubDomainKeyTree *subDomainKeyTree, integer rank, integer numProcesses, keyType *range,
                            integer *procParticleCounter) {
            subDomainKeyTree->set(rank, numProcesses, range, procParticleCounter);
        }

        __global__ void test(SubDomainKeyTree *subDomainKeyTree) {
            printf("device: subDomainKeyTree->rank = %i\n", subDomainKeyTree->rank);
            printf("device: subDomainKeyTree->numProcesses = %i\n", subDomainKeyTree->numProcesses);
            //printf("device: subDomainKeyTree->rank = %i\n", *subDomainKeyTree->rank);
            //printf("device: subDomainKeyTree->numProcesses = %i\n", *subDomainKeyTree->numProcesses);
            //for (int i=0; i<)
            //printf("device: subDomainKeyTree->rank = %i\n", subDomainKeyTree->rank);
        }

        __global__ void buildTree(Tree *tree, Particles *particles, DomainList *domainList, integer n, integer m) {

            integer domainListCounter = 0;

            integer path[21];

            real min_x, max_x;
#if DIM > 1
            real min_y, max_y;
#if DIM == 3
            real min_z, max_z;
#endif
#endif
            integer currentChild;
            integer childPath;
            bool insert = true;

            integer childIndex;
            integer temp;

            // loop over domain list indices (over the keys found/generated by createDomainListKernel)
            for (int i = 0; i < *domainList->domainListIndex; i++) {
                childIndex = 0;
                // iterate through levels (of corresponding domainListIndex)
                for (int j = 0; j < domainList->domainListLevels[i]; j++) {
                    path[j] = (integer) (domainList->domainListKeys[i] >> (MAX_LEVEL * DIM - DIM * (j + 1)) &
                                    (integer)(POW_DIM - 1));
                    temp = childIndex;
                    childIndex = tree->child[POW_DIM*childIndex + path[j]];
                    if (childIndex < n) {
                        if (childIndex == -1) {
                            // no child at all here, thus add node
                            int cell = atomicAdd(tree->index, 1);
                            tree->child[POW_DIM * temp + path[j]] = cell;
                            childIndex = cell;
                            domainList->domainListIndices[domainListCounter] = childIndex; //cell;
                            domainListCounter++;
                        } else {
                            // child is a leaf, thus add node in between
                            int cell = atomicAdd(tree->index, 1);
                            tree->child[POW_DIM * temp + path[j]] = cell;

                            min_x = *tree->minX;
                            max_x = *tree->maxX;
#if DIM > 1
                            min_y = *tree->minY;
                            max_y = *tree->maxY;
#if DIM == 3
                            min_z = *tree->minZ;
                            max_z = *tree->maxZ;
#endif
#endif

                            for (int k=0; k<=j; k++) {

                                currentChild = path[k];

                                if (currentChild % 2 != 0) {
                                    max_x = 0.5 * (min_x + max_x);
                                    currentChild -= 1;
                                }
                                else {
                                    min_x = 0.5 * (min_x + max_x);
                                }
#if DIM > 1
                                if (currentChild % 2 == 0 && currentChild % 4 != 0) {
                                    max_y = 0.5 * (min_y + max_y);
                                    currentChild -= 2;
                                }
                                else {
                                    min_y = 0.5 * (min_y + max_y);
                                }
#if DIM == 3
                                if (currentChild == 4) {
                                    max_z = 0.5 * (min_z + max_z);
                                    currentChild -= 4;
                                }
                                else {
                                    min_z = 0.5 * (min_z + max_z);
                                }
#endif
#endif
                            }
                            // insert old/original particle
                            childPath = 0; //(int) (domainListKeys[i] >> (21 * 3 - 3 * ((j+1) + 1)) & (int)7); //0; //currentChild; //0;
                            if (particles->x[childIndex] < 0.5 * (min_x + max_x)) {
                                childPath += 1;
                                //max_x = 0.5 * (min_x + max_x);
                            }
                            //else {
                            //    min_x = 0.5 * (min_x + max_x);
                            //}
#if DIM > 1
                            if (particles->y[childIndex] < 0.5 * (min_y + max_y)) {
                                childPath += 2;
                                //max_y = 0.5 * (min_y + max_y);
                            }
                            //else {
                            //    min_y = 0.5 * (min_y + max_y);
                            //}
#if DIM == 3
                            if (particles->z[childIndex] < 0.5 * (min_z + max_z)) {
                                childPath += 4;
                                //max_z = 0.5 * (min_z + max_z);
                            }
                            //else {
                            //    min_z = 0.5 * (min_z + max_z);
                            //}
#endif
#endif

                            particles->x[cell] += particles->mass[childIndex] * particles->x[childIndex];
#if DIM > 1
                            particles->y[cell] += particles->mass[childIndex] * particles->y[childIndex];
#if DIM == 3
                            particles->z[cell] += particles->mass[childIndex] * particles->z[childIndex];
#endif
#endif
                            particles->mass[cell] += particles->mass[childIndex];

                            //printf("adding node in between for index %i  cell = %i (childPath = %i,  j = %i)! x = (%f, %f, %f)\n",
                            //       childIndex, cell, childPath, j, x[childIndex], y[childIndex], z[childIndex]);


                            tree->child[POW_DIM * cell + childPath] = childIndex;
                            //printf("child[8 * %i + %i] = %i\n", cell, childPath, childIndex);

                            childIndex = cell;
                            domainList->domainListIndices[domainListCounter] = childIndex; //temp;
                            domainListCounter++;
                        }
                    }
                    else {
                        insert = true;
                        // check whether node already marked as domain list node
                        for (int k=0; k<domainListCounter; k++) {
                            if (childIndex == domainList->domainListIndices[k]) {
                                insert = false;
                                break;
                            }
                        }
                        if (insert) {
                            // mark/save node as domain list node
                            domainList->domainListIndices[domainListCounter] = childIndex; //temp;
                            domainListCounter++;
                        }
                    }
                }
            }
        }

        __global__ void particlesPerProcess(SubDomainKeyTree *subDomainKeyTree, Tree *tree, Particles *particles,
                                            integer n, integer m, Curve::Type curveType) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            keyType key;
            integer proc;

            while ((bodyIndex + offset) < n) {

                // calculate particle key from particle's position
                key = tree->getParticleKey(particles, bodyIndex + offset, MAX_LEVEL);

                // get corresponding process
                subDomainKeyTree->key2proc(key, curveType);

                // increment corresponding counter
                atomicAdd(&subDomainKeyTree->procParticleCounter[proc], 1);

                offset += stride;
            }

        }

        __global__ void markParticlesProcess(SubDomainKeyTree *subDomainKeyTree, Tree *tree, Particles *particles,
                                             integer n, integer m, integer *sortArray, Curve::Type curveType) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            keyType key;
            integer proc;
            integer counter;

            while ((bodyIndex + offset) < n) {

                // calculate particle key from particle's position
                key = tree->getParticleKey(particles, bodyIndex + offset, MAX_LEVEL);

                // get corresponding process
                subDomainKeyTree->key2proc(key, curveType);

                // mark particle with corresponding process
                sortArray[bodyIndex + offset] = proc;

                offset += stride;

            }
        }

        void Launch::set(SubDomainKeyTree *subDomainKeyTree, integer rank, integer numProcesses, keyType *range,
                         integer *procParticleCounter) {
            ExecutionPolicy executionPolicy(1, 1);
            cuda::launch(false, executionPolicy, ::SubDomainKeyTreeNS::Kernel::set, subDomainKeyTree, rank,
                         numProcesses, range, procParticleCounter);
        }

        void Launch::test(SubDomainKeyTree *subDomainKeyTree) {
            ExecutionPolicy executionPolicy(1, 1);
            cuda::launch(false, executionPolicy, ::SubDomainKeyTreeNS::Kernel::test, subDomainKeyTree);
        }

        real Launch::buildTree(Tree *tree, Particles *particles, DomainList *domainList, integer n, integer m) {
            //TODO: is there any possibility to call kernel with more than one thread?
            ExecutionPolicy executionPolicy(1, 1);
            cuda::launch(true, executionPolicy, ::SubDomainKeyTreeNS::Kernel::buildTree, tree, particles,
                         domainList, n, m);
        }

    }

}

CUDA_CALLABLE_MEMBER DomainList::DomainList() {

}

CUDA_CALLABLE_MEMBER DomainList::DomainList(integer *domainListIndices, integer *domainListLevels,
                                            integer *domainListIndex, integer *domainListCounter,
                                            keyType *domainListKeys, keyType *sortedDomainListKeys) :
                                            domainListIndices(domainListIndices), domainListLevels(domainListLevels),
                                            domainListIndex(domainListIndex), domainListCounter(domainListCounter),
                                            domainListKeys(domainListKeys), sortedDomainListKeys(sortedDomainListKeys) {

}

CUDA_CALLABLE_MEMBER DomainList::~DomainList() {

}

CUDA_CALLABLE_MEMBER void DomainList::set(integer *domainListIndices, integer *domainListLevels, integer *domainListIndex,
                              integer *domainListCounter, keyType *domainListKeys, keyType *sortedDomainListKeys) {

    this->domainListIndices = domainListIndices;
    this->domainListLevels = domainListLevels;
    this->domainListIndex = domainListIndex;
    this->domainListCounter = domainListCounter;
    this->domainListKeys = domainListKeys;
    this->sortedDomainListKeys = sortedDomainListKeys;

}

namespace DomainListNS {

    namespace Kernel {

        __global__ void set(DomainList *domainList, integer *domainListIndices, integer *domainListLevels,
                            integer *domainListIndex, integer *domainListCounter, keyType *domainListKeys,
                            keyType *sortedDomainListKeys) {

            domainList->set(domainListIndices, domainListLevels, domainListIndex, domainListCounter, domainListKeys,
                            sortedDomainListKeys);
        }

        __global__ void createDomainList(SubDomainKeyTree *subDomainKeyTree, DomainList *domainList,
                                         integer maxLevel, Curve::Type curveType) {

            char keyAsChar[21 * 2 + 3];

            // workaround for fixing bug... in principle: unsigned long keyMax = (1 << 63) - 1;
            keyType shiftValue = 1;
            keyType toShift = 63;
            keyType keyMax = (shiftValue << toShift) - 1; // 1 << 63 not working!
            //key2Char(keyMax, 21, keyAsChar); //printf("keyMax: %lu = %s\n", keyMax, keyAsChar);

            keyType key2test = 0UL;
            integer level = 0;
            level++;

            // in principle: traversing a (non-existent) octree by walking the 1D spacefilling curve (keys of the tree nodes)
            while (key2test < keyMax) {
                if (subDomainKeyTree->isDomainListNode(key2test & (~0UL << (DIM * (maxLevel - level + 1))),
                                                      maxLevel, level-1, curveType)) {
                    // add domain list key
                    domainList->domainListKeys[*domainList->domainListIndex] = key2test;
                    // add domain list level
                    domainList->domainListLevels[*domainList->domainListIndex] = level;
                    *domainList->domainListIndex += 1;
                    if (subDomainKeyTree->isDomainListNode(key2test, maxLevel, level, curveType)) {
                        level++;
                    }
                    else {
                        key2test = key2test + (1UL << DIM * (maxLevel - level));
                    }
                } else {
                    level--;
                    // not necessary... 1 = 1
                    //key2test = keyMaxLevel(key2test & (~0UL << (3 * (maxLevel - level))), maxLevel, level, s) + 1 - (1UL << (3 * (maxLevel - level)));
                }
            }
            //for (int i=0; i < *index; i++) {
            //    key2Char(domainListKeys[i], 21, keyAsChar);
            //}

        }

        void Launch::set(DomainList *domainList, integer *domainListIndices, integer *domainListLevels,
                             integer *domainListIndex, integer *domainListCounter, keyType *domainListKeys,
                             keyType *sortedDomainListKeys) {
            ExecutionPolicy executionPolicy(1, 1);
            cuda::launch(false, executionPolicy, ::DomainListNS::Kernel::set, domainList, domainListIndices, domainListLevels,
                         domainListIndex, domainListCounter, domainListKeys, sortedDomainListKeys);
        }

        real Launch::createDomainList(SubDomainKeyTree *subDomainKeyTree, DomainList *domainList, integer maxLevel,
                                      Curve::Type curveType) {
            //TODO: is there any possibility to call kernel with more than one thread?
            ExecutionPolicy executionPolicy(1,1);
            return cuda::launch(true, executionPolicy, ::DomainListNS::Kernel::createDomainList, subDomainKeyTree,
                                domainList, maxLevel, curveType);
        }
    }

}