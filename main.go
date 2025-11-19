package main

import (
	"akile_monitor/client/model"
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"log"
	"regexp"
	"sort"
	"strconv"
	"time"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/common/json"
	"github.com/glebarez/sqlite"
	"github.com/hertz-contrib/cors"
	"github.com/hertz-contrib/websocket"
	"gorm.io/gorm"
)

type Data struct {
	Name string `gorm:"primaryKey"`
	Data string
}
type M struct {
	Host      *model.Host
	State     *model.HostState
	TimeStamp int64
}

var db *gorm.DB
var filedb *gorm.DB

func initDb() {
	var dbfile = "file::memory:?cache=shared"
	Db, err := gorm.Open(sqlite.Open(dbfile), &gorm.Config{})
	if err != nil {
		log.Panic(err)
	}

	Db.AutoMigrate(&Data{})
	db = Db
}

func initFileDb() {
	var dbfile = "ak_monitor.db"
	Db, err := gorm.Open(sqlite.Open(dbfile), &gorm.Config{})
	if err != nil {
		log.Panic(err)
	}

	Db.AutoMigrate(&Host{})
	filedb = Db
}

type Host struct {
	Name    string `json:"name" gorm:"primaryKey"`
	DueTime int64  `json:"due_time"` // 到期时间
	BuyUrl  string `json:"buy_url"`  // 购买链接
	Seller  string `json:"seller"`   // 卖家
	Price   string `json:"price"`    // 价格
}

var upgrader = websocket.HertzUpgrader{
	CheckOrigin: func(r *app.RequestContext) bool {
		return true // 允许所有跨域请求
	},
	EnableCompression: true,
} // use default options

func monitor(_ context.Context, c *app.RequestContext) {
	err := upgrader.Upgrade(c, func(conn *websocket.Conn) {
		var authed bool
		for {
			mt, message, err := conn.ReadMessage()
			if err != nil {
				log.Printf("client: %s,read: %s\n", c.ClientIP(), err.Error())
				break
			}

			if !authed {
				if string(message) != cfg.AuthSecret {
					log.Printf("client: %s,auth failed\n", c.ClientIP())
					break
				}
				authed = true
				err = conn.WriteMessage(mt, []byte("auth success"))
				if err != nil {
					log.Printf("client: %s,write: %s\n", c.ClientIP(), err.Error())
					break
				}
				continue
			}

			//gzip解压
			var buf bytes.Buffer
			buf.Write(message)
			r, _ := gzip.NewReader(&buf)
			message, _ = io.ReadAll(r)
			r.Close()

			var d M

			err = json.Unmarshal(message, &d)
			if err != nil {
				log.Printf("client: %s,unmarshal: %s\n", c.ClientIP(), err.Error())
				break
			}

			var data Data
			db.Model(&Data{}).Where("name = ?", d.Host.Name).First(&data)
			if data.Name == "" {
				db.Create(&Data{Name: d.Host.Name, Data: string(message)})
			} else {
				db.Model(&Data{}).Where("name = ?", d.Host.Name).Update("data", string(message))
			}
		}
	})
	if err != nil {
		log.Printf("client: %s,upgrade: %s\n", c.ClientIP(), err.Error())
		return
	}
}

var offline = make(map[string]bool)

func main() {
	LoadConfig()
	initDb()
	initFileDb()
	if cfg.EnableTG {
		go startbot()
	}

	if cfg.TgChatID != 0 {
		go func() {
			for {
				var mm []M
				data := fetchData()
				json.Unmarshal(data, &mm)
				for _, v := range mm {
					// 30秒内离线
					if v.TimeStamp < time.Now().Unix()-60 {
						if !offline[v.Host.Name] {
							offline[v.Host.Name] = true
							msg := fmt.Sprintf("❌ %s 离线了", v.Host.Name)
							SendTGMessage(msg)
						}
					} else {
						if offline[v.Host.Name] {
							offline[v.Host.Name] = false
							msg := fmt.Sprintf("✅ %s 上线了", v.Host.Name)
							SendTGMessage(msg)
						}
					}
				}
				time.Sleep(time.Second * 20)

			}
		}()
	}
	h := server.Default(server.WithHostPorts(cfg.Listen))
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	h.Use(cors.New(config))
	h.NoHijackConnPool = true
	h.GET("/info", Info)
	h.POST("/info", UpdateInfo)
	h.GET(cfg.UpdateUri, monitor)
	h.GET(cfg.WebUri, ws)
	h.GET(cfg.HookUri, Hook)
	h.POST("/delete", DeleteHost)
	h.StaticFS("/", &app.FS{
		Root:               cfg.Frontend,
		IndexNames:         []string{"index.html"}, // 设置默认索引文件为 index.html
		GenerateIndexPages: false,                  // 禁止生成索引页面，可选
		Compress:           false,                  // 不启用压缩，可选
		AcceptByteRange:    false,                  // 不接受字节范围请求，可选
		PathRewrite:        nil,
		PathNotFound: func(ctx context.Context, c *app.RequestContext) {
			c.NotFound()
		},
	})
	h.Spin()
}

func Hook(_ context.Context, c *app.RequestContext) {
	token := c.Query("token")
	if token != cfg.HookToken {
		c.JSON(401, "auth failed")
		return
	}
	data := fetchData()
	c.JSON(200, data)
}

func Info(_ context.Context, c *app.RequestContext) {
	var ret []*Host
	err := filedb.Model(&Host{}).Find(&ret).Error
	if err != nil {
		log.Println(err)
		c.JSON(200, "[]")
		return
	}
	c.JSON(200, ret)
}

type UpdateRequest struct {
	AuthSecret string `json:"auth_secret"`
	Host
}

func UpdateInfo(_ context.Context, c *app.RequestContext) {
	var ret UpdateRequest
	err := c.BindJSON(&ret)
	if err != nil {
		c.JSON(400, "bad request")
		return
	}

	if ret.AuthSecret != cfg.AuthSecret {
		c.JSON(401, "auth failed")
		return
	}

	var h Host

	filedb.Model(&Host{}).Where("name = ?", ret.Name).First(&h)
	if h.Name == "" {
		h = ret.Host
		filedb.Model(&Host{}).Create(&h)
	} else {
		h = ret.Host
		filedb.Model(&Host{}).Where("name = ?", ret.Name).Save(&h)
	}
	c.JSON(200, "ok")
}

type DeleteHostRequest struct {
	AuthSecret string `json:"auth_secret"`
	Name       string `json:"name"`
}

func DeleteHost(_ context.Context, c *app.RequestContext) {
	var req DeleteHostRequest
	err := c.BindJSON(&req)
	if err != nil {
		c.JSON(400, "bad request")
		return
	}

	if req.AuthSecret != cfg.AuthSecret {
		c.JSON(401, "auth failed")
		return
	}

	var data Data
	db.Model(&Data{}).Where("name = ?", req.Name).First(&data)
	if data.Name == "" {
		c.JSON(404, "not found")
		return
	}

	db.Delete(&Data{}, "name = ?", req.Name)
	c.JSON(200, "ok")
}

func ws(_ context.Context, c *app.RequestContext) {
	err := upgrader.Upgrade(c, func(conn *websocket.Conn) {
		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				log.Printf("client: %s,read: %s\n", c.ClientIP(), err.Error())
				break
			}

			data := fetchData()
			err = conn.WriteMessage(websocket.TextMessage, append([]byte("data: "), data...))
			if err != nil {
				log.Printf("client: %s,write: %s\n", c.ClientIP(), err.Error())
				break
			}
		}
	})
	if err != nil {
		log.Printf("client: %s,upgrade: %s\n", c.ClientIP(), err.Error())
		return
	}
}

func fetchData() []byte {
	// 模拟数据获取
	var ret []Data
	db.Model(&Data{}).Find(&ret)

	var mm []M

	//排序根据Name 10在9后面
	sort.Slice(ret, func(i, j int) bool {
		return compareStrings(ret[i].Name, ret[j].Name) < 0
	})

	//var jsonData string
	for _, v := range ret {
		var m M
		json.Unmarshal([]byte(v.Data), &m)
		mm = append(mm, m)
	}

	jsonData, _ := json.Marshal(mm)
	return jsonData
}

// 定义一个函数来比较两个带字母和数字的字符串
func compareStrings(str1, str2 string) int {
	//先去除空格
	str1 = regexp.MustCompile(`\s+`).ReplaceAllString(str1, "")
	str2 = regexp.MustCompile(`\s+`).ReplaceAllString(str2, "")

	// 使用正则表达式提取字母和数字部分
	re := regexp.MustCompile(`([a-zA-Z]+)(\d*)`)
	matches1 := re.FindStringSubmatch(str1)
	matches2 := re.FindStringSubmatch(str2)

	if len(matches1) != 3 || len(matches2) != 3 {
		return 0 // 格式不匹配
	}

	// 提取字母部分
	letter1 := matches1[1]
	letter2 := matches2[1]

	// 提取并转换数字部分
	num1 := 0
	num2 := 0
	if len(matches1[2]) > 0 {
		num1, _ = strconv.Atoi(matches1[2])
	}
	if len(matches2[2]) > 0 {
		num2, _ = strconv.Atoi(matches2[2])
	}

	// 先比较字母部分，逐个字符比较
	for i := 0; i < len(letter1) && i < len(letter2); i++ {
		if letter1[i] < letter2[i] {
			return -1
		} else if letter1[i] > letter2[i] {
			return 1
		}
	}

	// 如果字母部分相同，长度不等时，短的字母部分小
	if len(letter1) < len(letter2) {
		return -1
	} else if len(letter1) > len(letter2) {
		return 1
	}

	// 字母相同，比较数字部分
	if num1 < num2 {
		return -1
	} else if num1 > num2 {
		return 1
	}

	// 如果字母和数字都相同
	return 0
}
