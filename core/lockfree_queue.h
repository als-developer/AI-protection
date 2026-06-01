#ifndef LOCKFREE_QUEUE_H
#define LOCKFREE_QUEUE_H

#include <atomic>
#include <cstddef>
#include <cstdint>

struct TelemetryPacket {
    uint64_t source_ip;
    uint64_t timestamp_ns;
    uint32_t channel_id;
    uint32_t num_samples;
    float frequency_data[64];  // Max 64 samples per packet
};

class LockFreeQueue {
public:
    explicit LockFreeQueue(size_t capacity);
    ~LockFreeQueue();
    
    bool push(const TelemetryPacket& packet);
    bool pop(TelemetryPacket& packet);
    size_t size() const;
    bool empty() const;
    bool full() const;
    
private:
    size_t m_capacity;
    TelemetryPacket* m_buffer;
    alignas(64) std::atomic<size_t> m_write_index;
    alignas(64) std::atomic<size_t> m_read_index;
};

#endif // LOCKFREE_QUEUE_H
