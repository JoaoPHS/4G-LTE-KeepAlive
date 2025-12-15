#!/bin/sh
# 4G-LTE-KeepAlive: Automatic 4G connection monitoring and recovery via QMI/MBIM

. /lib/functions.sh
. /lib/functions/network.sh

CONFIG_FILE="/etc/config/lte-keepalive"
LOG_TAG="LTE-KA"
MAX_FAILED_CYCLES=3
PING_LOSS_THRESHOLD=60
PING_COUNT=10
PING_INTERVAL=5

load_config() {
	config_load lte-keepalive
	config_get enabled config enabled 1
	config_get ping_target config ping_target "8.8.8.8"
	config_get ping_count config ping_count "$PING_COUNT"
	config_get ping_interval config ping_interval "$PING_INTERVAL"
	config_get loss_threshold config loss_threshold "$PING_LOSS_THRESHOLD"
	config_get max_failed_cycles config max_failed_cycles "$MAX_FAILED_CYCLES"
	config_get qmi_device config qmi_device "/dev/cdc-wdm0"
	config_get apn config apn ""
	config_get username config username ""
	config_get password config password ""
	config_get pincode config pincode ""
}

log_msg() {
	logger -t "$LOG_TAG" "$1"
}

get_qmi_device() {
	local device="$1"
	if [ -z "$device" ] || [ ! -e "$device" ]; then
		for dev in /dev/cdc-wdm* /dev/qmi*; do
			if [ -e "$dev" ]; then
				echo "$dev"
				return 0
			fi
		done
		return 1
	fi
	echo "$device"
	return 0
}

check_ping_loss() {
	local target="$1"
	local count="$2"
	local loss=0
	local sent=0
	local received=0
	
	if [ -z "$target" ] || [ -z "$count" ]; then
		return 1
	fi
	
	local ping_output=$(ping -c "$count" -W 3 "$target" 2>/dev/null)
	
	if [ -z "$ping_output" ]; then
		echo "100"
		return 0
	fi
	
	received=$(echo "$ping_output" | grep -o '[0-9]* packets received' | grep -o '[0-9]*')
	sent=$(echo "$ping_output" | grep -o '[0-9]* packets transmitted' | grep -o '[0-9]*')
	
	if [ -z "$received" ] || [ -z "$sent" ] || [ "$sent" -eq 0 ]; then
		loss=$(echo "$ping_output" | grep -o '[0-9]*% packet loss' | grep -o '[0-9]*')
		if [ -z "$loss" ]; then
			loss=100
		fi
	else
		loss=$(( (sent - received) * 100 / sent ))
	fi
	
	echo "$loss"
	return 0
}

# Intermediate processing: QMI recovery functions and ping loss verification

reset_qmi() {
	local device="$1"
	local apn="$2"
	local username="$3"
	local password="$4"
	local pincode="$5"
	
	if [ -z "$device" ] || [ ! -e "$device" ]; then
		log_msg "ERROR: QMI device not found: $device"
		return 1
	fi
	
	log_msg "Resetting QMI interface: $device"
	
	if [ -n "$pincode" ]; then
		uqmi -d "$device" --set-pin-code "$pincode" 2>/dev/null
		sleep 2
	fi
	
	uqmi -d "$device" --stop-network 0xffffffff --autoconnect 2>/dev/null
	sleep 2
	
	if [ -n "$apn" ]; then
		if [ -n "$username" ] && [ -n "$password" ]; then
			uqmi -d "$device" --start-network "$apn" \
				--autoconnect \
				--username "$username" \
				--password "$password" 2>/dev/null
		else
			uqmi -d "$device" --start-network "$apn" \
				--autoconnect 2>/dev/null
		fi
	else
		uqmi -d "$device" --start-network --autoconnect 2>/dev/null
	fi
	
	sleep 5
	
	uqmi -d "$device" --get-current-settings 2>/dev/null | \
		grep -q "ipv4" && return 0
	
	return 1
}

main_loop() {
	local failed_cycles=0
	local cycle_count=0
	
	load_config
	
	if [ "$enabled" != "1" ]; then
		log_msg "Service disabled in config"
		exit 0
	fi
	
	local qmi_dev=$(get_qmi_device "$qmi_device")
	if [ -z "$qmi_dev" ]; then
		log_msg "ERROR: No QMI device found"
		exit 1
	fi
	
	log_msg "Starting LTE KeepAlive monitor"
	log_msg "QMI Device: $qmi_dev"
	log_msg "Ping Target: $ping_target"
	log_msg "Loss Threshold: ${loss_threshold}%"
	
	while true; do
		sleep "$ping_interval"
		
		cycle_count=$((cycle_count + 1))
		log_msg "Cycle $cycle_count: Checking connection..."
		
		local loss=$(check_ping_loss "$ping_target" "$ping_count")
		
		if [ -z "$loss" ]; then
			log_msg "ERROR: Failed to check ping loss"
			continue
		fi
		
		log_msg "Ping loss: ${loss}%"
		
		if [ "$loss" -ge "$loss_threshold" ]; then
			log_msg "WARNING: Ping loss ${loss}% exceeds threshold ${loss_threshold}%"
			log_msg "Attempting QMI recovery..."
			
			if reset_qmi "$qmi_dev" "$apn" "$username" "$password" "$pincode"; then
				log_msg "QMI recovery successful"
				failed_cycles=0
				sleep 10
			else
				failed_cycles=$((failed_cycles + 1))
				log_msg "QMI recovery failed (attempt $failed_cycles/$max_failed_cycles)"
				
				if [ "$failed_cycles" -ge "$max_failed_cycles" ]; then
					log_msg "CRITICAL: Max failed cycles reached. Rebooting router..."
					sleep 5
					reboot
				fi
			fi
		else
			failed_cycles=0
		fi
	done
}

# Finalization: Signal handling and main monitoring loop initialization

trap 'log_msg "Received termination signal, exiting..."; exit 0' TERM INT

main_loop
