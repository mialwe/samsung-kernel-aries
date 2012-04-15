#!/system/xbin/busybox sh
#
# this starts the initscript processing and writes log messages
# and/or error messages for debugging of kernel initscripts or
# user/init.d-scripts.
#

# set busybox location
BB="/system/xbin/busybox"

# backup and clean logfile
$BB cp /data/user.log /data/user.log.bak
$BB rm /data/user.log

# start logging
exec >>/data/user.log
exec 2>&1

# start logfile output
echo
echo "************************************************"
echo "MIDNIGHT-ICS BOOT LOG"
echo "************************************************"
echo

# log basic system information
echo -n "Kernel: ";$BB uname -r
echo -n "PATH: ";echo $PATH
echo -n "ROM: ";cat /system/build.prop|$BB grep ro.build.display.id
echo -n "BusyBox:";$BB|$BB grep BusyBox
echo

# print file contents <string messagetext><file output>
cat_msg_sysfile() {
    MSG=$1
    SYSFILE=$2
    echo -n "$MSG"
    cat $SYSFILE
}

#initialize cpu
uv100=0;uv200=0;uv400=0;uv800=0;uv1000=0;cpumax=1000000;

# app settings parsing
# this gets all values directly from the app shared_prefs file, no need for
# other config files.
if $BB [ ! -f /cache/midnight_block ];then
    echo "APP: no blocker file present, proceeding..."
    xmlfile="/data/data/com.mialwe.midnight.control/shared_prefs/com.mialwe.midnight.control_preferences.xml"
    echo "APP: checking app preferences..."
    if $BB [ -f $xmlfile ];then
        echo "APP: preferences file found, parsing..."
        sched=`$BB sed -n 's|<string name=\"midnight_io\">\(.*\)</string>|\1|p' $xmlfile`
        limit800=`$BB awk -F"\"" ' /c_toggle_800\"/ {print $4}' $xmlfile`
        cpugov=`$BB sed -n 's|<string name=\"midnight_cpu_gov\">\(.*\)</string>|\1|p' $xmlfile`
        uvatboot=`$BB awk -F"\"" ' /c_toggle_uv_boot\"/ {print $4}' $xmlfile`
        uv1000=`$BB awk -F"\"" ' /uv_1000\"/ {print $4}' $xmlfile`;
        uv800=`$BB awk -F"\"" ' /uv_800\"/ {print $4}' $xmlfile`;
        uv400=`$BB awk -F"\"" ' /uv_400\"/ {print $4}' $xmlfile`;
        uv200=`$BB awk -F"\"" ' /uv_200\"/ {print $4}' $xmlfile`;
        uv100=`$BB awk -F"\"" ' /uv_100\"/ {print $4}' $xmlfile`;
        vibration_intensity=`$BB awk -F"\"" ' /vibration_intensity\"/ {print $4}' $xmlfile`
        touchwake=`$BB awk -F"\"" ' /touchwake\"/ {print $4}' $xmlfile`
        touchwake_timeout=`$BB awk -F"\"" ' /touchwake_timeout\"/ {print $4}' $xmlfile`
        echo "APP: IO sched -> $sched"
        echo "APP: limit800 -> $limit800"
        echo "APP: cpugov -> $cpugov"
        echo "APP: uv at boot -> $uvatboot"
        echo "APP: uv1000 -> $uv1000"
        echo "APP: uv800  -> $uv800"
        echo "APP: uv400  -> $uv400"
        echo "APP: uv200  -> $uv200"
        echo "APP: uv100  -> $uv100"
        echo "APP: vibration intensity -> $vibration_intensity"
        echo "APP: touchwake -> $touchwake"
        echo "APP: touchwake timeout-> $touchwake_timeout"
    else
        echo "APP: preferences file not found."
    fi
else
    echo "APP: blocker file found, not processing MidnightControl settings..."
    echo "APP: removing blocker file..."
    rm /cache/midnight_block
fi

# partitions
echo; echo "mount"
for i in $($BB mount | $BB grep relatime | $BB cut -d " " -f3);do
    busybox mount -o remount,noatime $i
done
mount

# set cpu max freq
echo; echo "cpu"

#testing
CONFFILE="midnight_options.conf"
if $BB [ -f /data/local/$CONFFILE ];then
    echo "configfile /data/local/midnight_options.conf found, checking values..."
    if $BB [ "`/system/xbin/busybox grep OC1128 /data/local/$CONFFILE`" ]; then
        echo "oc1128 found, setting..."
        echo 1 > /sys/devices/virtual/misc/midnight_cpufreq/oc_enable
        echo 1128000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    else
        echo "oc1128 not selected, using 1Ghz max..."
        echo 1000000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    fi
else
    echo "/data/local/midnight_options.conf not found, using 1Ghz max..."
    echo 1000000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
fi

sleep 1
$BB insmod /system/lib/modules/cpufreq_stats.ko

if $BB [ "$limit800" == "true" ];then
    echo "found 800Mhz limit, activating..."
    echo 800000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
else
    echo "800Mhz limit deactivated, skipping..."
fi

# set cpu governor
if $BB [[ "$cpugov" == "ondemand" || "$cpugov" == "conservative" || "$cpugov" == "smartassV2" ]];then
    echo "CPU: found vaild cpugov: <$cpugov>"
    echo $cpugov > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
fi

# parse undervolting
if $BB [ ! -f /cache/midnight_block ];then
    if $BB [ "$uv1000" -lt 0 ];then uv1000=$(($uv1000*(-1)));else uv1000=0;fi
    if $BB [ "$uv800" -lt 0 ];then uv800=$(($uv800*(-1)));else uv800=0;fi
    if $BB [ "$uv400" -lt 0 ];then uv400=$(($uv400*(-1)));else uv400=0;fi
    if $BB [ "$uv200" -lt 0 ];then uv200=$(($uv200*(-1)));else uv200=0;fi
    if $BB [ "$uv100" -lt 0 ];then uv100=$(($uv100*(-1)));else uv100=0;fi
fi

# set undervolting
echo "CPU: values after parsing: $uv1000, $uv800, $uv400, $uv200, $uv100"
if $BB [ "$uvatboot" == "true" ];then
    echo "CPU: UV at boot enabled, setting values now..."
    echo $uv1000 $uv800 $uv400 $uv200 $uv100 > /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table
fi

# debug output
cat_msg_sysfile "max           : " /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
cat_msg_sysfile "gov           : " /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat_msg_sysfile "UV_mv         : " /sys/devices/system/cpu/cpu0/cpufreq/UV_mV_table
cat_msg_sysfile "states_enabled: " /sys/devices/system/cpu/cpu0/cpufreq/states_enabled_table
echo
echo "freq/voltage  : ";cat /sys/devices/system/cpu/cpu0/cpufreq/frequency_voltage_table

# vm tweaks
echo; echo "vm"
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
echo; echo "sec"
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
echo; echo "prop"
setprop wifi.supplicant_scan_interval 180
echo -n "wifi.supplicant_scan_interval (is this actually used?): ";getprop wifi.supplicant_scan_interval

# kernel tweaks
echo; echo "kernel"
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
echo; echo "read_ahead_kb"
readahead=256
echo $readahead > /sys/devices/virtual/bdi/179:0/read_ahead_kb
echo $readahead > /sys/devices/virtual/bdi/179:8/read_ahead_kb
cat_msg_sysfile "179.0: " /sys/devices/virtual/bdi/179:0/read_ahead_kb
cat_msg_sysfile "179.8: " /sys/devices/virtual/bdi/179:8/read_ahead_kb

# small fs read_ahead
echo 16 > /sys/block/mtdblock2/queue/read_ahead_kb # system
echo 16 > /sys/block/mtdblock3/queue/read_ahead_kb # cache
echo 64 > /sys/block/mtdblock6/queue/read_ahead_kb # datadata

echo; echo "io"
MTD=`$BB ls -d /sys/block/mtdblock*`
LOOP=`$BB ls -d /sys/block/loop*`
MMC=`$BB ls -d /sys/block/mmc*`

# set IO scheduler    
if $BB [[ "$sched" == "noop" || "$sched" == "sio" ]];then
    iosched=$sched    
    echo "IO: found valid IO scheduler <$iosched>..."
else
    iosched="sio"    
fi        

# general IO tweaks
for i in $MTD $MMC $LOOP;do
    echo "$iosched" > $i/queue/scheduler
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

# set vibration intensity
echo;echo "vibration intensity"
if $BB [ ! -z $vibration_intensity ];then
    echo "found sensitivity value, setting..."
    echo $vibration_intensity > /sys/class/timed_output/vibrator/duty
    cat_msg_sysfile "/sys/class/timed_output/vibrator/duty: " /sys/class/timed_output/vibrator/duty 
else
    echo "deactivated, nothing to do..."
fi

# enable touchwake
echo;echo "touchwake"
if $BB [ "$touchwake" == "true" ];then
    echo "found setting, activating touchwake..."
    echo 1 > /sys/class/misc/touchwake/enabled
    cat_msg_sysfile "/sys/class/misc/touchwake/enabled: " /sys/class/misc/touchwake/enabled
else
    echo "deactivated, nothing to do..."
fi

# debug output BLN
echo;echo "bln"
cat_msg_sysfile "/sys/class/misc/backlightnotification/enabled: " /sys/class/misc/backlightnotification/enabled

# init.d support, executes all /system/etc/init.d/<S>scriptname files
echo; echo "init.d"
echo "creating /system/etc/init.d..."
$BB mount -o remount,rw /system
$BB mkdir -p /system/etc/init.d
$BB mount -o remount,ro /system

CONFFILE="midnight_options.conf"
if $BB [ -f /data/local/$CONFFILE ];then
    echo "configfile /data/local/midnight_options.conf found, checking values..."
    if $BB [ "`/system/xbin/busybox grep INITD /data/local/$CONFFILE`" ]; then
        echo "starting init.d script execution..."
        echo $(date) USER INIT START from /system/etc/init.d
        if cd /system/etc/init.d >/dev/null 2>&1 ; then
            for file in S* ; do
                if ! ls "$file" >/dev/null 2>&1 ; then continue ; fi
                echo "init.d: START '$file'"
                /system/bin/sh "$file"
                echo "init.d: EXIT '$file' ($?)"
            done
        fi
        echo $(date) USER INIT DONE from /system/etc/init.d
    else
        echo "init.d execution deactivated, nothing to do."
    fi
else
    echo "/data/local/midnight_options.conf not found, no init.d execution, skipping..."
fi

