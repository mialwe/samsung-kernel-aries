#!/system/xbin/busybox sh

/sbin/busybox cp /data/user.log /data/user.log.bak
/sbin/busybox rm /data/user.log
exec >>/data/user.log
exec 2>&1

# say hello :)
echo
echo "************************************************"
echo "MNCM7 BOOTSCRIPT LOG"
echo "************************************************"
echo
echo -n "Kernel: ";uname -r
echo -n "PATH: ";echo $PATH
echo -n "ROM: ";cat /system/build.prop|grep ro.build.display.id
echo

# set busybox location
BB="/system/xbin/busybox"

cat_msg_sysfile() {
    MSG=$1
    SYSFILE=$2
    echo -n "$MSG"
    cat $SYSFILE
}

$BB mount -t rootfs -o remount,rw rootfs

#-------------------------------------------------------------------------------
# partitions
#-------------------------------------------------------------------------------
echo "$(date) mount"
for k in $($BB mount | $BB grep relatime | $BB cut -d " " -f3)
do
    sync
    $BB mount -o remount,noatime,nodiratime $k
done

$BB mount|grep /system
$BB mount|grep /data
$BB mount|grep /dbdata
$BB mount|grep /cache

echo;echo "modules:"
$BB lsmod

#-------------------------------------------------------------------------------
# cpu
#-------------------------------------------------------------------------------
cat_msg_sysfile "max           : " /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
cat_msg_sysfile "gov           : " /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat_msg_sysfile "UV_mv         : " /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table
cat_msg_sysfile "states_enabled: " /sys/devices/system/cpu/cpu0/cpufreq/states_enabled_table
echo
echo "freq/voltage  : ";cat /sys/devices/system/cpu/cpu0/cpufreq/frequency_voltage_table
echo

#-------------------------------------------------------------------------------
# touchwake
#-------------------------------------------------------------------------------
cat_msg_sysfile "/sys/class/misc/touchwake/enabled: " /sys/class/misc/touchwake/enabled

#-------------------------------------------------------------------------------
# vm tweaks
#-------------------------------------------------------------------------------
echo; echo "$(date) vm"
echo "0" > /proc/sys/vm/swappiness                   # Not really needed as no /swap used...
echo "1500" > /proc/sys/vm/dirty_writeback_centisecs # Flush after 20sec. (o:500)
echo "1500" > /proc/sys/vm/dirty_expire_centisecs    # Pages expire after 20sec. (o:200)
echo "5" > /proc/sys/vm/dirty_background_ratio      # flush pages later (default 5% active mem)
echo "15" > /proc/sys/vm/dirty_ratio                 # process writes pages later (default 20%)
echo "3" > /proc/sys/vm/page-cluster
echo "0" > /proc/sys/vm/laptop_mode
echo "0" > /proc/sys/vm/oom_kill_allocating_task
echo "0" > /proc/sys/vm/panic_on_oom
echo "0" > /proc/sys/vm/overcommit_memory
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

#-------------------------------------------------------------------------------
# security
#-------------------------------------------------------------------------------
echo; echo "$(date) sec"
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 2 > /proc/sys/net/ipv6/conf/all/use_tempaddr
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
cat_msg_sysfile "SEC: ip_forward :" /proc/sys/net/ipv4/ip_forward
cat_msg_sysfile "SEC: rp_filter :" /proc/sys/net/ipv4/conf/all/rp_filter
cat_msg_sysfile "SEC: use_tempaddr :" /proc/sys/net/ipv6/conf/all/use_tempaddr
cat_msg_sysfile "SEC: accept_source_route :" /proc/sys/net/ipv4/conf/all/accept_source_route
cat_msg_sysfile "SEC: send_redirects :" /proc/sys/net/ipv4/conf/all/send_redirects
cat_msg_sysfile "SEC: icmp_echo_ignore_broadcasts :" /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts 

#-------------------------------------------------------------------------------
# IPv4/TCP
#-------------------------------------------------------------------------------
echo; echo "$(date) ipv4/tcp"
echo "TCP: setting ipv4/tcp tweaks..."
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
echo 1 > /proc/sys/net/ipv4/tcp_sack
echo 1 > /proc/sys/net/ipv4/tcp_dsack
echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle
echo 1 > /proc/sys/net/ipv4/tcp_window_scaling
echo 5 > /proc/sys/net/ipv4/tcp_keepalive_probes
echo 30 > /proc/sys/net/ipv4/tcp_keepalive_intvl
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout
echo 0 > /proc/sys/net/ipv4/tcp_timestamps

#-------------------------------------------------------------------------------
# setprop tweaks
#-------------------------------------------------------------------------------
echo; echo "$(date) prop"
setprop wifi.supplicant_scan_interval 180
setprop windowsmgr.max_events_per_sec 76;
setprop ro.ril.disable.power.collapse 1;
setprop ro.telephony.call_ring.delay 1000;
setprop mot.proximity.delay 150;
setprop ro.mot.eri.losalert.delay 1000;

echo -n "PROP: wifi.supplicant_scan_interval: ";getprop wifi.supplicant_scan_interval
echo -n "PROP: windowsmgr.max_events_per_sec: ";getprop windowsmgr.max_events_per_sec
echo -n "PROP: ro.ril.disable.power.collapse: ";getprop ro.ril.disable.power.collapse
echo -n "PROP: ro.telephony.call_ring.delay: ";getprop ro.telephony.call_ring.delay
echo -n "PROP: mot.proximity.delay: ";getprop mot.proximity.delay
echo -n "PROP: ro.mot.eri.losalert.delay: ";getprop ro.mot.eri.losalert.delay

#-------------------------------------------------------------------------------
# kernel tweaks
#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
# IO/read_ahead
#-------------------------------------------------------------------------------
echo 256 > /sys/devices/virtual/bdi/179:0/read_ahead_kb
echo 256 > /sys/devices/virtual/bdi/179:8/read_ahead_kb
cat_msg_sysfile "179.0: " /sys/devices/virtual/bdi/179:0/read_ahead_kb
cat_msg_sysfile "179.8: " /sys/devices/virtual/bdi/179:8/read_ahead_kb

# small fs read_ahead
echo 16 > /sys/block/mtdblock2/queue/read_ahead_kb # system
echo 16 > /sys/block/mtdblock3/queue/read_ahead_kb # cache
echo 64 > /sys/block/mtdblock6/queue/read_ahead_kb # datadata

#MTD=`$BB ls -d /sys/block/mtdblock*`
#LOOP=`$BB ls -d /sys/block/loop*`
#MMC=`$BB ls -d /sys/block/mmc*`

#for i in $MTD $MMC $LOOP;do
    #echo 0 > $i/queue/rotational
    #echo 0 > $i/queue/iostats
#done

#-------------------------------------------------------------------------------
# mem info
#-------------------------------------------------------------------------------
echo   
echo "RAM (/proc/meminfo):"
cat /proc/meminfo|grep ^MemTotal
cat /proc/meminfo|grep ^MemFree
cat /proc/meminfo|grep ^Buffers
cat /proc/meminfo|grep ^Cached

#-------------------------------------------------------------------------------
# init.d support, executes all /system/etc/init.d/<S>scriptname files
#-------------------------------------------------------------------------------
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

# fin
echo "mounting rootfs readonly..."
$BB mount -t rootfs -o remount,ro rootfs;

read sync < /data/sync_fifo
rm /data/sync_fifo
