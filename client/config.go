package main

import (
	"encoding/json"
	"log"
	"os"
)

type Config struct {
	AuthSecret string `json:"auth_secret"`
	Url        string `json:"url"`
	NetName    string `json:"net_name"`
	Name       string `json:"name"`
	ExpireTime string `json:"expire_time"`
}

var cfg *Config

func LoadConfig() {
	file, err := os.ReadFile("client.json")
	if err != nil {
		log.Panic(err)
	}
	cfg = &Config{}
	err = json.Unmarshal(file, cfg)
	if err != nil {
		log.Panic(err)
	}
	return
}
