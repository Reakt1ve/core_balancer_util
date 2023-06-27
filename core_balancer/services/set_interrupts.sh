#! /bin/bash

let ETH_COUNT=0
function get_ethernet_count() {
	ETH_COUNT=$(ls /sys/class/net/ | grep eth* | wc -l)
}

get_ethernet_count

CPU_0_affinity='000080'
CPU_1_affinity='800000'
for (( eth_num=0; eth_num<ETH_COUNT; eth_num++ )); do
	eth_irq=$(cat /proc/interrupts | grep eth${eth_num} | cut -d ':' -f1 | xargs)

	if [ -z $eth_irq ]; then
		echo "Невозможно настроить IRQ для интерфейса eth${eth_num}. Интерфейс пропущен"
		continue
	fi

	if [ $eth_num -lt 3 ]; then 
		echo $CPU_0_affinity > /proc/irq/${eth_irq}/smp_affinity
	else
		echo $CPU_1_affinity > /proc/irq/${eth_irq}/smp_affinity
	fi
done

exit 0
