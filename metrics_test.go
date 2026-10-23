package main

import "testing"

func TestFormatPercentage(t *testing.T) {
	tests := []struct {
		name     string
		value    uint64
		total    uint64
		expected string
	}{
		{name: "zero total", value: 0, total: 0, expected: "N/A"},
		{name: "nonzero total", value: 1, total: 4, expected: "25.00%"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := formatPercentage(test.value, test.total); got != test.expected {
				t.Fatalf("formatPercentage(%d, %d) = %q, want %q", test.value, test.total, got, test.expected)
			}
		})
	}
}

func TestFormatTrafficBalance(t *testing.T) {
	tests := []struct {
		name     string
		in       uint64
		out      uint64
		expected string
	}{
		{name: "no traffic", in: 0, out: 0, expected: "N/A"},
		{name: "inbound only", in: 10, out: 0, expected: "0.00%"},
		{name: "outbound only", in: 0, out: 10, expected: "0.00%"},
		{name: "inbound dominant", in: 3, out: 5, expected: "60.00%"},
		{name: "outbound dominant", in: 5, out: 3, expected: "60.00%"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := formatTrafficBalance(test.in, test.out); got != test.expected {
				t.Fatalf("formatTrafficBalance(%d, %d) = %q, want %q", test.in, test.out, got, test.expected)
			}
		})
	}
}
