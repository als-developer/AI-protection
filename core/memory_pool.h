#ifndef MEMORY_POOL_H
#define MEMORY_POOL_H

#include <cstddef>
#include <cstdint>
#include <vector>

class MemoryPool {
public:
    static void initialize(size_t pool_size_bytes);
    static void shutdown();
    
    static void* allocate(size_t size);
    static void deallocate(void* ptr);
    
    static size_t get_used_bytes();
    static size_t get_free_bytes();
    
    template<typename T>
    static T* allocate_array(size_t count) {
        return static_cast<T*>(allocate(count * sizeof(T)));
    }
    
    template<typename T>
    static void deallocate_array(T* ptr) {
        deallocate(static_cast<void*>(ptr));
    }
    
private:
    struct Block {
        size_t size;
        bool used;
        uint8_t* data;
        Block* next;
    };
    
    static uint8_t* s_pool;
    static size_t s_pool_size;
    static size_t s_used_bytes;
    static Block* s_free_list;
    static bool s_initialized;
    
    static void init_free_list();
    static Block* find_free_block(size_t size);
    static void merge_free_blocks();
};

#endif // MEMORY_POOL_H
