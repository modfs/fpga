#include "cpuminer-config.h"

#include "core.h"
#include "hash/templates.h"
#include "hash/CBlock.h"
#include "hash/Miner.h"
#include "hash/MinerThread.h"
#include <math.h>
#include <iostream>
#include <sstream>
#include "INIReader.h"

unsigned int nDifficulty = 0;
unsigned int nBlocksFoundCounter = 0;
unsigned int nBlocksFoundCounterTest = 0;
unsigned int nBlocksAccepted = 0;
unsigned int nBlocksRejected = 0;
unsigned int nReconnectCount = 0;
unsigned int nLoginCount = 0;
unsigned int nPingCount = 0;
unsigned int nHeight = 0;
unsigned int nTimerOffset = 0;
time_t nStartTimer;

CBigNum bnTarget = 0;

#ifdef WIN32
HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
#else
// Do nothing
#endif

char *device_name[8]; // CB
unsigned int GPUs[8] = { 1, 1, 1, 1, 1, 1, 1, 1 };

std::string sections(INIReader &reader);

namespace Core
{
	ServerConnection::ServerConnection(std::string ip, std::string port, std::string login, int nMaxThreads, int nMaxTimeout, int throughput, bool benchmark)
		: IP(ip), PORT(port), TIMER(), nThreads(nMaxThreads), nTimeout(nMaxTimeout), nThroughput(throughput), bBenchmark(benchmark), THREAD(boost::bind(&ServerConnection::ServerThread, this))
	{
		this->m_szLogin = login;

		printf("FPGA:\n");
		for (unsigned int i = 0; i < 8; i++)
		{
			if (device_name[i])
				printf("%u: %s\n", i+1, device_name[i]);
		}

		INIReader reader("config.ini");

		if (reader.ParseError() < 0) {
			std::cout << "Error loading configuration file..." << std::endl;
		}
		else
		{

			std::cout << "Loading configuration..." << std::endl;
			GPUs[0] = reader.GetInteger("GPU", "GPU0", 1);
			GPUs[1] = reader.GetInteger("GPU", "GPU1", 1);
			GPUs[2] = reader.GetInteger("GPU", "GPU2", 1);
			GPUs[3] = reader.GetInteger("GPU", "GPU3", 1);
			GPUs[4] = reader.GetInteger("GPU", "GPU4", 1);
			GPUs[5] = reader.GetInteger("GPU", "GPU5", 1);
			GPUs[6] = reader.GetInteger("GPU", "GPU6", 1);
			GPUs[7] = reader.GetInteger("GPU", "GPU7", 1);
		}

		time(&nStartTimer);
		StartTimer.Start();
		//nStartTimer = (unsigned int)time(0);

		for (int nIndex = 0; nIndex < nThreads; nIndex++)
		{
			uint16_t port = throughput + nIndex;
			SQRLAXIRef axi = SQRLAXICreate(SQRLAXIConnectionTCP, "127.0.0.1", port);
			if (axi == NULL) {
				printf("\nFatal error in opening SQRL bridge connection");
				exit(1);
			    }
			printf("\nSQRL Bridge connected.\n");
			MinerThread * minerThread = new MinerThread(nIndex);
			minerThread->SetThroughput(throughput);
			minerThread->SetIsBenchmark(benchmark);
			minerThread->SetAXI(axi);

			if (GPUs[nIndex] == 0) minerThread->SetIsShutdown(true);
			THREADS.push_back(minerThread);
		}
	}

	/** Reset the block on each of the Threads. **/
	void ServerConnection::ResetThreads()
	{

		/** Reset each individual flag to tell threads to stop mining. **/
		for (unsigned int nIndex = 0; nIndex < THREADS.size(); nIndex++)
		{
			THREADS[nIndex]->SetIsBlockFound(false);
			THREADS[nIndex]->SetIsNewBlock(true);
		}

	}

	/** Get the total hashes from Each Mining Thread. **/
	unsigned long long ServerConnection::Hashes()
	{
		unsigned long long nHashes = 0;
		for (unsigned int nIndex = 0; nIndex < THREADS.size(); nIndex++)
		{
			nHashes += THREADS[nIndex]->GetHashes();
		}

		return nHashes;
	}


	double ServerConnection::GetDifficulty(unsigned int nBits, int nChannel)
	{
		/** Prime Channel is just Decimal Held in Integer
		Multiplied and Divided by Significant Digits. **/
		if (nChannel == 1)
			return nBits / 10000000.0;

		/** Get the Proportion of the Bits First. **/
		auto dDiff =
			static_cast<double>(0x0000ffff) / static_cast<double>(nBits & 0x00ffffff);

		/** Calculate where on Compact Scale Difficulty is. **/
		int nShift = nBits >> 24;

		/** Shift down if Position on Compact Scale is above 124. **/
		while (nShift > 124)
		{
			dDiff = dDiff / 256.0;
			nShift--;
		}

		/** Shift up if Position on Compact Scale is below 124. **/
		while (nShift < 124)
		{
			dDiff = dDiff * 256.0;
			nShift++;
		}

		/** Offset the number by 64 to give larger starting reference. **/
		return dDiff * ((nChannel == 2) ? 64 : 1024 * 1024 * 256);
	}



	/** Main Connection Thread. Handles all the networking to allow
	Mining threads the most performance. **/
	void ServerConnection::ServerThread()
	{
		/** Don't begin until all mining threads are Created. **/
		while (THREADS.size() != nThreads)
			Sleep(1000);


		/** Initialize the Server Connection. **/
		CLIENT = new LLP::Miner(IP, PORT);

		while (true)
		{
			if (!CLIENT->Connect())
			{
				Sleep(15000);
			}
			else
			{
				if (!CLIENT->Ping(5))
				{
					CLIENT->Disconnect();
					printf("\nPool Server is down...\n\n");
					Sleep(15000);
				}
				else
				{
					printf("\nPool Server is up...\n");
					CLIENT->Disconnect();
					break;
				}
			}

			if (nPingCount >= 8)
			{
				printf("\nCannot connect to server after 8 attempts...Exiting\n\n");
				for (int nIndex = 0; nIndex < nThreads; nIndex++)
				{
					if (GPUs[nIndex] != 0) THREADS[nIndex]->SetIsShutdown(true);
					printf("\nShutting down thread %u\n", nIndex);
				}

				Sleep(1000);
				exit(0);
			}

			nPingCount++;
		}

		/** Initialize a Timer for the Hash Meter. **/
		TIMER.Start();
		
		unsigned int nTimerWait = 1;
		unsigned int nBestHeight = 0;
		unsigned int nReceivedBlockCount = 0;

		loop
		{
			try
			{
				Core::PoolWork *pWork = 0;

				/** Attempt with best efforts to keep the Connection Alive. **/
				if (!CLIENT->Connected() || CLIENT->Errors())
				{
					try
					{
						if (!CLIENT->Connect())
						{
							
							if (nReconnectCount >= 8)
							{
								printf("\nCannot connect to server after 8 attempts...Exiting\n\n");
								for (int nIndex = 0; nIndex < nThreads; nIndex++)
								{
									if (GPUs[nIndex] != 0) THREADS[nIndex]->SetIsShutdown(true);
									printf("\nShutting down thread %u\n", nIndex);
								}

								Sleep(1000);
								exit(0);
							}
							
							nReconnectCount++;
							printf("\nCannot connect to server on try %u... waiting for 15 seconds\n", nReconnectCount);
							Sleep(15000);
						}
						else
						{
							if (CLIENT->Login(m_szLogin, 5))
							{
								time_t currentTime;
								time(&currentTime);
#ifdef WIN32
								SetConsoleTextAttribute(hConsole, 2);
								printf("\nLogged In Successfully on %s\n", ctime(&currentTime));
								SetConsoleTextAttribute(hConsole, 7);
#else
								printf("\nLogged In Successfully on %s\n", ctime(&currentTime));
#endif
								pWork = CLIENT->WaitWorkUpdate(1);
								ResetThreads();
							}
							else
							{
								CLIENT->Disconnect();
#ifdef WIN32
								SetConsoleTextAttribute(hConsole, 4);
								printf("\nFailed to Log In...Exiting\n\n");
								SetConsoleTextAttribute(hConsole, 7);
#else
								printf("\nFailed to Log In...Exiting\n\n");
#endif

								for (int nIndex = 0; nIndex < nThreads; nIndex++)
								{
									if (GPUs[nIndex] != 0) THREADS[nIndex]->SetIsShutdown(true);
									printf("\nShutting down thread %u\n", nIndex);
								}

								Sleep(1000);
								exit(0);
							}
						}
					}
					catch (...)
					{
						Sleep(1000);
						continue;
					}

				}
				else 
				{
					
				
					if (pWork = CLIENT->WaitWorkUpdate(1))
					{
						ResetThreads();
					}
				
				}

				/** Rudimentary Meter **/
				if (TIMER.Elapsed() > nTimerWait)
				{
					unsigned int elapsedFromStart = StartTimer.Elapsed() + nTimerOffset;
					double  Elapsed = (double)TIMER.ElapsedMilliseconds();
					unsigned long long nHashes = Hashes();
					double nMHashps = ((double)nHashes / 1000.0) / (double)TIMER.ElapsedMilliseconds();
					double MegaHashesPerSecond = nHashes / 1000000.0 / elapsedFromStart;

					if ((elapsedFromStart > 5) && (nReceivedBlockCount < 1))
					{
#ifdef WIN32
						SetConsoleTextAttribute(hConsole, 6);
						printf("Block not received from pool on try %u... waiting 15 seconds\n\n", nLoginCount);
						SetConsoleTextAttribute(hConsole, 7);
#else
						printf("Block not received from pool on try %u... waiting 15 seconds\n\n", nLoginCount);
#endif
						CLIENT->Disconnect();
						Sleep(15000);

						if (nLoginCount >= 8)
						{
							printf("\nBlock not received from pool after 8 attempts...Exiting\n\n");
							for (int nIndex = 0; nIndex < nThreads; nIndex++)
							{
								if (GPUs[nIndex] != 0) THREADS[nIndex]->SetIsShutdown(true);
								printf("\nShutting down thread %u\n", nIndex);
							}

							Sleep(1000);
							exit(0);
						}

						nLoginCount++;
					}

					if (THREADS[0]->GetBlock() == NULL)
						continue;
					unsigned int nBits = THREADS[0]->GetBlock()->GetBits();

					double diff = GetDifficulty(nBits, 2);

					struct tm t;
#ifdef WIN32
					__time32_t aclock = elapsedFromStart;
					_gmtime32_s(&t, &aclock);
#else
					time_t aclock = elapsedFromStart;
					gmtime_r(&aclock, &t);
#endif

					bnTarget.SetCompact(nDifficulty);
					uint1024 TheTarget = bnTarget.getuint1024();
					uint64_t *ptarget = (uint64_t*)&TheTarget;
					unsigned long nHighBitsBN = ptarget[15];

					//double dDiff = (log(nHighBitsBN) / log(2)) + 960;
					//dDiff = (1024 - dDiff);

					double dDiff = 64.0 - log2(nHighBitsBN);

					printf("[Stats] %.03f MH/s | Shrs/24h %.03f | A=%u R=%u | Diff=%.03f/%.3f | %02d:%02d:%02d:%02d\n",
						MegaHashesPerSecond, (double)nBlocksFoundCounter / (double)elapsedFromStart * 86400.0, nBlocksAccepted, nBlocksRejected, diff, dDiff, t.tm_yday, t.tm_hour, t.tm_min, t.tm_sec);

					if (MegaHashesPerSecond > 2500)
					{
						printf("Hash rate too high..Exiting\n\n");
						for (int nIndex = 0; nIndex < nThreads; nIndex++)
						{
							if (GPUs[nIndex] != 0) THREADS[nIndex]->SetIsShutdown(true);
							printf("\nShutting down thread %u\n", nIndex);
						}

						Sleep(1000);
						exit(0);
					}

					TIMER.Reset();
					if (nTimerWait == 2)
						nTimerWait = 10;
				}


				/** Check if there is work to do for each Miner Thread. **/
				for (unsigned int nIndex = 0; nIndex < THREADS.size(); nIndex++)
				{

					/** Attempt to get a new block from the Server if Thread needs One. **/

					if (THREADS[nIndex]->GetIsNewBlock())
					{
						/** Retrieve new block from Server. **/
						/** Delete the Block Pointer if it Exists. **/
						CBlock* pBlock = THREADS[nIndex]->GetBlock();
						if (pBlock == NULL)
						{
							pBlock = new CBlock();
						}

						/** Retrieve new block from Server. **/
						if (!pWork)
							pWork = CLIENT->RequestWork(nTimeout);

						/** If the block is good, tell the Mining Thread its okay to Mine. **/
						if ((pWork))
						{
							pBlock = pWork->m_pBLOCK;
							THREADS[nIndex]->SetIsBlockFound(false);
							THREADS[nIndex]->SetIsNewBlock(false);
							THREADS[nIndex]->SetBits(pWork->m_unBits);
							THREADS[nIndex]->SetBlock(pBlock);

							nDifficulty = THREADS[nIndex]->GetBlock()->GetBits();
							nBestHeight = THREADS[nIndex]->GetBlock()->GetHeight();

							time_t currentTime;
							time(&currentTime);

							if (nHeight != nBestHeight)
							{
#ifdef WIN32
								SetConsoleTextAttribute(hConsole, 8);
								printf("\n[MASTER] Nexus Block %u | Share Diff %.6f | %s\n", nBestHeight, Core::GetDifficulty(THREADS[nIndex]->GetBits()), ctime(&currentTime));
								SetConsoleTextAttribute(hConsole, 7);
#else
								printf("\n[MASTER] Nexus Block %u | Share Diff %.6f | %s\n", nBestHeight, Core::GetDifficulty(THREADS[nIndex]->GetBits()), ctime(&currentTime));
#endif
								nReceivedBlockCount++;
								
								if (nReceivedBlockCount == 1) {
									StartTimer.Reset();
									nTimerOffset = 1;
								}
							}

							nHeight = nBestHeight;
							delete pWork;
							pWork = 0;
						}

						/** If the Block didn't come in properly, Reconnect to the Server. **/
						else
						{
							CLIENT->Disconnect();

							break;
						}

					}

					/** Submit a block from Mining Thread if Flagged. **/
					else if (THREADS[nIndex]->GetIsBlockFound())
					{
						//===========================================================================

						//Network Diff
						bnTarget.SetCompact(nDifficulty);
						uint1024 TheTarget = bnTarget.getuint1024();
						uint64_t *ptarget = (uint64_t*)&TheTarget;
						unsigned long nHighBitsNetwork = ptarget[15];

						//Share Diff
						bnTarget = CBigNum(THREADS[nIndex]->GetBlock()->GetHash());
						uint1024 TheTarget2 = bnTarget.getuint1024();
						uint64_t *ptarget2 = (uint64_t*)&TheTarget2;
						unsigned long nHighBitsShare = ptarget2[15];

						//double dDiff = (log(nHighBitsShare) / log(2)) + 960;
						//dDiff = (1024 - dDiff);

						double dDiff = 64.0 - log2(nHighBitsShare);

						//===========================================================================


						double  nHashes = THREADS[nIndex]->GetHashes();
						double nMHashps = ((double)nHashes / 1000.0) / (double)TIMER.ElapsedMilliseconds();

						nBlocksFoundCounter++;
						nBlocksFoundCounterTest++;
						if (bBenchmark)
						{
#ifdef WIN32
							SetConsoleTextAttribute(hConsole, 2);
							printf("\n\n******* TEST BLOCK with %.3f Leading Zero Bits FOUND *******\n\n", dDiff);
							printf("\n[MASTER] TEST Block number %u Found by \"%s\" GPU[%u]\n", nBlocksFoundCounterTest, device_name[THREADS[nIndex]->GetGpuId()], nIndex);
							SetConsoleTextAttribute(hConsole, 7);
#else
							printf("\n\n******* TEST BLOCK with %.3f Leading Zero Bits FOUND *******\n\n", dDiff);
							printf("\n[MASTER] TEST Block number %u Found by \"%s\" GPU[%u]\n", nBlocksFoundCounterTest, device_name[THREADS[nIndex]->GetGpuId()], nIndex);
#endif

							THREADS[nIndex]->SetIsNewBlock(true);
							THREADS[nIndex]->SetIsBlockFound(false);

							break;
						}
						else
						{
							if (nHighBitsShare <= nHighBitsNetwork)
							{
#ifdef WIN32
								SetConsoleTextAttribute(hConsole, 10);
								printf("\n\n******* Block/Share (Log2 %.3f) Found for Pool *******\n\n", dDiff);
								SetConsoleTextAttribute(hConsole, 7);
#else
								printf("\n\n******* Block/Share (Log2 %.3f) Found for Pool *******\n\n", dDiff);
#endif
							}
						}

						//							
						/** Attempt to Submit the Block to Network. **/
						unsigned long long nNonce = THREADS[nIndex]->GetBlock()->GetNonce();
						unsigned char RESPONSE = CLIENT->SubmitBlock(THREADS[nIndex]->GetBlock()->GetMerkleRoot(), THREADS[nIndex]->GetBlock()->GetNonce(), nTimeout);
						if (RESPONSE == 200)
						{
#ifdef WIN32
							SetConsoleTextAttribute(hConsole, 2);
							printf("\tShare (Log2 %.3f) Found by FPGA %u (Accepted)\n", dDiff, nIndex);
							SetConsoleTextAttribute(hConsole, 7);
#else
							printf("\tShare (Log2 %.3f) Found by \"%s\" GPU[%u] (Accepted)\n", dDiff, device_name[THREADS[nIndex]->GetGpuId()], nIndex);
#endif
							
							nBlocksAccepted++;
							THREADS[nIndex]->GetBlock()->SetNonce(nNonce + nThroughput);
							THREADS[nIndex]->SetIsNewBlock(false);
							THREADS[nIndex]->SetIsBlockFound(false);
						}
						else if (RESPONSE == 201)
						{
							nBlocksRejected++;
#ifdef WIN32
							SetConsoleTextAttribute(hConsole, 4);
							printf("\tShare (Log2 %.3f) Found by FPGA %u (Rejected)\n", dDiff, nIndex);
							SetConsoleTextAttribute(hConsole, 7);
#else
							printf("\tShare (Log2 %.3f) Found by \"%s\" GPU[%u] (Rejected)\n", dDiff, device_name[THREADS[nIndex]->GetGpuId()], nIndex);
#endif
							THREADS[nIndex]->SetIsNewBlock(true);
							THREADS[nIndex]->SetIsBlockFound(false);
						}
						else
						{
							nBlocksRejected++;
#ifdef WIN32
							SetConsoleTextAttribute(hConsole, 4);
							printf("[MASTER] Failure to Submit Share. Reconnecting...\n");
							SetConsoleTextAttribute(hConsole, 7);
#else
							printf("[MASTER] Failure to Submit Share. Reconnecting...\n");
#endif
							THREADS[nIndex]->SetIsNewBlock(true);
							THREADS[nIndex]->SetIsBlockFound(false);
							CLIENT->Disconnect();
						}

						break;


					}
				}
			}

			catch (...)
			{
#ifdef WIN32
				SetConsoleTextAttribute(hConsole, 6);
				printf("\nAn unknown error has occurred...\n");
				SetConsoleTextAttribute(hConsole, 7);
#else
				printf("\nAn unknown error has occurred...\n");
#endif
			}
		}

	};
}

std::string sections(INIReader &reader)
{
	std::stringstream ss;
	std::set<std::string> sections = reader.Sections();
	for (std::set<std::string>::iterator it = sections.begin(); it != sections.end(); ++it)
		ss << *it << ",";
	return ss.str();
}
