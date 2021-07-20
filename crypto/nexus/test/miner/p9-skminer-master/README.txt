Nividia SKMiner for Windows/Linux Pool version 1.1
Please improve and share:

To compile on Windows:
Visual Studio 2013 Solution for Windows, requires Boost to compile 

To compile on Ubuntu Linux:
./autogen.sh
./configure
make

There’s a precompiled binary for Windows in the "Precompiled" folder

Features:
Difficulty is displayed in two formats: Standard/Binary Logarithm (log2n)
Default intensity is set to 40, works correctly with GTX 1060 SC – Titan Xp
Difficulty for benchmark mode is set to 32 bits (2^32), block header hash with 32 or more leading zero bits

TITAN Xp	3840/128 = 30 SMs	Intensity = 60
TITAN X		3584/128 = 28 SMs	Intensity = 56
GTX 1080 Ti	3584/128 = 28 SMs	Intensity = 56
GTX 1080	2560/128 = 20 SMs	Intensity = 40
GTX 1070	1920/128 = 15 SMs	Intensity = 30
GTX 1060 6GB	1280/128 = 10 SMs	Intensity = 20
GTX 1060 3GB	1152/128 =  9 SMs	Intensity = 18

Recommended settings:
Power Limit = 66%
Core Clock = +100
Memory Clock = -502
Intensity = See above
Timeout = 30

Pool URLs:
http://nexuspool.ru/

Pool Servers:
us.nexuspool.ru
eu.nexuspool.ru

*** Change NXS payout address ***

Mining Mode:
./skminer IP PORT NXS_Address #GPUs Timeout Intensity Benchmark
./skminer us.nexuspool.ru 8333 2SZBJfBgk8rZ97uuhJJEzDEQNEBW6yvSjMZEH3kTBCVRyJYMnNq 1 30 40

Benchmark Mode: just add 1
./skminer us.nexuspool.ru 8333 2SZBJfBgk8rZ97uuhJJEzDEQNEBW6yvSjMZEH3kTBCVRyJYMnNq 1 30 40 1

Additional Information:
Share difficulty for "nexuspool.ru" is set to 1, which means that you need (1 x 2^34) hashes "On Average" to find a share

Use (Difficulty x 2^34) to calculate the number of hashes "On Average" required to solve the current block.
For example: (7496.565 x 2^34) = 128,790,006,029,352.96 hashes "On Average" to solve for this difficulty

Can always ask for help on the Nexus Slack forum


*** New ***
; Configuration file for SKMiner - config.ini

[GPU]            ; GPU configuration, 1=Use, 0=Skip
GPU0 = 1         ; GPU[0]
GPU1 = 1         ; GPU[1]
GPU2 = 1         ; GPU[2]
GPU3 = 1         ; GPU[3]
GPU4 = 1         ; GPU[4]
GPU5 = 1         ; GPU[5]
GPU6 = 1         ; GPU[6]
GPU7 = 1         ; GPU[7]
