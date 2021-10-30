#include "../../include/subdomain_key_tree/tree.cuh"
#include "../../include/cuda_utils/cuda_launcher.cuh"

CUDA_CALLABLE_MEMBER keyType KeyNS::lebesgue2hilbert(keyType lebesgue, integer maxLevel) {

    /*keyType hilbert = 0UL;
    integer dir = 0;
    for (integer lvl=maxLevel; lvl>0; lvl--) {
        keyType cell = (lebesgue >> ((lvl-1)*DIM)) & (keyType)((1<<DIM)-1);
        hilbert = hilbert << DIM;
        if (lvl > 0) {
            hilbert += HilbertTable[dir][cell];
        }
        dir = DirTable[dir][cell];
    }
    return hilbert;*/

    keyType hilbert = 1UL;
    int level = 0, dir = 0;
    //int rememberLevel;
    for (keyType tmp=lebesgue; tmp>1; level++) {
        tmp>>=DIM;
    }
    //rememberLevel = level;
    if (level == 0) {
        hilbert = 0UL;
    }
    for (; level>0; level--) {
        int cell = (lebesgue >> ((level-1)*DIM)) & ((1<<DIM)-1);
        hilbert = (hilbert<<DIM) + HilbertTable[dir][cell];
        dir = DirTable[dir][cell];
    }
    //if (lebesgue == 0UL) {
    //    printf("HERE: lebesgue = %lu --> level = %i, hilbert = %lu\n", lebesgue, rememberLevel, hilbert);
    //}
    return hilbert;

}

CUDA_CALLABLE_MEMBER keyType KeyNS::lebesgue2hilbert(keyType lebesgue, int maxLevel, int level) {

    keyType hilbert = 0UL; // 0UL is our root, placeholder bit omitted
    //int level = 0, dir = 0;
    int dir = 0;
    //for (keytype tmp=lebesgue; tmp>0UL; tmp>>=DIM, level++); // obtain of key
    //if (level != 21) {
    //    Logger(DEBUG) << "Lebesgue2Hilbert: level = " << level << ", key" << lebesgue;
    //}
    //Logger(DEBUG) << "Lebesgue2Hilbert(): lebesgue = " << lebesgue << ", level = " << level;
    for (int lvl=maxLevel; lvl>0; lvl--) {
        //int cell = lebesgue >> ((level-1)*DIM) & (keytype)((1<<DIM)-1);
        int cell = (lebesgue >> ((lvl-1)*DIM)) & (keyType)((1<<DIM)-1);
        hilbert = hilbert<<DIM;
        if (lvl>maxLevel-level) {
            //Logger(DEBUG) << "Lebesgue2Hilbert(): cell = " << cell << ", dir = " << dir;
            hilbert += HilbertTable[dir][cell];
        }
        dir = DirTable[dir][cell];
    }
    //Logger(DEBUG) << "Lebesgue2Hilbert(): hilbert  = " << hilbert;
    //Logger(DEBUG) << "==============================";
    return hilbert;
}

CUDA_CALLABLE_MEMBER Tree::Tree() {

}

CUDA_CALLABLE_MEMBER Tree::Tree(integer *count, integer *start, integer *child, integer *sorted, integer *index,
                                integer *toDeleteLeaf, integer *toDeleteNode, real *minX, real *maxX) : count(count),
                                start(start), child(child), sorted(sorted), index(index), toDeleteLeaf(toDeleteLeaf),
                                toDeleteNode(toDeleteNode), minX(minX), maxX(maxX) {

}
CUDA_CALLABLE_MEMBER void Tree::set(integer *count, integer *start, integer *child, integer *sorted,
                                        integer *index, integer *toDeleteLeaf, integer *toDeleteNode,
                                        real *minX, real *maxX) {
    this->count = count;
    this->start = start;
    this->child = child;
    this->sorted = sorted;
    this->index = index;
    this->toDeleteNode = toDeleteNode;
    this->toDeleteLeaf = toDeleteLeaf;
    this->minX = minX;
    this->maxX = maxX;
}

#if DIM > 1
CUDA_CALLABLE_MEMBER Tree::Tree(integer *count, integer *start, integer *child, integer *sorted, integer *index,
                                integer *toDeleteLeaf, integer *toDeleteNode, real *minX, real *maxX, real *minY,
                                real *maxY) : count(count), start(start), child(child), sorted(sorted), index(index),
                                toDeleteLeaf(toDeleteLeaf), toDeleteNode(toDeleteNode), minX(minX), maxX(maxX),
                                minY(minY), maxY(maxY) {

}
CUDA_CALLABLE_MEMBER void Tree::set(integer *count, integer *start, integer *child, integer *sorted,
                                        integer *index, integer *toDeleteLeaf, integer *toDeleteNode, real *minX,
                                        real *maxX, real *minY, real *maxY) {
    this->count = count;
    this->start = start;
    this->child = child;
    this->sorted = sorted;
    this->index = index;
    this->toDeleteNode = toDeleteNode;
    this->toDeleteLeaf = toDeleteLeaf;
    this->minX = minX;
    this->maxX = maxX;
    this->minY = minY;
    this->maxY = maxY;
}

#if DIM == 3
CUDA_CALLABLE_MEMBER Tree::Tree(integer *count, integer *start, integer *child, integer *sorted, integer *index,
                                integer *toDeleteLeaf, integer *toDeleteNode,
                                real *minX, real *maxX, real *minY, real *maxY, real *minZ, real *maxZ) : count(count),
                                start(start), child(child), sorted(sorted), index(index), toDeleteLeaf(toDeleteLeaf),
                                toDeleteNode(toDeleteNode), minX(minX), maxX(maxX), minY(minY), maxY(maxY), minZ(minZ),
                                maxZ(maxZ) {

}
CUDA_CALLABLE_MEMBER void Tree::set(integer *count, integer *start, integer *child, integer *sorted,
                                        integer *index, integer *toDeleteLeaf, integer *toDeleteNode,
                                        real *minX, real *maxX, real *minY, real *maxY,
                                        real *minZ, real *maxZ) {
    this->count = count;
    this->start = start;
    this->child = child;
    this->sorted = sorted;
    this->index = index;
    this->toDeleteNode = toDeleteNode;
    this->toDeleteLeaf = toDeleteLeaf;
    this->minX = minX;
    this->maxX = maxX;
    this->minY = minY;
    this->maxY = maxY;
    this->minZ = minZ;
    this->maxZ = maxZ;
}
#endif
#endif

CUDA_CALLABLE_MEMBER void Tree::reset(integer index, integer n) {
#if DIM == 1
    #pragma unroll 2
#elif DIM == 2
    #pragma unroll 4
#else
    #pragma unroll 8
#endif
    for (integer i=0; i<POW_DIM; i++) {
        // reset child indices
        child[index * POW_DIM + i] = -1;
    }
    // reset counter in dependence of being a node or a leaf
    if (index < n) {
        count[index] = 1;
    }
    else {
        count[index] = 0;
    }
    // reset start
    start[index] = -1;
    sorted[index] = 0;
}

CUDA_CALLABLE_MEMBER keyType Tree::getParticleKey(Particles *particles, integer index, integer maxLevel,
                                                  Curve::Type curveType) {

    integer level = 0;
    keyType particleKey = (keyType)0;

    integer sonBox;
    real min_x = *minX;
    real max_x = *maxX;
#if DIM > 1
    real min_y = *minY;
    real max_y = *maxY;
#if DIM == 3
    real min_z = *minZ;
    real max_z = *maxZ;
#endif
#endif

    integer particleLevel;
    integer particleLevelTemp = 0;
    integer childIndex = 0;
    // calculate path to the particle's position assuming an (oct-)tree with above bounding boxes
    while (level <= maxLevel) {
        sonBox = 0;
        // find insertion point for body
        if (particles->x[index] < 0.5 * (min_x + max_x)) {
            sonBox += 1;
            max_x = 0.5 * (min_x + max_x);
        }
        else { min_x = 0.5 * (min_x + max_x); }
#if DIM > 1
        if (particles->y[index] < 0.5 * (min_y+max_y)) {
            sonBox += 2;
            max_y = 0.5 * (min_y + max_y);
        }
        else { min_y = 0.5 * (min_y + max_y); }
#if DIM == 3
        if (particles->z[index] < 0.5 * (min_z+max_z)) {
            sonBox += 4;
            max_z = 0.5 * (min_z + max_z);
        }
        else { min_z =  0.5 * (min_z + max_z); }
#endif
#endif
        particleKey = particleKey | ((keyType)sonBox << (keyType)(DIM * (maxLevel-level-1)));
        level++;

        particleLevelTemp++;
        if (childIndex == index) {
            particleLevel = particleLevelTemp;
        }
        /*for (int i_child = 0; i_child < POW_DIM; i_child++) {
            if (child[POW_DIM * childIndex + i_child] == index) {
                printf("found index = %i for child[8 * %i + %i] = %i\n", index, childIndex, i_child, child[POW_DIM * childIndex + i_child]);
                break;
            }
        }*/
        childIndex = child[POW_DIM * childIndex + sonBox];
    }

    /*if (particleLevel == 0) {
        printf("particleLevel = %i particleLevelTemp = %i index = %i (%f, %f, %f)\n", particleLevel, particleLevelTemp, index,
               particles->x[index], particles->y[index], particles->z[index]);
    }*/

    //if (particleKey == 0UL) {
    //    printf("Why key = %lu? x = (%f, %f, %f) min = (%f, %f, %f), max = (%f, %f, %f)\n", particleKey,
    //           particles->x[index], particles->y[index], particles->z[index],
    //           *minX, *minY, *minZ, *maxX, *maxY, *maxZ);
    //}

    switch (curveType) {
        case Curve::lebesgue: {
            //keyType hilbert = KeyNS::lebesgue2hilbert(particleKey, maxLevel);
            return particleKey;
        }
        case Curve::hilbert: {
            return KeyNS::lebesgue2hilbert(particleKey, maxLevel, maxLevel);
            return KeyNS::lebesgue2hilbert(particleKey, maxLevel);
        }
        default:
            printf("Curve type not available!\n");
            return (keyType)0;
    }
}

CUDA_CALLABLE_MEMBER integer Tree::getTreeLevel(Particles *particles, integer index, integer maxLevel,
                                                Curve::Type curveType) {

    keyType key = getParticleKey(particles, index, maxLevel); //, curveType); //TODO: hilbert working for lebesgue: why???
    integer level = 0;
    integer childIndex;

    //integer *path = new integer[maxLevel];
    integer path[MAX_LEVEL];
    for (integer i=0; i<maxLevel; i++) {
        path[i] = (integer) (key >> (maxLevel * DIM - DIM * (i + 1)) & (integer)(POW_DIM - 1));
        //printf("path[%i] = %i\n", i, path[i]);
    }

    childIndex = 0;

    for (integer i=0; i<maxLevel; i++) {
        level++;
        if (childIndex == index) {
            return level;
        }
        childIndex = child[POW_DIM * childIndex + path[i]];
        //level++;
    }

    //childIndex = 0; //child[path[0]];
#if DIM == 3
    printf("ATTENTION: level = -1 (index = %i x = (%f, %f, %f) %f) tree index = %i\n",
           index, particles->x[index], particles->y[index], particles->z[index], particles->mass[index], *this->index);
#endif

    //for (integer i=0; i<maxLevel; i++) {
    //    childIndex = child[POW_DIM * childIndex + path[i]];
    //    for (int k=0; k<8; k++) {
    //        if (child[POW_DIM * childIndex + k] == index) {
    //            printf("FOUND index = %i in level %i for child = %i x = (%f, %f, %f) ((%i, %i), (%i, %i))\n", index, i, k,
    //                   particles->x[index], particles->y[index], particles->z[index],
    //                   toDeleteLeaf[0], toDeleteLeaf[1], toDeleteNode[0], toDeleteNode[1]);
    //        }
    //    }
    //    //printf("index = %i, path[%i] = %i, childIndex = %i\n", index, i, path[i], childIndex);
    //}

    //delete [] path;

    return -1;
}

CUDA_CALLABLE_MEMBER integer Tree::sumParticles() {
    integer sumParticles = 0;
    // sum over first level tree count values
    for (integer i=0; i<POW_DIM; i++) {
        sumParticles += count[child[i]];
    }
    printf("sumParticles = %i\n", sumParticles);
    return sumParticles;
}

CUDA_CALLABLE_MEMBER Tree::~Tree() {

}

__global__ void TreeNS::Kernel::computeBoundingBox(Tree *tree, Particles *particles, integer *mutex, integer n,
                                                 integer blockSize) {

    integer index = threadIdx.x + blockDim.x * blockIdx.x;
    integer stride = blockDim.x * gridDim.x;

    real x_min = particles->x[index];
    real x_max = particles->x[index];
#if DIM > 1
    real y_min = particles->y[index];
    real y_max = particles->y[index];
#if DIM == 3
    real z_min = particles->z[index];
    real z_max = particles->z[index];
#endif
#endif

    extern __shared__ real buffer[];

    real* x_min_buffer = (real*)buffer;
    real* x_max_buffer = (real*)&x_min_buffer[blockSize];
#if DIM > 1
    real* y_min_buffer = (real*)&x_max_buffer[blockSize];
    real* y_max_buffer = (real*)&y_min_buffer[blockSize];
#if DIM == 3
    real* z_min_buffer = (real*)&y_max_buffer[blockSize];
    real* z_max_buffer = (real*)&z_min_buffer[blockSize];
#endif
#endif

    integer offset = stride;

    // find (local) min/max
    while (index + offset < n) {

        x_min = fminf(x_min, particles->x[index + offset]);
        x_max = fmaxf(x_max, particles->x[index + offset]);
#if DIM > 1
        y_min = fminf(y_min, particles->y[index + offset]);
        y_max = fmaxf(y_max, particles->y[index + offset]);
#if DIM == 3
        z_min = fminf(z_min, particles->z[index + offset]);
        z_max = fmaxf(z_max, particles->z[index + offset]);
#endif
#endif

        offset += stride;
    }

    // save value in corresponding buffer
    x_min_buffer[threadIdx.x] = x_min;
    x_max_buffer[threadIdx.x] = x_max;
#if DIM > 1
    y_min_buffer[threadIdx.x] = y_min;
    y_max_buffer[threadIdx.x] = y_max;
#if DIM == 3
    z_min_buffer[threadIdx.x] = z_min;
    z_max_buffer[threadIdx.x] = z_max;
#endif
#endif

    // synchronize threads / wait for unfinished threads
    __syncthreads();

    integer i = blockDim.x/2; // assuming blockDim.x is a power of 2!
    //printf("blockDim.x = %i\n", blockDim.x);

    // reduction within block
    while (i != 0) {
        if (threadIdx.x < i) {
            x_min_buffer[threadIdx.x] = fminf(x_min_buffer[threadIdx.x], x_min_buffer[threadIdx.x + i]);
            x_max_buffer[threadIdx.x] = fmaxf(x_max_buffer[threadIdx.x], x_max_buffer[threadIdx.x + i]);
#if DIM > 1
            y_min_buffer[threadIdx.x] = fminf(y_min_buffer[threadIdx.x], y_min_buffer[threadIdx.x + i]);
            y_max_buffer[threadIdx.x] = fmaxf(y_max_buffer[threadIdx.x], y_max_buffer[threadIdx.x + i]);
#if DIM == 3
            z_min_buffer[threadIdx.x] = fminf(z_min_buffer[threadIdx.x], z_min_buffer[threadIdx.x + i]);
            z_max_buffer[threadIdx.x] = fmaxf(z_max_buffer[threadIdx.x], z_max_buffer[threadIdx.x + i]);
#endif
#endif
        }
        __syncthreads();
        i /= 2;
    }

    // combining the results and generate the root cell
    if (threadIdx.x == 0) {
        while (atomicCAS(mutex, 0 ,1) != 0); // lock

        *tree->minX = fminf(*tree->minX, x_min_buffer[0]);
        *tree->maxX = fmaxf(*tree->maxX, x_max_buffer[0]);
        //*tree->minX -= 0.001;
        //*tree->maxX += 0.001;
#if DIM > 1
        *tree->minY = fminf(*tree->minY, y_min_buffer[0]);
        *tree->maxY = fmaxf(*tree->maxY, y_max_buffer[0]);
        //*tree->minY -= 0.001;
        //*tree->maxY += 0.001;

#if CUBIC_DOMAINS
        if (*tree->minY < *tree->minX) {
            *tree->minX = *tree->minY;
        }
        else {
            *tree->minY = *tree->minX;
        }
        if (*tree->maxY > *tree->maxX) {
            *tree->maxX = *tree->maxY;
        }
        else {
            *tree->maxY = *tree->maxX;
        }
#endif

#if DIM == 3
        *tree->minZ = fminf(*tree->minZ, z_min_buffer[0]);
        *tree->maxZ = fmaxf(*tree->maxZ, z_max_buffer[0]);
        //*tree->minZ -= 0.001;
        //*tree->maxZ += 0.001;

#if CUBIC_DOMAINS
        if (*tree->minZ < *tree->minX) {
            *tree->minX = *tree->minZ;
            *tree->minY = *tree->minZ;
        }
        else {
            *tree->minZ = *tree->minX;
        }
        if (*tree->maxZ > *tree->maxX) {
            *tree->maxX = *tree->maxZ;
            *tree->maxY = *tree->maxZ;
        }
        else {
            *tree->maxZ = *tree->maxX;
        }
#endif

#endif
#endif
        atomicExch(mutex, 0); // unlock
    }
}



__global__ void TreeNS::Kernel::sumParticles(Tree *tree) {

    integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
    integer stride = blockDim.x * gridDim.x;
    integer offset = 0;

    if (bodyIndex == 0) {
        integer sumParticles = tree->sumParticles();
        printf("sumParticles = %i\n", sumParticles);
    }
}

#define COMPUTE_DIRECTLY 0

__global__ void TreeNS::Kernel::buildTree(Tree *tree, Particles *particles, integer n, integer m) {

    integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
    integer stride = blockDim.x * gridDim.x;

    //note: -1 used as "null pointer"
    //note: -2 used to lock a child (pointer)

    integer offset;
    int level;
    bool newBody = true;

    real min_x;
    real max_x;
    real x;
#if DIM > 1
    real y;
    real min_y;
    real max_y;
#if DIM == 3
    real z;
    real min_z;
    real max_z;
#endif
#endif

    integer childPath;
    integer temp;

    offset = 0;

    while ((bodyIndex + offset) < n) {

        if (newBody) {

            newBody = false;
            level = 0;

            // copy bounding box(es)
            min_x = *tree->minX;
            max_x = *tree->maxX;
            x = particles->x[bodyIndex + offset];
#if DIM > 1
            y = particles->y[bodyIndex + offset];
            min_y = *tree->minY;
            max_y = *tree->maxY;
#if DIM == 3
            z = particles->z[bodyIndex + offset];
            min_z = *tree->minZ;
            max_z = *tree->maxZ;
#endif
#endif
            temp = 0;
            childPath = 0;

            // find insertion point for body
            //if (particles->x[bodyIndex + offset] < 0.5 * (min_x + max_x)) { // x direction
            if (x < 0.5 * (min_x + max_x)) { // x direction
                childPath += 1;
                max_x = 0.5 * (min_x + max_x);
            }
            else {
                min_x = 0.5 * (min_x + max_x);
            }
#if DIM > 1
            //if (particles->y[bodyIndex + offset] < 0.5 * (min_y + max_y)) { // y direction
            if (y < 0.5 * (min_y + max_y)) { // y direction
                childPath += 2;
                max_y = 0.5 * (min_y + max_y);
            }
            else {
                min_y = 0.5 * (min_y + max_y);
            }
#if DIM == 3
            //if (particles->z[bodyIndex + offset] < 0.5 * (min_z + max_z)) {  // z direction
            if (z < 0.5 * (min_z + max_z)) {  // z direction
                childPath += 4;
                max_z = 0.5 * (min_z + max_z);
            }
            else {
                min_z = 0.5 * (min_z + max_z);
            }
#endif
#endif
        }

        integer childIndex = tree->child[temp*POW_DIM + childPath];

        // traverse tree until hitting leaf node
        while (childIndex >= m) { //n

            temp = childIndex;
            level++;

            childPath = 0;

            // find insertion point for body
            //if (particles->x[bodyIndex + offset] < 0.5 * (min_x + max_x)) { // x direction
            if (x < 0.5 * (min_x + max_x)) { // x direction
                childPath += 1;
                max_x = 0.5 * (min_x + max_x);
            }
            else {
                min_x = 0.5 * (min_x + max_x);
            }
#if DIM > 1
            //if (particles->y[bodyIndex + offset] < 0.5 * (min_y + max_y)) { // y direction
            if (y < 0.5 * (min_y + max_y)) { // y direction
                childPath += 2;
                max_y = 0.5 * (min_y + max_y);
            }
            else {
                min_y = 0.5 * (min_y + max_y);
            }
#if DIM == 3
            //if (particles->z[bodyIndex + offset] < 0.5 * (min_z + max_z)) { // z direction
            if (z < 0.5 * (min_z + max_z)) { // z direction
                childPath += 4;
                max_z = 0.5 * (min_z + max_z);
            }
            else {
                min_z = 0.5 * (min_z + max_z);
            }
#endif
#endif
#if COMPUTE_DIRECTLY
            if (particles->mass[bodyIndex + offset] != 0) {
                //particles->x[temp] += particles->weightedEntry(bodyIndex + offset, Entry::x);
                atomicAdd(&particles->x[temp], particles->weightedEntry(bodyIndex + offset, Entry::x));
#if DIM > 1
                //particles->y[temp] += particles->weightedEntry(bodyIndex + offset, Entry::y);
                atomicAdd(&particles->y[temp], particles->weightedEntry(bodyIndex + offset, Entry::y));
#if DIM == 3
                //particles->z[temp] += particles->weightedEntry(bodyIndex + offset, Entry::z);
                atomicAdd(&particles->z[temp], particles->weightedEntry(bodyIndex + offset, Entry::z));
#endif
#endif
            }

            //particles->mass[temp] += particles->mass[bodyIndex + offset];
            atomicAdd(&particles->mass[temp], particles->mass[bodyIndex + offset]);
#endif // COMPUTE_DIRECTLY

            atomicAdd(&tree->count[temp], 1);

            childIndex = tree->child[POW_DIM * temp + childPath];
        }

        // if child is not locked
        if (childIndex != -2) {

            integer locked = temp * POW_DIM + childPath;

            if (atomicCAS(&tree->child[locked], childIndex, -2) == childIndex) {

                // check whether a body is already stored at the location
                if (childIndex == -1) {
                    //insert body and release lock
                    tree->child[locked] = bodyIndex + offset;
                    particles->level[bodyIndex + offset] = level + 1;

                }
                else {
                    if (childIndex >= n) {
                        printf("ATTENTION!\n");
                    }
                    integer patch = POW_DIM * m; //8*n
                    while (childIndex >= 0 && childIndex < n) { // was n

                        //create a new cell (by atomically requesting the next unused array index)
                        integer cell = atomicAdd(tree->index, 1);
                        patch = min(patch, cell);

                        if (patch != cell) {
                            tree->child[POW_DIM * temp + childPath] = cell;
                        }

                        particles->level[temp] = level;
                        level++;

                        // insert old/original particle
                        childPath = 0;
                        if (particles->x[childIndex] < 0.5 * (min_x + max_x)) { childPath += 1; }
#if DIM > 1
                        if (particles->y[childIndex] < 0.5 * (min_y + max_y)) { childPath += 2; }
#if DIM == 3
                        if (particles->z[childIndex] < 0.5 * (min_z + max_z)) { childPath += 4; }
#endif
#endif

#if COMPUTE_DIRECTLY
                        particles->x[cell] += particles->weightedEntry(childIndex, Entry::x);
                        //particles->x[cell] += particles->weightedEntry(childIndex, Entry::x);
#if DIM > 1
                        particles->y[cell] += particles->weightedEntry(childIndex, Entry::y);
                        //particles->y[cell] += particles->weightedEntry(childIndex, Entry::y);
#if DIM == 3
                        particles->z[cell] += particles->weightedEntry(childIndex, Entry::z);
                        //particles->z[cell] += particles->weightedEntry(childIndex, Entry::z);
#endif
#endif

                        //if (cell % 1000 == 0) {
                        //    printf("buildTree: x[%i] = (%f, %f, %f) from x[%i] = (%f, %f, %f) m = %f\n", cell, particles->x[cell], particles->y[cell],
                        //           particles->z[cell], childIndex, particles->x[childIndex], particles->y[childIndex],
                        //           particles->z[childIndex], particles->mass[childIndex]);
                        //}

                        particles->mass[cell] += particles->mass[childIndex];
#endif // COMPUTE_DIRECTLY
                        tree->count[cell] += tree->count[childIndex];
                        //level++;

                        tree->child[POW_DIM * cell + childPath] = childIndex;
                        particles->level[cell] = level;
                        tree->start[cell] = -1;

                        // insert new particle
                        temp = cell;
                        childPath = 0;

                        // find insertion point for body
                        //if (particles->x[bodyIndex + offset] < 0.5 * (min_x + max_x)) {
                        if (x < 0.5 * (min_x + max_x)) {
                            childPath += 1;
                            max_x = 0.5 * (min_x + max_x);
                        } else {
                            min_x = 0.5 * (min_x + max_x);
                        }
#if DIM > 1
                        //if (particles->y[bodyIndex + offset] < 0.5 * (min_y + max_y)) {
                        if (y < 0.5 * (min_y + max_y)) {
                            childPath += 2;
                            max_y = 0.5 * (min_y + max_y);
                        } else {
                            min_y = 0.5 * (min_y + max_y);
                        }
#if DIM == 3
                        //if (particles->z[bodyIndex + offset] < 0.5 * (min_z + max_z)) {
                        if (z < 0.5 * (min_z + max_z)) {
                            childPath += 4;
                            max_z = 0.5 * (min_z + max_z);
                        } else {
                            min_z = 0.5 * (min_z + max_z);
                        }
#endif
#endif
#if COMPUTE_DIRECTLY
                        // COM / preparing for calculation of COM
                        if (particles->mass[bodyIndex + offset] != 0) {
                            //particles->x[cell] += particles->weightedEntry(bodyIndex + offset, Entry::x);
                            particles->x[cell] += particles->weightedEntry(bodyIndex + offset, Entry::x);
#if DIM > 1
                            //particles->y[cell] += particles->weightedEntry(bodyIndex + offset, Entry::y);
                            particles->y[cell] += particles->weightedEntry(bodyIndex + offset, Entry::y);
#if DIM == 3
                            //particles->z[cell] += particles->weightedEntry(bodyIndex + offset, Entry::z);
                            particles->z[cell] += particles->weightedEntry(bodyIndex + offset, Entry::z);
#endif
#endif
                            particles->mass[cell] += particles->mass[bodyIndex + offset];
                        }
#endif // COMPUTE_DIRECTLY
                        tree->count[cell] += tree->count[bodyIndex + offset];
                        childIndex = tree->child[POW_DIM * temp + childPath];
                    }

                    tree->child[POW_DIM * temp + childPath] = bodyIndex + offset;
                    particles->level[bodyIndex + offset] = level + 1;

                    __threadfence();  // written to global memory arrays (child, x, y, mass) thus need to fence
                    tree->child[locked] = patch;
                }
                offset += stride;
                newBody = true;
            }
        }
        //__syncthreads(); //TODO: needed?
    }
}


__global__ void TreeNS::Kernel::buildTreeMiluphcuda(Tree *tree, Particles *particles, integer n, integer m) {

}


__global__ void TreeNS::Kernel::calculateCentersOfMass(Tree *tree, Particles *particles, integer n, integer level) {

    integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
    integer stride = blockDim.x * gridDim.x;

    integer offset = n;

    //int counter[21];
    //for (int i=0; i<21;i++) {
    //    counter[i] = 0;
    //}

    integer index;

    while ((bodyIndex + offset) < *tree->index) {

        if (particles->level[bodyIndex + offset] == level) {

            if (particles->level[bodyIndex + offset] == -1 || particles->level[bodyIndex + offset] > 21) {
                printf("level[%i] = %i!!!\n", bodyIndex + offset, particles->level[bodyIndex + offset]);
            }

            particles->mass[bodyIndex + offset] = 0.;
            particles->x[bodyIndex + offset] = 0.;
#if DIM > 1
            particles->y[bodyIndex + offset] = 0.;
#if DIM == 3
            particles->z[bodyIndex + offset] = 0.;
#endif
#endif

            for (int child = 0; child < POW_DIM; ++child) {
                index = POW_DIM * (bodyIndex + offset) + child;
                if (tree->child[index] != -1) {
                    particles->x[bodyIndex + offset] += particles->weightedEntry(tree->child[index], Entry::x);
#if DIM > 1
                    particles->y[bodyIndex + offset] += particles->weightedEntry(tree->child[index], Entry::y);
#if DIM == 3
                    particles->z[bodyIndex + offset] += particles->weightedEntry(tree->child[index], Entry::z);
#endif
#endif
                    particles->mass[bodyIndex + offset] += particles->mass[tree->child[index]];
                }
            }

            if (particles->mass[bodyIndex + offset] > 0.) {
                particles->x[bodyIndex + offset] /= particles->mass[bodyIndex + offset];
#if DIM > 1
                particles->y[bodyIndex + offset] /= particles->mass[bodyIndex + offset];
#if DIM == 3
                particles->z[bodyIndex + offset] /= particles->mass[bodyIndex + offset];
#endif
#endif
            }


            //counter[particles->level[bodyIndex + offset]] += 1;

        }
        offset += stride;
    }

    //for (int i=0; i<21;i++) {
    //    printf("counter[%i] = %i\n", i, counter[i]);
    //}

}

/*
__global__
void SummarizationKernel(const int nnodesd, const int nbodiesd, volatile int* const __restrict__ countd, const int* const __restrict__ childd, volatile float4* const __restrict__ posMassd)
{
    int i, j, k, ch, inc, cnt, bottom;
    float m, cm, px, py, pz;
    __shared__ int child[THREADS3 * 8];
    __shared__ float mass[THREADS3 * 8];

    bottom = bottomd;
    inc = blockDim.x * gridDim.x;
    k = (bottom & (-WARPSIZE)) + threadIdx.x + blockIdx.x * blockDim.x;  // align to warp size
    if (k < bottom) k += inc;

    int restart = k;
    for (j = 0; j < 3; j++) {  // wait-free pre-passes
        // iterate over all cells assigned to thread
        while (k <= nnodesd) {
            if (posMassd[k].w < 0.0f) {
                for (i = 0; i < POW_DIM; i++) {
                    ch = childd[k*POW_DIM+i];
                    child[i*THREADS3+threadIdx.x] = ch;  // cache children
                    if ((ch >= nbodiesd) && ((mass[i*THREADS3+threadIdx.x] = posMassd[ch].w) < 0.0f)) {
                        break;
                    }
                }
                if (i == 8) {
                    // all children are ready
                    cm = 0.0f;
                    px = 0.0f;
                    py = 0.0f;
                    pz = 0.0f;
                    cnt = 0;
                    for (i = 0; i < 8; i++) {
                        ch = child[i*THREADS3+threadIdx.x];
                        if (ch >= 0) {
                            // four reads due to missing copy constructor for "volatile float4"
                            const float chx = posMassd[ch].x;
                            const float chy = posMassd[ch].y;
                            const float chz = posMassd[ch].z;
                            const float chw = posMassd[ch].w;
                            if (ch >= nbodiesd) {  // count bodies (needed later)
                                m = mass[i*THREADS3+threadIdx.x];
                                cnt += countd[ch];
                            } else {
                                m = chw;
                                cnt++;
                            }
                            // add child's contribution
                            cm += m;
                            px += chx * m;
                            py += chy * m;
                            pz += chz * m;
                        }
                    }
                    countd[k] = cnt;
                    m = 1.0f / cm;
                    // four writes due to missing copy constructor for "volatile float4"
                    posMassd[k].x = px * m;
                    posMassd[k].y = py * m;
                    posMassd[k].z = pz * m;
                    __threadfence();
                    posMassd[k].w = cm;
                }
            }
            k += inc;  // move on to next cell
        }
        k = restart;
    }

    j = 0;
    // iterate over all cells assigned to thread
    while (k <= nnodesd) {
        if (posMassd[k].w >= 0.0f) {
            k += inc;
        } else {
            if (j == 0) {
                j = 8;
                for (i = 0; i < 8; i++) {
                    ch = childd[k*8+i];
                    child[i*THREADS3+threadIdx.x] = ch;  // cache children
                    if ((ch < nbodiesd) || ((mass[i*THREADS3+threadIdx.x] = posMassd[ch].w) >= 0.0f)) {
                        j--;
                    }
                }
            } else {
                j = 8;
                for (i = 0; i < 8; i++) {
                    ch = child[i*THREADS3+threadIdx.x];
                    if ((ch < nbodiesd) || (mass[i*THREADS3+threadIdx.x] >= 0.0f) || ((mass[i*THREADS3+threadIdx.x] = posMassd[ch].w) >= 0.0f)) {
                        j--;
                    }
                }
            }

            if (j == 0) {
                // all children are ready
                cm = 0.0f;
                px = 0.0f;
                py = 0.0f;
                pz = 0.0f;
                cnt = 0;
                for (i = 0; i < 8; i++) {
                    ch = child[i*THREADS3+threadIdx.x];
                    if (ch >= 0) {
                        // four reads due to missing copy constructor for "volatile float4"
                        const float chx = posMassd[ch].x;
                        const float chy = posMassd[ch].y;
                        const float chz = posMassd[ch].z;
                        const float chw = posMassd[ch].w;
                        if (ch >= nbodiesd) {  // count bodies (needed later)
                            m = mass[i*THREADS3+threadIdx.x];
                            cnt += countd[ch];
                        } else {
                            m = chw;
                            cnt++;
                        }
                        // add child's contribution
                        cm += m;
                        px += chx * m;
                        py += chy * m;
                        pz += chz * m;
                    }
                }
                countd[k] = cnt;
                m = 1.0f / cm;
                // four writes due to missing copy constructor for "volatile float4"
                posMassd[k].x = px * m;
                posMassd[k].y = py * m;
                posMassd[k].z = pz * m;
                __threadfence();
                posMassd[k].w = cm;
                k += inc;
            }
        }
    }
}*/

__global__ void TreeNS::Kernel::centerOfMass(Tree *tree, Particles *particles, integer n) {

    integer bodyIndex = threadIdx.x + blockIdx.x*blockDim.x;
    integer stride = blockDim.x*gridDim.x;
    integer offset = 0;

    //note: most of it already done within buildTreeKernel
    bodyIndex += n;

    while (bodyIndex + offset < *tree->index) {

        //if (particles->mass[bodyIndex + offset] == 0) {
        //    printf("centreOfMassKernel: mass = 0 (%i)!\n", bodyIndex + offset);
        //}

        if (particles->mass[bodyIndex + offset] != 0) {
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

__global__ void TreeNS::Kernel::sort(Tree *tree, integer n, integer m) {

    integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
    integer stride = blockDim.x * gridDim.x;
    integer offset = 0;

    integer s = 0;
    if (threadIdx.x == 0) {

        for (integer i=0; i<POW_DIM; i++){

            integer node = tree->child[i];
            // not a leaf node
            if (node >= m) { //n
                tree->start[node] = s;
                s += tree->count[node];
            }
                // leaf node
            else if (node >= 0) {
                tree->sorted[s] = node;
                s++;
            }
        }
    }
    integer cell = m + bodyIndex;
    //integer ind = *tree->index;
    integer ind = tree->toDeleteNode[1];

    while ((cell + offset) < ind) {

        s = tree->start[cell + offset];

        if (s >= 0) {

            for (integer i=0; i<POW_DIM; i++) {
                integer node = tree->child[POW_DIM*(cell+offset) + i];
                // not a leaf node
                if (node >= m) { //m
                    tree->start[node] = s;
                    s += tree->count[node];
                }
                // leaf node
                else if (node >= 0) {
                    tree->sorted[s] = node;
                    s++;
                }
            }
            offset += stride;
        }
    }
}

__global__ void TreeNS::Kernel::getParticleKeys(Tree *tree, Particles *particles, keyType *keys, integer maxLevel,
                                integer n, Curve::Type curveType) {

    integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
    integer stride = blockDim.x * gridDim.x;
    integer offset = 0;

    keyType particleKey;

    while (bodyIndex + offset < n) {

        particleKey = tree->getParticleKey(particles, bodyIndex + offset, maxLevel, curveType);
#if DIM == 3
        if (particleKey == 1UL) {
            printf("particleKey = %lu (%f, %f, %f)\n", particleKey, particles->x[bodyIndex + offset],
                   particles->y[bodyIndex + offset], particles->z[bodyIndex + offset]);
        }
#endif

        if ((bodyIndex + offset) % 100 == 0) {
            printf("key = %lu\n", particleKey);
        }
        keys[bodyIndex + offset] = particleKey;

        offset += stride;
    }
}

namespace TreeNS {

    namespace Kernel {

        __global__ void set(Tree *tree, integer *count, integer *start, integer *child, integer *sorted,
                                  integer *index, integer *toDeleteLeaf, integer *toDeleteNode, real *minX, real *maxX) {
            tree->set(count, start, child, sorted, index, toDeleteLeaf, toDeleteNode, minX, maxX);
        }

        __global__ void info(Tree *tree, Particles *particles, integer n, integer m) {
            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            //while (bodyIndex + offset < n) {
            //    if ((bodyIndex + offset) % 10000 == 0) {
            //        printf("tree info\n");
            //    }
            //    offset += stride;
            //}

            bodyIndex += n;
            while (bodyIndex + offset < m) {

                //printf("particles->mass[%i] = %f (%f, %f, %f) (%i, %i)\n", bodyIndex + offset,
                //       particles->mass[bodyIndex + offset],
                //       particles->x[bodyIndex + offset],
                //       particles->y[bodyIndex + offset],
                //       particles->z[bodyIndex + offset], n, m);

                //printf("x[%i] = (%f, %f, %f) mass = %f\n", bodyIndex + offset, particles->x[bodyIndex + offset],
                //       particles->y[bodyIndex + offset], particles->z[bodyIndex + offset],
                //       particles->mass[bodyIndex + offset]);
#if DIM == 1
                printf("(%f), \n", particles->x[bodyIndex + offset]);
#elif DIM == 2
                printf("(%f, %f), \n", particles->x[bodyIndex + offset],
                       particles->y[bodyIndex + offset]);
#else
                printf("(%f, %f, %f), \n", particles->x[bodyIndex + offset],
                               particles->y[bodyIndex + offset], particles->z[bodyIndex + offset]);
#endif

                offset += stride;
            }
        }

        __global__ void info(Tree *tree, Particles *particles) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            while (bodyIndex + offset < POW_DIM) {
#if DIM == 3
                printf("child[POW_DIM * 0 + %i] = %i, x = (%f, %f, %f) m = %f\n", bodyIndex + offset,
                       tree->child[bodyIndex + offset], particles->x[tree->child[bodyIndex + offset]],
                       particles->y[tree->child[bodyIndex + offset]], particles->z[tree->child[bodyIndex + offset]],
                       particles->mass[tree->child[bodyIndex + offset]]);

                for (int i=0; i<POW_DIM; i++) {
                    printf("child[POW_DIM * %i + %i] = %i, x = (%f, %f, %f) m = %f\n", tree->child[bodyIndex + offset], i,
                           tree->child[POW_DIM * tree->child[bodyIndex + offset] + i],
                           particles->x[tree->child[POW_DIM * tree->child[bodyIndex + offset] + i]],
                           particles->y[tree->child[POW_DIM * tree->child[bodyIndex + offset] + i]],
                           particles->z[tree->child[POW_DIM * tree->child[bodyIndex + offset] + i]],
                           particles->mass[tree->child[POW_DIM * tree->child[bodyIndex + offset] + i]]);
                }
#endif

                offset += stride;
            }
        }

        __global__ void testTree(Tree *tree, Particles *particles, integer n, integer m) {

            integer bodyIndex = threadIdx.x + blockIdx.x * blockDim.x;
            integer stride = blockDim.x * gridDim.x;
            integer offset = 0;

            real mass;
            real masses[POW_DIM];

            while (bodyIndex + offset < POW_DIM) {

                mass = 0;

                for (int i=0; i<POW_DIM; i++) {
                    masses[i] = 0;
                    if (tree->child[POW_DIM * tree->child[bodyIndex + offset] + i] != -1) {
                        masses[i] = particles->mass[tree->child[POW_DIM * tree->child[bodyIndex + offset] + i]];
                        mass += masses[i];
                    }
                }
                if (mass != particles->mass[tree->child[bodyIndex + offset]]) {
                    printf("testTree: index: %i mass %f vs %f (%f, %f, %f, %f, %f, %f, %f, %f)\n", bodyIndex + offset, mass, particles->mass[tree->child[bodyIndex + offset]],
                           masses[0], masses[1], masses[2], masses[3], masses[4], masses[5], masses[6], masses[7]);
                }

                offset += stride;
            }

            //while (bodyIndex + offset < n) {
            //    if (particles->x[bodyIndex + offset] == 0.f &&
            //        particles->y[bodyIndex + offset] == 0.f &&
            //        particles->z[bodyIndex + offset] == 0.f &&
            //        particles->mass[bodyIndex + offset] == 0.f) {
            //        printf("particle ZERO for index = %i: (%f, %f, %f) %f\n", bodyIndex + offset,
            //               particles->x[bodyIndex + offset], particles->y[bodyIndex + offset],
            //               particles->z[bodyIndex + offset], particles->mass[bodyIndex + offset]);
            //    }
            //
            //    offset += stride;
            //}
            //offset = m;
            //while (bodyIndex + offset < *tree->index) {
            //    if (particles->x[bodyIndex + offset] == 0.f &&
            //        particles->y[bodyIndex + offset] == 0.f &&
            //        particles->z[bodyIndex + offset] == 0.f &&
            //        particles->mass[bodyIndex + offset] == 0.f) {
            //        printf("particle ZERO for index = %i: (%f, %f, %f) %f\n", bodyIndex + offset,
            //               particles->x[bodyIndex + offset], particles->y[bodyIndex + offset],
            //               particles->z[bodyIndex + offset], particles->mass[bodyIndex + offset]);
            //    }
            //    offset += stride;
            //}
        }

        void Launch::set(Tree *tree, integer *count, integer *start, integer *child, integer *sorted,
                             integer *index, integer *toDeleteLeaf, integer *toDeleteNode , real *minX, real *maxX) {
            ExecutionPolicy executionPolicy(1, 1);
            cuda::launch(false, executionPolicy, ::TreeNS::Kernel::set, tree, count, start, child, sorted,
                         index, toDeleteLeaf, toDeleteNode, minX, maxX);
        }

        real Launch::info(Tree *tree, Particles *particles, integer n, integer m) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::TreeNS::Kernel::info, tree, particles, n, m);
        }

        real Launch::info(Tree *tree, Particles *particles) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::TreeNS::Kernel::info, tree, particles);
        }

        real Launch::testTree(Tree *tree, Particles *particles, integer n, integer m) {
            ExecutionPolicy executionPolicy;
            return cuda::launch(true, executionPolicy, ::TreeNS::Kernel::testTree, tree, particles, n, m);
        }

#if DIM > 1

        __global__ void set(Tree *tree, integer *count, integer *start, integer *child, integer *sorted,
                                  integer *index, integer *toDeleteLeaf, integer *toDeleteNode, real *minX, real *maxX,
                                  real *minY, real *maxY) {
            tree->set(count, start, child, sorted, index, toDeleteLeaf, toDeleteNode, minX, maxX, minY, maxY);
        }

        void Launch::set(Tree *tree, integer *count, integer *start, integer *child, integer *sorted,
                             integer *index, integer *toDeleteLeaf, integer *toDeleteNode, real *minX, real *maxX,
                             real *minY, real *maxY) {
            ExecutionPolicy executionPolicy(1, 1);
            cuda::launch(false, executionPolicy, ::TreeNS::Kernel::set, tree, count, start, child, sorted, index,
                         toDeleteLeaf, toDeleteNode, minX, maxX, minY, maxY);
        }

#if DIM == 3

        __global__ void set(Tree *tree, integer *count, integer *start, integer *child, integer *sorted,
                                  integer *index, integer *toDeleteLeaf, integer *toDeleteNode, real *minX, real *maxX,
                                  real *minY, real *maxY, real *minZ, real *maxZ) {
            tree->set(count, start, child, sorted, index, toDeleteLeaf, toDeleteNode, minX, maxX, minY, maxY,
                      minZ, maxZ);
        }

        void Launch::set(Tree *tree, integer *count, integer *start, integer *child, integer *sorted,
                             integer *index, integer *toDeleteLeaf, integer *toDeleteNode, real *minX, real *maxX,
                             real *minY, real *maxY, real *minZ, real *maxZ) {
            ExecutionPolicy executionPolicy(1, 1);
            cuda::launch(false, executionPolicy, ::TreeNS::Kernel::set, tree, count, start, child, sorted, index,
                         toDeleteLeaf, toDeleteNode, minX, maxX, minY, maxY, minZ, maxZ);
        }

#endif
#endif

        namespace Launch {

            real sumParticles(Tree *tree) {
                ExecutionPolicy executionPolicy;
                return cuda::launch(true, executionPolicy, ::TreeNS::Kernel::sumParticles, tree);
            }

            real buildTree(Tree *tree, Particles *particles, integer n, integer m, bool time) {
                ExecutionPolicy executionPolicy;
                return cuda::launch(time, executionPolicy, ::TreeNS::Kernel::buildTree, tree, particles, n, m);
            }

            real buildTreeMiluphcuda(Tree *tree, Particles *particles, integer n, integer m, bool time) {
                ExecutionPolicy executionPolicy;
                return cuda::launch(time, executionPolicy, ::TreeNS::Kernel::buildTreeMiluphcuda, tree, particles, n, m);
            }

            real calculateCentersOfMass(Tree *tree, Particles *particles, integer n, integer level, bool time) {
                //size_t sharedMemory = NUM_THREADS_CALC_CENTER_OF_MASS * POW_DIM * sizeof(int);
                ExecutionPolicy executionPolicy; //(1, NUM_THREADS_CALC_CENTER_OF_MASS, sharedMemory);
                return cuda::launch(time, executionPolicy, ::TreeNS::Kernel::calculateCentersOfMass, tree, particles, n, level);
            }

            real computeBoundingBox(Tree *tree, Particles *particles, integer *mutex, integer n, integer blockSize,
                                    bool time) {
                size_t sharedMemory = 2 * DIM * sizeof(real) * blockSize;
                ExecutionPolicy executionPolicy(256, 256, sharedMemory);
                return cuda::launch(time, executionPolicy, ::TreeNS::Kernel::computeBoundingBox, tree, particles, mutex,
                                    n, blockSize);
            }

            real centerOfMass(Tree *tree, Particles *particles, integer n, bool time) {
                ExecutionPolicy executionPolicy;
                return cuda::launch(time, executionPolicy, ::TreeNS::Kernel::centerOfMass, tree, particles, n);
            }

            real sort(Tree *tree, integer n, integer m, bool time) {
                ExecutionPolicy executionPolicy;
                return cuda::launch(time, executionPolicy, ::TreeNS::Kernel::sort, tree, n, m);
            }

            real getParticleKeys(Tree *tree, Particles *particles, keyType *keys, integer maxLevel, integer n,
                                 Curve::Type curveType, bool time) {
                ExecutionPolicy executionPolicy;
                return cuda::launch(time, executionPolicy, ::TreeNS::Kernel::getParticleKeys, tree, particles, keys,
                                    maxLevel, n, curveType);
            }

        }
    }
}
