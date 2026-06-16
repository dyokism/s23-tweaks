# S23 Performance Tweaks

Low-risk kernel and subsystem optimizations for Samsung Galaxy S23 (SM-S911*) devices running the Snapdragon 8 Gen 2 platform. Designed for KernelSU, APatch, and Magisk.

*Note: This module does not overclock your device. Instead, it makes system processes more efficient and responsive.*

---

## Design Philosophy

Stock One UI configurations aggressively swap active memory to virtual storage (swappiness set to 130) and aggressively scale down GPU/CPU idle frequencies, which can introduce micro-stutters during high-refresh 120Hz system animations.

This module applies conservative, low-risk tuning values to minimize scheduling latencies, storage overhead, and memory thrashing. It does not overclock the device, modify thermal protection limits, or increase maximum frequency bounds.

---

## Execution Workflow

Samsung devices run a late post-boot optimization script (`init.kernel.post_boot-kalama.sh`) that resets many kernel parameters to defaults. To ensure optimizations persist, this module uses a two-phase execution design:

1. **Early Boot (post-fs-data.sh)**: Reconfigures ZRAM to use `lz4` compression while swap usage is at zero. A safety guard queries `/proc/meminfo` to ensure free RAM exceeds current swap usage before resetting the swap interface, preventing kernel Out-Of-Memory (OOM) crashes.
2. **Late Boot (service.sh)**: Polls for boot completion (`sys.boot_completed=1`) and waits for **90 seconds** before applying tweaks. This delay ensures the optimizations outlast and survive Samsung's late post-boot script overrides.

---

## Optimizations Applied

### Memory & ZRAM
* **swappiness**: Set to `80` (reduced from `130`) to retain active application pages in physical RAM.
* **Compression**: Configured to `lz4` (from stock `deflate` or `zstd`) for fast decompression speeds.
* **Virtual Memory**: Raised dirty page limits (`dirty_bytes` to 150MB, `dirty_background_bytes` to 50MB) and expire timeouts (`dirty_expire_centisecs` to 500, `dirty_writeback_centisecs` to 1000) to group write operations and reduce CPU wakeups.

### Processor & Scheduler (WALT)
* **Target Load**: `hispeed_load` set to `85` across all CPU clusters to scale frequency responsively under task loads.
* **Rate Limits**: Configured cluster up/down rate limits (Prime cluster up limit set to `1000us`, Gold/Silver to `500us`) to stabilize frequency scaling.
* **GPU**: Elevated minimum clock frequency of the Adreno 740 to `295 MHz` to eliminate rendering lag when waking the display subsystem.

### Storage (UFS) & I/O
* **I/O Scheduler**: Switched physical block devices (`sd*`) to `none` (No-Op) to bypass CPU-bound software queuing, utilizing the hardware's native command queuing.
* **Read-Ahead**: Increased to `256KB`.
* **Request Limit**: `nr_requests` set to `128` to expand queue depth.

### Network
* **TCP Fast Open**: Configured `tcp_fastopen` to `3` to enable client/server handshake payload optimizations.

---

## Safety Exclusions (Unmodified Paths)

To guarantee system stability and hardware safety, the following systems are unmodified:
* **Thermal Subsystems**: No changes are applied to paths under `/sys/class/thermal/`.
* **Maximum Frequencies**: Peak CPU (`scaling_max_freq`) and GPU (`max_gpuclk`) limits are left stock to avoid conflicts with Samsung's Game Optimization Service (GOS).
* **TCP Congestion**: Left at stock defaults (TCP BBR is not compiled in the stock kernel).
* **Adreno Boost**: Unconfigured (driver is unsupported on this kernel).

---

## Compatibility

* **Kernel Nodes**: WALT CPU adjustments require kernel support. On stock kernels, missing paths are safely bypassed.
* **Tested Environments**: Active on One UI 8.5 (BeyondROM). Compatible with standard One UI variants.
