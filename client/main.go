package main

import (
	"akile_monitor/client/model"
	"bytes"
	"compress/gzip"
	"context"
	"flag"
	"fmt"
	"github.com/cloudwego/hertz/pkg/common/json"
	"github.com/henrylee2cn/goutil/calendar/cron"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
)

func main() {
	LoadConfig()

	startNetworkTracker()

	flag.Parse()
	log.SetFlags(0)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	reconnectDelay := time.Second
	for {
		connected, err := reportLoop(ctx)
		if err == nil || ctx.Err() != nil {
			return
		}

		if connected {
			reconnectDelay = time.Second
		}
		log.Printf("connection closed: %v; reconnecting in %s", err, reconnectDelay)

		select {
		case <-time.After(reconnectDelay):
		case <-ctx.Done():
			return
		}

		if reconnectDelay < 30*time.Second {
			reconnectDelay *= 2
			if reconnectDelay > 30*time.Second {
				reconnectDelay = 30 * time.Second
			}
		}
	}
}

func startNetworkTracker() {
	go func() {
		c := cron.New()
		c.AddFunc("* * * * * *", func() {
			TrackNetworkSpeed()
		})
		c.Start()
	}()
}

func reportLoop(ctx context.Context) (bool, error) {
	u := cfg.Url
	log.Printf("connecting to %s", u)

	c, _, err := websocket.DefaultDialer.Dial(cfg.Url, nil)
	if err != nil {
		return false, fmt.Errorf("dial: %w", err)
	}
	defer c.Close()

	if err := writeMessage(c, websocket.TextMessage, []byte(cfg.AuthSecret)); err != nil {
		return false, fmt.Errorf("write auth_secret: %w", err)
	}

	if err := c.SetReadDeadline(time.Now().Add(15 * time.Second)); err != nil {
		return false, fmt.Errorf("set auth read deadline: %w", err)
	}
	_, message, err := c.ReadMessage()
	if err != nil {
		return false, fmt.Errorf("read auth response: %w", err)
	}
	if err := c.SetReadDeadline(time.Time{}); err != nil {
		return false, fmt.Errorf("clear auth read deadline: %w", err)
	}
	if string(message) != "auth success" {
		return false, fmt.Errorf("auth_secret验证失败: %s", message)
	}
	log.Println("auth_secret验证成功")
	log.Println("正在上报数据...")

	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case t := <-ticker.C:
			var D struct {
				Host      *model.Host
				State     *model.HostState
				TimeStamp int64
			}
			D.Host = GetHost()
			D.State = GetState()
			D.TimeStamp = t.Unix()
			//gzip压缩json
			dataBytes, err := json.Marshal(D)
			if err != nil {
				return true, fmt.Errorf("json.Marshal: %w", err)
			}

			var buf bytes.Buffer
			gz := gzip.NewWriter(&buf)
			if _, err := gz.Write(dataBytes); err != nil {
				return true, fmt.Errorf("gzip.Write: %w", err)
			}

			if err := gz.Close(); err != nil {
				return true, fmt.Errorf("gzip.Close: %w", err)
			}

			if err := writeMessage(c, websocket.TextMessage, buf.Bytes()); err != nil {
				return true, fmt.Errorf("write metrics: %w", err)
			}
		case <-ctx.Done():
			log.Println("interrupt")
			_ = writeMessage(c, websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
			return true, nil
		}
	}
}

func writeMessage(c *websocket.Conn, messageType int, data []byte) error {
	if err := c.SetWriteDeadline(time.Now().Add(10 * time.Second)); err != nil {
		return err
	}
	return c.WriteMessage(messageType, data)
}
