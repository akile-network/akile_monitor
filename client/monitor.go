package main

import (
	"akile_monitor/client/model"
	"fmt"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
	"log"
	"runtime"
	"strconv"
	"time"
)

func GetState() *model.HostState {
	var ret model.HostState
	cp, err := cpu.Percent(0, false)
	if err != nil || len(cp) == 0 {
		log.Println("cpu.Percent error:", err)
	} else {
		ret.CPU = cp[0]
	}

	loadStat, err := load.Avg()
	if err != nil {
		log.Println("load.Avg error:", err)
	} else {
		ret.Load1 = Decimal(loadStat.Load1)
		ret.Load5 = Decimal(loadStat.Load5)
		ret.Load15 = Decimal(loadStat.Load15)

	}

	vm, err := mem.VirtualMemory()
	if err != nil {
		log.Println("mem.VirtualMemory error:", err)
	} else {
		ret.MemUsed = vm.Total - vm.Available
	}

	uptime, err := host.Uptime()
	if err != nil {
		log.Println("host.Uptime error:", err)
	} else {
		ret.Uptime = uptime
	}

	swap, err := mem.SwapMemory()
	if err != nil {
		log.Println("mem.SwapMemory error:", err)
	} else {
		ret.SwapUsed = swap.Used
	}

	ret.NetInTransfer, ret.NetOutTransfer = netInTransfer, netOutTransfer
	ret.NetInSpeed, ret.NetOutSpeed = netInSpeed, netOutSpeed

	return &ret

}

func GetHost() *model.Host {
	var ret model.Host
	ret.Name = cfg.Name
	var cpuType string
	hi, err := host.Info()
	if err != nil {
		log.Println("host.Info error:", err)
	}
	cpuType = "Virtual"
	ret.Platform = hi.Platform
	ret.PlatformVersion = hi.PlatformVersion
	ret.Arch = hi.KernelArch
	ret.Virtualization = hi.VirtualizationSystem
	ret.BootTime = hi.BootTime
	ci, err := cpu.Info()
	if err != nil {
		log.Println("cpu.Info error:", err)
	}
	ret.CPU = append(ret.CPU, fmt.Sprintf("%s %d %s Core", ci[0].ModelName, runtime.NumCPU(), cpuType))
	vm, err := mem.VirtualMemory()
	if err != nil {
		log.Println("mem.VirtualMemory error:", err)
	}

	swap, err := mem.SwapMemory()
	if err != nil {
		log.Println("mem.SwapMemory error:", err)
	}

	ret.MemTotal = vm.Total
	ret.SwapTotal = swap.Total
	ret.ExpireTime = cfg.ExpireTime
	return &ret

}

var (
	netInSpeed, netOutSpeed, netInTransfer, netOutTransfer, lastUpdateNetStats uint64
)

// TrackNetworkSpeed NIC监控，统计流量与速度
func TrackNetworkSpeed() {
	var innerNetInTransfer, innerNetOutTransfer uint64
	nc, err := net.IOCounters(true)
	if err == nil {
		for _, v := range nc {
			if v.Name == cfg.NetName {
				innerNetInTransfer += v.BytesRecv
				innerNetOutTransfer += v.BytesSent
			}
		}
		now := uint64(time.Now().Unix())
		diff := now - lastUpdateNetStats
		if diff > 0 {
			netInSpeed = (innerNetInTransfer - netInTransfer) / diff
			netOutSpeed = (innerNetOutTransfer - netOutTransfer) / diff
		}
		netInTransfer = innerNetInTransfer
		netOutTransfer = innerNetOutTransfer
		lastUpdateNetStats = now

	}
}

// 保留两位小数
func Decimal(value float64) float64 {
	value, _ = strconv.ParseFloat(fmt.Sprintf("%.2f", value), 64)
	return value
}
