#!/system/bin/sh
# s23 performance tweaks - service.sh
# applies kernel/subsystem optimizations post-boot for sm-s911b
# author: dyokism

# shellcheck disable=SC3043

MODDIR=${0%/*}

# initialize/clear log on boot
> "$MODDIR/tweak.log"

# device guard
MODEL=$(getprop ro.product.model)
case "$MODEL" in
    SM-S911*)
        # correct model, continue execution
        ;;
    *)
        # mismatch, log and abort silently
        timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[$timestamp] [ERROR] Device guard triggered. Model mismatch: '$MODEL'. Expected SM-S911*. Aborting tweaks." >> "$MODDIR/tweak.log"
        exit 0
        ;;
esac

# safe write function
write_value() {
    local path="$1"
    local value="$2"
    local timestamp_val
    timestamp_val=${TIMESTAMP:-$(date "+%Y-%m-%d %H:%M:%S")}
    
    if [ ! -e "$path" ]; then
        echo "[$timestamp_val] [SKIP] Path does not exist: $path" >> "$MODDIR/tweak.log"
        return 0
    fi
    
    if echo "$value" > "$path" 2>/dev/null; then
        echo "[$timestamp_val] [OK] Wrote '$value' to $path" >> "$MODDIR/tweak.log"
    else
        echo "[$timestamp_val] [ERR] Failed to write '$value' to $path" >> "$MODDIR/tweak.log"
    fi
}

# safe write window polling
wait_for_boot() {
    local timeout=480
    local elapsed=0

    while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
        if [ "$elapsed" -ge "$timeout" ]; then
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [ERROR] Boot completion timeout reached (${elapsed}s)." >> "$MODDIR/tweak.log"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] Boot completed. Sleeping 90 seconds to survive init.kernel.post_boot-kalama.sh resets..." >> "$MODDIR/tweak.log"
    sleep 90
    return 0
}


# tweak applications
apply_tweaks() {
    local TIMESTAMP
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] [INFO] Applying optimization tweaks..." >> "$MODDIR/tweak.log"

    # cpu walt tuning
    write_value "/sys/devices/system/cpu/cpufreq/policy0/walt/hispeed_load" "85"
    write_value "/sys/devices/system/cpu/cpufreq/policy3/walt/hispeed_load" "85"
    write_value "/sys/devices/system/cpu/cpufreq/policy7/walt/hispeed_load" "85"
    write_value "/sys/devices/system/cpu/cpufreq/policy0/walt/up_rate_limit_us" "500"
    write_value "/sys/devices/system/cpu/cpufreq/policy3/walt/up_rate_limit_us" "500"
    write_value "/sys/devices/system/cpu/cpufreq/policy7/walt/up_rate_limit_us" "1000"
    write_value "/sys/devices/system/cpu/cpufreq/policy0/walt/down_rate_limit_us" "20000"
    write_value "/sys/devices/system/cpu/cpufreq/policy3/walt/down_rate_limit_us" "20000"
    write_value "/sys/devices/system/cpu/cpufreq/policy7/walt/down_rate_limit_us" "20000"

    # virtual memory tuning
    write_value "/proc/sys/vm/swappiness" "80"
    write_value "/proc/sys/vm/dirty_bytes" "157286400"
    write_value "/proc/sys/vm/dirty_background_bytes" "52428800"
    write_value "/proc/sys/vm/dirty_expire_centisecs" "500"
    write_value "/proc/sys/vm/dirty_writeback_centisecs" "1000"

    # i/o queue tweaks
    local dev
    for dev in sda sdb sdc sdd sde sdf; do
        local sched_path="/sys/block/${dev}/queue/scheduler"
        if [ -f "$sched_path" ]; then
            local avail
            read -r avail < "$sched_path"
            case "$avail" in
                *none*)
                    write_value "$sched_path" "none"
                    ;;
                *)
                    echo "[$TIMESTAMP] [SKIP] 'none' scheduler not available for $dev (available: $avail)" >> "$MODDIR/tweak.log"
                    ;;
            esac
        fi
        write_value "/sys/block/${dev}/queue/read_ahead_kb" "256"
        
        # read active scheduler to safely assign queue depth limits (hardware max is 32 for none)
        local active_sched=""
        if [ -f "$sched_path" ]; then
            read -r active_sched < "$sched_path"
        fi
        case "$active_sched" in
            *"[none]"*)
                write_value "/sys/block/${dev}/queue/nr_requests" "31"
                ;;
            *)
                write_value "/sys/block/${dev}/queue/nr_requests" "128"
                ;;
        esac
    done

    # network tuning
    write_value "/proc/sys/net/ipv4/tcp_fastopen" "3"

    # gpu tuning
    write_value "/sys/class/kgsl/kgsl-3d0/devfreq/min_freq" "295000000"

    # kernel misc tuning
    write_value "/proc/sys/kernel/perf_cpu_time_max_percent" "10"

    local end_timestamp
    end_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$end_timestamp] [INFO] Optimization tweaks completed." >> "$MODDIR/tweak.log"
}

# execution pipeline
wait_for_boot && apply_tweaks
