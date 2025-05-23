#ifndef C_CUDA_POOL_BASE58_CUH
#define C_CUDA_POOL_BASE58_CUH

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifndef __uint
#define __uint
typedef unsigned int uint;
#endif //__uint

#ifdef __cplusplus
extern "C" {
#endif

extern bool (*b58_sha256_impl)(void *, const void *, size_t);

extern bool b58tobin(void *bin, size_t *binsz, const char *b58, size_t b58sz);
extern int b58check(const void *bin, size_t binsz, const char *b58, size_t b58sz);

extern bool b58enc(char *b58, size_t *b58sz, const void *bin, size_t binsz);
extern bool b58check_enc(char *b58c, size_t *b58c_sz, uint8_t ver, const void *data, size_t datasz);

#ifdef __cplusplus
}
#endif

#endif //C_CUDA_POOL_BASE58_CUH
