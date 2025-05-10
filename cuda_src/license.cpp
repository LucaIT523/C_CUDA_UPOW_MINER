
#include "license.h"
#include <stdio.h>
#include <string.h>
#include <Windows.h>
#include "ThemidaSDK.h"

BYTE	g_bFileLicenseData[32] = { 0, };
BYTE	g_nDeviceLicenseData[32] = { 0, };

bool	g_bTrialVer = true;


int     getDeviceInfo(char* p_szGPUDevInfo, int p_nDeviceID, char* p_szGPUDevHead)
{

	int             w_nRtn = -1;

	cudaError_t cudaStatus = cudaSetDevice(p_nDeviceID);
	if (cudaStatus != cudaSuccess) {
		goto L_EXIT;
	}

	cudaDeviceProp prop;
	cudaGetDeviceProperties(&prop, p_nDeviceID); // Get properties of device 0


	if(p_szGPUDevInfo != NULL)
		sprintf(p_szGPUDevInfo, "%02d-%s-%08x-%08x", p_nDeviceID, prop.name, prop.pciBusID, prop.pciDeviceID);

	if (p_szGPUDevHead != NULL) {
		sprintf(p_szGPUDevHead, "%02d-%s", p_nDeviceID, prop.name);
	}

	//. ok
	w_nRtn = 0;
L_EXIT:
	return w_nRtn;
}

int  getHashInfo(BYTE* p_szGPUDevInfo, int p_nlen, BYTE* p_OouHash)
{
//	VM_TIGER_WHITE_START

	int             w_nRtn = -1;
	BYTE			w_szHashTemp[32] = { 0, };

	if (p_szGPUDevInfo == NULL || p_nlen <= 0) {
		goto L_EXIT;
	}

	SHA256_CTX ctx;
	sha256_init(&ctx);
	sha256_update(&ctx, (BYTE*)p_szGPUDevInfo, p_nlen);
	sha256_final(&ctx, w_szHashTemp);

	for (int i = 0; i < 32; i++) {
		p_OouHash[i] = 0xFF - w_szHashTemp[i];
	}

	//. ok
	w_nRtn = 0;
L_EXIT:
//	VM_TIGER_WHITE_END
	return w_nRtn;
}
int  checklicense(char* p_szGPUDevHead, int p_nDeviceID)
{
//	VM_TIGER_WHITE_START

	int					w_nRtn = -1;
	char				w_szFilePath[256] = "";
	FILE*				w_pFile = NULL;
	char				w_szTemp[256] = { 0, };
	BYTE				w_bHashLicense_1[32] = { 0, };
	BYTE				w_bHashLicense_2[32] = { 0, };
	char				w_szModPathFull[256] = { 0, };
	char				w_szModTemp[256] = { 0, };
	int					i;


	g_bTrialVer = true;

	GetModuleFileNameA(NULL, w_szModPathFull, 256);
	strncpy(w_szModTemp, w_szModPathFull, strlen(w_szModPathFull) - strlen("CudaRuntimeTest.exe"));
	sprintf(w_szFilePath, "%s%s.lic", w_szModTemp, p_szGPUDevHead);

	w_pFile = fopen(w_szFilePath, "rb");
	if (w_pFile == NULL) {
		goto L_EXIT;
	}

	int w_nReadLen = fread(g_bFileLicenseData, 1, 32, w_pFile);
	if (w_nReadLen != 32) {
		goto L_EXIT;
	}
	fclose(w_pFile);

	memset(w_szTemp, 0x00, 256);
	if(getDeviceInfo(w_szTemp, p_nDeviceID, NULL) != 0){
		goto L_EXIT;
	}

	if (getHashInfo((BYTE*)w_szTemp, strlen(w_szTemp), w_bHashLicense_1) != 0) {
		goto L_EXIT;
	}

	if (getHashInfo(w_bHashLicense_1, 32, g_nDeviceLicenseData) != 0) {
		goto L_EXIT;
	}

	for (i = 0; i < 32; i++) {
		if (g_nDeviceLicenseData[i] != g_bFileLicenseData[i]) {
			goto L_EXIT;
		}
	}

	//. OK
	g_bTrialVer = false;
	w_nRtn = 0;

L_EXIT:
//	VM_TIGER_WHITE_END
	return w_nRtn;
}
