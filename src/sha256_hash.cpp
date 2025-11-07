#include "sha256_hash.h"
#include <openssl/evp.h>
#include <iomanip>
#include <sstream>

std::string sha256(const std::string& input) {
    EVP_MD_CTX* context = EVP_MD_CTX_new();
    const EVP_MD* md = EVP_sha256();
    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int hash_len;

    EVP_DigestInit_ex(context, md, nullptr);
    EVP_DigestUpdate(context, input.c_str(), input.size());
    EVP_DigestFinal_ex(context, hash, &hash_len);
    EVP_MD_CTX_free(context);

    std::ostringstream result;
    for (unsigned int i = 0; i < hash_len; ++i) {
        result << std::hex << std::setw(2) << std::setfill('0') 
               << static_cast<int>(hash[i]);
    }
    return result.str();
}
