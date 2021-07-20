#include "hash/Miner.h"
#include "hash/Packet.h"

namespace LLP
{
	Miner::Miner() : Outbound()
	{

	}

	Miner::Miner(std::string ip, std::string port) : Outbound(ip, port)
	{
	}


	Miner::Miner(const Miner& miner)
	{
	}

	Miner& Miner::operator=(const Miner& miner)
	{
		return *this;
	}

	Miner::~Miner()
	{
	}

	bool Miner::Login(std::string strAccountName, int nTimeout)
	{
		Packet* PACKET = new Packet();
		PACKET->SetHeader(LOGIN);

		PACKET->SetData(std::vector<unsigned char>(strAccountName.begin(), strAccountName.end()));


		PACKET->SetLength(PACKET->GetData().size());

		this->WritePacket(PACKET);
		delete(PACKET);

		Packet RESPONSE = ReadNextPacket(nTimeout);

		if (RESPONSE.IsNull())
			return false;

		ResetPacket();

		return RESPONSE.GetHeader() == LOGIN_SUCCESS;
	}

	void Miner::SetChannel(unsigned int nChannel)
	{

		Packet* packet = new Packet();
		packet->SetHeader(SET_CHANNEL);
		packet->SetLength(4);
		packet->SetData(uint2bytes(nChannel));

		this->WritePacket(packet);

		delete(packet);
	}

	bool Miner::Ping(int nTimeout)
	{
		Packet* packet = new Packet();
		packet->SetHeader(PING);

		this->WritePacket(packet);

		delete(packet);


		Packet RESPONSE = ReadNextPacket(nTimeout);

		if (RESPONSE.IsNull())
			return NULL;

		if (RESPONSE.GetHeader() == PING)
			ResetPacket();

		return true;
	}

	Core::PoolWork *Miner::WaitWorkUpdate(int nTimeout)
	{
		Packet RESPONSE;

		for (;;)
		{
			RESPONSE = ReadNextPacket(nTimeout);
			Sleep(1);

			if (RESPONSE.IsNull())
				return NULL;
			if (RESPONSE.GetHeader() != BLOCK_DATA)
				ResetPacket();						//just drop everything except work. it must be reject packet from prev stale share
			break;
		}


		Core::PoolWork *pWork = new Core::PoolWork();

		std::vector<unsigned char> data = RESPONSE.GetData();

		pWork->m_pBLOCK = DeserializeBlock(std::vector<unsigned char>(data.begin() + 4, data.end()));

		pWork->m_unBits = bytes2uint(RESPONSE.GetData());	//pool variant
		//pWork->m_unBits = pWork->m_pBLOCK->GetBits();		//solo variant
	//	printf("\nget other block %i\n", nTimeout);
		ResetPacket();

		return pWork;
	}

	Core::PoolWork *Miner::RequestWork(int nTimeout)
	{
		Packet* packet = new Packet();
		packet->SetHeader(GET_BLOCK);
		this->WritePacket(packet);
		delete(packet);
	//	printf("\nrequest work\n");
		return WaitWorkUpdate(nTimeout);
	}

	Core::CBlock* Miner::GetBlock(int nTimeout)
	{
		Packet* packet = new Packet();
		packet->SetHeader(GET_BLOCK);
		this->WritePacket(packet);
		delete(packet);


		Packet RESPONSE = ReadNextPacket(nTimeout);

		if (RESPONSE.IsNull() || RESPONSE.GetLength() == 0)
			return NULL;
		Core::CBlock* BLOCK = DeserializeBlock(RESPONSE.GetData());
		ResetPacket();
	//	printf("\nget other block\n");
		return BLOCK;
	}


	bool Miner::GetBlock(Core::CBlock* BLOCK, int nTimeout)
	{
		Packet* packet = new Packet();
		packet->SetHeader(GET_BLOCK);
		this->WritePacket(packet);
		delete(packet);

		Packet RESPONSE = ReadNextPacket(nTimeout);

		if (RESPONSE.IsNull() || RESPONSE.GetLength() == 0)
			return false;
		bool dbRes = DeserializeBlock(RESPONSE.GetData(), BLOCK);
		ResetPacket();
		
		return dbRes;
	}



	unsigned int Miner::GetHeight(int nTimeout)
	{
		Packet* packet = new Packet();
		packet->SetHeader((unsigned char)GET_HEIGHT);
		this->WritePacket(packet);
		delete(packet);

		Packet RESPONSE = ReadNextPacket(nTimeout);

		if (RESPONSE.IsNull())
			return 0;

		if (RESPONSE.GetData().size() == 0)
		{
			return 0;
		}
	
		unsigned int nHeight = bytes2uint(RESPONSE.GetData());
		ResetPacket();
		return nHeight;
	}

	unsigned char Miner::SubmitBlock(uint512 hashMerkleRoot, unsigned long long nNonce, int nTimeout)
	{
		Packet* PACKET = new Packet();
		PACKET->SetHeader(SUBMIT_BLOCK);

		PACKET->SetData(hashMerkleRoot.GetBytes());
		std::vector<unsigned char> NONCE = uint2bytes64(nNonce);

		std::vector<unsigned char> pckt = PACKET->GetData();
		pckt.insert(pckt.end(), NONCE.begin(), NONCE.end());
		PACKET->SetData(pckt);
		PACKET->SetLength(72);

		this->WritePacket(PACKET);
		delete(PACKET);

		Packet RESPONSE = ReadNextPacket(nTimeout);
		if (RESPONSE.IsNull())
			return 0;

		if (RESPONSE.GetHeader() == 200 || RESPONSE.GetHeader() == 201)
		{
			ResetPacket();
			return RESPONSE.GetHeader();
		}
		else {
			printf("\other error %u \n", RESPONSE.GetHeader());
			return 201;
		}
	}

	bool Miner::DeserializeBlock(std::vector<unsigned char> DATA, Core::CBlock* BLOCK)
	{
		if (DATA.size() == 0)
			return false;
		BLOCK->SetVersion(bytes2uint(std::vector<unsigned char>(DATA.begin(), DATA.begin() + 4)));

		uint1024 prevBlock = BLOCK->GetPrevBlock();
		prevBlock.SetBytes(std::vector<unsigned char>(DATA.begin() + 4, DATA.begin() + 132));
		BLOCK->SetPrevBlock(prevBlock);

		uint512 merkleRoot = BLOCK->GetMerkleRoot();
		merkleRoot.SetBytes(std::vector<unsigned char>(DATA.begin() + 132, DATA.end() - 20));
		BLOCK->SetMerkleRoot(merkleRoot);

		BLOCK->SetChannel(bytes2uint(std::vector<unsigned char>(DATA.end() - 20, DATA.end() - 16)));
		BLOCK->SetHeight(bytes2uint(std::vector<unsigned char>(DATA.end() - 16, DATA.end() - 12)));
		BLOCK->SetBits(bytes2uint(std::vector<unsigned char>(DATA.end() - 12, DATA.end() - 8)));
		BLOCK->SetNonce(bytes2uint64(std::vector<unsigned char>(DATA.end() - 8, DATA.end())));

		return true;
	}

	Core::CBlock* Miner::DeserializeBlock(std::vector<unsigned char> DATA)
	{
		if (DATA.size() == 0)
			return nullptr;
		Core::CBlock* BLOCK = new Core::CBlock();
		BLOCK->SetVersion(bytes2uint(std::vector<unsigned char>(DATA.begin(), DATA.begin() + 4)));

		uint1024 prevBlock = BLOCK->GetPrevBlock();
		prevBlock.SetBytes(std::vector<unsigned char>(DATA.begin() + 4, DATA.begin() + 132));
		BLOCK->SetPrevBlock(prevBlock);

		uint512 merkleRoot = BLOCK->GetMerkleRoot();
		merkleRoot.SetBytes(std::vector<unsigned char>(DATA.begin() + 132, DATA.end() - 20));
		BLOCK->SetMerkleRoot(merkleRoot);

		BLOCK->SetChannel(bytes2uint(std::vector<unsigned char>(DATA.end() - 20, DATA.end() - 16)));
		BLOCK->SetHeight(bytes2uint(std::vector<unsigned char>(DATA.end() - 16, DATA.end() - 12)));
		BLOCK->SetBits(bytes2uint(std::vector<unsigned char>(DATA.end() - 12, DATA.end() - 8)));
		BLOCK->SetNonce(bytes2uint64(std::vector<unsigned char>(DATA.end() - 8, DATA.end())));

		return BLOCK;
	}

	std::vector<unsigned char> Miner::uint2bytes(unsigned int UINT)
	{
		std::vector<unsigned char> BYTES(4, 0);
		BYTES[0] = UINT >> 24;
		BYTES[1] = UINT >> 16;
		BYTES[2] = UINT >> 8;
		BYTES[3] = UINT;

		return BYTES;
	}

	std::vector<unsigned char> Miner::uint2bytes64(unsigned long long UINT)
	{
		std::vector<unsigned char> INTS[2];
		INTS[0] = uint2bytes((unsigned int)UINT);
		INTS[1] = uint2bytes((unsigned int)(UINT >> 32));
		std::vector<unsigned char> BYTES;
		BYTES.insert(BYTES.end(), INTS[0].begin(), INTS[0].end());
		BYTES.insert(BYTES.end(), INTS[1].begin(), INTS[1].end());
		return BYTES;

	}


}
