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
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 

#VNC password - http://hints.macworld.com/article.php?story=20071103011608872
echo $2 | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

#Start VNC/reset changes
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

sysctl -n machdep.cpu.brand_string hw.memsize
system_profiler SPHardwareDataType SPSoftwareDataType

brew install tailscale
sudo brew services start tailscale
# 5. 讓子彈飛一會兒 (等待 Daemon 建立 Socket)echo "⏳ 等待 Tailscale 服務啟動中..."
sleep 10
# 6. 登入並配置# --ssh: 順便開啟 Tailscale SSH 功能，以後 SSH 更方便# --accept-routes: 如你有設 Subnet Router 這很有用
sudo tailscale up --authkey "$TS_KEY" --ssh --accept-routes
# 7. 開啟 Funnel (確保本地 80 port 真的有東西在跑喔)
sudo tailscale funnel 80# 8. 收工檢查
echo "✅ 完成！目前狀態："
tailscale status

#install ngrok
# brew install ngrok

#configure ngrok and start it
# ngrok authtoken $3
# ngrok tcp 5900 &
