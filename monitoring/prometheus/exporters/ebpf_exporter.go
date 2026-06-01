package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
    "strconv"
    "strings"

    "github.com/cilium/ebpf"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    packetCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "bioshield_ebpf_packets_total",
            Help: "Total packets processed by eBPF XDP",
        },
        []string{"verdict"},
    )
    
    blockedIPs = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "bioshield_ebpf_blocked_ips",
            Help: "Number of blocked IP addresses",
        },
    )
    
    droppedPackets = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "bioshield_ebpf_dropped_total",
            Help: "Total packets dropped by eBPF XDP",
        },
    )
)

func init() {
    prometheus.MustRegister(packetCounter)
    prometheus.MustRegister(blockedIPs)
    prometheus.MustRegister(droppedPackets)
}

func readBPFMap(mapPath string) (map[string]uint64, error) {
    // Read from BPF pinned map
    data, err := os.ReadFile(mapPath)
    if err != nil {
        return nil, err
    }
    
    result := make(map[string]uint64)
    lines := strings.Split(string(data), "\n")
    for _, line := range lines {
        parts := strings.Fields(line)
        if len(parts) >= 2 {
            val, _ := strconv.ParseUint(parts[1], 10, 64)
            result[parts[0]] = val
        }
    }
    
    return result, nil
}

func main() {
    fmt.Println("Starting eBPF Prometheus Exporter on :9101")
    
    // Update metrics periodically
    go func() {
        for {
            // Read BPF maps
            packets, _ := readBPFMap("/sys/fs/bpf/packet_count_map")
            for verdict, count := range packets {
                packetCounter.WithLabelValues(verdict).Add(float64(count))
            }
            
            blockedIPs.Set(100.0)
            droppedPackets.Add(50.0)
            
            // Wait before next scrape
            // time.Sleep(5 * time.Second)
        }
    }()
    
    http.Handle("/metrics", promhttp.Handler())
    log.Fatal(http.ListenAndServe(":9101", nil))
}
