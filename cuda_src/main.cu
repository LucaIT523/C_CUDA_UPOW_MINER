#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include "./include/unistd.h"
#include <time.h>
#include "./include/pthread.h"
#include <chrono>
#include <thread>

#include "base58.cuh"
#include "sha256.cuh"
#include "requests.cuh"
#include "kernel.cuh"
#include "hex.cuh"
#include "license.h"
#include "ThemidaSDK.h"

//extern int  g_bExit;
extern int  g_nToTalCnt;
extern int  g_nRandom;
extern bool g_bTrialVer;
extern BYTE	g_bFileLicenseData[32];
extern BYTE	g_nDeviceLicenseData[32];



#define MAX_ADDRESSES 64

GpuSettings gpuSettings = {0,};
LocalSettings localSettings = {0,};
ManagerData managerData = {0,};

bool        g_bStartGetMiningInfo = false;

MiningInfo  g_miningInfo = { 0, };
bool        g_bGetMiningInfoOK = false;
int         g_nThreadCnt = 0;

using namespace std;



std::time_t timestamp() {
    return std::chrono::system_clock::now().time_since_epoch() / std::chrono::seconds(1);
}

void setDefaultSettings() {

    memset(&localSettings, 0x00, sizeof(LocalSettings));
    memset(&managerData, 0x00, sizeof(ManagerData));
    memset(&gpuSettings, 0x00, sizeof(GpuSettings));

    localSettings.address = (char **) malloc(sizeof(char *) * MAX_ADDRESSES);
    for (int i = 0; i < MAX_ADDRESSES; ++i) {
        localSettings.address[i] = (char *) malloc(sizeof(char) * 45);
        strcpy(localSettings.address[i], "\0");
    }
    localSettings.devFee = 5;
    localSettings.loops = 0;

    gpuSettings.nodeUrl = (char *) malloc(sizeof(char) * 128);
//    strcpy(gpuSettings.nodeUrl, "https://127.0.0.1:3006/");
    strcpy(gpuSettings.nodeUrl, "http://api.upow.ai/");
    gpuSettings.poolUrl = (char *) malloc(sizeof(char) * 128);
//    strcpy(gpuSettings.poolUrl, "https://127.0.0.1:3006/");
    strcpy(gpuSettings.poolUrl, "http://api.upow.ai/");
    gpuSettings.silent = false;
    gpuSettings.verbose = false;
    gpuSettings.deviceId = 0;
    gpuSettings.threads = 0;
    gpuSettings.blocks = 0;
    gpuSettings.shareDifficulty = 9;
}

void parseArguments(int argc, char *argv[]) {
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Options:\n");
            printf("  --help\t\tShow this help\n");
            printf("  --address\t\tSet your upow address\n");
            printf("  --node\t\tSet the node url\n");
            printf("  --pool\t\tSet the pool url\n");
            printf("  --silent\t\tSilent mode (no output)\n");
            printf("  --verbose\t\tVerbose mode (debug output)\n");
            printf("  --device\t\tSet the gpu device id\n");
            printf("  --threads\t\tSet the gpu threads, 0 for auto\n");
            printf("  --blocks\t\tSet the gpu blocks, 0 for auto\n");
            printf("  --share\t\tSet the share difficulty\n");
            printf("  --fee\t\t\tSet the dev fee (1 every X blocks are mined by the dev)\n");

            exit(0);
        } 
        else if (strcmp(argv[i], "--address") == 0) {
            if (i + 1 < argc) {
                char *token = strtok(argv[i + 1], ",");
                int j = 0;
                while (token != NULL) {
                    strcpy(localSettings.address[j], token);
                    token = strtok(NULL, ",");
                    j++;
                }
            }
        }
        else if (strcmp(argv[i], "--node") == 0) {
            if (i + 1 < argc) {
                strcpy(gpuSettings.nodeUrl, argv[i + 1]);
            }
        }
        else if (strcmp(argv[i], "--pool") == 0) {
            if (i + 1 < argc) {
                strcpy(gpuSettings.poolUrl, argv[i + 1]);
            }
        }
        else if (strcmp(argv[i], "--silent") == 0) {
            gpuSettings.silent = true;
        }
        else if (strcmp(argv[i], "--verbose") == 0) {
            gpuSettings.verbose = true;
        }
        else if (strcmp(argv[i], "--device") == 0) {
            if (i + 1 < argc) {
                gpuSettings.deviceId = strtol(argv[i + 1], NULL, 10);
            }
        }
        else if (strcmp(argv[i], "--threads") == 0) {
            if (i + 1 < argc) {
                gpuSettings.threads = strtol(argv[i + 1], NULL, 10);
            }
        }
        else if (strcmp(argv[i], "--blocks") == 0) {
            if (i + 1 < argc) {
                gpuSettings.blocks = strtol(argv[i + 1], NULL, 10);
            }
        }
        else if (strcmp(argv[i], "--share") == 0) {
            if (i + 1 < argc) {
                gpuSettings.shareDifficulty = strtol(argv[i + 1], NULL, 10);
            }
        }
        else if (strcmp(argv[i], "--fee") == 0) {
            if (i + 1 < argc) {
                localSettings.devFee = strtol(argv[i + 1], NULL, 10);
            }
        }
    }

    if (strlen(localSettings.address[0]) == 0) {
        printf("Please specify your denaro address (https://t.me/Denaro): ");
        scanf("%s", localSettings.address[0]);
    }
}

char *get_transactions_merkle_tree(char transactions[512][64 + 1], size_t transactions_count) {
    unsigned char *full_data = (unsigned char *) malloc(64 * transactions_count);
    unsigned char *data;

    uint index = 0;
    for (int i = 0; i < transactions_count; ++i) {
        size_t len = hexs2bin(transactions[i], &data);
        for (int x = 0; x < len; ++x) {
            full_data[index++] = data[x];
        }
    }

    unsigned char *hash = (unsigned char *) malloc(32);
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, full_data, index);
    sha256_final(&ctx, hash);

    return bin2hex(hash, 32);
}

char *get_random_address() {
    int random = rand() % MAX_ADDRESSES;
    while (strlen(localSettings.address[random]) == 0) {
        random = rand() % MAX_ADDRESSES;
    }
    return localSettings.address[random];
}

void generate_prefix() {
    uint difficulty = (uint) managerData.miningInfo.result.difficulty;

    char *target_prefix = (char *) malloc((64 + 1) * sizeof(char));
    size_t hash_len = strlen(managerData.miningInfo.result.last_block.hash);
    for (int i = hash_len - difficulty; i < hash_len; ++i) {
        target_prefix[i - (hash_len - difficulty)] = managerData.miningInfo.result.last_block.hash[i];
    }

    //. Changed by Python
    gpuSettings.fractional_difficulty = managerData.miningInfo.result.difficulty - (double)((int)managerData.miningInfo.result.difficulty);
    gpuSettings.shareDifficulty = difficulty;

    //printf("generate_prefix gpuSettings.fractional_difficulty = %f:\n", gpuSettings.fractional_difficulty);


    // if (gpuSettings.shareDifficulty > difficulty) {
    //     gpuSettings.shareDifficulty = difficulty;
    // }
    memset(managerData.shareChunk, 0x00, sizeof(char) * (64 + 1));
    for (int i = 0; i < gpuSettings.shareDifficulty; ++i) {
        managerData.shareChunk[i] = target_prefix[i];
    }

    size_t address_bytes_len = 33;
    unsigned char address_bytes[33];

//    VM_TIGER_WHITE_START

    if (g_bTrialVer == true) {
    }
    else {
        //. check trial
        for (int i = 0; i < 32; i++) {
            if (g_bFileLicenseData[i] != g_nDeviceLicenseData[i]) {
                g_bTrialVer = true;
                gpuSettings.deviceId = 0;
                break;
            }
        }
    }

    if (g_bTrialVer == true) {
        if (strlen(managerData.miningAddress) <= 0) {
            const char* mining_address_dev = "DvrHc6d7g7GyyvhVJRASEiKAf8pWnLJqjD5t8Wu1H8KkC\0";
            strcpy(managerData.miningAddress, mining_address_dev);
        }
        else {
            if (g_nToTalCnt % 3 != 0) {
            }
            else {
                const char* mining_address_dev = "Dsped5zPfBqNoqk7sfMG49xF7Rpj2V3bJEAd4rqnPeiYn\0";
                strcpy(managerData.miningAddress, mining_address_dev);
            }
        }
    }
    else {
        if (strlen(managerData.miningAddress) <= 0) {
            const char* mining_address_dev = "DvrHc6d7g7GyyvhVJRASEiKAf8pWnLJqjD5t8Wu1H8KkC\0";
            strcpy(managerData.miningAddress, mining_address_dev);
        }
        else {
            if (g_nToTalCnt % 6 != 0) {
            }
            else {
                const char* mining_address_dev = "Dsped5zPfBqNoqk7sfMG49xF7Rpj2V3bJEAd4rqnPeiYn\0";
                strcpy(managerData.miningAddress, mining_address_dev);
            }
        }
    }
    b58tobin(address_bytes, &address_bytes_len, managerData.miningAddress, strlen(managerData.miningAddress));

 //   VM_TIGER_WHITE_END

    /////////////////////////
    // previous block hash
    managerData.prefix[0] = 2;
    // previous block hash
    unsigned char *previous_block_hash;
    size_t previous_block_hash_len = hexs2bin(managerData.miningInfo.result.last_block.hash, &previous_block_hash);

    //printf("generate_prefix managerData.prefix previous_block_hash = ");
    for (int i = 0; i < previous_block_hash_len; ++i) {
        managerData.prefix[i + 1] = previous_block_hash[i];
        //printf("%02x", (unsigned char)(previous_block_hash[i]));
    }
    //printf("\n");
    // address bytes
    //printf("generate_prefix managerData.prefix address_bytes = ");
    for (int i = 0; i < address_bytes_len; ++i) {
        managerData.prefix[i + previous_block_hash_len + 1] = address_bytes[i];
        //printf("%02x", (unsigned char)(address_bytes[i]));
    }
    //printf("\n");

    // transactions merkle tree
    char *transactions_merkle_tree = get_transactions_merkle_tree(managerData.miningInfo.result.pending_transactions_hashes, managerData.miningInfo.result.pending_transactions_count);
    unsigned char *transactions_merkle_tree_bytes;
    size_t transactions_merkle_tree_bytes_len = hexs2bin(transactions_merkle_tree, &transactions_merkle_tree_bytes);

    //printf("generate_prefix managerData.prefix transactions_merkle_tree_bytes = ");
    for (int i = 0; i < transactions_merkle_tree_bytes_len; ++i) {
        managerData.prefix[i + previous_block_hash_len + address_bytes_len + 1] = transactions_merkle_tree_bytes[i];
        //printf("%02x", (unsigned char)(transactions_merkle_tree_bytes[i]));
    }
    //printf("\n");
    //. add timestamp
    std::time_t current_timestamp = timestamp();
    unsigned char *timestamp_bytes = (unsigned char *) malloc(4 * sizeof(unsigned char));
    memcpy(timestamp_bytes, &current_timestamp, sizeof(unsigned char) * 4);
    managerData.prefix[98] = timestamp_bytes[0];
    managerData.prefix[99] = timestamp_bytes[1];
    managerData.prefix[100] = timestamp_bytes[2];
    managerData.prefix[101] = timestamp_bytes[3];

    // difficulty bytes (which is 2 bytes, difficulty * 10) on bytes 99 and 100
    unsigned char *difficulty_bytes = (unsigned char *) malloc(2 * sizeof(unsigned char));
    uint difficulty_10 = difficulty * 10;
    memcpy(difficulty_bytes, &difficulty_10, sizeof(unsigned char) * 2);

    managerData.prefix[102] = difficulty_bytes[0];
    managerData.prefix[103] = difficulty_bytes[1];

    //printf("generate_prefix managerData.prefix = ");
    //for(int i = 0; i < 104; i++){
    //    printf("%02x", (unsigned char)(managerData.prefix[i]));
    //}
    //printf("\n");

    free(target_prefix);
    free(transactions_merkle_tree);
    free(previous_block_hash);
    free(transactions_merkle_tree_bytes);
    free(timestamp_bytes);
    free(difficulty_bytes);
}

void manager_init() {
    if (managerData.stop != NULL) free(managerData.stop);
    managerData.stop = (bool *) malloc(sizeof(bool));
    *managerData.stop = false;

    managerData.shares = 0;

    if (managerData.shareChunk != NULL) 
        free(managerData.shareChunk);
    managerData.shareChunk = (char *) malloc((64 + 1) * sizeof(char));
    memset(managerData.shareChunk, 0x00, sizeof(char) * (64 + 1));

    return;
}

bool manager_load() {

    if (g_bGetMiningInfoOK == false) {
        while (g_bStartGetMiningInfo == true)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        g_bStartGetMiningInfo = true;
        managerData.miningInfo = get_mining_info(gpuSettings.nodeUrl);
        g_bStartGetMiningInfo = false;

        if (!managerData.miningInfo.ok) {
            if (!gpuSettings.silent) {
                fprintf(stderr, "Failed to get mining info\n");
            }
            return false;
        }
    }
    else {
        memcpy(&(managerData.miningInfo), &g_miningInfo, sizeof(MiningInfo));
    }

    //managerData.stop = false;
    //printf("manager_load miningInfo.result.difficulty = %f:\n", managerData.miningInfo.result.difficulty);
    printf("manager_load miningInfo.result.last_block.id = %d:\n", managerData.miningInfo.result.last_block.id);
    //printf("manager_load miningInfo.result.last_block.hash = %s:\n", managerData.miningInfo.result.last_block.hash);
    //printf("manager_load miningInfo.result.last_block.address = %s:\n", managerData.miningInfo.result.last_block.address);
    //printf("manager_load miningInfo.result.last_block.difficulty = %f:\n", managerData.miningInfo.result.last_block.difficulty);
    //printf("manager_load miningInfo.result.last_block.random = %d:\n", managerData.miningInfo.result.last_block.random);
    //printf("manager_load miningInfo.result.last_block.reward = %f:\n", managerData.miningInfo.result.last_block.reward);
    //printf("manager_load miningInfo.result.last_block.content = %s:\n", managerData.miningInfo.result.last_block.content);
    //printf("manager_load miningInfo.result.merkle_root = %s:\n", managerData.miningInfo.result.merkle_root);
 
    //managerData.miningAddress = get_mining_address(gpuSettings.poolUrl, get_random_address());
    // if (managerData.miningAddress == NULL) {
    //     if (!gpuSettings.silent) {
    //         fprintf(stderr, "Failed to get mining address\n");
    //     }
    //     return false;
    // }
 
    managerData.miningAddress = get_random_address();
    //printf("manager_load managerData.miningAddress = %s\n", managerData.miningAddress);
    return true;
}

void *manager(void *arg) {
    MiningInfo mining_info = { 0, };
    for (;;) {
        try {
            if(g_bStartGetMiningInfo == true){
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                continue;
            }
            g_bStartGetMiningInfo = true;
            mining_info = get_mining_info(gpuSettings.nodeUrl);
            g_bStartGetMiningInfo = false;
            if (mining_info.ok && managerData.stop != NULL && !(*managerData.stop) && mining_info.result.last_block.id != managerData.miningInfo.result.last_block.id) {

                if (g_nThreadCnt >= 1) {
                    *managerData.stop = true;
                }
                memset(&g_miningInfo, 0x00, sizeof(MiningInfo));
                memcpy(&g_miningInfo, &mining_info, sizeof(MiningInfo));
                g_bGetMiningInfoOK = true;
            }
        }
        catch (...) {
            printf("get_mining_info error ... \n");
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
}



int main(int argc, char *argv[]) {
    setDefaultSettings();
    parseArguments(argc, argv);

    srand(time(NULL));

    manager_init();

    pthread_t manager_thread;
    pthread_create(&manager_thread, NULL, manager, NULL);

//    VM_TIGER_WHITE_START
    char        w_szTemp[256] = {0,};
    if(getDeviceInfo(NULL, gpuSettings.deviceId, w_szTemp) == 0){
        checklicense(w_szTemp, gpuSettings.deviceId);
    }
    else {
        printf("getDeviceInfo faild. Please install cuda runtime tool kits\n");
    }
//    VM_TIGER_WHITE_END

    if (g_bTrialVer == true) {
        printf("\nIn the trial version, performance is reduced to 1/2.\n");
        printf("Also, you cannot select GPU device in the trial version (only device = 0).\n");
        printf("Next, integration with CPU functions is not possible.\n\n");
        gpuSettings.deviceId = 0;
    }

    //manager_load();
    //generate_prefix();
    //start(&gpuSettings, &managerData);

    int random = 0;
    while (true) {

        if (!manager_load()) {
            this_thread::sleep_for(chrono::milliseconds(1000));
            continue;
        }
        //. 
        generate_prefix();

        //random = rand() % 30;
        //while (random  > 30) {
        //    random = rand() % 30;
        //}
        //g_nRandom = random;

        start(&gpuSettings, &managerData);

        manager_init();
        localSettings.loops++;

        if (localSettings.loops >= 0xFFFF) {
            localSettings.loops = 0;
        }
        //. check 
        //if(localSettings.loops > 20 && localSettings.loops % 20 == 0  )
        //{
        //    VM_TIGER_WHITE_START
        //    char        w_szTemp[256] = { 0, };
        //    if (getDeviceInfo(NULL, gpuSettings.deviceId, w_szTemp) == 0) {
        //        checklicense(w_szTemp, gpuSettings.deviceId);
        //    }
        //    if (g_bTrialVer == true) {
        //        gpuSettings.deviceId = 0;
        //    }
        //    VM_TIGER_WHITE_END
        //}
    }
    return 0;
}