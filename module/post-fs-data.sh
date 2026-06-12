#!/system/bin/sh
# s23 performance tweaks - post-fs-data.sh
# early-boot zram reconfiguration logic
# author: dyokism

MODDIR=${0%/*}

# Initialize/clear log on boot
> "$MODDIR/zram_early.log"

# safe write function
write_value() {
    local path="$1"
    local value="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    if [ ! -e "$path" ]; then
        echo "[$timestamp] [SKIP] Path does not exist: $path" >> "$MODDIR/zram_early.log"
        return 0
    fi
    
    if echo "$value" > "$path" 2>/dev/null; then
        echo "[$timestamp] [OK] Wrote '$value' to $path" >> "$MODDIR/zram_early.log"
    else
        echo "[$timestamp] [ERR] Failed to write '$value' to $path" >> "$MODDIR/zram_early.log"
    fi
}

# helper for zram logging
log_zram_step() {
    local step="$1"
    local status="$2"
    local msg="$3"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [ZRAM] $step: $status - $msg" >> "$MODDIR/zram_early.log"
}

# guard check: skip if current comp_algorithm is already lz4
comp_algo_path="/sys/block/zram0/comp_algorithm"
if [ -f "$comp_algo_path" ]; then
    current_algo=$(cat "$comp_algo_path")
    case "$current_algo" in
        *"[lz4]"*)
            log_zram_step "Guard Check" "SKIP" "Already lz4, nothing to do."
            exit 0
            ;;
    esac
fi

# zram reconfiguration logic

# step a: read current disksize from /sys/block/zram0/disksize
disksize_path="/sys/block/zram0/disksize"
if [ ! -f "$disksize_path" ]; then
    log_zram_step "Step A (Read disksize)" "SKIP" "Path $disksize_path not found"
    exit 0
fi

original_disksize=$(cat "$disksize_path")
if [ -z "$original_disksize" ] || [ "$original_disksize" -eq 0 ]; then
    original_disksize=4294967296
fi
log_zram_step "Step A (Read disksize)" "OK" "Original disksize: $original_disksize"

# step b: check available free ram vs current swap usage
mem_free=""
swap_total=""
swap_free=""

if [ -f /proc/meminfo ]; then
    while read -r name value unit; do
        case "$name" in
            MemFree:) mem_free=$value ;;
            SwapTotal:) swap_total=$value ;;
            SwapFree:) swap_free=$value ;;
        esac
    done < /proc/meminfo
else
    log_zram_step "Step B (RAM check)" "SKIP" "/proc/meminfo not found"
    exit 0
fi

if [ -z "$mem_free" ] || [ -z "$swap_total" ] || [ -z "$swap_free" ]; then
    log_zram_step "Step B (RAM check)" "ERR" "Failed to parse /proc/meminfo"
    exit 0
fi

swap_used=$((swap_total - swap_free))
mem_free_mb=$((mem_free / 1024))
swap_used_mb=$((swap_used / 1024))

if [ "$mem_free" -le "$swap_used" ]; then
    log_zram_step "Step B (RAM check)" "SKIP" "Free RAM (${mem_free_mb}MB) <= Swap Used (${swap_used_mb}MB). Aborting ZRAM reconfig for safety."
    exit 0
else
    log_zram_step "Step B (RAM check)" "OK" "Free RAM (${mem_free_mb}MB) > Swap Used (${swap_used_mb}MB). Safe to proceed."
fi

# step c: swapoff the zram device (try /dev/block/zram0, fallback /dev/zram0)
swap_dev=""
if swapoff /dev/block/zram0 2>/dev/null; then
    swap_dev="/dev/block/zram0"
    log_zram_step "Step C (swapoff)" "OK" "Disabled swap on /dev/block/zram0"
elif swapoff /dev/zram0 2>/dev/null; then
    swap_dev="/dev/zram0"
    log_zram_step "Step C (swapoff)" "OK" "Disabled swap on /dev/zram0"
else
    # swapoff failed. check if zram is actually active in /proc/swaps.
    if grep -q "zram0" /proc/swaps 2>/dev/null; then
        log_zram_step "Step C (swapoff)" "ERR" "ZRAM is active but swapoff failed"
        exit 0
    else
        # zram is not active as swap yet. determine the appropriate swap device path.
        if [ -b "/dev/block/zram0" ]; then
            swap_dev="/dev/block/zram0"
        elif [ -b "/dev/zram0" ]; then
            swap_dev="/dev/zram0"
        elif [ -e "/dev/block/zram0" ]; then
            swap_dev="/dev/block/zram0"
        elif [ -e "/dev/zram0" ]; then
            swap_dev="/dev/zram0"
        else
            log_zram_step "Step C (swapoff)" "ERR" "No ZRAM block device found"
            exit 0
        fi
        log_zram_step "Step C (swapoff)" "OK" "ZRAM is not active as swap yet. Proceeding with configuration."
    fi
fi

# step d: echo 1 > /sys/block/zram0/reset
reset_path="/sys/block/zram0/reset"
if [ -f "$reset_path" ]; then
    if echo 1 > "$reset_path" 2>/dev/null; then
        log_zram_step "Step D (Reset ZRAM)" "OK" "Successfully reset zram0"
    else
        log_zram_step "Step D (Reset ZRAM)" "ERR" "Failed to write 1 to $reset_path"
        # try to restore original swap
        swapon "$swap_dev" 2>/dev/null
        exit 0
    fi
else
    log_zram_step "Step D (Reset ZRAM)" "ERR" "Reset path $reset_path not found"
    swapon "$swap_dev" 2>/dev/null
    exit 0
fi

# step e: echo lz4 > /sys/block/zram0/comp_algorithm
comp_path="/sys/block/zram0/comp_algorithm"
if [ -f "$comp_path" ]; then
    if echo lz4 > "$comp_path" 2>/dev/null; then
        log_zram_step "Step E (Set Algorithm)" "OK" "Successfully changed algorithm to lz4"
    else
        log_zram_step "Step E (Set Algorithm)" "ERR" "Failed to write lz4 to $comp_path"
        # try to restore disksize and swap
        echo "$original_disksize" > "$disksize_path" 2>/dev/null
        mkswap "$swap_dev" >/dev/null 2>&1
        swapon "$swap_dev" 2>/dev/null
        exit 0
    fi
else
    log_zram_step "Step E (Set Algorithm)" "ERR" "Comp algorithm path $comp_path not found"
    # try to restore disksize and swap
    echo "$original_disksize" > "$disksize_path" 2>/dev/null
    mkswap "$swap_dev" >/dev/null 2>&1
    swapon "$swap_dev" 2>/dev/null
    exit 0
fi

# step f: restore original disksize
if echo "$original_disksize" > "$disksize_path" 2>/dev/null; then
    log_zram_step "Step F (Restore disksize)" "OK" "Restored disksize to $original_disksize"
else
    log_zram_step "Step F (Restore disksize)" "ERR" "Failed to write $original_disksize to $disksize_path"
    exit 0
fi

# step g: mkswap and swapon
if mkswap "$swap_dev" >/dev/null 2>&1; then
    log_zram_step "Step G (mkswap)" "OK" "Prepared swap on $swap_dev"
else
    log_zram_step "Step G (mkswap)" "ERR" "Failed mkswap on $swap_dev"
fi

if swapon "$swap_dev" 2>/dev/null; then
    log_zram_step "Step G (swapon)" "OK" "Successfully enabled swap on $swap_dev"
else
    log_zram_step "Step G (swapon)" "ERR" "Failed swapon on $swap_dev"
fi
