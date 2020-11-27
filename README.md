# xray
## 介绍
- xray安装脚本，适用于centos7+/debian9+/ubuntu16.04+
- 调用xray官方安装脚本
- 使用vless+tcp+xtls模式
- 回落使用nginx，配置伪装站

## 使用
### server安装
bash <(curl -Ls https://raw.githubusercontent.com/atrandys/xray/main/install.sh)

### client使用(win64)
1. 获取server安装完成后生成的client.json
2. 下载客户端文件https://github.com/atrandys/xray/raw/main/Xray-windows-64.zip 并解压
3. 将client.json添加到解压后的文件夹中
4. start.bat开启代理/stop.bat关闭代理
5. 配合浏览器插件使用


