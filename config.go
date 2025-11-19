package main

import (
	"encoding/json"
	"log"
	"os"
)

type Config struct {
	AuthSecret string `json:"auth_secret"`
	Listen     string `json:"listen"`
	Frontend   string `json:"frontend"`
	EnableTG   bool   `json:"enable_tg"`
	TgToken    string `json:"tg_token"`
	UpdateUri  string `json:"update_uri"`
	WebUri     string `json:"web_uri"`
	HookUri    string `json:"hook_uri"`
	HookToken  string `json:"hook_token"`
	TgChatID   int64  `json:"tg_chat_id"`
}

var cfg *Config

func LoadConfig() {
	file, err := os.ReadFile("config.json")
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
