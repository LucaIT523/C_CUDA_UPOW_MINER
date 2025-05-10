# 

<div align="center">
   <h1>C++_CUDA_UPOW_MINER</h1>
</div>

This code is a CUDA-based cryptocurrency miner. 

It manages GPU and local settings, parses command-line arguments, interacts with mining nodes/pools, manages mining threads, and handles licensing/trial logic.

### Key Components 

1. Global Variables and Settings

- GpuSettings, LocalSettings, ManagerData: Structures holding configuration for GPU mining, local miner settings, and runtime manager state.

- MAX_ADDRESSES: Maximum number of wallet addresses supported.
- Various flags and buffers: For mining info, thread control, licensing, etc. 

2. Utility Functions
- timestamp(): Returns the current system time as a Unix timestamp.
- setDefaultSettings(): Initializes all settings to default values, allocates memory for addresses and URLs, and sets default mining parameters.

- parseArguments(): Parses command-line arguments to override default settings (e.g., address, node URL, pool URL, device ID, etc.).

- get_transactions_merkle_tree(): Computes the Merkle root of the pending transactions for block construction.

- get_random_address(): Selects a random non-empty address from the address list. 

3. Mining Preparation

- generate_prefix(): Prepares the mining prefix (block header) including previous block hash, address, Merkle root, timestamp, and difficulty. 

Handles licensing/trial logic to potentially restrict mining capabilities. 

4. Manager Functions

- manager_init(): Initializes or resets the manager state, including memory allocation for control flags and share chunks.

- manager_load(): Loads mining info from the node, updates manager state, and selects a mining address.

- manager(): Thread function that periodically fetches new mining info and signals the main thread if a new block is detected. 

5. Main Function

- Initialization: Sets defaults, parses arguments, seeds random number generator, and starts the manager thread.

- Licensing: Checks device license and applies trial restrictions if necessary.

- Mining Loop:

  - Loads mining info.

  - Prepares the mining prefix.

  - Starts the mining process ( start() function, not shown here).

  - Re-initializes manager state for the next round.

  - Periodically checks and resets loop counters.


### Notable Features
- Threading: Uses pthreads and C++ threads for concurrent mining info fetching and mining.

- CUDA Integration: Designed to work with CUDA for GPU mining (device selection, thread/block configuration).

- Licensing/Trial Logic: Restricts features and performance in trial mode.

- Dynamic Configuration: Allows runtime configuration via command-line arguments.

### Typical Flow
1. Startup: Initialize settings and parse user input.

2. License Check: Ensure the miner is licensed or apply trial restrictions.

3. Mining Loop:

   - Fetch latest mining info.

   - Prepare mining data (prefix, address, Merkle root).

  - Launch mining kernel (GPU).

   - Repeat.









### **Contact Us**

For any inquiries or questions, please contact us.

telegram : @topdev1012

email :  skymorning523@gmail.com

Teams :  https://teams.live.com/l/invite/FEA2FDDFSy11sfuegI