package main

import "fmt"

func formatPercentage(value, total uint64) string {
	if total == 0 {
		return "N/A"
	}

	return fmt.Sprintf("%.2f%%", float64(value)/float64(total)*100)
}

func formatTrafficBalance(in, out uint64) string {
	if in > out {
		return formatPercentage(out, in)
	}

	return formatPercentage(in, out)
}
