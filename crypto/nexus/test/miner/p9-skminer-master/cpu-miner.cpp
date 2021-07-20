/*
 * Copyright 2010 Jeff Garzik
 * Copyright 2012-2014 pooler
 * Copyright 2021      Modfs
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.  See COPYING for more details.
 */

#include "cpuminer-config.h"

#include "core.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <inttypes.h>
#include <unistd.h>
#include <sys/time.h>
#include <time.h>
#include <math.h>
#ifdef WIN32

#include <windows.h>
#else
#include <errno.h>
#include <signal.h>
#include <sys/resource.h>
#if HAVE_SYS_SYSCTL_H
#include <sys/types.h>
#if HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif
#include <sys/sysctl.h>
#endif
#endif
#include <jansson.h>
#include <curl/curl.h>
#include <openssl/sha.h>
#include "compat.h"
#include "miner.h"

#ifdef WIN32
#include <Mmsystem.h>
#pragma comment(lib, "winmm.lib")
#endif

#define PROGRAM_NAME		"FK_nexusminer"

/* // from heavy.cu
#ifdef __cplusplus
extern "C"
{
#endif
int cuda_num_devices();
void cuda_devicenames();
int cuda_finddevice(char *name);
void cuda_deviceproperties(int GPU_N);
#ifdef __cplusplus
}
#endif
*/

static bool submit_old = false;
bool use_syslog = false;
static bool opt_background = false;
static bool opt_quiet = false;
static int opt_retries = -1;
static int opt_fail_pause = 30;
int opt_timeout = 270;
static int opt_scantime = 5;
static json_t *opt_config;
static const bool opt_time = true;
//static sha256_algos opt_algo = ALGO_HEAVY;
static int opt_n_threads = 0;
static double opt_difficulty = 1; // CH
int device_map[8] = { 0, 1, 2, 3, 4, 5, 6, 7 }; // CB
static int num_processors;
int tp_coef[8];


#ifndef WIN32
static void signal_handler(int sig)
{
	switch (sig) {
	case SIGHUP:
		applog(LOG_INFO, "SIGHUP received");
		break;
	case SIGINT:
		applog(LOG_INFO, "SIGINT received, exiting");
		exit(0);
		break;
	case SIGTERM:
		applog(LOG_INFO, "SIGTERM received, exiting");
		exit(0);
		break;
	}
}
#endif

#define PROGRAM_VERSION "v0.1"
int main(int argc, char *argv[])
{
	struct thr_info *thr;
	long flags;
//	int i;

#ifdef WIN32
	SYSTEM_INFO sysinfo;
#endif

	printf("\n        ***** SK Nexus Miner for SQRL bridge by Modfs *****\n");
	 printf("\t             This is version " PROGRAM_VERSION " \n");
	 printf("\t               Open Source (GPL)\n");
	 printf("\t                  Pool Version\n\n");

	 if (argc < 3)
	 {
		 printf("Too Few Arguments. The Required Arguments are Ip and Port\n");
		 printf("Default Arguments are Total Threads = CPU Cores and Connection Timeout = 10 Seconds\n");
		 printf("Format for Arguments is 'IP PORT THREADS TIMEOUT'\n");

		 Sleep(10000);

		 return 0;
	 }

	num_processors = 1;
	std::string IP = argv[1];
	std::string PORT = argv[2];
	std::string LOGIN = argv[3];
	int nThreads = num_processors;
	bool bBenchmark = false;

	if (argc > 4)
		nThreads = boost::lexical_cast<int>(argv[4]);

	int nTimeout = 30;
	
	int nThroughput = 512 * 896;
	int nThroughputMultiplier = 28;
//	if (argc > 6)
//		nThroughputMultiplier = boost::lexical_cast<int>(argv[6]);

//	if (argc > 7)
//		bBenchmark = boost::lexical_cast<bool>(argv[7]);

	nThroughput *= nThroughputMultiplier;
	nThroughput = 2000;
	if (argc > 5)
		nThroughput = boost::lexical_cast<int>(argv[5]);

#ifdef _DEBUG
	nThreads = 1;
#endif

	printf("Initializing Miner %s:%s Threads = %i Timeout = %i | Throughput = %i\n", IP.c_str(), PORT.c_str(), nThreads, nTimeout, nThroughput);
	printf("\nPayout Address: %s\n\n", LOGIN.c_str());
	Core::ServerConnection MINERS(IP, PORT, LOGIN, nThreads, nTimeout, nThroughput, bBenchmark);
	loop{ Sleep(1000); }
}
