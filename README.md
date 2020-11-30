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
### server安装
bash <(curl -Ls https://raw.githubusercontent.com/atrandys/xray/main/install.sh)

### client使用
配合各支持xray的客户端使用

or

win64使用：
1. 获取server安装完成后生成的client.json
2. 下载客户端文件https://github.com/atrandys/xray/raw/main/Xray-windows-64.zip 并解压
3. 将client.json添加到解压后的文件夹中
4. start.bat开启代理/stop.bat关闭代理
5. 配合浏览器插件使用

## install_wp.sh使用
### server安装
bash <(curl -Ls https://raw.githubusercontent.com/atrandys/xray/main/install_wp.sh)

### client使用
配合各支持xray的客户端使用


