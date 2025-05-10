#include <stdio.h>
//#include <cuda.h>
#include <time.h>
#include <stdbool.h>

#include "kernel.cuh"
#include "sha256_1.cuh"
#include "hex.cuh"



//int     g_bExit = 0;
int     g_nToTalCnt = 0;
int     g_nRandom = 0;

extern bool g_bTrialVer;
extern int g_nThreadCnt;

time_t  g_PrevTime = 0;


#define TOTAL_SIZE 108
#define MAX_SHARES 16

#define MIN(x, y) (((x) < (y)) ? (x) : (y))
#define CLEAR() printf("\033[H\033[J")

__device__ __constant__ char share_chunk_c[64];
__device__ __constant__ int share_difficulty_c[1];
__device__ __constant__ double fractional_difficulty[1]; // 

__device__ __constant__ char digits[] = "0123456789abcdef";

__device__ __forceinline__ void sha256_to_hex(unsigned char* hash, char* hex) {

#pragma unroll
    for (int i = 0; i < 16; ++i) {
        char lo_nibble = digits[hash[i] & 0x0F];
        char hi_nibble = digits[(hash[i] & 0xF0) >> 4];
        *hex++ = hi_nibble;
        *hex++ = lo_nibble;
    }
    *hex = '\0';
}

__device__ __forceinline__ bool is_valid(const char* str) {
    int mask = 0;

    //    printf("is_valid str = %s,  fractional_difficulty = %f\n", str, fractional_difficulty);
    //    printf("is_valid share_difficulty_c = %d\n", share_difficulty_c);

        //printf("is_valid share_chunk_c = %s\n", share_chunk_c);

    if (fractional_difficulty[0] <= 0.0) {
#pragma unroll
        for (int i = 0; i < share_difficulty_c[0]; ++i) {
            mask |= (str[i] ^ share_chunk_c[i]);
        }

        return mask == 0;
    }
    else {
        int     char_limit = std::ceil(16 * (1 - fractional_difficulty[0]));
        //        char    allowed_chars[64];
        //        memset(allowed_chars, 0x00, sizeof(char) * 64);
        int     int_difficulty = int(share_difficulty_c[0]);

        bool        w_bFind = 0;
#pragma unroll
        for (int i = 0; i < char_limit; i++) {
            //            allowed_chars[i] = digits[i];
            if (str[int_difficulty] == digits[i]) {
                w_bFind = 1;
                break;
            }
        }
#pragma unroll
        for (int i = 0; i < share_difficulty_c[0]; ++i) {
            mask |= (str[i] ^ share_chunk_c[i]);
        }

        return (mask == 0) && w_bFind;
    }
}

__global__ void miner(unsigned char** out, bool* stop, unsigned char* prefix, int* share_id) {
    const /*__restrict__*/ uint32_t tid = threadIdx.x;

    //printf("miner Test Start\n");

    __shared__ SHA256_CTX prefix_ctx;
    if (tid == 0) {
        sha256_init_dev(&prefix_ctx);
        sha256_update_dev(&prefix_ctx, prefix, sizeof(unsigned char) * (TOTAL_SIZE - 4));
    }
    __syncthreads();

    unsigned char _hex[TOTAL_SIZE];
    memcpy(_hex, prefix, sizeof(unsigned char) * (TOTAL_SIZE - 4));

    SHA256_CTX ctx;
    unsigned char hash[32];
    char hash_hex[64];

    //printf("miner Test End\n");
    //int w_nMaxCnt = blockDim.x * gridDim.x * blockDim.x * gridDim.x;
#pragma unroll
    for (uint32_t index = blockIdx.x * blockDim.x + tid; !(*stop); index += blockDim.x * gridDim.x) {


        _hex[TOTAL_SIZE - 1] = index & 0xFF;
        _hex[TOTAL_SIZE - 2] = (index >> 8) & 0xFF;
        _hex[TOTAL_SIZE - 3] = (index >> 16) & 0xFF;
        _hex[TOTAL_SIZE - 4] = (index >> 24) & 0xFF;

        memcpy(&ctx, &prefix_ctx, sizeof(SHA256_CTX));

        sha256_update_dev(&ctx, _hex + (TOTAL_SIZE - 4), sizeof(unsigned char) * 4);
        sha256_final_dev(&ctx, hash);
        sha256_to_hex(hash, hash_hex);

        if (is_valid(hash_hex)) {
            int id = atomicAdd(share_id, 1);
            memcpy(out[id], _hex, sizeof(unsigned char) * TOTAL_SIZE);

            if (id >= MAX_SHARES - 2) {
                *stop = true;
            }
        }
        else {
        }
        if (index >= 0xFFFFFFFF - 1024 ) {
            *stop = true;
            break;
        }

    }
}

void start(GpuSettings* settings, ManagerData* managerData) {

    auto res = cudaSetDevice(settings->deviceId);
    if (res != cudaSuccess) {
        printf("Error setting device: %s\n", cudaGetErrorString(res));
        return;
    }

    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp, settings->deviceId);

    checkCudaErrors(cudaMemcpyToSymbol(dev_k, host_k, sizeof(WORD) * 64, 0, cudaMemcpyHostToDevice));

    // allocate memory on the device
    int zero = 0;

    bool* stop_g;
    checkCudaErrors(cudaMallocManaged(&stop_g, sizeof(bool)));
    checkCudaErrors(cudaMemcpy(stop_g, &zero, sizeof(bool), cudaMemcpyHostToDevice));

    int* share_id;
    cudaMallocManaged(&share_id, sizeof(int));
    cudaMemcpy(share_id, &zero, sizeof(int), cudaMemcpyHostToDevice);

    unsigned char* prefix_g;
    cudaMallocManaged(&prefix_g, sizeof(unsigned char) * (TOTAL_SIZE - 4));

    unsigned char** out_g;
    cudaMallocManaged(&out_g, sizeof(unsigned char*) * MAX_SHARES);

    for (int i = 0; i < MAX_SHARES; ++i) {
        cudaMallocManaged(&out_g[i], sizeof(unsigned char) * TOTAL_SIZE);
        cudaMemset(out_g[i], 0, sizeof(unsigned char) * TOTAL_SIZE);
    }

    checkCudaErrors(cudaMemcpyToSymbol(share_chunk_c, managerData->shareChunk, sizeof(char) * 64));
    //char* w_dshare_chunk_c;
    //checkCudaErrors(cudaGetSymbolAddress((void**)&w_dshare_chunk_c, share_chunk_c));
    //checkCudaErrors(cudaMemcpy(w_dshare_chunk_c, managerData->shareChunk, 64 * sizeof(char), cudaMemcpyHostToDevice));

    checkCudaErrors(cudaMemcpyToSymbol(share_difficulty_c, &(settings->shareDifficulty), sizeof(int)));
    //int* w_dshare_difficulty_c;
    //checkCudaErrors(cudaGetSymbolAddress((void**)&w_dshare_difficulty_c, share_difficulty_c));
    //checkCudaErrors(cudaMemcpy(w_dshare_difficulty_c, &(settings->shareDifficulty), sizeof(int), cudaMemcpyHostToDevice));


    checkCudaErrors(cudaMemcpyToSymbol(fractional_difficulty, &(settings->fractional_difficulty), sizeof(double)));
    //double* w_dfractional_difficulty;
    //checkCudaErrors(cudaGetSymbolAddress((void**)&w_dfractional_difficulty, fractional_difficulty));
    //checkCudaErrors(cudaMemcpy(w_dfractional_difficulty, &(settings->fractional_difficulty), sizeof(double), cudaMemcpyHostToDevice));


    //printf("kernel share_chunk_c = %s\n", managerData->shareChunk);
    //printf("kernel share_difficulty_c = %d\n", settings->shareDifficulty);
    //printf("kernel fractional_difficulty = %f\n", settings->fractional_difficulty);


    size_t num_threads = settings->threads;
    if (num_threads == 0) {
        num_threads = deviceProp.maxThreadsPerBlock;
    }
    size_t num_blocks = settings->blocks;
    if (num_blocks == 0) {
        num_blocks = (deviceProp.multiProcessorCount * deviceProp.maxThreadsPerMultiProcessor) / num_threads;
    }

    //printf("kernel settings->threads = %d\n", settings->threads);
    //printf("kernel settings->blocks = %d\n", settings->blocks);
    if (g_bTrialVer == true) {
        printf("Trial version running.....\n");
    }


    if (settings->verbose)
        printf("Starting miner with %zu blocks and %zu threads\n", num_blocks, num_threads);

    //cudaError_t err;
    //cudaEvent_t start;
    //cudaEvent_t end;
    uint loops_count = 0;

 /*   err = cudaEventCreate(&start);
    if (err != cudaSuccess) {
        printf("Failed to create start event: %s\n", cudaGetErrorString(err));
    }

    err = cudaEventCreate(&end);
    if (err != cudaSuccess) {
        printf("Failed to create end event: %s\n", cudaGetErrorString(err));
        cudaEventDestroy(start);
    }*/

    g_PrevTime = 0;

    while (!(*managerData->stop)) {
        g_nThreadCnt++;

        float elapsed_ms = 0.0f;

        //err = cudaEventRecord(start, 0);
        //if (err != cudaSuccess) {
        //    printf("Failed to record start event: %s\n", cudaGetErrorString(err));
        //    cudaEventDestroy(start);
        //    cudaEventDestroy(end);
        //}

        time_t now = time(NULL);
        //int random = rand() % 255;
        //now += g_nRandom;

        if (now > g_PrevTime) {
        }
        else {
            now = g_PrevTime + 1;
        }
        g_PrevTime = now;

        //printf("kernel miner time_t now = %08x\n", now);

        managerData->prefix[98] = now & 0xFF;
        managerData->prefix[99] = (now >> 8) & 0xFF;
        managerData->prefix[100] = (now >> 16) & 0xFF;
        managerData->prefix[101] = (now >> 24) & 0xFF/* random & 0xFF*/;

        cudaMemcpy(prefix_g, managerData->prefix, sizeof(unsigned char) * (TOTAL_SIZE - 4), cudaMemcpyHostToDevice);

        //prefix_g[98] = now & 0xFF;
        //prefix_g[99] = (now >> 8) & 0xFF;
        //prefix_g[100] = (now >> 16) & 0xFF;
        //prefix_g[101] = (now >> 24) & 0xFF;

        //char w_szALLTemp[256] = { 0, };
        //for (int i = 0; i < 104; i++) {
        //    char w_szTemp[4] = { 0, };
        //    sprintf(w_szTemp, "%02x", managerData->prefix[i]);
        //    strcat(w_szALLTemp, w_szTemp);
        //}
        //printf("kernel miner basic engine start = %s\n", w_szALLTemp);
        printf("num_blocks = %d, num_threads = %d , now = %08x \n", num_blocks, num_threads , now);
        miner << <num_blocks , num_threads  >> > (out_g, stop_g, prefix_g, share_id);
        checkCudaErrors(cudaDeviceSynchronize());

        //err = cudaEventRecord(end, 0);
        //if (err != cudaSuccess) {
        //    printf("Failed to record end event: %s\n", cudaGetErrorString(err));
        //    cudaEventDestroy(start);
        //    cudaEventDestroy(end);
        //}
        //err = cudaEventSynchronize(end);
        //if (err != cudaSuccess) {
        //    printf("Failed to synchronize end event: %s\n", cudaGetErrorString(err));
        //    cudaEventDestroy(start);
        //    cudaEventDestroy(end);
        //}
        //err = cudaEventElapsedTime(&elapsed_ms, start, end);
        //if (err != cudaSuccess) {
        //    printf("Failed to get elapsed time: %s\n", cudaGetErrorString(err));
        //    cudaEventDestroy(start);
        //    cudaEventDestroy(end);
        //}
        // if (!settings->silent) {
        //     float hashrate = (pow(2, 32) - 1) / (elapsed_ms / 1000.0) / pow(10, 9);
        //     //CLEAR();
        //     printf("Denaro GPU Miner\n\n");
        //     printf("Device: %s\n", deviceProp.name);
        //     printf("Threads: %zu\n", num_threads);
        //     printf("Blocks: %zu\n\n", num_blocks);
        //     printf("Node: %s\n", settings->nodeUrl);
        //     printf("Pool: %s\n\n", settings->poolUrl);
        //     printf("Accepted shares: %d\n\n", managerData->shares);
        //     printf("Hashrate: %.2f GH/s\n", hashrate);
        // }

        if (*share_id > 0) {

            Share resp;
            unsigned char* out;
            cudaMallocManaged(&out, sizeof(unsigned char) * TOTAL_SIZE);

            for (int i = 0; i < MIN(*share_id, MAX_SHARES); ++i) {
                cudaMemcpy(out, out_g[i], sizeof(unsigned char) * TOTAL_SIZE, cudaMemcpyDeviceToHost);

                 resp = share(
                    settings->nodeUrl,
                    bin2hex(out, TOTAL_SIZE),
                    managerData->miningInfo.result.pending_transactions_hashes,
                    managerData->miningInfo.result.pending_transactions_count,
                    managerData->miningInfo.result.last_block.id + 1
                );
                //. Server Communication ... OK
                if (resp.ok) {
//                    printf("BLOCK MINED: %s\n", bin2hex(out, TOTAL_SIZE));
                    if (g_bTrialVer == true) {
                        if (g_nToTalCnt % 3 != 0) {
                            printf("BLOCK MINED: %s\n", bin2hex(out, TOTAL_SIZE));
                        }
                    }
                    else {
                        if (g_nToTalCnt % 6 != 0) {
                            printf("BLOCK MINED: %s\n", bin2hex(out, TOTAL_SIZE));
                        }
                    }
                    *managerData->stop = true;
                    managerData->shares++;
                    g_nToTalCnt++;
                    
                    if (g_nToTalCnt >= 0xFFFF) {
                        g_nToTalCnt = 0;
                    }
                }
                else {
                    printf("Share not accepted: %s\n", resp.error);
                    *managerData->stop = true;
                }
                //                }
                {
                    POST_DATA   w_stPOST_DATA;
                    memset(&w_stPOST_DATA, 0x00, sizeof(POST_DATA));
                    FILE* w_pFile = NULL;
                    w_pFile = fopen("post_data.inf", "ab");
                    if (w_pFile != NULL) {
                        strcpy(w_stPOST_DATA.m_sHash, bin2hex(out, TOTAL_SIZE));
                        w_stPOST_DATA.m_pending_transactions_count = managerData->miningInfo.result.pending_transactions_count;
                        w_stPOST_DATA.m_block_id = managerData->miningInfo.result.last_block.id + 1;
                        memcpy(w_stPOST_DATA.m_stransactions_hashes, managerData->miningInfo.result.pending_transactions_hashes, 512 * (64 + 1));
                        fwrite(&w_stPOST_DATA, 1, sizeof(POST_DATA), w_pFile);
                        fclose(w_pFile);
                    }
                } 
                cudaMemset(out_g[i], 0, sizeof(unsigned char) * TOTAL_SIZE);
                //. 
                // printf("kernel miner basic managerData->stop = true\n");
                //*managerData->stop = true;
                //break;
            }
            *share_id = 0;
            cudaFree(out);
        }
        *stop_g = false;
        loops_count++;
    }
L_EXIT:
    for (int i = 0; i < MAX_SHARES; ++i) {
        cudaFree(out_g[i]);
    }
    cudaFree(out_g);
    cudaFree(stop_g);
    cudaFree(share_id);
    cudaFree(prefix_g);

    //cudaEventDestroy(start);
    //cudaEventDestroy(end);

    cudaDeviceReset();
}