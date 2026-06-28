# S23 Performance Tweaks

This is a safe root module that improves performance for Samsung Galaxy S23 (SM-S911*) devices. It works with KernelSU, APatch, and Magisk.

This module does not overclock your phone. It only makes the system work more efficiently.

## Why use this module?

By default, Samsung One UI uses virtual memory too much and lowers CPU/GPU speeds quickly to save battery. This can cause small lag when you use your phone at 120Hz.

This module improves settings for memory, CPU, GPU, and storage. It helps to make your phone smoother without overheating or using too much battery.

## How it works

Samsung phones run a script after booting that resets performance settings. To keep our settings, this module works in two steps:

1. **Early Boot (post-fs-data.sh)**: Sets ZRAM memory compression to lz4 for faster loading speeds. It checks if your phone has enough free RAM before starting to prevent crashes.
2. **Late Boot (service.sh)**: Waits until the phone finishes booting, sleeps for 90 seconds, and then applies the tweaks. This delay makes sure our changes are not reset by Samsung.

## Optimizations

### Memory & ZRAM
* **swappiness**: Set to 80 (reduced from 130) to keep apps in the fast physical RAM.
* **ZRAM Compression**: Uses lz4 for faster loading.
* **Virtual Memory**: Changes settings so the CPU writes data to storage in larger groups, which saves CPU energy.

### Processor & GPU
* **CPU (WALT)**: Tunes how fast the processor cores change their speeds based on your usage.
* **GPU (Adreno 740)**: Increases the minimum speed to 295 MHz to stop lag when you turn on the screen.

### Storage & Network
* **Storage (UFS)**: Changes storage settings to read data faster.
* **Network**: Enables TCP Fast Open to load web pages quicker.

## Safety Rules

To keep your phone safe, we do not change:
* **Thermal controls**: The phone will cool down normally if it gets hot.
* **Maximum speeds**: Maximum CPU and GPU speeds are not changed, so you will not damage your hardware.

## Compatibility

* Tested on Samsung One UI.
* If your system does not support a setting, the module skips it safely without errors.
