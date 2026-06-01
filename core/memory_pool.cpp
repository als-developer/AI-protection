#include "memory_pool.h"
#include <cstring>
#include <iostream>
#include <sys/mman.h>

uint8_t* MemoryPool::s_pool = nullptr;
size_t MemoryPool::s_pool_size = 0;
size_t MemoryPool::s_used_bytes = 0;
MemoryPool::Block* MemoryPool::s_free_list = nullptr;
bool MemoryPool::s_initialized = false;

void MemoryPool::initialize(size_t pool_size_bytes) {
    if (s_initialized) return;
    
    // Use mmap for large allocations
    s_pool = static_cast<uint8_t*>(
        mmap(nullptr, pool_size_bytes, PROT_READ | PROT_WRITE,
             MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    );
    
    if (s_pool == MAP_FAILED) {
        std::cerr << "[MEMPOOL] Failed to allocate " << pool_size_bytes << " bytes" << std::endl;
        return;
    }
    
    s_pool_size = pool_size_bytes;
    s_used_bytes = 0;
    s_initialized = true;
    
    init_free_list();
    
    std::cout << "[MEMPOOL] Initialized with " << pool_size_bytes / (1024 * 1024) 
              << " MB" << std::endl;
}

void MemoryPool::shutdown() {
    if (!s_initialized) return;
    
    munmap(s_pool, s_pool_size);
    s_pool = nullptr;
    s_pool_size = 0;
    s_used_bytes = 0;
    s_free_list = nullptr;
    s_initialized = false;
    
    std::cout << "[MEMPOOL] Shutdown complete" << std::endl;
}

void MemoryPool::init_free_list() {
    s_free_list = reinterpret_cast<Block*>(s_pool);
    s_free_list->size = s_pool_size - sizeof(Block);
    s_free_list->used = false;
    s_free_list->data = s_pool + sizeof(Block);
    s_free_list->next = nullptr;
}

void* MemoryPool::allocate(size_t size) {
    if (!s_initialized) return nullptr;
    
    // Align to 8 bytes
    size = (size + 7) & ~7;
    
    Block* block = find_free_block(size);
    if (!block) return nullptr;
    
    block->used = true;
    s_used_bytes += block->size;
    
    return block->data;
}

void MemoryPool::deallocate(void* ptr) {
    if (!ptr || !s_initialized) return;
    
    Block* block = reinterpret_cast<Block*>(
        static_cast<uint8_t*>(ptr) - sizeof(Block)
    );
    
    block->used = false;
    s_used_bytes -= block->size;
    
    merge_free_blocks();
}

MemoryPool::Block* MemoryPool::find_free_block(size_t size) {
    Block* current = s_free_list;
    Block* best = nullptr;
    size_t best_size = SIZE_MAX;
    
    while (current) {
        if (!current->used && current->size >= size && current->size < best_size) {
            best = current;
            best_size = current->size;
        }
        current = current->next;
    }
    
    return best;
}

void MemoryPool::merge_free_blocks() {
    // Simple first-fit merge - would be optimized in production
    Block* current = s_free_list;
    while (current && current->next) {
        if (!current->used && !current->next->used &&
            current->data + current->size == current->next->data) {
            current->size += sizeof(Block) + current->next->size;
            current->next = current->next->next;
        } else {
            current = current->next;
        }
    }
}

size_t MemoryPool::get_used_bytes() {
    return s_used_bytes;
}

size_t MemoryPool::get_free_bytes() {
    return s_pool_size - s_used_bytes;
}
