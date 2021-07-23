/*
* test routine for new algorithm
*
*/
#include "../hash/uint1024.h"
#include "hash/skein.h"
#include "hash/KeccakHash.h"
#include "../miner.h"
#include "../miner2.h"

#define ROTL64(x, y)			(((x) << (y)) | ((x) >> (64 - (y))))

#define SKEIN_KS_PARITY			0x5555555555555555ULL

const uint64_t SKEIN1024_IV[16] =
{
	0x5A4352BE62092156ULL, 0x5F6E8B1A72F001CAULL, 0xFFCBFE9CA1A2CE26ULL, 0x6C23C39667038BCAULL,
	0x583A8BFCCE34EB6CULL, 0x3FDBFB11D4A46A3EULL, 0x3304ACFCA8300998ULL, 0xB2F6675FA17F0FD2ULL,
	0x9D2599730EF7AB6BULL, 0x0914A20D3DFEA9E4ULL, 0xCC1A9CAFA494DBD3ULL, 0x9828030DA0A6388CULL,
	0x0D339D5DAADEE3DCULL, 0xFC46DE35C4E2A086ULL, 0x53D6E4F52E19A6D1ULL, 0x5663952F715D1DDDULL
};

const uint64_t keccakf_rnd_consts[24] =
{
	0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808AULL,
	0x8000000080008000ULL, 0x000000000000808BULL, 0x0000000080000001ULL,
	0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008AULL,
	0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000AULL,
	0x000000008000808BULL, 0x800000000000008BULL, 0x8000000000008089ULL,
	0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
	0x000000000000800AULL, 0x800000008000000AULL, 0x8000000080008081ULL,
	0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

//#define SKEIN_INJECT_KEY(p, s)	do { \
	p += h; \
	p.sd += t[(s) % 3]; \
	p.se += t[((s) + 1) % 3]; \
	p.sf += (s); \
} while(0)

void DumpQwords(void *data, int len)
{
	putchar('\n');
	for (int i = 0; i < len; ++i)
	{
		if (!(i & 3) && i) printf("0x%016llX,\n", ((uint64_t *)data)[i]);
		else if (i == (len - 1)) printf("0x%016llX\n\n", ((uint64_t *)data)[i]);
		else printf("0x%016llX, ", ((uint64_t *)data)[i]);
	}
}

void DumpVerilogStyle(void *data, int len)
{
	printf("%d'h", len << 3);

	for (int i = len - 1; i >= 0; --i) printf("%02X", ((uint8_t *)data)[i]);
	printf("\n");
}

static void RotateSkeinKey(uint64_t *h)
{
	uint64_t tmp = h[0];

	for (int i = 0; i < 16; ++i) h[i] = h[i + 1];

	h[16] = tmp;
}

void SkeinInjectKey(uint64_t *p, const uint64_t *h, const uint64_t *t, int s)
{
	for (int i = 0; i < 16; ++i) p[i] += h[i];

	p[13] += t[s % 3];
	p[14] += t[(s + 1) % 3];
	p[15] += s;
}

void SkeinMix8(uint64_t *pv0, uint64_t *pv1, const uint32_t rc0, const uint32_t rc1, const uint32_t rc2, const uint32_t rc3, const uint32_t rc4, const uint32_t rc5, const uint32_t rc6, const uint32_t rc7)
{
	uint64_t Temp[8];

	for (int i = 0; i < 8; ++i) pv0[i] += pv1[i];

	pv1[0] = ROTL64(pv1[0], rc0);
	pv1[1] = ROTL64(pv1[1], rc1);
	pv1[2] = ROTL64(pv1[2], rc2);
	pv1[3] = ROTL64(pv1[3], rc3);
	pv1[4] = ROTL64(pv1[4], rc4);
	pv1[5] = ROTL64(pv1[5], rc5);
	pv1[6] = ROTL64(pv1[6], rc6);
	pv1[7] = ROTL64(pv1[7], rc7);

	for (int i = 0; i < 8; ++i) pv1[i] ^= pv0[i];

	memcpy(Temp, pv0, 64);

	pv0[0] = Temp[0];
	pv0[1] = Temp[1];
	pv0[2] = Temp[3];
	pv0[3] = Temp[2];
	pv0[4] = Temp[5];
	pv0[5] = Temp[6];
	pv0[6] = Temp[7];
	pv0[7] = Temp[4];

	memcpy(Temp, pv1, 64);

	pv1[0] = Temp[4];
	pv1[1] = Temp[6];
	pv1[2] = Temp[5];
	pv1[3] = Temp[7];
	pv1[4] = Temp[3];
	pv1[5] = Temp[1];
	pv1[6] = Temp[2];
	pv1[7] = Temp[0];
}

void SkeinEvenRound(uint64_t *p)
{
	uint64_t pv0[8], pv1[8];

	for (int i = 0; i < 16; i++)
	{
		if (i & 1) pv1[i >> 1] = p[i];
		else pv0[i >> 1] = p[i];
	}

	SkeinMix8(pv0, pv1, 55, 43, 37, 40, 16, 22, 38, 12);

	SkeinMix8(pv0, pv1, 25, 25, 46, 13, 14, 13, 52, 57);

	SkeinMix8(pv0, pv1, 33, 8, 18, 57, 21, 12, 32, 54);

	SkeinMix8(pv0, pv1, 34, 43, 25, 60, 44, 9, 59, 34);

	for (int i = 0; i < 16; ++i)
	{
		if (i & 1) p[i] = pv1[i >> 1];
		else p[i] = pv0[i >> 1];
	}
}

void SkeinOddRound(uint64_t *p)
{
	uint64_t pv0[8], pv1[8];

	for (int i = 0; i < 16; i++)
	{
		if (i & 1) pv1[i >> 1] = p[i];
		else pv0[i >> 1] = p[i];
	}

	SkeinMix8(pv0, pv1, 28, 7, 47, 48, 51, 9, 35, 41);

	SkeinMix8(pv0, pv1, 17, 6, 18, 25, 43, 42, 40, 15);

	SkeinMix8(pv0, pv1, 58, 7, 32, 45, 19, 18, 2, 56);

	SkeinMix8(pv0, pv1, 47, 49, 27, 58, 37, 48, 53, 56);

	for (int i = 0; i < 16; ++i)
	{
		if (i & 1) p[i] = pv1[i >> 1];
		else p[i] = pv0[i >> 1];
	}
}

void SkeinRoundTest(uint64_t *State, uint64_t *Key, uint64_t *Type)
{
	//uint64_t StateBak[16];

	//memcpy(StateBak, State, 128);

	for (int i = 0; i < 20; i += 2)
	{
		SkeinInjectKey(State, Key, Type, i);

		//printf("\nState after key injection %d:\n", i);
		//DumpVerilogStyle(State, 128);

		SkeinEvenRound(State);
		RotateSkeinKey(Key);

		//printf("\nState after round %d:\n", i);
		//DumpVerilogStyle(State, 128);

		//printf("\nKey after rotation:\n");
		//DumpVerilogStyle(Key, 136);

		SkeinInjectKey(State, Key, Type, i + 1);

		//printf("\nState after key injection %d:\n", i + 1);
		//DumpVerilogStyle(State, 128);

		SkeinOddRound(State);
		RotateSkeinKey(Key);

		//printf("\nState after round %d:\n", i + 1);
		//DumpVerilogStyle(State, 128);

		//printf("\nKey after rotation:\n");
		//DumpVerilogStyle(Key, 136);
	}

	SkeinInjectKey(State, Key, Type, 20);

	//for(int i = 0; i < 16; ++i) State[i] ^= StateBak[i];

	// I am cheap and dirty. x.x
	RotateSkeinKey(Key);
	RotateSkeinKey(Key);
	RotateSkeinKey(Key);
	RotateSkeinKey(Key);
	RotateSkeinKey(Key);
}



void NXSMidstate(uint64_t *OutputKey, uint64_t *Input)
{
	uint64_t h[17], p[16], t[3];

	memcpy(p, Input, 128);
	memcpy(h, SKEIN1024_IV, 128);

	h[16] = SKEIN_KS_PARITY;
	for (int i = 0; i < 16; ++i) h[16] ^= h[i];

	t[0] = 0x80ULL;
	t[1] = 0x7000000000000000ULL;
	t[2] = 0x7000000000000080ULL;

	SkeinRoundTest(p, h, t);

	h[16] = SKEIN_KS_PARITY;
	for (int i = 0; i < 16; ++i)
	{
		h[i] = Input[i] ^ p[i];
		h[16] ^= h[i];
	}

	//printf("Key output (after midstate, the feed-forward data for Skein-1024):\n");
	//DumpQwords(h, 17);
	//DumpVerilogStyle(h, 136);

	memcpy(OutputKey, h, 136);
}




#pragma pack(push, 1)
typedef struct FPGAWorkPacket_s
{
	uint64_t BlkHdrTail[10];
	uint64_t Midstate[17];
} FPGAWorkPacket;
#pragma pack(pop)

extern bool opt_benchmark;

//ORIGINAL

static const uint64_t cpu_SKEIN1024_IV_1024[16] =
{
	0x5A4352BE62092156,
	0x5F6E8B1A72F001CA,
	0xFFCBFE9CA1A2CE26,
	0x6C23C39667038BCA,
	0x583A8BFCCE34EB6C,
	0x3FDBFB11D4A46A3E,
	0x3304ACFCA8300998,
	0xB2F6675FA17F0FD2,
	0x9D2599730EF7AB6B,
	0x0914A20D3DFEA9E4,
	0xCC1A9CAFA494DBD3,
	0x9828030DA0A6388C,
	0x0D339D5DAADEE3DC,
	0xFC46DE35C4E2A086,
	0x53D6E4F52E19A6D1,
	0x5663952F715D1DDD,
};

static const int cpu_ROT1024[8][8] =
{
	{ 55, 43, 37, 40, 16, 22, 38, 12 },
	{ 25, 25, 46, 13, 14, 13, 52, 57 },
	{ 33, 8, 18, 57, 21, 12, 32, 54 },
	{ 34, 43, 25, 60, 44, 9, 59, 34 },
	{ 28, 7, 47, 48, 51, 9, 35, 41 },
	{ 17, 6, 18, 25, 43, 42, 40, 15 },
	{ 58, 7, 32, 45, 19, 18, 2, 56 },
	{ 47, 49, 27, 58, 37, 48, 53, 56 }
};

#define ROL64(x, n)        (((x) << (n)) | ((x) >> (64 - (n))))

void Round1024_host(uint64_t &p0, uint64_t &p1, uint64_t &p2, uint64_t &p3, uint64_t &p4, uint64_t &p5, uint64_t &p6, uint64_t &p7,
	uint64_t &p8, uint64_t &p9, uint64_t &pA, uint64_t &pB, uint64_t &pC, uint64_t &pD, uint64_t &pE, uint64_t &pF, int ROT)
{
	p0 += p1;
	p1 = ROL64(p1, cpu_ROT1024[ROT][0]);
	p1 ^= p0;
	p2 += p3;
	p3 = ROL64(p3, cpu_ROT1024[ROT][1]);
	p3 ^= p2;
	p4 += p5;
	p5 = ROL64(p5, cpu_ROT1024[ROT][2]);
	p5 ^= p4;
	p6 += p7;
	p7 = ROL64(p7, cpu_ROT1024[ROT][3]);
	p7 ^= p6;
	p8 += p9;
	p9 = ROL64(p9, cpu_ROT1024[ROT][4]);
	p9 ^= p8;
	pA += pB;
	pB = ROL64(pB, cpu_ROT1024[ROT][5]);
	pB ^= pA;
	pC += pD;
	pD = ROL64(pD, cpu_ROT1024[ROT][6]);
	pD ^= pC;
	pE += pF;
	pF = ROL64(pF, cpu_ROT1024[ROT][7]);
	pF ^= pE;
}

void skein1024_setBlock(void *pdata, unsigned int nHeight, uint64_t *cpu_Message, uint64_t *hv)
{
	//uint64_t hv[17];
	uint64_t t[3];
	uint64_t h[17];
	uint64_t p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15;

	uint64_t cpu_skein_ks_parity = 0x5555555555555555;
	h[16] = cpu_skein_ks_parity;
	//uint64_t cpu_Message[27];


	for (int i = 0; i < 16; i++) {
		h[i] = cpu_SKEIN1024_IV_1024[i];
		h[16] ^= h[i];
	}
	uint64_t* alt_data = (uint64_t*)pdata;
	/////////////////////// round 1 //////////////////////////// should be on cpu => constant on gpu
	p0 = alt_data[0];
	p1 = alt_data[1];
	p2 = alt_data[2];
	p3 = alt_data[3];
	p4 = alt_data[4];
	p5 = alt_data[5];
	p6 = alt_data[6];
	p7 = alt_data[7];
	p8 = alt_data[8];
	p9 = alt_data[9];
	p10 = alt_data[10];
	p11 = alt_data[11];
	p12 = alt_data[12];
	p13 = alt_data[13];
	p14 = alt_data[14];
	p15 = alt_data[15];
	t[0] = 0x80; // ptr  
	t[1] = 0x7000000000000000; // etype
	t[2] = 0x7000000000000080;

	p0 += h[0];
	p1 += h[1];
	p2 += h[2];
	p3 += h[3];
	p4 += h[4];
	p5 += h[5];
	p6 += h[6];
	p7 += h[7];
	p8 += h[8];
	p9 += h[9];
	p10 += h[10];
	p11 += h[11];
	p12 += h[12];
	p13 += h[13] + t[0];
	p14 += h[14] + t[1];
	p15 += h[15];

	for (int i = 1; i < 21; i += 2)
	{
		Round1024_host(p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, 0);
		Round1024_host(p0, p9, p2, p13, p6, p11, p4, p15, p10, p7, p12, p3, p14, p5, p8, p1, 1);
		Round1024_host(p0, p7, p2, p5, p4, p3, p6, p1, p12, p15, p14, p13, p8, p11, p10, p9, 2);
		Round1024_host(p0, p15, p2, p11, p6, p13, p4, p9, p14, p1, p8, p5, p10, p3, p12, p7, 3);

		p0 += h[(i + 0) % 17];
		p1 += h[(i + 1) % 17];
		p2 += h[(i + 2) % 17];
		p3 += h[(i + 3) % 17];
		p4 += h[(i + 4) % 17];
		p5 += h[(i + 5) % 17];
		p6 += h[(i + 6) % 17];
		p7 += h[(i + 7) % 17];
		p8 += h[(i + 8) % 17];
		p9 += h[(i + 9) % 17];
		p10 += h[(i + 10) % 17];
		p11 += h[(i + 11) % 17];
		p12 += h[(i + 12) % 17];
		p13 += h[(i + 13) % 17] + t[(i + 0) % 3];
		p14 += h[(i + 14) % 17] + t[(i + 1) % 3];
		p15 += h[(i + 15) % 17] + (uint64_t)i;

		Round1024_host(p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, 4);
		Round1024_host(p0, p9, p2, p13, p6, p11, p4, p15, p10, p7, p12, p3, p14, p5, p8, p1, 5);
		Round1024_host(p0, p7, p2, p5, p4, p3, p6, p1, p12, p15, p14, p13, p8, p11, p10, p9, 6);
		Round1024_host(p0, p15, p2, p11, p6, p13, p4, p9, p14, p1, p8, p5, p10, p3, p12, p7, 7);

		p0 += h[(i + 1) % 17];
		p1 += h[(i + 2) % 17];
		p2 += h[(i + 3) % 17];
		p3 += h[(i + 4) % 17];
		p4 += h[(i + 5) % 17];
		p5 += h[(i + 6) % 17];
		p6 += h[(i + 7) % 17];
		p7 += h[(i + 8) % 17];
		p8 += h[(i + 9) % 17];
		p9 += h[(i + 10) % 17];
		p10 += h[(i + 11) % 17];
		p11 += h[(i + 12) % 17];
		p12 += h[(i + 13) % 17];
		p13 += h[(i + 14) % 17] + t[(i + 1) % 3];
		p14 += h[(i + 15) % 17] + t[(i + 2) % 3];
		p15 += h[(i + 16) % 17] + (uint64_t)(i + 1);

	}

	h[0] = p0^alt_data[0];
	h[1] = p1^alt_data[1];
	h[2] = p2^alt_data[2];
	h[3] = p3^alt_data[3];
	h[4] = p4^alt_data[4];
	h[5] = p5^alt_data[5];
	h[6] = p6^alt_data[6];
	h[7] = p7^alt_data[7];
	h[8] = p8^alt_data[8];
	h[9] = p9^alt_data[9];
	h[10] = p10^alt_data[10];
	h[11] = p11^alt_data[11];
	h[12] = p12^alt_data[12];
	h[13] = p13^alt_data[13];
	h[14] = p14^alt_data[14];
	h[15] = p15^alt_data[15];
	h[16] = cpu_skein_ks_parity;
	for (int i = 0; i < 16; i++) { h[16] ^= h[i]; }
	for (int i = 0; i < 17; i++) { hv[i] = h[i]; } //will slow down things

	for (int i = 0; i < 27; i++) { cpu_Message[i] = alt_data[i]; } //might slow down things


	//nBestHeight = nHeight;

	//cudaMemcpyToSymbol(c_hv, hv, sizeof(hv), 0, cudaMemcpyHostToDevice);
//	cudaMemcpyToSymbol(uMessage, cpu_Message, sizeof(cpu_Message), 0, cudaMemcpyHostToDevice);
}





extern bool scanhash_sk1024(unsigned int thr_id, uint32_t* TheData, uint1024 TheTarget, uint64_t &TheNonce, unsigned long long  max_nonce, unsigned long long *hashes_done, int throughput, int newh, unsigned int nHeight, SQRLAXIRef axi)
{
	uint64_t *ptarget = (uint64_t*)&TheTarget;

	const uint64_t first_nonce = TheNonce;// +((uint64_t)throughput * rep);

	const uint64_t Htarg = ptarget[15];
	uint8_t  Key[136], Midstate[136], BlkHdrTail[80];
	uint64_t hv[17];
	uint64_t cpu_Message[27];




	
		NXSMidstate((uint64_t *)&Key, (uint64_t *)TheData);

		for (int i = 135; i > -1; i--)
			Midstate[135 - i] = Key[i];


		for (int i = 207; i > 127; i--)
			BlkHdrTail[207 - i] = ((unsigned char *)TheData)[i];

	if (!newh){

		if (axi == NULL)
		{
			printf("\nError: Lost Sqrl Bridge connection.\n");
			exit(1);
		}


		uint8_t err = 0;

		for (int i = 0; i < 80; i += 4){
			err = SQRLAXIWrite(axi, htonl(((uint32_t *)BlkHdrTail)[i / 4]), 0x8c + i, false);
			if (err != 0) printf("\nError: unable to write BlkHdrTail to FPGA\n");
		}
		for (int i = 0; i < 136; i += 4){
			err = SQRLAXIWrite(axi, htonl(((uint32_t *)Midstate)[i / 4]), 0x4 + i, false);
			if (err != 0) printf("\nError: unable to write Midstate to FPGA\n");
		}

		uint32_t nonceStartHigh = first_nonce >> 32;
		uint32_t nonceStartLow = first_nonce & 0xFFFFFFFF;

		err = SQRLAXIWrite(axi, nonceStartLow, 0xdc, false);
		if (err != 0) printf("\nError: unable to write nonceStartLow to FPGA\n");
		err = SQRLAXIWrite(axi, nonceStartHigh, 0xe0, false);
		if (err != 0) printf("\nError: unable to write nonceStartHigh to FPGA\n");


		uint32_t targetHigh = Htarg >> 32;
		uint32_t targetLow = Htarg & 0xFFFFFFFF;

		err = SQRLAXIWrite(axi, targetLow, 0xe4, false);
		if (err != 0) printf("\nError: unable to write targetLow to FPGA\n");
		err = SQRLAXIWrite(axi, targetHigh, 0xe8, false);
		if (err != 0) printf("\nError: unable to write targetHigh to FPGA\n");

		err = SQRLAXIWrite(axi, 0xFFFFFFFF, 0xF8, false);
		if (err != 0) printf("\nError: unable to write enable interrupt to FPGA\n");

		err = SQRLAXIWrite(axi, 0xFFFFFFFF, 0xFC, false);
		if (err != 0) printf("\nError: unable to write starting hashcore to FPGA\n");
	}

	/*
	Sleep(1000);

	uint32_t  GoodNonceFound;
	uint64_t foundNonce;
	uint32_t foundNonce_Lo, foundNonce_Hi;
	uint8_t err = 0;

	err = SQRLAXIRead(axi, &GoodNonceFound, 0xF4);
	if (err != 0) printf("\nError: unable to read GoodNonceFound from FPGA\n");

	if (GoodNonceFound == 0xFFFFFFFF){
		err = SQRLAXIRead(axi, &foundNonce_Lo, 0xEC);
		if (err != 0)  printf("\nError: unable to read foundNonce_Lo from FPGA\n");

		err = SQRLAXIRead(axi, &foundNonce_Hi, 0xF0);
		if (err != 0) printf("\nError: unable to read foundNonce_Hi from FPGA\n");

		foundNonce = ((uint64_t)foundNonce_Hi) << 32 | foundNonce_Lo;

	}
	else foundNonce = 0xffffffffffffffff;
	*/
	
	uint64_t interruptNonce;
	uint64_t foundNonce;

	SQRLAXIResult axiRes = SQRLAXIWaitForInterrupt(axi, (1 << 0), &interruptNonce, 500);
	if (axiRes == SQRLAXIResultOK) {
		foundNonce = interruptNonce;
	}
	else if (axiRes == SQRLAXIResultTimedOut) {
		//	printf("\nInterrupt Timeout\n");
		foundNonce = 0xffffffffffffffff;
	}
	else {
		printf("\nFPGA Interrupt Error\n");
		exit(1);
	}





	int order = 0;
	if (foundNonce != 0xffffffffffffffff)
	{
		((uint64_t*)TheData)[26] = foundNonce;
		uint1024 skein;
		Skein1024_Ctxt_t ctx;
		Skein1024_Init(&ctx, 1024);
		Skein1024_Update(&ctx, (unsigned char *)TheData, 216);
		Skein1024_Final(&ctx, (unsigned char *)&skein);
		
/*		printf("\nSKEIN:\n");
		for (int i = 0; i < 128; i++)
			printf("%02x", ((unsigned char *)&skein)[i]);
		printf("\n");
*/		
		uint64_t keccak[16];
		Keccak_HashInstance ctx_keccak;
		Keccak_HashInitialize(&ctx_keccak, 576, 1024, 1024, 0x05);
		Keccak_HashUpdate(&ctx_keccak, (unsigned char *)&skein, 1024);
		Keccak_HashFinal(&ctx_keccak, (unsigned char *)&keccak);
		
		/*
		printf("\nHash: ");
		for (int i = 0; i < 16;i++)
		printf("%016llX", keccak[i]);
		printf("\n");
		*/
		if (keccak[15] <= Htarg) {
			printf("\nFound nonce at %i interrups exipered times \n", newh);
			/*	
			printf("\nFound nonce: %016llX\n", foundNonce);
			printf("\nheader tail: ");
			for (int i = 0; i < 80; i += 4){
				printf("%02x", htonl(((uint32_t *)BlkHdrTail)[i / 4]));
			
			}
	        */
		   /*	printf("\nmidstate: ");
			for (int i = 0; i < 136; i += 4){
				printf("%02x", htonl(((uint32_t *)Midstate)[i / 4]));
				
			}

			printf("\n");
			*/

			TheNonce = foundNonce; //return the nonce
			*hashes_done = foundNonce - first_nonce + 1;
			return true;
		}
		else {
			printf("\nFPGA #%d: result for nonce %lu does not validate on CPU! \n", thr_id, foundNonce);
		}
	}
	((uint64_t*)TheData)[26] = first_nonce;
	((uint64_t*)TheData)[26] += throughput;

	uint64_t doneNonce = ((uint64_t*)TheData)[26];

	if (doneNonce < 18446744072149270489lu)
		*hashes_done = doneNonce - first_nonce + 1;



	

	return false;
}
