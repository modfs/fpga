
#include <cuda.h>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"


#include <stdio.h>
#include <stdint.h>
#include <memory.h>

extern cudaError_t MyStreamSynchronize(cudaStream_t stream, int situation, int thr_id);
__constant__ uint64_t pTarget[16];

#include "cuda_helper.h"
