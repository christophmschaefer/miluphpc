#include "../../include/integrator/predictor_corrector.h"

PredictorCorrector::PredictorCorrector(integer numParticles, integer numNodes) :
                                        Miluphpc(numParticles, numNodes) {
    integratedParticles = new IntegratedParticles[2];
    printf("PredictorCorrector()\n");
}

PredictorCorrector::~PredictorCorrector() {
    printf("~PredictorCorrector()\n");
}

void PredictorCorrector::integrate() {
    printf("PredictorCorrector::integrate()\n");
    rhs();
    //rhs();
}