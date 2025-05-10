// CURLPostTest.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <windows.h>
#include <time.h>
#include <chrono>
#include <thread>

#include "requests.h"

const char* g_pFilePath = "post_data.inf";
const char* g_pNodeURL = "http://api.upow.ai/";

int main()
{
    FILE*       w_pFile = NULL;
    FILE*       w_pFile_Backup = NULL;
    POST_DATA   w_stPOST_DATA;
    int         w_nLen = 0;
    int         w_nBuckupFileCnt = 0;

    w_pFile = fopen("D:\\zBackup_data_1.inf", "rb");
    memset(&w_stPOST_DATA, 0x00, sizeof(POST_DATA));
    w_nLen = fread(&w_stPOST_DATA, 1, sizeof(POST_DATA), w_pFile);
    fclose(w_pFile);
    w_pFile = NULL;

    MiningInfo mining_info = { 0, };
    mining_info = get_mining_info(g_pNodeURL);


    while (true) {
//        w_pFile = fopen(g_pFilePath, "rb");
//        if (w_pFile == NULL) {
//            std::this_thread::sleep_for(std::chrono::milliseconds(500));
////            printf("w_pFile == NULL \n");
//            continue;
//        }
//        //. 
//        memset(&w_stPOST_DATA, 0x00, sizeof(POST_DATA));
//        w_nLen = fread(&w_stPOST_DATA, 1, sizeof(POST_DATA), w_pFile);
//        if (w_nLen != sizeof(POST_DATA)) {
//            std::this_thread::sleep_for(std::chrono::milliseconds(500));
////            printf("w_nLen != sizeof(POST_DATA) \n");
//            continue;
//        }
//        //. backup data
//        w_nBuckupFileCnt++;
//        char    w_szTemp[256] = "";
//        sprintf(w_szTemp, "zBackup_data_%d.inf", w_nBuckupFileCnt);
//        w_pFile_Backup = fopen(w_szTemp, "wb");
//        if (w_pFile_Backup != NULL) {
//            fwrite(&w_stPOST_DATA, 1, sizeof(POST_DATA), w_pFile_Backup);
//            fclose(w_pFile_Backup);
//            w_pFile_Backup = NULL;
//        }
//
//        fclose(w_pFile);
//        w_pFile = NULL;
        //.
        for (int i = 0; i < 20; i++) {
            Share* resp;
            memset(&resp, 0x00, sizeof(Share));
            resp = share(
                g_pNodeURL,
                w_stPOST_DATA.m_sHash,
                w_stPOST_DATA.m_stransactions_hashes,
                w_stPOST_DATA.m_pending_transactions_count,
                w_stPOST_DATA.m_block_id
            );
            if (resp->ok) {
                printf("------ Block Mined = %d --------- \n", w_stPOST_DATA.m_block_id);
                delete resp;
                break;
            }
            else {
                printf("Share not accepted: %s\n", resp->error);
                delete resp;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(300));

        }

        w_pFile = fopen(g_pFilePath, "wb");
        fclose(w_pFile);
        w_pFile = NULL;

     std::this_thread::sleep_for(std::chrono::milliseconds(500));

    }









	return 0;
}

