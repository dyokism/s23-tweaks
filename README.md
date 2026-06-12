# S23 Performance Tweaks

Low-risk kernel & subsystem optimizations for all base variants of the **Samsung Galaxy S23 (SM-S911*)** running the Snapdragon 8 Gen 2 platform. Compatible with **KernelSU**, **APatch**, and **Magisk**.

---

## ⚡ Tweaks & Optimizations

* **RAM & Swap**: Lowers swappiness (`80` vs `130` default) to keep active apps in physical RAM, switching ZRAM compression to efficient **lz4** during early boot (`post-fs-data.sh`).
* **CPU WALT**: Ramps frequency faster under load (`hispeed_load=85`) and applies stability filters (`up_rate_limit`, `down_rate_limit`) to eliminate micro-stutters.
* **Storage (UFS)**: Bypasses CPU-bound queuing (`scheduler=none`), doubles read-ahead (`256KB`), and adaptively tunes request limit (`31` for `none` scheduler to match hardware queue limits, `128` otherwise) for faster loading times.
* **Battery & Wear**: Groups write operations by raising VM dirty page timeouts (`5s/10s`), reducing background wakeups and flash wear.
* **GPU**: Elevates minimum clock to `295 MHz` to prevent rendering lag during high-refresh 120Hz UI animations.
* **Network**: Enables client + server TCP Fast Open (`3`) to lower connection latency.

---

## 🛡️ Safety & Safeguards

* **Device Guard**: Aborts silently if the device is not an S23 base variant (`SM-S911*`).
* **Safe Write Window**: Waits for boot completion + a **90-second delay** in `service.sh` to survive late One UI post-boot optimization resets.
* **Safe Write Function**: Verifies path existence before writing, logging `OK`, `ERR`, or `SKIP` with timestamps to `tweak.log`.
* **ZRAM Safety Guard**: Compares `SwapUsed` vs `MemFree` before disabling swap. The operation runs in early boot (`post-fs-data.sh`) when swap usage is near zero, defaulting to a 4GB fallback swap size if the original ZRAM size is read as `0`.

---

## 🚫 Intentionally Skipped (Not Applied)

* **TCP BBR**: Skipped (not compiled in the stock kernel).
* **adrenoboost**: Skipped (not supported on this kernel).
* **Thermal Zones**: Untouched to ensure hardware safety.
* **scaling_max_freq / max_gpuclk**: Untouched to avoid Game Optimization Service (GOS) conflicts.

---

## ⚠️ Disclaimers & Compatibility

* **CPU WALT Tuning**: Requires a custom kernel that exposes WALT sysfs nodes (e.g., custom kernels exposing WALT parameters). On the stock kernel, this section is silently skipped.
* **Compatibility**: Tested on One UI 8.5 (BeyondROM). Other One UI versions may work but are untested.
