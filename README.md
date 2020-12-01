# xray
## 介绍
### install.sh
- xray安装脚本，适用于centos7+/debian9+/ubuntu16.04+
- 调用xray官方安装脚本
- 使用vless+tcp+xtls模式
- 回落使用nginx，配置伪装站

### install_wp.sh
- xray安装脚本，适用于centos7
- 调用xray官方安装脚本
- 使用vless+tcp+xtls模式
- 回落使用nginx，配置wordpress

## install.sh使用
bash <(curl -Ls https://raw.githubusercontent.com/atrandys/xray/main/install.sh)

## install_wp.sh使用
bash <(curl -Ls https://raw.githubusercontent.com/atrandys/xray/main/install_wp.sh)

## client使用
- OpenWrt
  - PassWall
- Windows
  - v2rayN
- Android
  - v2rayNG
- iOS / Mac
  - Shadowrocket


