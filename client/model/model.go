package model

type HostState struct {
	CPU            float64
	MemUsed        uint64
	SwapUsed       uint64
	NetInTransfer  uint64
	NetOutTransfer uint64
	NetInSpeed     uint64
	NetOutSpeed    uint64
	Uptime         uint64
	Load1          float64
	Load5          float64
	Load15         float64
}

type Host struct {
	Name            string
	Platform        string
	PlatformVersion string
	CPU             []string
	MemTotal        uint64
	SwapTotal       uint64
	Arch            string
	Virtualization  string
	BootTime        uint64
	ExpireTime      string
}
