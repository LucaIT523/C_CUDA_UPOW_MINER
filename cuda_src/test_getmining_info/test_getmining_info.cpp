// test_getmining_info.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <chrono>
#include <thread>
#include <time.h>

#include "unistd.h"
#include "requests.h"
#include "pthread.h"


const char g_nodeurl[64] = "http://api.upow.ai/";

void* manager(void* arg) {
	MiningInfo mining_info = { 0, };
	for (;;) {
		mining_info = get_mining_info(g_nodeurl);
		if (mining_info.ok ) {
			printf("get_mining_info ... ok \n");
		}
		else {
			printf("get_mining_info ... error \n");
		}
		std::this_thread::sleep_for(std::chrono::milliseconds(1000));
	}
}

int main()
{

	pthread_t manager_thread;
	pthread_create(&manager_thread, NULL, manager, NULL);


	std::cout << "Hello World!\n";

	while (/*g_bExit == 0*/true) {
		std::this_thread::sleep_for(std::chrono::milliseconds(500));
		continue;
	}

}
