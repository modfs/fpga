#ifndef __MINER2_H__
#define __MINER2_H__


#include "hash/uint1024.h"

//#ifdef __cplusplus
//extern "C" {
//#endif

#include "cpuminer-config.h"

#include <stdbool.h>
#include <inttypes.h>
#include <sys/time.h>
#include <jansson.h>
#include <curl/curl.h>
#include <SQRL/SQRLAXI.h>

extern bool scanhash_sk1024(unsigned int thr_id, uint32_t* TheData, uint1024 TheTarget, uint64_t &TheNonce, 
	unsigned long long max_nonce, unsigned long long *hashes_done, int throughput, int thbpSkein = 256, unsigned int nHeight = 0, SQRLAXIRef axi=NULL);

//#ifdef __cplusplus
//}
//#endif

#endif /* __MINER2_H__ */
