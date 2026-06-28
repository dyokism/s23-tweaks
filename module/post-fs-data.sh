#!/system/bin/sh

# shellcheck disable=SC3043

MODDIR=${0%/*}

: > "$MODDIR/zram_early.log"

log_zram_step() {
    local step="$1"
    local status="$2"
    local msg="$3"
    echo "[$TIMESTAMP] [ZRAM] $step: $status - $msg" >> "$MODDIR/zram_early.log"
}

run_post_fs_data() {
    # Cache timestamp to avoid subshell forks on every log line.
    local TIMESTAMP
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # Skip if compression algorithm is already lz4.
    local comp_algo_path="/sys/block/zram0/comp_algorithm"
    if [ -f "$comp_algo_path" ]; then
        local current_algo
        read -r current_algo < "$comp_algo_path"
        case "$current_algo" in
            *"[lz4]"*)
                log_zram_step "Guard Check" "SKIP" "Already lz4, nothing to do."
                return 0
                ;;
        esac
    fi

    local disksize_path="/sys/block/zram0/disksize"
    if [ ! -f "$disksize_path" ]; then
        log_zram_step "Step A (Read disksize)" "SKIP" "Path $disksize_path not found"
        return 0
    fi

    local original_disksize
    read -r original_disksize < "$disksize_path"
    if [ -z "$original_disksize" ] || [ "$original_disksize" -eq 0 ]; then
        original_disksize=4294967296
    fi
    log_zram_step "Step A (Read disksize)" "OK" "Original disksize: $original_disksize"

    local mem_free=""
    local swap_total=""
    local swap_free=""

    if [ -f /proc/meminfo ]; then
        local name value
        while read -r name value _; do
            case "$name" in
                MemFree:) mem_free=$value ;;
                SwapTotal:) swap_total=$value ;;
                SwapFree:) swap_free=$value ;;
            esac
        done < /proc/meminfo
    else
        log_zram_step "Step B (RAM check)" "SKIP" "/proc/meminfo not found"
        return 0
    fi

    if [ -z "$mem_free" ] || [ -z "$swap_total" ] || [ -z "$swap_free" ]; then
        log_zram_step "Step B (RAM check)" "ERR" "Failed to parse /proc/meminfo"
        return 0
    fi

    local swap_used=$((swap_total - swap_free))
    local mem_free_mb=$((mem_free / 1024))
    local swap_used_mb=$((swap_used / 1024))

    if [ "$mem_free" -le "$swap_used" ]; then
        log_zram_step "Step B (RAM check)" "SKIP" "Free RAM (${mem_free_mb}MB) <= Swap Used (${swap_used_mb}MB). Aborting ZRAM reconfig for safety."
        return 0
    else
        log_zram_step "Step B (RAM check)" "OK" "Free RAM (${mem_free_mb}MB) > Swap Used (${swap_used_mb}MB). Safe to proceed."
    fi

    # Swapoff ZRAM device (try /dev/block/zram0, fallback /dev/zram0).
    local swap_dev=""
    if swapoff /dev/block/zram0 2>/dev/null; then
        swap_dev="/dev/block/zram0"
        log_zram_step "Step C (swapoff)" "OK" "Disabled swap on /dev/block/zram0"
    elif swapoff /dev/zram0 2>/dev/null; then
        swap_dev="/dev/zram0"
        log_zram_step "Step C (swapoff)" "OK" "Disabled swap on /dev/zram0"
    else
        # Swapoff failed. Abort only if ZRAM is active in /proc/swaps.
        if grep -q "zram0" /proc/swaps 2>/dev/null; then
            log_zram_step "Step C (swapoff)" "ERR" "ZRAM is active but swapoff failed"
            return 0
        else
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
                return 0
            fi
            log_zram_step "Step C (swapoff)" "OK" "ZRAM is not active as swap yet. Proceeding with configuration."
        fi
    fi

    local reset_path="/sys/block/zram0/reset"
    if [ -f "$reset_path" ]; then
        if echo 1 > "$reset_path" 2>/dev/null; then
            log_zram_step "Step D (Reset ZRAM)" "OK" "Successfully reset zram0"
        else
            log_zram_step "Step D (Reset ZRAM)" "ERR" "Failed to write 1 to $reset_path"
            swapon "$swap_dev" 2>/dev/null
            return 0
        fi
    else
        log_zram_step "Step D (Reset ZRAM)" "ERR" "Reset path $reset_path not found"
        swapon "$swap_dev" 2>/dev/null
        return 0
    fi

    local comp_path="/sys/block/zram0/comp_algorithm"
    if [ -f "$comp_path" ]; then
        if echo lz4 > "$comp_path" 2>/dev/null; then
            log_zram_step "Step E (Set Algorithm)" "OK" "Successfully changed algorithm to lz4"
        else
            log_zram_step "Step E (Set Algorithm)" "ERR" "Failed to write lz4 to $comp_path"
            echo "$original_disksize" > "$disksize_path" 2>/dev/null
            mkswap "$swap_dev" >/dev/null 2>&1
            swapon "$swap_dev" 2>/dev/null
            return 0
        fi
    else
        log_zram_step "Step E (Set Algorithm)" "ERR" "Comp algorithm path $comp_path not found"
        echo "$original_disksize" > "$disksize_path" 2>/dev/null
        mkswap "$swap_dev" >/dev/null 2>&1
        swapon "$swap_dev" 2>/dev/null
        return 0
    fi

    if echo "$original_disksize" > "$disksize_path" 2>/dev/null; then
        log_zram_step "Step F (Restore disksize)" "OK" "Restored disksize to $original_disksize"
    else
        log_zram_step "Step F (Restore disksize)" "ERR" "Failed to write $original_disksize to $disksize_path"
        return 0
    fi

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
}

run_post_fs_data
