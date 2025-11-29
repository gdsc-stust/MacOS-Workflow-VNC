#configure.sh VNC_USER_PASSWORD VNC_PASSWORD TS_KEY

#disable spotlight indexing
sudo mdutil -i off -a

#Create new account
sudo dscl . -create /Users/vncuser
sudo dscl . -create /Users/vncuser UserShell /bin/bash
sudo dscl . -create /Users/vncuser RealName "User"
sudo dscl . -create /Users/vncuser UniqueID 1001
sudo dscl . -create /Users/vncuser PrimaryGroupID 80
sudo dscl . -create /Users/vncuser NFSHomeDirectory /Users/vncuser
sudo dscl . -passwd /Users/vncuser $1
sudo dscl . -passwd /Users/vncuser $1
sudo createhomedir -c -u vncuser > /dev/null

#Enable VNC
# sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
# sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 


defaults write com.apple.universalaccess reduceTransparency -bool false
killall Dock

echo "🕵️ Check SIP Status..."
csrutil status

echo "🔓 SIP is disabled! Injecting permissions into TCC.db..."

# 使用 Python 腳本來處理 SQLite，比較不會因為欄位變動而炸裂
sudo python3 -c "
import sqlite3
import time
import os

# TCC 資料庫路徑
db_path = '/Library/Application Support/com.apple.TCC/TCC.db'

if not os.path.exists(db_path):
    print(f'❌ Error: DB not found at {db_path}')
    exit(1)

try:
    con = sqlite3.connect(db_path)
    cur = con.cursor()

    # 定義我們要授權的服務
    # 1. kTCCServiceScreenCapture: 允許看畫面
    # 2. kTCCServicePostEvent: 允許控制滑鼠鍵盤
    # 3. kTCCServiceAccessibility: 輔助使用權限 (有時候需要)
    services = [
        'kTCCServiceScreenCapture', 
        'kTCCServicePostEvent',
        'kTCCServiceAccessibility'
    ]
    
    # 目標程式：macOS 內建螢幕分享代理程式
    client = 'com.apple.screensharing.agent'
    
    # 獲取當前時間戳
    now = int(time.time())

    # 針對每個服務進行注入
    for service in services:
        print(f'💉 Injecting {service} for {client}...')
        
        # 這是 macOS 12+ (含 Sequoia) 常見的 TCC 表結構插入
        # 使用 INSERT OR REPLACE 覆蓋舊設定
        # auth_value=2 代表 'Allowed'
        cur.execute('''
            INSERT OR REPLACE INTO access 
            (service, client, client_type, auth_value, auth_reason, auth_version, csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier, flags, last_modified)
            VALUES (?, ?, 0, 2, 4, 1, NULL, NULL, 0, 'UNUSED', 0, ?)
        ''', (service, client, now))
        
    con.commit()
    print('✅ TCC Permissions injected successfully.')
    con.close()

except Exception as e:
    print(f'❌ TCC Injection Failed: {e}')
    # 如果是因為欄位數量不對 (macOS 版本差異)，這裡會報錯，但通常 macOS 15 結構如上
    exit(1)
"

# --- 接下來接你原本的 Kickstart 重啟指令 ---

echo "🔄 Restarting Remote Management to apply TCC changes..."
VNC_PWD="$VNC_PASSWORD"

# 1. 停止服務
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off
sleep 1

# 2. 重新啟動 (現在它應該已經有權限了)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -clientopts -setvnclegacy -vnclegacy yes \
  -clientopts -setvncpw -vncpw "$VNC_PWD" \
  -restart -agent -privs -all -allowAccessFor -allUsers

# 3. 確保使用者也在群組裡
sudo dseditgroup -o edit -a "$(whoami)" -t user com.apple.access_screensharing

echo "🚀 Ready to connect!"
echo "✅ Screen Sharing enabled."
echo "使用螢幕共享時，帳號[vncuser] || Apple Screen Sharing User [vncuser]"

#VNC password - http://hints.macworld.com/article.php?story=20071103011608872
echo $2 | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

#Start VNC/reset changes
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate
echo "--- VM Info ---"
sysctl -n machdep.cpu.brand_string hw.memsize
system_profiler SPHardwareDataType SPSoftwareDataType

brew install tailscale
sudo brew services start tailscale
# 5. 讓子彈飛一會兒 (等待 Daemon 建立 Socket)echo "⏳ 等待 Tailscale 服務啟動中..."

# 6. 登入並配置# --ssh: 順便開啟 Tailscale SSH 功能，以後 SSH 更方便# --accept-routes: 如你有設 Subnet Router 這很有用
sudo tailscale up --authkey "$TS_KEY"
echo "--- VM IP ---"
tailscale ip
echo "-------------"
open -a Terminal && sleep 1 && osascript -e 'tell application "Terminal" to quit'
open /System/Library/PreferencePanes/Displays.prefPane
# 7. 開啟 Funnel (確保本地 80 port 真的有東西在跑喔)
sudo tailscale funnel 80


#install ngrok
# brew install ngrok

#configure ngrok and start it
# ngrok authtoken $3
# ngrok tcp 5900 &
