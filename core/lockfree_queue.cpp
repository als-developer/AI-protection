#include "lockfree_queue.h"
#include <cstring>

LockFreeQueue::LockFreeQueue(size_t capacity)
    : m_capacity(1)
    , m_write_index(0)
    , m_read_index(0)
{
    while (m_capacity < capacity) m_capacity <<= 1;
    m_buffer = new TelemetryPacket[m_capacity];
    memset(m_buffer, 0, sizeof(TelemetryPacket) * m_capacity);
}

LockFreeQueue::~LockFreeQueue() {
    delete[] m_buffer;
}

bool LockFreeQueue::push(const TelemetryPacket& packet) {
    size_t write_idx = m_write_index.load(std::memory_order_relaxed);
    size_t read_idx = m_read_index.load(std::memory_order_acquire);
    
    if (write_idx - read_idx >= m_capacity) {
        return false;
    }
    
    m_buffer[write_idx & (m_capacity - 1)] = packet;
    m_write_index.store(write_idx + 1, std::memory_order_release);
    return true;
}

bool LockFreeQueue::pop(TelemetryPacket& packet) {
    size_t read_idx = m_read_index.load(std::memory_order_relaxed);
    size_t write_idx = m_write_index.load(std::memory_order_acquire);
    
    if (read_idx == write_idx) {
        return false;
    }
    
    packet = m_buffer[read_idx & (m_capacity - 1)];
    m_read_index.store(read_idx + 1, std::memory_order_release);
    return true;
}

size_t LockFreeQueue::size() const {
    size_t write_idx = m_write_index.load(std::memory_order_acquire);
    size_t read_idx = m_read_index.load(std::memory_order_acquire);
    return write_idx - read_idx;
}

bool LockFreeQueue::empty() const {
    return size() == 0;
}

bool LockFreeQueue::full() const {
    size_t write_idx = m_write_index.load(std::memory_order_acquire);
    size_t read_idx = m_read_index.load(std::memory_order_acquire);
    return (write_idx - read_idx) >= m_capacity;
}
