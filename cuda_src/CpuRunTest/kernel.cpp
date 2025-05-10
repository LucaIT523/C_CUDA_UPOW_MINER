#include <stdio.h>
#include <time.h>
#include <stdbool.h>

#include "kernel.h"
#include "sha256.h"
#include "hex.cuh"
#include <process.h> // For _beginthreadex



//int     g_bExit = 0;
int     g_nToTalCnt = 0;
int     g_nRandom = 0;

//extern bool g_bTrialVer;
extern int g_nThreadCnt;

time_t  g_PrevTime = 0;


#define TOTAL_SIZE      108
#define MAX_SHARES      16
#define NUM_THREADS     4


#define MIN(x, y) (((x) < (y)) ? (x) : (y))
#define CLEAR() printf("\033[H\033[J")

char share_chunk_c[64];
int share_difficulty_c[1];
double fractional_difficulty[1]; // 

char digits[] = "0123456789abcdef";


bool       stop_g = 0;
int        share_id = 0;
unsigned char prefix_g[TOTAL_SIZE - 4] = { 0, };
unsigned char* out_g[MAX_SHARES];

void sha256_to_hex(unsigned char* hash, char* hex) {


    for (int i = 0; i < 16; ++i) {
        char lo_nibble = digits[hash[i] & 0x0F];
        char hi_nibble = digits[(hash[i] & 0xF0) >> 4];
        *hex++ = hi_nibble;
        *hex++ = lo_nibble;
    }
    *hex = '\0';
}

bool is_valid(const char* str) {
    int mask = 0;

    if (fractional_difficulty[0] <= 0.0) {

        for (int i = 0; i < share_difficulty_c[0]; ++i) {
            mask |= (str[i] ^ share_chunk_c[i]);
        }

        return mask == 0;
    }
    else {
        int     char_limit = ceil(16 * (1 - fractional_difficulty[0]));
        int     int_difficulty = int(share_difficulty_c[0]);
        bool        w_bFind = 0;

        for (int i = 0; i < char_limit; i++) {
            if (str[int_difficulty] == digits[i]) {
                w_bFind = 1;
                break;
            }
        }

        for (int i = 0; i < share_difficulty_c[0]; ++i) {
            mask |= (str[i] ^ share_chunk_c[i]);
        }

        return (mask == 0) && w_bFind;
    }
}
SHA256_CTX prefix_ctx;

int atomicAdd(int* address, int value) {
#ifdef _WIN32 // Windows platform
	return InterlockedAdd(reinterpret_cast<LONG volatile*>(address), value);
#elif defined(__linux__) // Linux platform
	return __sync_fetch_and_add(address, value);
#else
#error "Atomic add not supported on this platform"
#endif
}

unsigned int __stdcall miner(void* param) {

	int* threadNumPtr = (int*)param;
	int threadNum = *threadNumPtr;

    unsigned char _hex[TOTAL_SIZE];
    memcpy(_hex, prefix_g, sizeof(unsigned char) * (TOTAL_SIZE - 4));

    SHA256_CTX ctx;
    unsigned char hash[32];
    char hash_hex[64];

//    printf("miner threadNum = %d\n", threadNum);
    for (long index = threadNum; !(stop_g); index += 1000) {
        _hex[TOTAL_SIZE - 1] = index & 0xFF;
        _hex[TOTAL_SIZE - 2] = (index >> 8) & 0xFF;
        _hex[TOTAL_SIZE - 3] = (index >> 16) & 0xFF;
        _hex[TOTAL_SIZE - 4] = (index >> 24) & 0xFF;

        memcpy(&ctx, &prefix_ctx, sizeof(SHA256_CTX));

        sha256_update(&ctx, _hex + (TOTAL_SIZE - 4), sizeof(unsigned char) * 4);
        sha256_final(&ctx, hash);
        sha256_to_hex(hash, hash_hex);

        if (is_valid(hash_hex)) {
            printf("cpu is_valid ok = %s\n", hash_hex);
            int id = atomicAdd(&share_id, 1);
            memcpy(out_g[id], _hex, sizeof(unsigned char) * TOTAL_SIZE);
            if (id >= MAX_SHARES - 2) {
                stop_g = true;
            }
        }
        else {
        }
        if (index >= 0xFFFFFFFF / 2 ) {
            stop_g = true;
            break;
        }

    }
	_endthreadex(0); // Exit the thread
	return 0;
}


void start(GpuSettings* settings, ManagerData* managerData) {

    // allocate memory on the device
    int zero = 0;

    stop_g = 0;
    share_id = 0;
    memset(prefix_g, 0x00, sizeof(unsigned char)*(TOTAL_SIZE - 4));

    for (int i = 0; i < MAX_SHARES; ++i) {
        out_g[i] = new unsigned char[TOTAL_SIZE];
        memset(out_g[i], 0, sizeof(unsigned char) * TOTAL_SIZE);
    }

    memcpy(share_chunk_c, managerData->shareChunk, sizeof(char) * 64);
    memcpy(share_difficulty_c, &(settings->shareDifficulty), sizeof(int));
    memcpy(fractional_difficulty, &(settings->fractional_difficulty), sizeof(double));

	uintptr_t threadHandle[NUM_THREADS];
	int threadArgs[NUM_THREADS];
// 
//    uint loops_count = 0;
    g_PrevTime = 0;
    while (!(*managerData->stop)) {
        g_nThreadCnt++;

        time_t now = time(NULL);

        now += 100;

        if (now > g_PrevTime) {
        }
        else {
            now = g_PrevTime + 1;
        }
        g_PrevTime = now;

        managerData->prefix[98] = now & 0xFF;
        managerData->prefix[99] = (now >> 8) & 0xFF;
        managerData->prefix[100] = (now >> 16) & 0xFF;
        managerData->prefix[101] = (now >> 24) & 0xFF/* random & 0xFF*/;

        memcpy(prefix_g, managerData->prefix, sizeof(unsigned char) * (TOTAL_SIZE - 4));

        memset(&prefix_ctx, 0x00, sizeof(SHA256_CTX));
		sha256_init(&prefix_ctx);
		sha256_update(&prefix_ctx, prefix_g, sizeof(unsigned char) * (TOTAL_SIZE - 4));

		printf("now = %08x \n", now);


        memset(threadHandle, 0x00, sizeof(uintptr_t) * NUM_THREADS);
		for (int i = 0; i < NUM_THREADS; ++i) {
		    threadArgs[i] = i;
		    threadHandle[i] = _beginthreadex(nullptr, 0, miner, &threadArgs[i], 0, nullptr);
		}
    	WaitForMultipleObjects(NUM_THREADS, (HANDLE*)threadHandle, TRUE, INFINITE);
		for (int i = 0; i < NUM_THREADS; ++i) {
            if(threadHandle[i] != 0)
    			CloseHandle((HANDLE)threadHandle[i]);
		}

        //miner << <num_blocks , num_threads  >> > (out_g, stop_g, prefix_g, share_id);
        //checkCudaErrors(cudaDeviceSynchronize());

        if (share_id > 0) {
            {
                FILE* w_pFile = NULL;
                w_pFile = fopen("myinfo_cpu_valid.txt", "ab");
                if (w_pFile != NULL) {
                    char    w_szTemp[16] = { 0, };
                    sprintf(w_szTemp, "%d\r\n", managerData->miningInfo.result.last_block.id + 1);
                    fwrite(w_szTemp, 1, 16, w_pFile);
                    fclose(w_pFile);
                }
            }
            Share resp;
            unsigned char out[TOTAL_SIZE];

            for (int i = 0; i < MIN(share_id, MAX_SHARES); ++i) {
                memcpy(out, out_g[i], sizeof(unsigned char) * TOTAL_SIZE);

                resp = share(
                    settings->nodeUrl,
                    bin2hex(out, TOTAL_SIZE),
                    managerData->miningInfo.result.pending_transactions_hashes,
                    managerData->miningInfo.result.pending_transactions_count,
                    managerData->miningInfo.result.last_block.id + 1
                );

                if (resp.ok) {

                    printf("BLOCK MINED: %s\n", bin2hex(out, TOTAL_SIZE));
 
                    *managerData->stop = true;
                    managerData->shares++;
                    g_nToTalCnt++;
                    
                    if (g_nToTalCnt >= 0xFFFF) {
                        g_nToTalCnt = 0;
                    }
                    //.
                    {
                        FILE* w_pFile = NULL;
                        w_pFile = fopen("myinfo_cpu.txt", "ab");
                        if (w_pFile != NULL) {
                            char    w_szTemp[16] = { 0, };
                            sprintf(w_szTemp, "%d\r\n", managerData->miningInfo.result.last_block.id + 1);
                            fwrite(w_szTemp, 1, 16, w_pFile);
                            fclose(w_pFile);
                        }
                    }

                }
                else {
                    printf("Share not accepted: %s\n", resp.error);
                    *managerData->stop = true;
                }
                //                }
				memset(out_g[i], 0, sizeof(unsigned char) * TOTAL_SIZE);

                //. 
                // printf("kernel miner basic managerData->stop = true\n");
                //*managerData->stop = true;
                //break;
            }
            share_id = 0;
        }
        stop_g = false;

//        loops_count++;
    }


L_EXIT:
    for (int i = 0; i < MAX_SHARES; ++i) {
        delete (out_g[i]);
    }
}