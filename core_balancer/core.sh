#! /bin/bash

let ETH_COUNT=0
function get_ethernet_count() {
	ETH_COUNT=$(ls /sys/class/net/ | grep eth* | wc -l)
}

function is_cores_scheduler_set() {
	let error_found=0

	for (( eth_num=0; eth_num<ETH_COUNT; eth_num++ )); do
		eth_irq=$(cat /proc/interrupts | grep eth${eth_num} | cut -d ':' -f1 | xargs)
		if [ -z $eth_irq ]; then
			echo "${red}не найден IRQ в списке прерываний для существующего eth${eth_num}${normal}"
			exit -1
		fi

		mask_eth=$(cat /proc/irq/${eth_irq}/smp_affinity)
		if [ $eth_num -lt 3 ]; then
			if ! echo "$mask_eth" | grep -E "*000080$" > /dev/null; then
				((error_found++))
			fi

			continue
		fi

		if ! echo "$mask_eth" | grep -E "*800000$" > /dev/null; then
			((error_found++))
		fi
	done

	if [ $ETH_COUNT -lt 4 ]; then
		cmdline_isolcpus=$(cat /boot/boot.conf | grep "cmdline" | grep "isolcpus=7")
	else
		cmdline_isolcpus=$(cat /boot/boot.conf | grep "cmdline" | grep "isolcpus=7,23")
	fi

	if [ -z "$cmdline_isolcpus" ]; then
		((error_found++))
	fi

	if [ ! -f /etc/systemd/system/set-interrupts.service ]; then
		((error_found++))
	fi

	if [ ! -f /usr/local/set_interrupts.sh ]; then
		((error_found++))
	fi

	if [ $error_found -ne 0 ]; then
		return 1
	fi

	return 0
}

function clear_prev_cores_scheduler() {
	rm /usr/local/set_interrupts.sh 2>/dev/null
	rm /etc/systemd/system/set-interrupts.service 2>/dev/null
	sed -i -E 's! isolcpus[=0-9,]*!!' /boot/boot.conf

	systemctl daemon-reload
}

### return code 0 - возвращает событие, что настройка не потребовалась
### return code 1 - возвращает событие, что настройка произведена успешно
function set_up_cores_scheduler() {
	is_cores_scheduler_set
	local error_code=$?

	if [ $error_code -eq 1 ]; then
		clear_prev_cores_scheduler

		lines=$(cat /boot/boot.conf | grep -n -P '^(?!.*Recovery).*label' | cut -d ':' -f1 | xargs)

		OLD_IFS=$IFS
		IFS=$' '
		for line_num in $lines; do
			if [ $ETH_COUNT -lt 4 ]; then
				sed -i "$((line_num + 4))s/\$/ isolcpus=7/" /boot/boot.conf
			else
				sed -i "$((line_num + 4))s/\$/ isolcpus=7,23/" /boot/boot.conf
			fi
		done
		IFS=$OLD_IFS

		cp -a ./services/set_interrupts.sh /usr/local
		chmod +x /usr/local/set_interrupts.sh

		cp -a ./services/set-interrupts.service /etc/systemd/system/

		systemctl daemon-reload
		systemctl enable set-interrupts
		systemctl restart set-interrupts

		return 1
	fi

	return 0
}

get_ethernet_count
set_up_cores_scheduler
exit_code=$?
if [ $exit_code -eq 0 ]; then
	echo "Установка не требуется"
elif [ $exit_code -eq 1 ]; then
	echo "Установка произведена"
fi
