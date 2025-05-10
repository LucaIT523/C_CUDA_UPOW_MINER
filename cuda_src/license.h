#pragma once


#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "stdio.h"

#include "sha256.cuh"


#include "cuda_runtime.h"
#include "device_launch_parameters.h"


typedef struct {
	char	m_szDeviceHead[64];
	BYTE	m_bData[32];
} UPOW_LICENSE_INFO;



int  getHashInfo(BYTE* p_szGPUDevInfo, int p_nlen, BYTE* p_OouHash);


int  getDeviceInfo(char* p_szGPUDevInfo, int p_nDeviceID, char* p_szGPUDevHead);

int  checklicense(char* p_szGPUDevHead, int p_nDeviceID);


