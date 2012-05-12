#!/system/xbin/busybox sh
#
# this starts the initscript processing and writes log messages
# and/or error messages for debugging of kernel initscripts or
# user/init.d-scripts.
#

# set busybox location
BB="/system/xbin/busybox"

# backup and clean logfile
$BB cp /data/user.log /data/last_user.log
$BB rm /data/user.log

# start logging
exec >>/data/user.log
exec 2>&1

# init some device lists
MTD=`$BB ls -d /sys/block/mtdblock*`
LOOP=`$BB ls -d /sys/block/loop*`
MMC=`$BB ls -d /sys/block/mmc*`
    
# start logfile output
echo
echo "************************************************"
echo "MIDNIGHT-ICS BOOT LOG"
echo "************************************************"
echo
echo "$(date)"
echo
# log basic system information
echo -n "Kernel: ";$BB uname -r
echo -n "PATH: ";echo $PATH
echo -n "ROM: ";cat /system/build.prop|$BB grep ro.build.display.id
echo -n "BusyBox:";$BB|$BB grep BusyBox

if $BB [ -f /boot.txt ];then
    echo;echo "----------------------------------------"
    echo;echo "$(date) init bootlog"
    cat /boot.txt
    echo;echo "----------------------------------------"
fi

echo;echo "$(date) modules"
ls -l /system/lib/modules

echo;echo "$(date) modules loaded"
$BB lsmod
echo

# print file contents <string messagetext><file output>
cat_msg_sysfile() {
    MSG=$1
    SYSFILE=$2
    echo -n "$MSG"
    cat $SYSFILE
}

# partitions
echo; echo "$(date) mount"
for i in $($BB mount | $BB grep relatime | $BB cut -d " " -f3);do
    busybox mount -o remount,noatime $i
done
mount

CONFFILE="midnight_options.conf"
echo; echo "$(date) $CONFFILE"
if $BB [ -f /data/local/$CONFFILE ];then

    # set cpu max freq
    if $BB [ "`/system/xbin/busybox grep OC1128 /data/local/$CONFFILE`" ]; then
        echo "oc1128 found, setting..."
        echo 1 > /sys/devices/virtual/misc/midnight_cpufreq/oc_enable
        echo 1128000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    else
        echo "oc1128 not selected, using 1Ghz max..."
        echo 1000000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    fi

    # set 800Mhz maxfreq if desired
    if $BB [ "`/system/xbin/busybox grep MAX800 /data/local/$CONFFILE`" ]; then
        echo "max800 found, setting..."
        echo 800000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    fi

    # set cpu governor
    if $BB [ "`/system/xbin/busybox grep ONDEMAND /data/local/$CONFFILE`" ]; then
        echo "ONDEMAND found, setting..."
        echo "ondemand" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    fi

    # sdcard read_ahead
    if $BB [ "`/system/xbin/busybox grep 512 /data/local/$CONFFILE`" ]; then
        echo "readahead 512Kb found, setting..."
        echo 512 > /sys/devices/virtual/bdi/179:0/read_ahead_kb
        echo 512 > /sys/devices/virtual/bdi/179:8/read_ahead_kb
    fi

    # IO scheduler
    if $BB [ "`/system/xbin/busybox grep NOOP /data/local/$CONFFILE`" ]; then
        echo "NOOP scheduler found, setting..."
        for i in $MTD $MMC $LOOP;do
            echo "$iosched" > $i/queue/scheduler
        done
    fi

    # touch_wake
    if $BB [ "`/system/xbin/busybox grep TOUCHWAKE /data/local/$CONFFILE`" ]; then
        echo "touchwake found, setting..."
        echo 1 > /sys/class/misc/touchwake/enabled
    fi

else
    echo "/data/local/$CONFFILE not found, skipping..."
fi

# load cpufreq_stats module after oc has been en-/disabled
sleep 1
$BB insmod /system/lib/modules/cpufreq_stats.ko

CONFFILE="midnight_uv.conf"
echo; echo "$(date) $CONFFILE"
if $BB [ -f /data/local/$CONFFILE ];then
    # set uv values
    if $BB [ "`/system/xbin/busybox grep UV1 /data/local/$CONFFILE`" ]; then
        echo "UV1 found, setting..."
        echo "0 0 25 50 75" > /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table
    elif $BB [ "`/system/xbin/busybox grep UV2 /data/local/$CONFFILE`" ]; then
        echo "UV2 found, setting..."
        echo "0 0 25 75 100" > /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table
    elif $BB [ "`/system/xbin/busybox grep UV3 /data/local/$CONFFILE`" ]; then
        echo "UV3 found, setting..."
        echo "0 0 50 75 125" > /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table
    else
        echo "using default values (no undervolting)..."
    fi
else
    echo "/data/local/$CONFFILE not found, skipping..."
fi

CONFFILE="midnight_vibration.conf"
echo; echo "$(date) $CONFFILE"
if $BB [ -f /data/local/$CONFFILE ];then
    # set uv values
    if $BB [ "`/system/xbin/busybox grep VIB0 /data/local/$CONFFILE`" ]; then
        echo "VIB0 found, setting..."
        echo 20000 > /sys/class/timed_output/vibrator/duty
    elif $BB [ "`/system/xbin/busybox grep VIB1 /data/local/$CONFFILE`" ]; then
        echo "VIB1 found, setting..."
        echo 25000 > /sys/class/timed_output/vibrator/duty
    elif $BB [ "`/system/xbin/busybox grep VIB2 /data/local/$CONFFILE`" ]; then
        echo "VIB2 found, setting..."
        echo 30000 > /sys/class/timed_output/vibrator/duty
    elif $BB [ "`/system/xbin/busybox grep VIB3 /data/local/$CONFFILE`" ]; then
        echo "VIB3 found, setting..."
        echo 35000 > /sys/class/timed_output/vibrator/duty
    else
        echo "using default value..."
    fi
else
    echo "/data/local/$CONFFILE not found, skipping..."
fi

# debug output
cat_msg_sysfile "max           : " /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
cat_msg_sysfile "gov           : " /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat_msg_sysfile "UV_mv         : " /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table
cat_msg_sysfile "states_enabled: " /sys/devices/system/cpu/cpu0/cpufreq/states_enabled_table
echo
echo "freq/voltage  : ";cat /sys/devices/system/cpu/cpu0/cpufreq/frequency_voltage_table
echo
cat_msg_sysfile "/sys/class/timed_output/vibrator/duty: " /sys/class/timed_output/vibrator/duty 
cat_msg_sysfile "/sys/class/misc/touchwake/enabled: " /sys/class/misc/touchwake/enabled

#--------------------- GENERAL TWEAK SECTION --------------------

# vm tweaks
echo; echo "$(date) vm"
echo "0" > /proc/sys/vm/swappiness                   # Not really needed as no /swap used...
echo "1500" > /proc/sys/vm/dirty_writeback_centisecs # Flush after 20sec. (o:500)
echo "1500" > /proc/sys/vm/dirty_expire_centisecs    # Pages expire after 20sec. (o:200)
echo "5" > /proc/sys/vm/dirty_background_ratio       # flush pages later (default 5% active mem)
echo "15" > /proc/sys/vm/dirty_ratio                 # process writes pages later (default 20%)  
echo "3" > /proc/sys/vm/page-cluster
echo "0" > /proc/sys/vm/laptop_mode
echo "0" > /proc/sys/vm/oom_kill_allocating_task
echo "0" > /proc/sys/vm/panic_on_oom
echo "1" > /proc/sys/vm/overcommit_memory
cat_msg_sysfile "swappiness: " /proc/sys/vm/swappiness                   
cat_msg_sysfile "dirty_writeback_centisecs: " /proc/sys/vm/dirty_writeback_centisecs
cat_msg_sysfile "dirty_expire_centisecs: " /proc/sys/vm/dirty_expire_centisecs    
cat_msg_sysfile "dirty_background_ratio: " /proc/sys/vm/dirty_background_ratio
cat_msg_sysfile "dirty_ratio: " /proc/sys/vm/dirty_ratio 
cat_msg_sysfile "page-cluster: " /proc/sys/vm/page-cluster
cat_msg_sysfile "laptop_mode: " /proc/sys/vm/laptop_mode
cat_msg_sysfile "oom_kill_allocating_task: " /proc/sys/vm/oom_kill_allocating_task
cat_msg_sysfile "panic_on_oom: " /proc/sys/vm/panic_on_oom
cat_msg_sysfile "overcommit_memory: " /proc/sys/vm/overcommit_memory

# security enhancements
# rp_filter must be reset to 0 if TUN module is used (issues)
echo; echo "$(date) sec"
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 2 > /proc/sys/net/ipv6/conf/all/use_tempaddr
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo -n "SEC: ip_forward :";cat /proc/sys/net/ipv4/ip_forward
echo -n "SEC: rp_filter :";cat /proc/sys/net/ipv4/conf/all/rp_filter
echo -n "SEC: use_tempaddr :";cat /proc/sys/net/ipv6/conf/all/use_tempaddr
echo -n "SEC: accept_source_route :";cat /proc/sys/net/ipv4/conf/all/accept_source_route
echo -n "SEC: send_redirects :";cat /proc/sys/net/ipv4/conf/all/send_redirects
echo -n "SEC: icmp_echo_ignore_broadcasts :";cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts 

# setprop tweaks
echo; echo "$(date) prop"
setprop wifi.supplicant_scan_interval 180
echo -n "wifi.supplicant_scan_interval (is this actually used?): ";getprop wifi.supplicant_scan_interval

# kernel tweaks
echo; echo "$(date) kernel"
echo "NO_GENTLE_FAIR_SLEEPERS" > /sys/kernel/debug/sched_features
echo 500 512000 64 2048 > /proc/sys/kernel/sem 
echo 3000000 > /proc/sys/kernel/sched_latency_ns
echo 500000 > /proc/sys/kernel/sched_wakeup_granularity_ns
echo 500000 > /proc/sys/kernel/sched_min_granularity_ns
echo 0 > /proc/sys/kernel/panic_on_oops
echo 0 > /proc/sys/kernel/panic
cat_msg_sysfile "sched_features: " /sys/kernel/debug/sched_features
cat_msg_sysfile "sem: " /proc/sys/kernel/sem; 
cat_msg_sysfile "sched_latency_ns: " /proc/sys/kernel/sched_latency_ns
cat_msg_sysfile "sched_wakeup_granularity_ns: " /proc/sys/kernel/sched_wakeup_granularity_ns
cat_msg_sysfile "sched_min_granularity_ns: " /proc/sys/kernel/sched_min_granularity_ns
cat_msg_sysfile "panic_on_oops: " /proc/sys/kernel/panic_on_oops
cat_msg_sysfile "panic: " /proc/sys/kernel/panic

# set sdcard read_ahead
echo; echo "$(date) read_ahead_kb"
cat_msg_sysfile "default: " /sys/devices/virtual/bdi/default/read_ahead_kb
cat_msg_sysfile "179.0: " /sys/devices/virtual/bdi/179:0/read_ahead_kb
cat_msg_sysfile "179.8: " /sys/devices/virtual/bdi/179:8/read_ahead_kb

# small fs read_ahead
echo 16 > /sys/block/mtdblock2/queue/read_ahead_kb # system
echo 16 > /sys/block/mtdblock3/queue/read_ahead_kb # cache
echo 64 > /sys/block/mtdblock6/queue/read_ahead_kb # datadata

echo; echo "$(date) io"    
# general IO tweaks
for i in $MTD $MMC $LOOP;do
    echo 0 > $i/queue/rotational
    echo 0 > $i/queue/iostats
done

# mtd/mmc only tweaks
for i in $MTD $MMC;do
    echo 1024 > $i/queue/nr_requests
done

# log output
for i in $MTD $MMC $LOOP $RAM;do
    cat_msg_sysfile "$i/queue/scheduler: " $i/queue/scheduler
    cat_msg_sysfile "$i/queue/rotational: " $i/queue/rotational
    cat_msg_sysfile "$i/queue/iostats: " $i/queue/iostats
    cat_msg_sysfile "$i/queue/read_ahead_kb: " $i/queue/read_ahead_kb
    cat_msg_sysfile "$i/queue/rq_affinity: " $i/queue/rq_affinity   
    cat_msg_sysfile "$i/queue/nr_requests: " $i/queue/nr_requests
    echo
done

#--------------------- INITSCRIPT SECTION --------------------

# init.d support, executes all /system/etc/init.d/<S>scriptname files
echo;echo "$(date) init.d/userinit.d"
CONFFILE="midnight_options.conf"
if $BB [ -f /data/local/$CONFFILE ];then
    echo "configfile /data/local/midnight_options.conf found, checking values..."
    if $BB [ "`/system/xbin/busybox grep INITD /data/local/$CONFFILE`" ]; then
        echo $(date) USER INIT START from /system/etc/init.d
        if cd /system/etc/init.d >/dev/null 2>&1 ; then
            for file in S* ; do
                if ! ls "$file" >/dev/null 2>&1 ; then continue ; fi
                echo "/system/etc/init.d: START '$file'"
                /system/bin/sh "$file"
                echo "/system/etc/init.d: EXIT '$file' ($?)"
            done
        fi
        echo $(date) USER INIT DONE from /system/etc/init.d
        echo $(date) USER INIT START from /data/local/userinit.d
        if cd /data/local/userinit.d >/dev/null 2>&1 ; then
            for file in S* ; do
                if ! ls "$file" >/dev/null 2>&1 ; then continue ; fi
                echo "/data/local/userinit.d: START '$file'"
                /system/bin/sh "$file"
                echo "/data/local/userinit.d: EXIT '$file' ($?)"
            done
        fi
        echo $(date) USER INIT DONE from /data/local/userinit.d
    else
        echo "init.d execution deactivated, nothing to do."
    fi
else
    echo "/data/local/midnight_options.conf not found, no init.d execution, skipping..."
fi

