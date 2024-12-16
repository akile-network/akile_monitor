package main

import (
	"encoding/json"
	"fmt"
	"log"
	"regexp"
	"strconv"
	"time"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

func startbot() {
	bot, err := tgbotapi.NewBotAPI(cfg.TgToken)
	if err != nil {
		log.Println("Error creating bot", err)
		return
	}

	bot.Debug = false

	log.Printf("Authorized on account %s", bot.Self.UserName)

	setBotCommands(bot)

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60

	updates := bot.GetUpdatesChan(u)

	for update := range updates {
		if update.Message != nil { // If we got a message
			log.Printf("[%s] %s", update.Message.From.UserName, update.Message.Text)

			if update.Message.IsCommand() {
				if update.Message.Command() == "akall" {

					var ret []Data
					db.Model(&Data{}).Find(&ret)

					var mm []M
					for _, v := range ret {
						var m M
						json.Unmarshal([]byte(v.Data), &m)
						mm = append(mm, m)
					}

					var online int
					var cpu int
					var mem uint64
					var memused uint64
					var downspeed uint64
					var upspeed uint64
					var downflow uint64
					var upflow uint64
					var swapused uint64
					var swap uint64
					time_now := time.Now().Unix()
					for _, v := range mm {
						if v.TimeStamp > time_now-30 {
							online++
						}
						cpu += parseCPU(v.Host.CPU[0])
						mem += v.Host.MemTotal
						memused += v.State.MemUsed
						swap += v.Host.SwapTotal
						swapused += v.State.SwapUsed
						downspeed += v.State.NetInSpeed
						upspeed += v.State.NetOutSpeed
						downflow += v.State.NetInTransfer
						upflow += v.State.NetOutTransfer
					}

					//流量对等性
					var duideng string
					if downflow > upflow {
						duideng = fmt.Sprintf("%.2f%%", float64(upflow)/float64(downflow)*100)
					} else {
						duideng = fmt.Sprintf("%.2f%%", float64(downflow)/float64(upflow)*100)
					}

					msg := fmt.Sprintf(`统计信息
===========================
服务器数量： %d
在线服务器： %d
CPU核心数： %d
内存： %s [%s/%s]
交换分区： %s [%s/%s]
下行速度： ↓%s/s
上行速度： ↑%s/s
下行流量： ↓%s
上行流量： ↑%s
流量对等性： %s

更新于：%s UTC`,
						len(mm), online, cpu,
						fmt.Sprintf("%.2f%%", float64(memused)/float64(mem)*100),
						formatSize(memused), formatSize(mem),
						fmt.Sprintf("%.2f%%", float64(swapused)/float64(swap)*100),
						formatSize(swapused), formatSize(swap),
						formatSize(downspeed), formatSize(upspeed),
						formatSize(downflow), formatSize(upflow),
						duideng,
						time.Now().UTC().Format("2006-01-02 15:04:05"),
					)
					bot.Send(tgbotapi.NewMessage(update.Message.Chat.ID, msg))
				} else if update.Message.Command() == "id" {
					msg := tgbotapi.NewMessage(update.Message.Chat.ID, fmt.Sprintf("你的ID是: %d", update.Message.From.ID))
					bot.Send(msg)
				} else if update.Message.Command() == "server" {
					var servers []Data
					db.Model(&Data{}).Find(&servers)

					if len(servers) == 0 {
						bot.Send(tgbotapi.NewMessage(update.Message.Chat.ID, "没有找到任何服务器信息。"))
						return
					}

					var rows [][]tgbotapi.InlineKeyboardButton
					row := []tgbotapi.InlineKeyboardButton{}
					for i, server := range servers {
						callbackData := fmt.Sprintf("/status %s", server.Name)
						row = append(row, tgbotapi.NewInlineKeyboardButtonData(server.Name, callbackData))
						if (i+1)%2 == 0 {
							rows = append(rows, row)
							row = []tgbotapi.InlineKeyboardButton{}
						}
					}
					if len(row) > 0 {
						rows = append(rows, row)
					}

					keyboard := tgbotapi.NewInlineKeyboardMarkup(rows...)
					msg := tgbotapi.NewMessage(update.Message.Chat.ID, "请选择一个服务器:")
					msg.ReplyMarkup = keyboard
					bot.Send(msg)
				} else if update.Message.Command() == "status" {
					serverName := update.Message.CommandArguments()
					if serverName == "" {
						bot.Send(tgbotapi.NewMessage(update.Message.Chat.ID, "用法: /status <服务器名称>"))
					} else {
						sendOrEditServerStatus(bot, update.Message.Chat.ID, 0, serverName)
					}
				}
			}
		} else if update.CallbackQuery != nil {
			callbackData := update.CallbackQuery.Data
			if len(callbackData) > 8 && callbackData[:8] == "/status " {
				serverName := callbackData[8:]
				// 编辑原消息并展示服务器信息
				sendOrEditServerStatus(bot, update.CallbackQuery.Message.Chat.ID, update.CallbackQuery.Message.MessageID, serverName)
			}
		}
	}
}

// 设置命令列表
func setBotCommands(bot *tgbotapi.BotAPI) {
	commands := []tgbotapi.BotCommand{
		{Command: "id", Description: "查看你的 Telegram 用户 ID"},
		{Command: "akall", Description: "查看所有服务器的统计信息"},
		{Command: "server", Description: "获取服务器列表"},
		{Command: "status", Description: "查看某个服务器状态"},
	}
	// 创建命令配置
	_, err := bot.Request(tgbotapi.NewSetMyCommands(commands...))
	if err != nil {
		log.Println("设置命令失败:", err)
	} else {
		log.Println("命令设置成功")
	}
}

// 新建/编辑消息展示单个服务器信息
func sendOrEditServerStatus(bot *tgbotapi.BotAPI, chatID int64, messageID int, serverName string) {
	var data Data
	if err := db.First(&data, "name = ?", serverName).Error; err != nil {
		// messageID != 0 说明消息来自点击列表中按钮回调, 只需要编辑原信息; 否则消息来自直接调用 /status 命令, 需要新建信息
		if messageID != 0 {
			editMsg := tgbotapi.NewEditMessageText(chatID, messageID, "未找到指定的服务器信息。")
			bot.Send(editMsg)
		} else {
			bot.Send(tgbotapi.NewMessage(chatID, "未找到指定的服务器信息。"))
		}
		return
	}

	var m M
	if err := json.Unmarshal([]byte(data.Data), &m); err != nil {
		// messageID != 0 说明消息来自点击列表中按钮回调, 只需要编辑原信息; 否则消息来自直接调用 /status 命令, 需要新建信息
		if messageID != 0 {
			editMsg := tgbotapi.NewEditMessageText(chatID, messageID, "解析服务器数据失败。")
			bot.Send(editMsg)
		} else {
			bot.Send(tgbotapi.NewMessage(chatID, "解析服务器数据失败。"))
		}
		return
	}

	msgText := formatServerMessage(serverName, &m)
	if messageID != 0 {
		editMsg := tgbotapi.NewEditMessageText(chatID, messageID, msgText)
		bot.Send(editMsg)
	} else {
		bot.Send(tgbotapi.NewMessage(chatID, msgText))
	}
}

// 格式化服务器信息
func formatServerMessage(serverName string, m *M) string {
	//流量对等性
	var duideng string
	if m.State.NetInTransfer > m.State.NetOutTransfer {
		duideng = fmt.Sprintf("%.2f%%", float64(m.State.NetOutTransfer)/float64(m.State.NetInTransfer)*100)
	} else {
		duideng = fmt.Sprintf("%.2f%%", float64(m.State.NetInTransfer)/float64(m.State.NetOutTransfer)*100)
	}
	return fmt.Sprintf(`服务器: %s
CPU核心数: %d
内存: %s [%s/%s]
交换分区: %s [%s/%s]
下行速度: ↓%s/s
上行速度: ↑%s/s
下行流量: ↓%s
上行流量: ↑%s
流量对等性: %s
运行时间: %s

更新于: %s UTC`,
		serverName,
		parseCPU(m.Host.CPU[0]),
		fmt.Sprintf("%.2f%%", float64(m.State.MemUsed)/float64(m.Host.MemTotal)*100),
		formatSize(m.State.MemUsed),
		formatSize(m.Host.MemTotal),
		fmt.Sprintf("%.2f%%", float64(m.State.SwapUsed)/float64(m.Host.SwapTotal)*100),
		formatSize(m.State.SwapUsed),
		formatSize(m.Host.SwapTotal),
		formatSize(m.State.NetInSpeed),
		formatSize(m.State.NetOutSpeed),
		formatSize(m.State.NetInTransfer),
		formatSize(m.State.NetOutTransfer),
		duideng,
		time.Duration(m.State.Uptime)*time.Second,
		time.Now().UTC().Format("2006-01-02 15:04:05"),
	)
}

// 解析CPU数量
func parseCPU(cpu string) int {
	re := regexp.MustCompile(`(\d+) (Virtual) Core`)

	// 查找匹配项
	matches := re.FindStringSubmatch(cpu)
	if len(matches) >= 2 {
		virtualCores := matches[1]

		vint, err := strconv.Atoi(virtualCores)
		if err != nil {
			return 0
		}
		return vint
	}
	return 0
}

// 格式化字节大小
func formatSize(size uint64) string {
	if size < 1024 {
		return fmt.Sprintf("%d B", size)
	} else if size < 1024*1024 {
		return fmt.Sprintf("%.2f KB", float64(size)/1024)
	} else if size < 1024*1024*1024 {
		return fmt.Sprintf("%.2f MB", float64(size)/1024/1024)
	} else if size < 1024*1024*1024*1024 {
		return fmt.Sprintf("%.2f GB", float64(size)/1024/1024/1024)
	} else if size < 1024*1024*1024*1024*1024 {
		return fmt.Sprintf("%.2f TB", float64(size)/1024/1024/1024/1024)
	} else if size < 1024*1024*1024*1024*1024*1024 {
		return fmt.Sprintf("%.2f PB", float64(size)/1024/1024/1024/1024/1024)
	} else {
		return fmt.Sprintf("%.2f EB", float64(size)/1024/1024/1024/1024/1024/1024)
	}
}

func SendTGMessage(msg string) {
	bot, err := tgbotapi.NewBotAPI(cfg.TgToken)
	if err != nil {
		log.Println("Error creating bot", err)
		return
	}

	bot.Debug = false

	log.Printf("Authorized on account %s", bot.Self.UserName)

	msgs := tgbotapi.NewMessage(cfg.TgChatID, msg)
	bot.Send(msgs)
}
