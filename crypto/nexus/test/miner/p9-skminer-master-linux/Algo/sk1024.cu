/*
* test routine for new algorithm
*
*/
#include "../hash/uint1024.h"
#include "hash/skein.h"
#include "hash/KeccakHash.h"
#include "miner.h"
#include "miner2.h"


extern int device_map[8];
extern void skein1024_setBlock(void *pdata, unsigned nHeight);
extern uint64_t skein1024_cpu_hash(int thr_id, int threads, uint64_t startNounce, int order, int threadsperblock = 256);
extern uint64_t sk1024_keccak_cpu_hash(int thr_id, int threads, uint64_t startNounce, uint64_t *d_nonceVector, uint64_t *d_hash, int order, int threadsperblock = 32);
extern void sk1024_keccak_cpu_init(int thr_id);
extern void sk1024_set_Target(const void *ptarget);

extern bool opt_benchmark;

extern bool scanhash_sk1024(unsigned int thr_id, uint32_t* TheData, uint1024 TheTarget, uint64_t &TheNonce, unsigned long long max_nonce, unsigned long long *hashes_done, int throughput, int thbpSkein, unsigned int nHeight)
{
	uint64_t *ptarget = (uint64_t*)&TheTarget;

	const uint64_t first_nonce = TheNonce;

	const uint64_t Htarg = ptarget[15];

	static bool init[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
	if (!init[thr_id])
	{
		cudaSetDevice(device_map[thr_id]);
		cudaDeviceReset();
		cudaSetDeviceFlags(cudaDeviceScheduleBlockingSync);

		sk1024_keccak_cpu_init(thr_id);

		init[thr_id] = true;
	}


	skein1024_setBlock((void*)TheData, nHeight);
	sk1024_set_Target(ptarget);

	int order = 0;
	uint64_t foundNonce = skein1024_cpu_hash(thr_id, throughput, ((uint64_t*)TheData)[26], order++, thbpSkein);
	if (foundNonce != 0xffffffffffffffff)
	{
		((uint64_t*)TheData)[26] = foundNonce;
		uint1024 skein;
		Skein1024_Ctxt_t ctx;
		Skein1024_Init(&ctx, 1024);
		Skein1024_Update(&ctx, (unsigned char *)TheData, 216);
		Skein1024_Final(&ctx, (unsigned char *)&skein);

		uint64_t keccak[16];
		Keccak_HashInstance ctx_keccak;
		Keccak_HashInitialize(&ctx_keccak, 576, 1024, 1024, 0x05);
		Keccak_HashUpdate(&ctx_keccak, (unsigned char *)&skein, 1024);
		Keccak_HashFinal(&ctx_keccak, (unsigned char *)&keccak);

		if (keccak[15] <= Htarg) {
			TheNonce = foundNonce; //return the nonce
			*hashes_done = foundNonce - first_nonce + 1;
			return true;
		}
		else {
			printf("GPU #%d: result for nonce %lu does not validate on CPU! \n", thr_id, foundNonce);
		}
	}
	((uint64_t*)TheData)[26] += throughput;

	uint64_t doneNonce = ((uint64_t*)TheData)[26];

	if (doneNonce < 18446744072149270489lu)
		*hashes_done = doneNonce - first_nonce + 1;

	return false;
}
