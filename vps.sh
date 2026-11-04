#!/usr/bin/env bash
set -euo pipefail; [ "$(uname -s)" = "Linux" ] || { echo "仅支持 Linux 系统" >&2; exit 1; }
if [ "$(id -u)" -ne 0 ]; then
if [ -f "$0" ] && command -v sudo >/dev/null 2>&1; then
exec sudo -E bash "$0" "$@"
else
echo "错误: 请使用 root 权限或 sudo 运行此脚本" >&2; exit 1
fi
fi
require_root(){ [ "$(id -u)" -eq 0 ] || { echo "需要 root 权限" >&2; exit 1; }
}
clear(){ command clear 2>/dev/null || true
}
CLR_RESET=$'\033[0m'; CLR_BOLD=$'\033[1m'; CLR_DIM=$'\033[2m'; CLR_RED=$'\033[31m'; CLR_GREEN=$'\033[32m'; CLR_YELLOW=$'\033[33m'
CLR_CYAN=$'\033[36m'; VPS_VERSION="aee7c22"; VPS_BUILD_TIME="2026-11-04 16:07"
VPS_RAW_URL="${VPS_RAW_URL:-https://raw.githubusercontent.com/666OS/vps-sh/main}"
[ -f /etc/vps-sh/origin ] && VPS_RAW_URL="$(head -n 1 /etc/vps-sh/origin | tr -d '\r\n ')"
VPS_APP_FEED="${VPS_APP_FEED:-https://raw.githubusercontent.com/666OS/vps-apps/main}"
[ -f /etc/vps-sh/feed ] && VPS_APP_FEED="$(head -n 1 /etc/vps-sh/feed | tr -d '\r\n ')"; VPS_CACHE_DIR="/run/vps-sh"
mkdir -p -m 700 "$VPS_CACHE_DIR" 2>/dev/null || VPS_CACHE_DIR="/tmp"; sys_swap_snapshot(){
free -m | awk 'NR==3{if($2>0) printf "%s/%s MB (%.1f%%)", $3, $2, $3*100/$2; else print "未启用"}'
}
sys_tz_snapshot(){ local tz=$(timedatectl 2>/dev/null | awk -F': ' '/Time zone/{print $2}'); echo "${tz:-$(date +%Z)}"
}
sys_snapshot(){ local os=$(grep -oP '(?<=PRETTY_NAME=")[^"]*' /etc/os-release 2>/dev/null || uname -sr); local kernel=$(uname -r)
local cpu=$(LC_ALL=C lscpu 2>/dev/null | awk -F':' '/Model name/{sub(/^[ \t]+/, "", $2); print $2; exit}')
[ -n "$cpu" ] || cpu=$(awk -F':' '/model name|Hardware|Processor|^Model/{sub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)
[ -n "$cpu" ] || cpu=$(uname -m); local cores=$(nproc 2>/dev/null || echo 1)
local uptime=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); if(d>0) printf "%d天 %d小时 %d分", d, h, m; else if(h>0) printf "%d小时 %d分", h, m; else printf "%d分", (m>0?m:1)}' /proc/uptime 2>/dev/null || echo "未知")
local mem="" swap="无"
local mem_out=$(free -m 2>/dev/null | awk '
        NR==2 {m=sprintf("%s/%s MB (%.1f%%)", $3, $2, $3*100/$2)}
        NR==3 {if($2>0) s=sprintf("%s/%s MB (%.1f%%)", $3, $2, $3*100/$2); else s="无"}
        END {printf "%s|%s", m, (s?s:"无")}
    ')
[ -n "$mem_out" ] && IFS='|' read -r mem swap <<< "$mem_out"; local disk=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
local load=$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null || uptime | awk -F'load average: ' '{print $2}')
local bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知"); local ipv4="${VPS_IPV4_CACHE:-}"
if [ -z "$ipv4" ]; then
local k_ip=$( (ip -4 route get 1.1.1.1 2>/dev/null || true) | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
if [ -n "$k_ip" ] && [[ ! "$k_ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.) ]]; then
ipv4="$k_ip"
else
ipv4=$(curl -s4m2 https://api.ipify.org 2>/dev/null || curl -s4m2 https://icanhazip.com 2>/dev/null || echo "离线")
fi
if [ "$ipv4" != "离线" ]; then
export VPS_IPV4_CACHE="$ipv4"
fi
fi
local ipv6="${VPS_IPV6_CACHE:-}"
if [ -z "$ipv6" ]; then
ipv6=$( (ip -6 route get 2606:4700:4700::1111 2>/dev/null || true) | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
[ -n "$ipv6" ] || ipv6=$( (ip -6 addr show scope global -deprecated 2>/dev/null || true) | awk '/inet6 [23]/ {split($2, a, "/"); print a[1]; exit}')
[ -n "$ipv6" ] || ipv6=$(curl -s6m1 https://api64.ipify.org 2>/dev/null || echo "无")
if [ -n "$ipv6" ] && [ "$ipv6" != "无" ]; then
export VPS_IPV6_CACHE="$ipv6"
fi
fi
printf "${CLR_BOLD}系统:${CLR_RESET}     %s\n" "$os ($kernel)"; printf "${CLR_BOLD}处理器:${CLR_RESET}   %s (%s 核心)\n" "$cpu" "$cores"
printf "${CLR_BOLD}运行:${CLR_RESET}     在线: %s | ${CLR_BOLD}系统负载:${CLR_RESET} %s\n" "$uptime" "$load"
printf "${CLR_BOLD}内存:${CLR_RESET}     %s | ${CLR_BOLD}虚拟内存:${CLR_RESET} %s\n" "$mem" "$swap"
printf "${CLR_BOLD}磁盘:${CLR_RESET}     %s | ${CLR_BOLD}拥塞算法:${CLR_RESET} %s\n" "$disk" "$bbr"
printf "${CLR_BOLD}网络:${CLR_RESET}     IPv4: %s\n" "$ipv4"; printf "          IPv6: %s\n" "$ipv6"
}
sys_update(){ require_root; DEBIAN_FRONTEND=noninteractive apt-get update -y; DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y; DEBIAN_FRONTEND=noninteractive apt-get clean -y
}
sys_swap(){ require_root; local mb="${1:-2048}"; swapoff -a 2>/dev/null || true; rm -f /swapfile
fallocate -l "${mb}M" /swapfile || dd if=/dev/zero of=/swapfile bs=1M count="$mb"; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
sed -i '/\/swapfile/d' /etc/fstab; echo "/swapfile swap swap defaults 0 0" >> /etc/fstab; sysctl -w vm.swappiness=10
echo "vm.swappiness=10" > /etc/sysctl.d/99-swap.conf
}
sys_swap_off(){ require_root; swapoff -a 2>/dev/null || true; rm -f /swapfile; sed -i '/\/swapfile/d' /etc/fstab
rm -f /etc/sysctl.d/99-swap.conf
}
sys_tz(){ require_root; local tz="${1:-Asia/Shanghai}"; timedatectl set-timezone "$tz"
}
sys_tz_utc(){ require_root; timedatectl set-timezone UTC
}
sys_hosts_heal(){ local h="${1:-$(hostname 2>/dev/null || uname -n)}"; [ -n "$h" ] || return 0
grep -qE "^\s*(127\.0\.0\.1|127\.0\.1\.1)\s+.*\b$h\b" /etc/hosts 2>/dev/null && return 0
if grep -qE "^\s*127\.0\.1\.1" /etc/hosts 2>/dev/null; then
sed -i -E "s/^\s*127\.0\.1\.1.*/127.0.1.1 $h/" /etc/hosts
else
echo "127.0.1.1 $h" >> /etc/hosts
fi
}
sys_hostname(){ require_root; local host="$1"
if [ "${#host}" -gt 253 ] || [[ ! "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
printf "${CLR_RED}错误: 主机名格式无效 (仅限字母数字及短横线)${CLR_RESET}\n" >&2; return 1
fi
hostnamectl set-hostname "$host" 2>/dev/null || { hostname "$host" 2>/dev/null || true; echo "$host" > /etc/hostname
}
if [ -f /etc/cloud/cloud.cfg ]; then
if grep -q "preserve_hostname" /etc/cloud/cloud.cfg 2>/dev/null; then
sed -i 's/^preserve_hostname:.*/preserve_hostname: true/' /etc/cloud/cloud.cfg 2>/dev/null || true
else
echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
fi
fi
sys_hosts_heal "$host"; printf "${CLR_GREEN}已修改主机名: %s${CLR_RESET}\n" "$host"
}
sys_pkgs(){ require_root; DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget git tar unzip zstd tmux vim htop btop jq socat bind9-dnsutils tree
}
sys_tune(){ require_root; modprobe tcp_bbr 2>/dev/null || true
    cat > /etc/security/limits.d/99-nofile.conf << 'EOF'
* soft nofile 65535
* hard nofile 65535
EOF
    cat > /etc/sysctl.d/99-sys-tune.conf << 'EOF'
fs.file-max = 65535
vm.swappiness = 10
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
sysctl --system; sys_hosts_heal
}
sys_shortcut(){ [ "$(id -u)" -eq 0 ] || return 0; local registered=0
if [ -f "$0" ] && [ "$0" != "bash" ] && [ "$0" != "sh" ]; then
local src=$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")
if [ "$src" != "/usr/local/bin/vs" ]; then
[ -f /usr/local/bin/vs ] || registered=1; cmp -s "$src" /usr/local/bin/vs 2>/dev/null || cp -f "$src" /usr/local/bin/vs
fi
elif [ ! -f /usr/local/bin/vs ]; then curl -fsSL "$VPS_RAW_URL/vps.sh" -o /usr/local/bin/vs 2>/dev/null && registered=1 || return 0
fi
chmod 755 /usr/local/bin/vs 2>/dev/null || true; [ -L /usr/bin/vs ] || ln -sf /usr/local/bin/vs /usr/bin/vs 2>/dev/null || true
[ "$registered" -eq 1 ] && echo -e "${CLR_CYAN}已注册全局命令: vs${CLR_RESET}" >&2 || true
}
sys_uninstall(){ require_root; read -r -p "确认卸载 vs? (y/N): " confirm
case "$confirm" in
[yY][eE][sS]|[yY])
local self=$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")
systemctl disable --now vps-firewall 2>/dev/null || true
rm -f /etc/systemd/system/vps-firewall.service /usr/local/bin/vs /usr/bin/vs 2>/dev/null || true
rm -rf /etc/vps-sh /run/vps-sh /tmp/.vps_* 2>/dev/null || true; systemctl daemon-reload 2>/dev/null || true
[ -f "$self" ] && rm -f "$self" 2>/dev/null || true; echo "已卸载"; exit 0; ;;
*)
echo "已取消"; ;;
esac
}
ui_sys_swap(){
while true; do
clear; printf "${CLR_BOLD}--- 虚拟内存 (Swap) ---${CLR_RESET}\n"; printf "${CLR_DIM}当前状态:${CLR_RESET} %s\n\n" "$(sys_swap_snapshot)"
printf "${CLR_CYAN}[1]${CLR_RESET} 配置 2GB\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 配置 4GB\n"
printf "${CLR_CYAN}[3]${CLR_RESET} 自定义大小 (MB)\n"; printf "${CLR_CYAN}[4]${CLR_RESET} 关闭并释放\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
read -r -p "请选择: " choice
case "$choice" in 1) sys_swap 2048 ;; 2) sys_swap 4096 ;; 3) read -r -p "大小 (MB): " mb && sys_swap "$mb" ;; 4) sys_swap_off ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_sys_tz(){
while true; do
clear; printf "${CLR_BOLD}--- 系统时区 ---${CLR_RESET}\n"; printf "${CLR_DIM}当前时区:${CLR_RESET} %s\n\n" "$(sys_tz_snapshot)"
printf "${CLR_CYAN}[1]${CLR_RESET} 设置为 Asia/Shanghai\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 恢复为 UTC (默认)\n"
printf "${CLR_CYAN}[3]${CLR_RESET} 自定义时区\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) sys_tz "Asia/Shanghai" ;; 2) sys_tz_utc ;; 3) read -r -p "时区 (如 America/New_York): " tz && sys_tz "$tz" ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_sys_hostname(){ clear; local cur_host=$(hostname 2>/dev/null || uname -n); printf "${CLR_BOLD}--- 主机名称 ---${CLR_RESET}\n"
printf "${CLR_DIM}当前主机名:${CLR_RESET} %s\n\n" "$cur_host"; read -r -p "新主机名 (回车取消): " host; [ -z "$host" ] && return 0; sys_hostname "$host"
read -r -p "按回车返回..."
}
ui_sys_update(){ clear; local os=$(grep -oP '(?<=PRETTY_NAME=")[^"]*' /etc/os-release 2>/dev/null || uname -sr); local kernel=$(uname -r)
local up_cnt=$(apt-get -s -o Debug::NoLocking=true upgrade 2>/dev/null | awk '/^[0-9]+ upgraded/ {print $1; exit}')
local status_str="组件处于最新状态"; [ -n "$up_cnt" ] && [ "$up_cnt" -gt 0 ] 2>/dev/null && status_str="${up_cnt} 个软件包可升级"
printf "${CLR_BOLD}--- 更新系统组件 ---${CLR_RESET}\n"; printf "${CLR_DIM}系统环境:${CLR_RESET} %s (%s)\n" "$os" "$kernel"
printf "${CLR_DIM}当前状态:${CLR_RESET} %s\n\n" "$status_str"; read -r -p "确认更新系统组件? (y/N, 回车取消): " confirm
case "$confirm" in
[yY][eE][sS]|[yY])
echo; sys_update; echo; printf "${CLR_GREEN}系统组件更新完成${CLR_RESET}\n"; ;;
*)
return 0; ;;
esac
read -r -p "按回车返回..."
}
ui_sys_pkgs(){ clear; local tools=("curl" "wget" "git" "tar" "unzip" "zstd" "tmux" "vim" "htop" "btop" "jq" "socat" "dig" "tree")
local missing=(); local installed=(); local t
for t in "${tools[@]}"; do
if command -v "$t" >/dev/null 2>&1; then
installed+=("$t")
else
missing+=("$t")
fi
done
printf "${CLR_BOLD}--- 基础工具 ---${CLR_RESET}\n"; printf "${CLR_DIM}已安装:${CLR_RESET} %d/%d" "${#installed[@]}" "${#tools[@]}"
[ "${#installed[@]}" -gt 0 ] && printf " (${CLR_GREEN}%s${CLR_RESET})" "${installed[*]}"; echo
if [ "${#missing[@]}" -gt 0 ]; then
printf "${CLR_DIM}待安装:${CLR_RESET} ${CLR_YELLOW}%s${CLR_RESET}\n\n" "${missing[*]}"
else
printf "${CLR_DIM}待安装:${CLR_RESET} ${CLR_GREEN}全部就绪${CLR_RESET}\n\n"
fi
read -r -p "确认安装基础工具? (y/N, 回车取消): " confirm
case "$confirm" in
[yY][eE][sS]|[yY])
echo; sys_pkgs; echo; printf "${CLR_GREEN}基础工具安装完成${CLR_RESET}\n"; ;;
*)
return 0; ;;
esac
read -r -p "按回车返回..."
}
ui_sys_tune(){ clear; local bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知"); local nofile=$(ulimit -n 2>/dev/null || echo "1024")
local swap_tune=$(sysctl -n vm.swappiness 2>/dev/null || echo "60"); local status_bbr="${CLR_YELLOW}未开启${CLR_RESET}"
[ "$bbr" = "bbr" ] && status_bbr="${CLR_GREEN}已启用 (bbr + $qdisc)${CLR_RESET}"; local status_nofile="${CLR_YELLOW}${nofile}${CLR_RESET}"
[ "$nofile" -ge 65535 ] 2>/dev/null && status_nofile="${CLR_GREEN}${nofile}${CLR_RESET}"
local status_swp="${CLR_YELLOW}${swap_tune}${CLR_RESET}"
[ "$swap_tune" -le 10 ] 2>/dev/null && status_swp="${CLR_GREEN}${swap_tune} (倾向物理内存)${CLR_RESET}"
printf "${CLR_BOLD}--- 系统性能调优 ---${CLR_RESET}\n"; printf "${CLR_DIM}BBR 加速:${CLR_RESET}   %b\n" "$status_bbr"
printf "${CLR_DIM}文件句柄:${CLR_RESET}   %b\n" "$status_nofile"; printf "${CLR_DIM}Swappiness:${CLR_RESET} %b\n\n" "$status_swp"
read -r -p "确认应用性能调优? (y/N, 回车取消): " confirm
case "$confirm" in
[yY][eE][sS]|[yY])
echo; sys_tune; echo; printf "${CLR_GREEN}系统性能调优已应用 (BBR / 65535 句柄 / Swappiness 优化)${CLR_RESET}\n"; ;;
*)
return 0; ;;
esac
read -r -p "按回车返回..."
}
ui_sys(){
while true; do
clear; printf "${CLR_BOLD}--- 系统配置 ---${CLR_RESET}\n\n"; printf "${CLR_CYAN}[1]${CLR_RESET} 虚拟内存 (Swap)\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 系统时区\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 主机名称\n"; printf "${CLR_CYAN}[4]${CLR_RESET} 更新系统组件\n"
printf "${CLR_CYAN}[5]${CLR_RESET} 安装基础工具\n"; printf "${CLR_CYAN}[6]${CLR_RESET} 系统性能调优\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
read -r -p "请选择: " choice
case "$choice" in 1) ui_sys_swap ;; 2) ui_sys_tz ;; 3) ui_sys_hostname ;; 4) ui_sys_update ;; 5) ui_sys_pkgs ;; 6) ui_sys_tune ;; 0|*) return ;; esac
done
}
net_dns_snapshot(){ grep -E '^nameserver' /etc/resolv.conf 2>/dev/null || echo "无"
}
net_dns_set(){ require_root; chattr -i /etc/resolv.conf 2>/dev/null || true; local servers=("$@"); > /etc/resolv.conf
for s in "${servers[@]}"; do
echo "nameserver $s" >> /etc/resolv.conf
done
}
net_dns_foreign(){ net_dns_set "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" "2001:4860:4860::8888"
}
net_dns_domestic(){ net_dns_set "223.5.5.5" "183.60.83.19" "2400:3200::1" "2400:da00::6666"
}
net_dns_restore(){ require_root; chattr -i /etc/resolv.conf 2>/dev/null || true
if [ -f /run/systemd/resolve/resolv.conf ]; then
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
else
net_dns_set "8.8.8.8" "1.1.1.1"
fi
}
net_priority_snapshot(){
if grep -Eq '^\s*precedence\s+::ffff:0:0/96\s+100' /etc/gai.conf 2>/dev/null; then
echo "IPv4 优先"
else
echo "IPv6 优先 (系统默认)"
fi
}
net_v4_first(){ require_root
sed -i -E 's/^#?precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' /etc/gai.conf 2>/dev/null || echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
}
net_v6_first(){ require_root
sed -i -E 's/^precedence ::ffff:0:0\/96  100/#precedence ::ffff:0:0\/96  100/' /etc/gai.conf 2>/dev/null || true
}
net_trace(){
if ! command -v nexttrace >/dev/null 2>&1; then
printf "${CLR_CYAN}正在下载安装 NextTrace...${CLR_RESET}\n"; curl -fsSLm 15 https://nxtrace.org/nt | bash || {
printf "${CLR_RED}错误: 安装 NextTrace 失败${CLR_RESET}\n" >&2; return 1
}
fi
local target="${1:-}"
if [ -n "$target" ]; then
nexttrace "$target"
else
nexttrace --fast-trace --tcp
fi
}
ui_dns(){
while true; do
clear; printf "${CLR_BOLD}--- DNS 配置 ---${CLR_RESET}\n"; printf "${CLR_DIM}当前 DNS:${CLR_RESET}\n"; net_dns_snapshot; echo
printf "${CLR_CYAN}[1]${CLR_RESET} 国外双栈 (Cloudflare / Google)\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 国内双栈 (Aliyun / DNSPod)\n"
printf "${CLR_CYAN}[3]${CLR_RESET} 自定义 DNS\n"; printf "${CLR_CYAN}[4]${CLR_RESET} 恢复默认\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
read -r -p "请选择: " choice
case "$choice" in 1) net_dns_foreign ;; 2) net_dns_domestic ;; 3) read -r -p "DNS 服务器 (空格隔开): " servers && net_dns_set $servers ;; 4) net_dns_restore ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_net_priority(){
while true; do
clear; printf "${CLR_BOLD}--- 出站优先级 ---${CLR_RESET}\n"; printf "${CLR_DIM}当前状态:${CLR_RESET} %s\n\n" "$(net_priority_snapshot)"
printf "${CLR_CYAN}[1]${CLR_RESET} IPv4 优先\n"; printf "${CLR_CYAN}[2]${CLR_RESET} IPv6 优先 (默认)\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) net_v4_first ;; 2) net_v6_first ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_net_trace(){
while true; do
clear; local cur_ip=$(echo "${SSH_CLIENT:-${SSH_CONNECTION:-}}" | awk '{print $1}'); local nt_status="未安装"
command -v nexttrace >/dev/null 2>&1 && nt_status="已就绪"; local local_ip="${VPS_IPV4_CACHE:-}"
if [ -z "$local_ip" ]; then
local_ip=$( (ip -4 route get 1.1.1.1 2>/dev/null || true) | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
if [ -z "$local_ip" ] || [[ "$local_ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.) ]]; then
local_ip=$(curl -s4m2 https://api.ipify.org 2>/dev/null || curl -s4m2 https://icanhazip.com 2>/dev/null || echo "未知")
fi
if [ "$local_ip" != "未知" ]; then
export VPS_IPV4_CACHE="$local_ip"
fi
fi
printf "${CLR_BOLD}--- 回程路由诊断 ---${CLR_RESET}\n"; printf "${CLR_DIM}本机 IPv4:${CLR_RESET}   %s\n" "$local_ip"
printf "${CLR_DIM}连接来源:${CLR_RESET}   %s\n" "${cur_ip:-本地控制台}"; printf "${CLR_DIM}NextTrace:${CLR_RESET}  %s\n\n" "$nt_status"
printf "${CLR_CYAN}[1]${CLR_RESET} 四网快速测试 (电信/联通/移动/教育网)\n"
[ -n "$cur_ip" ] && printf "${CLR_CYAN}[2]${CLR_RESET} 诊断到当前客户端 (%s)\n" "$cur_ip"; printf "${CLR_CYAN}[3]${CLR_RESET} 自定义目标 IP / 域名\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice; [ -z "$choice" ] && return 0
case "$choice" in
1)
echo; net_trace; echo; read -r -p "按回车返回..."; ;;
2)
if [ -n "$cur_ip" ]; then
echo; net_trace "$cur_ip"; echo; read -r -p "按回车返回..."
fi
;;
3)
read -r -p "目标 IP 或域名 (回车取消): " target
if [ -n "$target" ]; then
echo; net_trace "$target"; echo; read -r -p "按回车返回..."
fi
;; 0|*) return 0 ;;
esac
done
}
ui_net(){
while true; do
clear; printf "${CLR_BOLD}--- 网络配置 ---${CLR_RESET}\n\n"; printf "${CLR_CYAN}[1]${CLR_RESET} DNS 配置\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 出站协议优先级\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 回程路由诊断\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
read -r -p "请选择: " choice
case "$choice" in 1) ui_dns ;; 2) ui_net_priority ;; 3) ui_net_trace ;; 0|*) return ;; esac
done
}
sec_get_port(){ local p=$(sshd -T 2>/dev/null | awk '/^port / {print $2; exit}'); echo "${p:-22}"
}
sec_get_pwd(){ local a=$(sshd -T 2>/dev/null | awk '/^passwordauthentication / {print $2; exit}'); echo "${a:-yes}"
}
sec_get_root_login(){ local s=$(sshd -T 2>/dev/null | awk '/^permitrootlogin / {print $2; exit}'); echo "${s:-prohibit-password}"
}
sec_ssh_apply(){ local port="${1:-$(sec_get_port)}"; local pwd="${2:-$(sec_get_pwd)}"; local root="${3:-$(sec_get_root_login)}"
if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
printf "${CLR_RED}错误: 端口无效 (1-65535)${CLR_RESET}\n" >&2; return 1
fi
mkdir -p /etc/ssh/sshd_config.d; local conf="/etc/ssh/sshd_config.d/00-vps.conf"; local bak=""; [ -f "$conf" ] && bak=$(cat "$conf")
    cat > "$conf" << EOF
Port $port
PasswordAuthentication $pwd
PermitRootLogin $root
EOF
if ! sshd -t >/dev/null 2>&1; then
if [ -n "$bak" ]; then
echo "$bak" > "$conf"
else
rm -f "$conf"
fi
printf "${CLR_RED}错误: SSH 配置语法校验失败，已自动回滚${CLR_RESET}\n" >&2; return 1
fi
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
}
sec_port(){ require_root; local port="$1"
if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
printf "${CLR_RED}错误: 端口无效 (1-65535)${CLR_RESET}\n" >&2; return 1
fi
sec_ssh_apply "$port" "$(sec_get_pwd)" "$(sec_get_root_login)" || return 1
iptables -C VPS-IN -p tcp --dport "$port" -j ACCEPT 2>/dev/null || iptables -A VPS-IN -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
fw_save 2>/dev/null || true; [ -d /etc/fail2ban/jail.d ] && sec_f2b_sync 2>/dev/null || true
}
sec_port_restore(){ sec_port 22
}
sec_list_sudoers(){
awk -F: '
    FILENAME=="/etc/group" && ($1=="sudo" || $1=="wheel") {
        sudo_gid[$3]=1
        n=split($4, members, ",")
        for(i=1; i<=n; i++) if(members[i]!="") sudo_users[members[i]]=1
    }
    FILENAME=="/etc/passwd" && $3>=1000 && $3<60000 {
        if(sudo_gid[$4] || sudo_users[$1]) {
            if(!seen[$1]) { print $1; seen[$1]=1 }
        }
    }
    ' /etc/group /etc/passwd 2>/dev/null
for f in /etc/sudoers.d/90-*; do
if [ -f "$f" ]; then
local u="${f##*90-}"; [ -n "$u" ] && [ "$u" != "*" ] && id -u "$u" >/dev/null 2>&1 && echo "$u"
fi
done
}
sec_has_keys(){ local target="${1:-}"
if [ -n "$target" ]; then
local h="/root"; [ "$target" != "root" ] && h="/home/$target"; [ -s "$h/.ssh/authorized_keys" ]; return $?
fi
[ -s /root/.ssh/authorized_keys ] && return 0; local u
for u in $(sec_list_sudoers); do
[ -s "/home/$u/.ssh/authorized_keys" ] && return 0
done
return 1
}
sec_key(){ require_root; local key="$1"; local u="${2:-root}"; local h="/root"
if [ "$u" != "root" ]; then
id "$u" >/dev/null 2>&1 || return 1; h="/home/$u"
fi
local tmp=$(mktemp)
if [[ "$key" =~ ^https?:// ]]; then
curl -fsSLm 8 "$key" > "$tmp" || { rm -f "$tmp"; printf "${CLR_RED}错误: 获取公钥失败${CLR_RESET}\n" >&2; return 1; }
else
echo "$key" > "$tmp"
fi
if ! ssh-keygen -l -f "$tmp" >/dev/null 2>&1; then
rm -f "$tmp"; printf "${CLR_RED}错误: 公钥格式无效${CLR_RESET}\n" >&2; return 1
fi
mkdir -p "$h/.ssh"; chmod 700 "$h/.ssh"; cat "$tmp" >> "$h/.ssh/authorized_keys"; rm -f "$tmp"; chmod 600 "$h/.ssh/authorized_keys"
if [ "$u" != "root" ]; then
chown -R "$u:$u" "$h/.ssh"
fi
printf "${CLR_GREEN}已导入用户 %s 公钥${CLR_RESET}\n" "$u"
}
sec_gen_key(){ require_root; local u="${1:-root}"; local h="/root"
if [ "$u" != "root" ]; then
id "$u" >/dev/null 2>&1 || return 1; h="/home/$u"
fi
local priv="$h/.ssh/id_ed25519_vps"; local pub="$h/.ssh/id_ed25519_vps.pub"; mkdir -p "$h/.ssh"; chmod 700 "$h/.ssh"; rm -f "$priv" "$pub"
ssh-keygen -t ed25519 -N "" -f "$priv" -C "$u@$(hostname)" >/dev/null 2>&1; chmod 600 "$priv"; chmod 644 "$pub"
cat "$pub" >> "$h/.ssh/authorized_keys"; chmod 600 "$h/.ssh/authorized_keys"
if [ "$u" != "root" ]; then
chown -R "$u:$u" "$h/.ssh"; chmod 755 "$h" 2>/dev/null || true
fi
local port=$(sec_get_port)
local ip=$(curl -s4m2 https://api.ipify.org 2>/dev/null || curl -s4m2 https://icanhazip.com 2>/dev/null || echo "<服务器IP>"); clear
printf "\n${CLR_BOLD}--- 密钥对已生成: %s ---${CLR_RESET}\n\n" "$u"; cat "$priv"; echo
printf "\n${CLR_DIM}登录命令: ssh -i <私钥> -p %s %s@%s${CLR_RESET}\n" "$port" "$u" "$ip"
printf "${CLR_DIM}服务端已暂存: %s (验证成功后建议清除)${CLR_RESET}\n" "$priv"
}
sec_show_key(){ require_root; local u="${1:-root}"; local h="/root"
if [ "$u" != "root" ]; then
id "$u" >/dev/null 2>&1 || return 1; h="/home/$u"
fi
local priv="$h/.ssh/id_ed25519_vps"
if [ ! -f "$priv" ]; then
printf "${CLR_YELLOW}未找到用户 %s 的暂存私钥${CLR_RESET}\n" "$u"; return 0
fi
local port=$(sec_get_port)
local ip=$(curl -s4m2 https://api.ipify.org 2>/dev/null || curl -s4m2 https://icanhazip.com 2>/dev/null || echo "<服务器IP>"); clear
printf "\n${CLR_BOLD}--- 暂存私钥: %s ---${CLR_RESET}\n\n" "$u"; cat "$priv"; echo
printf "\n${CLR_DIM}登录命令: ssh -i <私钥> -p %s %s@%s${CLR_RESET}\n" "$port" "$u" "$ip"
}
sec_clean_key(){ require_root; local u="${1:-root}"; local h="/root"
if [ "$u" != "root" ]; then
id "$u" >/dev/null 2>&1 || return 1; h="/home/$u"
fi
local priv="$h/.ssh/id_ed25519_vps"; local pub="$h/.ssh/id_ed25519_vps.pub"; rm -f "$priv" "$pub"
printf "${CLR_GREEN}已清除用户 %s 的暂存私钥${CLR_RESET}\n" "$u"
}
sec_lock_pwd(){ require_root
if ! sec_has_keys; then
printf "${CLR_RED}错误: 未配置 SSH 公钥，禁止禁用密码${CLR_RESET}\n" >&2; return 1
fi
sec_ssh_apply "$(sec_get_port)" "no" "$(sec_get_root_login)"
}
sec_unlock_pwd(){ require_root; sec_ssh_apply "$(sec_get_port)" "yes" "$(sec_get_root_login)"
}
sec_root_login(){ require_root; local mode="$1"
if [ "$mode" = "no" ]; then
local sudoers=$(sec_list_sudoers)
if [ -z "$sudoers" ]; then
printf "${CLR_RED}错误: 无 sudo 用户，禁止禁用 Root 登录${CLR_RESET}\n" >&2; return 1
fi
if [ "$(sec_get_pwd)" = "no" ]; then
local has_user_key=0
for u in $sudoers; do
[ -s "/home/$u/.ssh/authorized_keys" ] && has_user_key=1 && break
done
if [ "$has_user_key" -eq 0 ]; then
printf "${CLR_RED}错误: sudo 用户未配置密钥，禁止禁用 Root 登录${CLR_RESET}\n" >&2; return 1
fi
fi
elif [ "$mode" = "prohibit-password" ] || [ "$mode" = "without-password" ]; then
if ! sec_has_keys root; then
printf "${CLR_RED}错误: Root 未配置公钥，无法设置为仅限密钥${CLR_RESET}\n" >&2; return 1
fi
fi
sec_ssh_apply "$(sec_get_port)" "$(sec_get_pwd)" "$mode"
}
sec_user_list(){ local root_key="否"; [ -s /root/.ssh/authorized_keys ] && root_key="是"
printf "%-16s | UID: %-5s | 权限: %-8s | 拥有密钥: %s\n" "root" "0" "特权" "$root_key"
awk -F: '$3 >= 1000 && $3 < 60000 {printf "%s %s\n", $1, $3}' /etc/passwd | while read -r u uid; do local perm="普通"
if [ -f "/etc/sudoers.d/90-$u" ]; then
perm="sudo (免密)"; elif id -nG "$u" 2>/dev/null | grep -Eq '\b(sudo|wheel)\b'; then perm="sudo (密码)"
fi
local has_key="否"; [ -s "/home/$u/.ssh/authorized_keys" ] && has_key="是"
printf "%-16s | UID: %-5s | 权限: %-8s | 拥有密钥: %s\n" "$u" "$uid" "$perm" "$has_key"
done
}
sec_passwd(){ require_root; local u="${1:-root}"
if ! id "$u" >/dev/null 2>&1; then
printf "${CLR_RED}错误: 用户 %s 不存在${CLR_RESET}\n" "$u" >&2; return 1
fi
read -r -s -p "输入用户 $u 的新密码: " p1; echo; read -r -s -p "再次确认新密码: " p2; echo
if [ "$p1" != "$p2" ] || [ -z "$p1" ]; then
printf "${CLR_RED}错误: 密码不一致或为空${CLR_RESET}\n" >&2; return 1
fi
echo "$u:$p1" | chpasswd; printf "${CLR_GREEN}已更新用户 %s 密码${CLR_RESET}\n" "$u"
}
sec_user_add(){ require_root; local u="$1"; local pwd="${2:-}"
if [[ ! "$u" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
printf "${CLR_RED}错误: 用户名格式无效${CLR_RESET}\n" >&2; return 1
fi
if ! id "$u" >/dev/null 2>&1; then
useradd -m -s /bin/bash "$u"
fi
if [ -n "$pwd" ]; then
echo "$u:$pwd" | chpasswd
else
usermod -p '*' "$u" 2>/dev/null || true
fi
chmod 755 "/home/$u" 2>/dev/null || true
if ! command -v sudo >/dev/null 2>&1; then
apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
fi
usermod -aG sudo "$u" 2>/dev/null || usermod -aG wheel "$u" 2>/dev/null || true; install -m 0440 /dev/null "/etc/sudoers.d/90-$u"
printf '%s\n' "$u ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/90-$u"
if ! visudo -cf "/etc/sudoers.d/90-$u" >/dev/null 2>&1; then
rm -f "/etc/sudoers.d/90-$u"; printf "${CLR_RED}错误: sudoers 语法校验失败${CLR_RESET}\n" >&2; return 1
fi
mkdir -p "/home/$u/.ssh"; chmod 700 "/home/$u/.ssh"
if [ -s /root/.ssh/authorized_keys ]; then
cp /root/.ssh/authorized_keys "/home/$u/.ssh/authorized_keys"
else
touch "/home/$u/.ssh/authorized_keys"
fi
chmod 600 "/home/$u/.ssh/authorized_keys"; chown -R "$u:$u" "/home/$u/.ssh"; printf "${CLR_GREEN}已创建 sudo 用户: %s${CLR_RESET}\n" "$u"
}
sec_user_del(){ require_root; local u="$1"
if [ -z "$u" ] || [ "$u" = "root" ]; then
printf "${CLR_RED}错误: 禁止删除 root${CLR_RESET}\n" >&2; return 1
fi
if [ "$u" = "${SUDO_USER:-}" ]; then
printf "${CLR_RED}错误: 禁止删除当前登录用户 (%s)${CLR_RESET}\n" "$u" >&2; return 1
fi
if ! id "$u" >/dev/null 2>&1; then
printf "${CLR_YELLOW}用户 %s 不存在${CLR_RESET}\n" "$u"; return 0
fi
rm -f "/etc/sudoers.d/90-$u"; pkill -u "$u" 2>/dev/null || true; userdel -r "$u" 2>/dev/null || true
printf "${CLR_GREEN}已删除用户 %s${CLR_RESET}\n" "$u"
}
sec_snapshot(){ local port="22" pwd_auth="yes" root_login="prohibit-password"
local parsed=$(sshd -T 2>/dev/null | awk '
        /^port / && !p {p=$2}
        /^passwordauthentication / && !a {a=$2}
        /^permitrootlogin / && !r {r=$2}
        END {printf "%s %s %s", (p?p:"22"), (a?a:"yes"), (r?r:"prohibit-password")}
    ')
[ -n "$parsed" ] && read -r port pwd_auth root_login <<< "$parsed"; local pwd_status="${CLR_GREEN}允许${CLR_RESET}"
[ "$pwd_auth" = "no" ] && pwd_status="${CLR_YELLOW}仅限密钥${CLR_RESET}"; local root_desc="${CLR_GREEN}允许${CLR_RESET}"
[ "$root_login" = "no" ] && root_desc="${CLR_RED}禁止${CLR_RESET}"
if [ "$root_login" = "prohibit-password" ] || [ "$root_login" = "without-password" ]; then
root_desc="${CLR_YELLOW}仅限密钥${CLR_RESET}"
fi
local sudoers=$(sec_list_sudoers | sort -u | tr '\n' ' ' | sed 's/ $//'); local user_desc="${CLR_DIM}无${CLR_RESET}"
[ -n "$sudoers" ] && user_desc="${CLR_CYAN}${sudoers} (sudo)${CLR_RESET}"; local fw_desc="${CLR_DIM}未配置${CLR_RESET}"
if iptables -L VPS-IN -n >/dev/null 2>&1; then
if iptables -S INPUT 2>/dev/null | grep -q '^-P INPUT DROP'; then
fw_desc="${CLR_GREEN}白名单模式${CLR_RESET}"
else
fw_desc="${CLR_YELLOW}黑名单模式${CLR_RESET}"
fi
fi
local f2b_desc="${CLR_DIM}未安装${CLR_RESET}"
if sec_f2b_is_installed; then
if sec_f2b_is_active; then
local banned=$(fail2ban-client status sshd 2>/dev/null | awk '/Currently banned:/ {print $NF}')
f2b_desc="${CLR_GREEN}运行中 (封禁 ${banned:-0})${CLR_RESET}"
else
f2b_desc="${CLR_YELLOW}已停止${CLR_RESET}"
fi
fi
printf "${CLR_BOLD}SSH 策略:${CLR_RESET} 端口 %s | 密码: %s | Root: %s\n" "$port" "$pwd_status" "$root_desc"
printf "${CLR_BOLD}系统账户:${CLR_RESET} root (特权) | %s\n" "$user_desc"
printf "${CLR_BOLD}安全防御:${CLR_RESET} 防火墙: %s | Fail2ban: %s\n" "$fw_desc" "$f2b_desc"; local conflict=$(fw_conflict || true)
if [ -n "$conflict" ]; then
local cname="UFW"; [ "$conflict" = "firewalld" ] && cname="Firewalld"
printf "${CLR_RED}${CLR_BOLD}[警告] %s 运行中，与防火墙规则冲突${CLR_RESET}\n" "$cname"
fi
}
sec_f2b_is_installed(){ command -v fail2ban-client >/dev/null 2>&1
}
sec_f2b_is_active(){ systemctl is-active --quiet fail2ban 2>/dev/null
}
sec_f2b_snapshot(){
if ! sec_f2b_is_installed; then
printf "${CLR_BOLD}状态:${CLR_RESET} ${CLR_DIM}未安装${CLR_RESET}\n"; return 0
fi
local active="已停止"; sec_f2b_is_active && active="运行中"; local ssh_port=$(sec_get_port); local cur=0 total=0
if [ "$active" = "运行中" ]; then
local raw=$(fail2ban-client status sshd 2>/dev/null || true); cur=$(echo "$raw" | awk '/Currently banned:/ {print $NF}')
total=$(echo "$raw" | awk '/Total banned:/ {print $NF}')
fi
local cur_ip=$(echo "${SSH_CLIENT:-${SSH_CONNECTION:-}}" | awk '{print $1}'); [ -z "$cur_ip" ] && cur_ip="本地控制台"; local wl="无"
[ -f /etc/fail2ban/whitelist.ips ] && wl=$(tr '\n' ' ' < /etc/fail2ban/whitelist.ips | sed 's/[[:space:]]*$//'); [ -n "$wl" ] || wl="无"
printf "${CLR_BOLD}状态:${CLR_RESET} %s | ${CLR_BOLD}端口:${CLR_RESET} %s | ${CLR_BOLD}来源:${CLR_RESET} %s\n" "$active" "$ssh_port" "$cur_ip"
printf "${CLR_BOLD}白名单:${CLR_RESET} %s\n" "$wl"
printf "${CLR_BOLD}当前封禁:${CLR_RESET} %s | ${CLR_BOLD}累计封禁:${CLR_RESET} %s\n" "${cur:-0}" "${total:-0}"
}
sec_f2b_sync(){ require_root; sys_hosts_heal; local ssh_port=$(sec_get_port)
local cur_ip=$(echo "${SSH_CLIENT:-${SSH_CONNECTION:-}}" | awk '{print $1}'); local extra=""; [ -n "$cur_ip" ] && extra=" $cur_ip"
if [ -f /etc/fail2ban/whitelist.ips ]; then
local clean_wl=$(grep -E '^[0-9a-fA-F:\./]+$' /etc/fail2ban/whitelist.ips 2>/dev/null | tr '\n' ' ' || true)
[ -n "$clean_wl" ] && extra="$extra $clean_wl"
fi
mkdir -p /etc/fail2ban/jail.d
    cat > /etc/fail2ban/jail.d/sshd.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1$extra
bantime = 1d
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = $ssh_port
backend = systemd
mode = normal
EOF
systemctl enable fail2ban 2>/dev/null || true; systemctl restart fail2ban 2>/dev/null || true
if [ -n "$cur_ip" ]; then
fail2ban-client set sshd unbanip "$cur_ip" 2>/dev/null || true
fi
printf "${CLR_GREEN}已同步 Fail2ban (端口: %s)${CLR_RESET}\n" "$ssh_port"
}
sec_f2b_install(){ require_root; DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban; sec_f2b_sync
}
sec_f2b(){ sec_f2b_install
}
sec_f2b_allow(){ require_root; mkdir -p /etc/fail2ban
for ip in "$@"; do
if [[ "$ip" =~ ^[0-9a-fA-F:\./]+$ ]]; then
echo "$ip" >> /etc/fail2ban/whitelist.ips; fail2ban-client set sshd unbanip "$ip" 2>/dev/null || true
fi
done
sort -u /etc/fail2ban/whitelist.ips -o /etc/fail2ban/whitelist.ips 2>/dev/null || true; sec_f2b_sync
}
sec_f2b_disallow(){ require_root; [ -f /etc/fail2ban/whitelist.ips ] || return 0
for ip in "$@"; do
local tmp=$(mktemp); grep -vFx "$ip" /etc/fail2ban/whitelist.ips > "$tmp" 2>/dev/null || true; mv "$tmp" /etc/fail2ban/whitelist.ips
done
sec_f2b_sync
}
sec_f2b_ban(){ require_root
for ip in "$@"; do
fail2ban-client set sshd banip "$ip" || true
done
}
sec_f2b_unban(){ require_root
for ip in "$@"; do
fail2ban-client set sshd unbanip "$ip" || true
done
}
sec_f2b_unban_all(){ require_root; systemctl stop fail2ban 2>/dev/null || true; rm -f /var/lib/fail2ban/fail2ban.sqlite3; sec_f2b_sync
printf "${CLR_GREEN}已清空封禁记录${CLR_RESET}\n"
}
sec_f2b_log(){
if [ -f /var/log/fail2ban.log ]; then
tail -n 25 /var/log/fail2ban.log
else
journalctl -u fail2ban -n 25 --no-pager 2>/dev/null || echo "暂无日志"
fi
}
sec_f2b_toggle(){ require_root
if systemctl is-active --quiet fail2ban; then
systemctl stop fail2ban; printf "${CLR_YELLOW}已停止 Fail2ban${CLR_RESET}\n"
else
sec_f2b_sync; printf "${CLR_GREEN}已启动 Fail2ban${CLR_RESET}\n"
fi
}
sec_f2b_uninstall(){ require_root; systemctl disable --now fail2ban 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt-get purge -y fail2ban 2>/dev/null || true; rm -rf /etc/fail2ban /var/lib/fail2ban 2>/dev/null || true
printf "${CLR_GREEN}已卸载 Fail2ban${CLR_RESET}\n"
}
ui_sec_port(){
while true; do
clear; local cur_port=$(sec_get_port); printf "${CLR_BOLD}--- SSH 端口 ---${CLR_RESET}\n"
printf "${CLR_DIM}当前端口:${CLR_RESET} %s\n\n" "$cur_port"; printf "${CLR_CYAN}[1]${CLR_RESET} 修改端口\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 恢复默认 (22)\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) read -r -p "端口 (1-65535): " p && sec_port "$p" ;; 2) sec_port_restore ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_sec_pwd(){
while true; do
clear; local pwd_status="允许密码登录"; [ "$(sec_get_pwd)" = "no" ] && pwd_status="已锁定 (仅限密钥)"; printf "${CLR_BOLD}--- 密码登录 ---${CLR_RESET}\n"
printf "${CLR_DIM}当前状态:${CLR_RESET} %s\n\n" "$pwd_status"; printf "${CLR_CYAN}[1]${CLR_RESET} 禁用密码登录\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 允许密码登录\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) sec_lock_pwd ;; 2) sec_unlock_pwd ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_sec_root(){
while true; do
clear; local root_status=$(sec_get_root_login); local status_str="仅限密钥 (prohibit-password)"
[ "$root_status" = "yes" ] && status_str="允许密码与密钥"; [ "$root_status" = "no" ] && status_str="完全禁止"
printf "${CLR_BOLD}--- Root 登录 ---${CLR_RESET}\n"; printf "${CLR_DIM}当前状态:${CLR_RESET} %s\n\n" "$status_str"
printf "${CLR_CYAN}[1]${CLR_RESET} 禁止登录\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 仅限密钥\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 允许密码与密钥\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) sec_root_login "no" ;; 2) sec_root_login "prohibit-password" ;; 3) sec_root_login "yes" ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_sec_account(){
while true; do
clear; printf "${CLR_BOLD}--- 用户管理 ---${CLR_RESET}\n\n"; printf "${CLR_DIM}账户列表:${CLR_RESET}\n"; sec_user_list; echo
printf "${CLR_CYAN}[1]${CLR_RESET} 创建用户\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 修改密码\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 管理密钥\n"
printf "${CLR_CYAN}[4]${CLR_RESET} 删除用户\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in
1)
read -r -p "用户名: " uname; [ -z "$uname" ] && continue; read -r -s -p "密码 (留空仅限密钥): " upass; echo; sec_user_add "$uname" "$upass"
if ! sec_has_keys "$uname"; then
echo; read -r -p "是否为 $uname 生成密钥对? (Y/n): " gen_key
case "$gen_key" in
n|N) ;; *) sec_gen_key "$uname" ;;
esac
fi
;;
2)
read -r -p "用户名 (默认 root): " uname; sec_passwd "${uname:-root}"; ;;
3)
read -r -p "用户名 (默认 root): " uname; ui_sec_key "${uname:-root}"; ;;
4)
read -r -p "删除用户名: " uname; [ -n "$uname" ] && sec_user_del "$uname"; ;; 0|*) return ;;
esac
read -r -p "按回车返回..."
done
}
ui_sec_user(){ ui_sec_account
}
ui_sec_key(){ local target_user="${1:-}"
while true; do
clear; printf "${CLR_BOLD}--- 密钥管理 ---${CLR_RESET}\n\n"; printf "${CLR_CYAN}[1]${CLR_RESET} 生成密钥对\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 查看暂存私钥\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 清除暂存私钥\n"; printf "${CLR_CYAN}[4]${CLR_RESET} 导入公钥\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in
1)
local u="$target_user"; [ -z "$u" ] && read -r -p "用户名 (默认 root): " u; sec_gen_key "${u:-root}"; ;;
2)
local u="$target_user"; [ -z "$u" ] && read -r -p "用户名 (默认 root): " u; sec_show_key "${u:-root}"; ;;
3)
local u="$target_user"; [ -z "$u" ] && read -r -p "用户名 (默认 root): " u; sec_clean_key "${u:-root}"; ;;
4)
local u="$target_user"; [ -z "$u" ] && read -r -p "用户名 (默认 root): " u; read -r -p "公钥内容 (文本或 GitHub .keys 链接): " key
[ -n "$key" ] && sec_key "$key" "${u:-root}"; ;; 0|*) return ;;
esac
read -r -p "按回车返回..."
done
}
ui_ssh(){
while true; do
clear; local port=$(sec_get_port); local pwd_status="允许密码"; [ "$(sec_get_pwd)" = "no" ] && pwd_status="仅限密钥"
local root_status=$(sec_get_root_login); local root_str="仅限密钥"; [ "$root_status" = "yes" ] && root_str="允许登录"
[ "$root_status" = "no" ] && root_str="禁止登录"; printf "${CLR_BOLD}--- SSH 加固 ---${CLR_RESET}\n\n"
printf "${CLR_DIM}当前策略:${CLR_RESET} 端口 %s | 密码: %s | Root: %s\n\n" "$port" "$pwd_status" "$root_str"
printf "${CLR_CYAN}[1]${CLR_RESET} SSH 端口\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 密码登录\n"; printf "${CLR_CYAN}[3]${CLR_RESET} Root 登录\n"
printf "${CLR_CYAN}[4]${CLR_RESET} 密钥管理\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) ui_sec_port ;; 2) ui_sec_pwd ;; 3) ui_sec_root ;; 4) ui_sec_key ;; 0|*) return ;; esac
done
}
ui_sec(){
while true; do
clear; printf "${CLR_BOLD}--- 安全防护 ---${CLR_RESET}\n\n"; sec_snapshot; echo; printf "${CLR_CYAN}[1]${CLR_RESET} SSH 加固\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 用户管理\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 防火墙 (iptables)\n"
printf "${CLR_CYAN}[4]${CLR_RESET} 防爆破 (Fail2ban)\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) ui_ssh ;; 2) ui_sec_account ;; 3) ui_fw ;; 4) ui_sec_f2b ;; 0|*) return ;; esac
done
}
ui_sec_f2b(){
while true; do
clear; printf "${CLR_BOLD}--- 防爆破 (Fail2ban) ---${CLR_RESET}\n\n"; sec_f2b_snapshot; echo
if ! sec_f2b_is_installed; then
printf "${CLR_CYAN}[1]${CLR_RESET} 安装并启用 Fail2ban\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) sec_f2b_install && read -r -p "按回车返回..." ;; 0|*) return ;; esac
else
local f2b_action="启动服务"; sec_f2b_is_active && f2b_action="停止服务"; printf "${CLR_CYAN}[1]${CLR_RESET} 同步配置并重启\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 解封 IP\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 解封全部 IP\n"; printf "${CLR_CYAN}[4]${CLR_RESET} 添加白名单\n"
printf "${CLR_CYAN}[5]${CLR_RESET} 移除白名单\n"; printf "${CLR_CYAN}[6]${CLR_RESET} 拦截日志\n"
printf "${CLR_CYAN}[7]${CLR_RESET} %s\n" "$f2b_action"; printf "${CLR_CYAN}[8]${CLR_RESET} 卸载 Fail2ban\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in
1) sec_f2b_sync && read -r -p "按回车返回..." ;;
2)
local cur_banned=$(fail2ban-client status sshd 2>/dev/null | awk '/Banned IP list:/ {sub(/.*Banned IP list:[[:space:]]*/, ""); print $0}')
[ -n "$cur_banned" ] && printf "${CLR_DIM}当前封禁: %s${CLR_RESET}\n" "$cur_banned"
read -r -p "解封 IP (空格隔开): " ips && [ -n "$ips" ] && sec_f2b_unban $ips && read -r -p "按回车返回..."; ;;
3) sec_f2b_unban_all && read -r -p "按回车返回..." ;;
4) read -r -p "加白 IP/网段: " ips && [ -n "$ips" ] && sec_f2b_allow $ips && read -r -p "按回车返回..." ;;
5) read -r -p "移除白名单 IP: " ips && [ -n "$ips" ] && sec_f2b_disallow $ips && read -r -p "按回车返回..." ;;
6) sec_f2b_log && echo && read -r -p "按回车返回..." ;; 7) sec_f2b_toggle && read -r -p "按回车返回..." ;;
8) sec_f2b_uninstall && read -r -p "按回车返回..." ;; 0|*) return ;;
esac
fi
done
}
fw_is_installed(){ command -v iptables >/dev/null 2>&1 && command -v ipset >/dev/null 2>&1
}
fw_is_initialized(){ iptables -L VPS-IN -n >/dev/null 2>&1
}
fw_conflict(){
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
echo "ufw"; return 0
fi
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
echo "firewalld"; return 0
fi
return 1
}
fw_resolve_conflict(){ require_root; local c=$(fw_conflict || true)
if [ "$c" = "ufw" ]; then
ufw disable 2>/dev/null || true; systemctl disable ufw 2>/dev/null || true; printf "${CLR_GREEN}已停用 UFW${CLR_RESET}\n"
elif [ "$c" = "firewalld" ]; then systemctl disable --now firewalld 2>/dev/null || true; printf "${CLR_GREEN}已停用 Firewalld${CLR_RESET}\n"
fi
fw_install
}
fw_install(){ require_root
if ! fw_is_installed; then
DEBIAN_FRONTEND=noninteractive apt-get update -y 2>/dev/null || true; DEBIAN_FRONTEND=noninteractive apt-get install -y iptables ipset
fi
fw_init; fw_save; printf "${CLR_GREEN}防火墙初始化完成${CLR_RESET}\n"
}
fw_init(){ ipset create vps_whitelist hash:net 2>/dev/null || true; ipset create vps_blacklist hash:net 2>/dev/null || true
iptables -w 2 -N VPS-IN 2>/dev/null || true; iptables -w 2 -C INPUT -j VPS-IN 2>/dev/null || iptables -w 2 -I INPUT 1 -j VPS-IN
iptables -w 2 -C VPS-IN -i lo -j ACCEPT 2>/dev/null || iptables -w 2 -A VPS-IN -i lo -j ACCEPT
iptables -w 2 -C VPS-IN -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -w 2 -A VPS-IN -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -w 2 -C VPS-IN -m set --match-set vps_blacklist src -j DROP 2>/dev/null || iptables -w 2 -A VPS-IN -m set --match-set vps_blacklist src -j DROP
iptables -w 2 -C VPS-IN -m set --match-set vps_whitelist src -j ACCEPT 2>/dev/null || iptables -w 2 -A VPS-IN -m set --match-set vps_whitelist src -j ACCEPT
local ssh_port=$(sec_get_port)
iptables -w 2 -C VPS-IN -p tcp --dport "$ssh_port" -j ACCEPT 2>/dev/null || iptables -w 2 -A VPS-IN -p tcp --dport "$ssh_port" -j ACCEPT
}
fw_save(){ require_root; mkdir -p /etc/iptables; iptables-save > /etc/iptables/rules.v4
ipset save > /etc/iptables/ipset.rules 2>/dev/null || true
if [ ! -f /etc/systemd/system/vps-firewall.service ]; then
        cat > /etc/systemd/system/vps-firewall.service << 'EOF'
[Unit]
Description=VPS Native Firewall Persistence
Before=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'which ipset >/dev/null && [ -f /etc/iptables/ipset.rules ] && ipset restore -exist < /etc/iptables/ipset.rules 2>/dev/null || true; [ -f /etc/iptables/rules.v4 ] && iptables-restore < /etc/iptables/rules.v4 2>/dev/null || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 2>/dev/null || true; systemctl enable vps-firewall 2>/dev/null || true
fi
which netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save 2>/dev/null || true
}
fw_get_ping(){
if iptables -w 2 -C VPS-IN -p icmp --icmp-type echo-request -j DROP 2>/dev/null; then
echo "drop"
else
echo "accept"
fi
}
fw_get_ddos(){
if iptables -w 2 -C VPS-IN -p tcp --syn -j DROP 2>/dev/null; then
echo "on"
else
echo "off"
fi
}
fw_snapshot(){
if ! fw_is_installed; then
local missing=""; command -v iptables >/dev/null 2>&1 || missing="iptables "; command -v ipset >/dev/null 2>&1 || missing="${missing}ipset"
printf "${CLR_BOLD}状态:${CLR_RESET} ${CLR_DIM}未安装 (缺失: %s)${CLR_RESET}\n" "$missing"; return 0
fi
local conflict=$(fw_conflict || true)
if [ -n "$conflict" ]; then
local cname="UFW"; [ "$conflict" = "firewalld" ] && cname="Firewalld"
printf "${CLR_BOLD}状态:${CLR_RESET} ${CLR_RED}冲突 (%s 运行中)${CLR_RESET}\n" "$cname"; return 0
fi
if ! fw_is_initialized; then
printf "${CLR_BOLD}状态:${CLR_RESET} ${CLR_YELLOW}未初始化${CLR_RESET}\n"; return 0
fi
local ssh_port=$(sec_get_port); local ipt_rules=$(iptables -S 2>/dev/null || true)
local in_policy=$(awk '/^-P INPUT/ {print $3}' <<< "$ipt_rules"); local policy_desc="默认丢弃 (DROP)"
[ "$in_policy" = "ACCEPT" ] && policy_desc="默认放行 (ACCEPT)"
local bans=$( (ipset list -t vps_blacklist 2>/dev/null || true) | awk '/Number of entries:/ {print $NF}')
local allows=$( (ipset list -t vps_whitelist 2>/dev/null || true) | awk '/Number of entries:/ {print $NF}'); local ping_status="允许"
if grep -qE '^-A VPS-IN -p icmp .*-j DROP' <<< "$ipt_rules"; then
ping_status="已拦截"
fi
local ddos_status="已关闭"
if grep -qE '^-A VPS-IN -p tcp .*(SYN|--syn) -j DROP' <<< "$ipt_rules"; then
ddos_status="已开启"
fi
printf "${CLR_BOLD}入站:${CLR_RESET} %s | ${CLR_BOLD}Ping:${CLR_RESET} %s | ${CLR_BOLD}防DDoS:${CLR_RESET} %s\n" "$policy_desc" "$ping_status" "$ddos_status"
printf "${CLR_BOLD}黑名单:${CLR_RESET} %s IP | ${CLR_BOLD}白名单:${CLR_RESET} %s IP\n\n" "${bans:-0}" "${allows:-0}"
printf " ${CLR_DIM}%-9s %-18s %s${CLR_RESET}\n" "协议" "目标/端口" "说明"; printf " %s\n" "----------------------------------------------------"
printf " %-9s %-18s %s\n" "all" "127.0.0.1 (lo)" "本地回环"; printf " %-9s %-18s %s\n" "all" "ESTABLISHED" "已建连接"
printf " %-9s %-18s %s\n" "tcp" "$ssh_port" "SSH 保护"
printf "%s\n" "$ipt_rules" | awk -v ssh="$ssh_port" '
    /^-A (INPUT|VPS-IN)/ && /-j ACCEPT/ {
        proto=""; port=""
        for(i=1;i<=NF;i++) {
            if($i=="-p") proto=$(i+1)
            if($i=="--dport") port=$(i+1)
        }
        if((proto=="tcp" || proto=="udp") && port!="" && port!=ssh) {
            if(!seen[port]) { order[count++]=port; seen[port]=1 }
            if(proto=="tcp") has_tcp[port]=1
            if(proto=="udp") has_udp[port]=1
        }
    }
    END {
        for(i=0; i<count; i++) {
            p=order[i]
            if(has_tcp[p] && has_udp[p]) pr="tcp/udp"
            else if(has_tcp[p]) pr="tcp"
            else if(has_udp[p]) pr="udp"
            else pr="unknown"
            printf " %-9s %-18s %s\n", pr, p, "放行"
        }
    }'
printf " %s\n\n" "----------------------------------------------------"
}
fw_open(){ require_root; fw_init
for p in "$@"; do
if [[ ! "$p" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
printf "${CLR_RED}错误: 端口格式无效 (%s)${CLR_RESET}\n" "$p" >&2; continue
fi
iptables -w 2 -C VPS-IN -p tcp --dport "$p" -j ACCEPT 2>/dev/null || iptables -w 2 -A VPS-IN -p tcp --dport "$p" -j ACCEPT
iptables -w 2 -C VPS-IN -p udp --dport "$p" -j ACCEPT 2>/dev/null || iptables -w 2 -A VPS-IN -p udp --dport "$p" -j ACCEPT
done
fw_save
}
fw_close(){ require_root; local ssh_port=$(sec_get_port)
for p in "$@"; do
if [ "$p" = "$ssh_port" ]; then
echo "跳过 SSH 端口 ($p)" >&2; continue
fi
(iptables -S 2>/dev/null || true) | awk -v target="$p" '
        /^-A (INPUT|VPS-IN)/ && /-j ACCEPT/ && /--dport/ {
            for(i=1;i<=NF;i++) {
                if($i=="--dport") {
                    val=$(i+1)
                    if(val==target || (target=="443" && val=="https") || (target=="80" && val=="http") || (target=="https" && val=="443") || (target=="http" && val=="80")) {
                        print $0
                    }
                }
            }
        }' | while read -r line; do
[ -n "$line" ] && iptables -w 2 -D ${line#-A } 2>/dev/null || true
done
done
fw_save
}
fw_open_all(){ require_root; iptables -w 2 -P INPUT ACCEPT; fw_save
}
fw_close_all(){ require_root; iptables -w 2 -P INPUT ACCEPT; iptables -w 2 -F INPUT; iptables -w 2 -F VPS-IN 2>/dev/null || true
iptables -w 2 -X VPS-IN 2>/dev/null || true; fw_init; iptables -w 2 -P INPUT DROP; fw_save
}
fw_ban_ip(){ require_root; fw_init
for ip in "$@"; do
ipset del vps_whitelist "$ip" -exist 2>/dev/null || true; ipset add vps_blacklist "$ip" -exist 2>/dev/null || true
done
fw_save
}
fw_allow_ip(){ require_root; fw_init
for ip in "$@"; do
ipset del vps_blacklist "$ip" -exist 2>/dev/null || true; ipset add vps_whitelist "$ip" -exist 2>/dev/null || true
done
fw_save
}
fw_unban_ip(){ require_root
for ip in "$@"; do
ipset del vps_blacklist "$ip" -exist 2>/dev/null || true; ipset del vps_whitelist "$ip" -exist 2>/dev/null || true
done
fw_save
}
fw_ping(){ require_root; fw_init; local state="${1:-toggle}"
if [ "$state" = "toggle" ]; then
[ "$(fw_get_ping)" = "drop" ] && state="on" || state="off"
fi
if [ "$state" = "off" ]; then
iptables -w 2 -C VPS-IN -p icmp --icmp-type echo-request -j DROP 2>/dev/null || iptables -w 2 -A VPS-IN -p icmp --icmp-type echo-request -j DROP
else
iptables -w 2 -D VPS-IN -p icmp --icmp-type echo-request -j DROP 2>/dev/null || true
fi
fw_save
}
fw_ddos(){ require_root; fw_init; local state="${1:-toggle}"
if [ "$state" = "toggle" ]; then
[ "$(fw_get_ddos)" = "on" ] && state="off" || state="on"
fi
if [ "$state" = "on" ]; then
iptables -w 2 -C VPS-IN -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null || iptables -w 2 -I VPS-IN 1 -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
iptables -w 2 -C VPS-IN -p tcp --syn -j DROP 2>/dev/null || iptables -w 2 -I VPS-IN 2 -p tcp --syn -j DROP
iptables -w 2 -C VPS-IN -p udp -m limit --limit 3000/s --limit-burst 500 -j ACCEPT 2>/dev/null || iptables -w 2 -I VPS-IN 3 -p udp -m limit --limit 3000/s --limit-burst 500 -j ACCEPT
iptables -w 2 -C VPS-IN -p udp -j DROP 2>/dev/null || iptables -w 2 -I VPS-IN 4 -p udp -j DROP
if iptables -w 2 -L DOCKER-USER -n >/dev/null 2>&1; then
iptables -w 2 -C DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null || iptables -w 2 -I DOCKER-USER 1 -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
iptables -w 2 -C DOCKER-USER -p tcp --syn -j DROP 2>/dev/null || iptables -w 2 -I DOCKER-USER 2 -p tcp --syn -j DROP
iptables -w 2 -C DOCKER-USER -p udp -m limit --limit 3000/s --limit-burst 500 -j ACCEPT 2>/dev/null || iptables -w 2 -I DOCKER-USER 3 -p udp -m limit --limit 3000/s --limit-burst 500 -j ACCEPT
iptables -w 2 -C DOCKER-USER -p udp -j DROP 2>/dev/null || iptables -w 2 -I DOCKER-USER 4 -p udp -j DROP
fi
else
iptables -w 2 -D VPS-IN -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null || true
iptables -w 2 -D VPS-IN -p tcp --syn -j DROP 2>/dev/null || true
iptables -w 2 -D VPS-IN -p udp -m limit --limit 3000/s --limit-burst 500 -j ACCEPT 2>/dev/null || true
iptables -w 2 -D VPS-IN -p udp -j DROP 2>/dev/null || true
if iptables -w 2 -L DOCKER-USER -n >/dev/null 2>&1; then
iptables -w 2 -D DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null || true
iptables -w 2 -D DOCKER-USER -p tcp --syn -j DROP 2>/dev/null || true
iptables -w 2 -D DOCKER-USER -p udp -m limit --limit 3000/s --limit-burst 500 -j ACCEPT 2>/dev/null || true
iptables -w 2 -D DOCKER-USER -p udp -j DROP 2>/dev/null || true
fi
fi
fw_save
}
fw_reset(){ require_root; fw_close_all; ipset flush vps_blacklist 2>/dev/null || true; ipset flush vps_whitelist 2>/dev/null || true
fw_init; fw_save
}
ui_fw(){
while true; do
clear; printf "${CLR_BOLD}--- 防火墙 (iptables) ---${CLR_RESET}\n\n"; fw_snapshot; echo; local conflict=$(fw_conflict || true)
if [ -n "$conflict" ]; then
local cname="UFW"; [ "$conflict" = "firewalld" ] && cname="Firewalld"; printf "${CLR_YELLOW}冲突: %s 正在运行${CLR_RESET}\n\n" "$cname"
printf "${CLR_CYAN}[1]${CLR_RESET} 停用 %s 并接管\n" "$cname"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) fw_resolve_conflict && read -r -p "按回车返回..." ;; 0|*) return ;; esac
elif ! fw_is_installed || ! fw_is_initialized; then printf "${CLR_CYAN}[1]${CLR_RESET} 初始化防火墙\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
read -r -p "请选择: " choice
case "$choice" in 1) fw_install && read -r -p "按回车返回..." ;; 0|*) return ;; esac
else
local ping_action="禁 Ping: 开启"; [ "$(fw_get_ping)" = "drop" ] && ping_action="禁 Ping: 关闭"; local ddos_action="防 DDoS 限流: 开启"
[ "$(fw_get_ddos)" = "on" ] && ddos_action="防 DDoS 限流: 关闭"; printf "${CLR_CYAN}[1]${CLR_RESET} 放行端口\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 关闭端口\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 放行全部端口\n"; printf "${CLR_CYAN}[4]${CLR_RESET} 关闭全部端口\n"
printf "${CLR_CYAN}[5]${CLR_RESET} 封禁 IP (黑名单)\n"; printf "${CLR_CYAN}[6]${CLR_RESET} 放行 IP (白名单)\n"
printf "${CLR_CYAN}[7]${CLR_RESET} 移除 IP 限制\n"; printf "${CLR_CYAN}[8]${CLR_RESET} %s\n" "$ping_action"
printf "${CLR_CYAN}[9]${CLR_RESET} %s\n" "$ddos_action"; printf "${CLR_CYAN}[10]${CLR_RESET} 重置规则\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) read -r -p "放行端口 (空格隔开/如 80 443 1000:2000): " port && [ -n "$port" ] && fw_open $port ;; 2) read -r -p "关闭端口 (空格隔开): " port && [ -n "$port" ] && fw_close $port ;; 3) fw_open_all ;; 4) fw_close_all ;; 5) read -r -p "封禁 IP/网段: " ip && [ -n "$ip" ] && fw_ban_ip $ip ;; 6) read -r -p "放行 IP/网段: " ip && [ -n "$ip" ] && fw_allow_ip $ip ;; 7) read -r -p "移除 IP: " ip && [ -n "$ip" ] && fw_unban_ip $ip ;; 8) fw_ping toggle; continue ;; 9) fw_ddos toggle; continue ;; 10) fw_reset ;; 0|*) return ;; esac
read -r -p "按回车返回..."
fi
done
}
ops_snapshot(){ local ports=$(ss -tulpn 2>/dev/null | awk 'NR>1 {c++} END {print c+0}')
local crons=$(crontab -l 2>/dev/null | awk '!/^[[:space:]]*(#|$)/ {c++} END {print c+0}')
local logs=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGTPBkmgtpb]' | head -n 1)
[ -z "$logs" ] && logs=$(du -sh /var/log 2>/dev/null | awk '{print $1}')
printf "${CLR_BOLD}运维状态:${CLR_RESET} 端口: %s | 定时任务: %s | 日志: %s\n" "$ports" "$crons" "${logs:-0B}"
}
ops_ports(){ local raw="${1:-$(ss -tulpn 2>/dev/null || true)}"
printf "  ${CLR_DIM}%-6s %-7s %-20s %s${CLR_RESET}\n" "协议" "端口" "监听地址" "服务进程"
printf "  %s\n" "--------------------------------------------------------"
printf "%s\n" "$raw" | awk 'NR>1 {
        proto=$1
        sub(/tcp.*/, "tcp", proto)
        sub(/udp.*/, "udp", proto)
        laddr=$5
        n=split(laddr, a, ":")
        port=a[n]
        ip=""
        for(i=1;i<n;i++) { ip = (ip=="" ? a[i] : ip ":" a[i]) }
        if(ip=="") ip="*"
        scope="公网"
        if(ip ~ /^(127\.|::1$)/) scope="本地"
        proc=$7
        pname="-"
        if(match(proc, /"([^"]+)"/)) {
            s=substr(proc, RSTART+1, RLENGTH-2)
            pname=s
        }
        if(match(proc, /pid=([0-9]+)/)) {
            s=substr(proc, RSTART+4, RLENGTH-4)
            pname=pname " (" s ")"
        }
        printf "  %-6s %-7s %-20s %s\n", proto, port, ip " (" scope ")", pname
    }'
printf "  %s\n" "--------------------------------------------------------"
}
ops_disk(){ printf "  ${CLR_DIM}%-18s %-10s %-10s %-8s %s${CLR_RESET}\n" "挂载点" "已用" "总容量" "使用率" "设备/类型"
printf "  %s\n" "--------------------------------------------------------"
df -hT 2>/dev/null | awk 'NR>1 && $2 !~ /^(tmpfs|devtmpfs|squashfs|overlay)$/ {
        printf "  %-18s %-10s %-10s %-8s %s (%s)\n", $7, $4, $3, $6, $1, $2
    }'
printf "  %s\n" "--------------------------------------------------------"
}
ops_disk_top(){ printf "${CLR_CYAN}扫描大文件 (Top 10)...${CLR_RESET}\n\n"
( du -ahx / 2>/dev/null | awk '$2 != "/" {print $0}' | sort -rh | head -n 10 | awk '{printf "  %-10s %s\n", $1, $2}' ) || true
}
ops_cron_list(){ local u_cron=$(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' || true)
printf "${CLR_BOLD}[用户任务]${CLR_RESET}\n"
if [ -n "$u_cron" ]; then
echo "$u_cron"
else
printf "  ${CLR_DIM}(未配置)${CLR_RESET}\n"
fi
echo
if [ -d /etc/cron.d ]; then
local sys_files=$(ls -1 /etc/cron.d 2>/dev/null | grep -Ev '^\.|\.dpkg-' || true)
if [ -n "$sys_files" ]; then
printf "${CLR_BOLD}[系统任务 (/etc/cron.d)]${CLR_RESET}\n"; echo "$sys_files" | sed 's/^/  • /'
fi
fi
}
ops_clean(){ require_root; local before=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGTPBkmgtpb]' | head -n 1)
[ -z "$before" ] && before=$(du -sh /var/log 2>/dev/null | awk '{print $1}'); journalctl --rotate 2>/dev/null || true
journalctl --vacuum-time=1d 2>/dev/null || true; journalctl --vacuum-size=10M 2>/dev/null || true
find /var/log -type f \( -name "*.gz" -o -name "*.[0-9]" -o -name "*.old" \) -delete 2>/dev/null || true
apt-get clean -y 2>/dev/null || true; rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true
find /tmp /var/tmp -type f -atime +1 -delete 2>/dev/null || true
local after=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGTPBkmgtpb]' | head -n 1)
[ -z "$after" ] && after=$(du -sh /var/log 2>/dev/null | awk '{print $1}')
printf "${CLR_GREEN}已清理系统日志与缓存 (${before:-0B} -> ${after:-0B})${CLR_RESET}\n"
}
ops_clean_history(){ local files=("$HOME/.bash_history" "$HOME/.zsh_history" "/root/.bash_history" "/root/.zsh_history"); local f
for f in "${files[@]}"; do
[ -f "$f" ] && > "$f" 2>/dev/null || true
done
history -c 2>/dev/null || true; history -w 2>/dev/null || true; printf "${CLR_GREEN}已清空历史记录${CLR_RESET}\n"
}
ops_update_badge(){ local cache="${VPS_CACHE_DIR:-/tmp}/update_meta"; local now=$(date +%s); local mtime=0
[ -f "$cache" ] && mtime=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)
if [ $((now - mtime)) -gt 21600 ]; then
touch "$cache" 2>/dev/null || true
(
local rver=$(curl -fsSLm 2 "$VPS_RAW_URL/vps.sh" 2>/dev/null | head -n 40 | grep -o 'VPS_VERSION="[^"]*"' | head -n 1 | cut -d'"' -f2 || true)
[ -n "$rver" ] && echo "$rver" > "$cache"; ) &
fi
local cached_ver=$(cat "$cache" 2>/dev/null || true)
if [ -n "$cached_ver" ] && [ "$cached_ver" != "$VPS_VERSION" ]; then
printf " ${CLR_YELLOW}[新版本: %s]${CLR_RESET}" "$cached_ver"
fi
}
ops_update(){ require_root; printf "${CLR_CYAN}检查新版本...${CLR_RESET}\n"; local tmp=$(mktemp)
if ! curl -fsSLm 15 "$VPS_RAW_URL/vps.sh" -o "$tmp"; then
rm -f "$tmp"; printf "${CLR_RED}错误: 无法获取远端脚本${CLR_RESET}\n" >&2; return 1
fi
if ! bash -n "$tmp" 2>/dev/null; then
rm -f "$tmp"; printf "${CLR_RED}错误: 脚本语法校验失败${CLR_RESET}\n" >&2; return 1
fi
local remote_ver=$(grep -o 'VPS_VERSION="[^"]*"' "$tmp" 2>/dev/null | head -n 1 | cut -d'"' -f2 || true)
local remote_date=$(grep -o 'VPS_BUILD_TIME="[^"]*"' "$tmp" 2>/dev/null | head -n 1 | cut -d'"' -f2 || true)
if [ -z "$remote_ver" ]; then
rm -f "$tmp"; printf "${CLR_RED}错误: 解析远端版本信息失败${CLR_RESET}\n" >&2; return 1
fi
if [ "$remote_ver" = "$VPS_VERSION" ]; then
rm -f "$tmp"; printf "${CLR_GREEN}已是最新版本: %s${CLR_RESET}\n" "$VPS_VERSION"; return 0
fi
printf "\n${CLR_BOLD}发现新版本: ${CLR_GREEN}%s${CLR_RESET} ${CLR_DIM}(当前: %s)${CLR_RESET}\n" "$remote_ver" "$VPS_VERSION"
[ -n "$remote_date" ] && printf "${CLR_DIM}发布时间: %s${CLR_RESET}\n\n" "$remote_date"; local confirm="${1:-}"
if [ "$confirm" != "-y" ] && [ "$confirm" != "--yes" ]; then
read -r -p "确认更新? (y/N, 回车取消): " confirm
fi
case "$confirm" in
[yY][eE][sS]|[yY]|-y|--yes)
chmod 755 "$tmp"; mv -f "$tmp" /usr/local/bin/vs; rm -f "${VPS_CACHE_DIR:-/tmp}/update_meta" 2>/dev/null || true
[ -L /usr/bin/vs ] || ln -sf /usr/local/bin/vs /usr/bin/vs 2>/dev/null || true; printf "${CLR_GREEN}已更新至 %s${CLR_RESET}\n" "$remote_ver"
exit 0; ;;
*)
rm -f "$tmp"; echo "已取消"; ;;
esac
}
ui_ops_ports(){ clear; local raw=$(ss -tulpn 2>/dev/null || true); local total=$(printf "%s\n" "$raw" | awk 'NR>1 {c++} END {print c+0}')
printf "${CLR_BOLD}--- 监听端口 ---${CLR_RESET}\n"; printf "${CLR_DIM}监听端口数:${CLR_RESET} %s\n\n" "$total"; ops_ports "$raw"; echo
read -r -p "按回车返回..."
}
ui_ops_disk(){
while true; do
clear; local root_usage=$(df -h / 2>/dev/null | awk 'NR==2 {printf "%s / %s (已用 %s)", $3, $2, $5}')
printf "${CLR_BOLD}--- 磁盘使用 ---${CLR_RESET}\n"; printf "${CLR_DIM}根分区:${CLR_RESET} %s\n\n" "$root_usage"; ops_disk; echo
printf "${CLR_CYAN}[1]${CLR_RESET} 扫描大文件 (Top 10)\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
[ -z "$choice" ] && return 0
case "$choice" in
1)
echo; ops_disk_top; echo; read -r -p "按回车返回..."; ;; 0|*) return 0 ;;
esac
done
}
ui_ops_clean(){ clear; local j_size=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGTPBkmgtpb]' | head -n 1)
[ -z "$j_size" ] && j_size=$(du -sh /var/log 2>/dev/null | awk '{print $1}')
local apt_size=$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
local tmp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}'); printf "${CLR_BOLD}--- 清理系统日志 ---${CLR_RESET}\n"
printf "${CLR_DIM}系统日志:${CLR_RESET} %s (保留 10M)\n" "${j_size:-0B}"; printf "${CLR_DIM}包缓存:${CLR_RESET}   %s\n" "${apt_size:-0B}"
printf "${CLR_DIM}临时文件:${CLR_RESET} %s\n\n" "${tmp_size:-0B}"; read -r -p "确认清理? (y/N, 回车取消): " confirm
case "$confirm" in
[yY][eE][sS]|[yY])
echo; ops_clean; echo; ;;
*)
return 0; ;;
esac
read -r -p "按回车返回..."
}
ui_ops_clean_history(){ clear; local files=("$HOME/.bash_history" "$HOME/.zsh_history" "/root/.bash_history" "/root/.zsh_history")
local total_lines=0; local f
for f in "${files[@]}"; do
if [ -f "$f" ]; then
local cnt=$(wc -l < "$f" 2>/dev/null || echo 0); total_lines=$((total_lines + cnt))
fi
done
printf "${CLR_BOLD}--- 清理命令历史 ---${CLR_RESET}\n"; printf "${CLR_DIM}历史记录:${CLR_RESET} %s 条\n" "$total_lines"
printf "${CLR_YELLOW}注意: 清空后无法恢复${CLR_RESET}\n\n"; read -r -p "确认清空? (y/N, 回车取消): " confirm
case "$confirm" in
[yY][eE][sS]|[yY])
echo; ops_clean_history; echo; ;;
*)
return 0; ;;
esac
read -r -p "按回车返回..."
}
ui_ops_cron(){
while true; do
clear; local u_cnt=$(crontab -l 2>/dev/null | awk '!/^[[:space:]]*(#|$)/ {c++} END {print c+0}')
printf "${CLR_BOLD}--- 定时任务 ---${CLR_RESET}\n"; printf "${CLR_DIM}用户任务数:${CLR_RESET} %s\n\n" "$u_cnt"; ops_cron_list; echo
printf "${CLR_CYAN}[1]${CLR_RESET} 编辑任务 (crontab -e)\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 清空用户任务\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice; [ -z "$choice" ] && return 0
case "$choice" in
1)
crontab -e; ;;
2)
read -r -p "确认清空用户定时任务? (y/N, 回车取消): " confirm
case "$confirm" in
[yY][eE][sS]|[yY])
crontab -r 2>/dev/null || true; printf "${CLR_GREEN}已清空用户定时任务${CLR_RESET}\n"; read -r -p "按回车返回..."; ;;
esac
;; 0|*) return 0 ;;
esac
done
}
ui_ops(){
while true; do
clear; printf "${CLR_BOLD}--- 运维监控 ---${CLR_RESET}\n\n"; ops_snapshot; echo; printf "${CLR_CYAN}[1]${CLR_RESET} 监听端口\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 磁盘使用\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 清理系统日志\n"; printf "${CLR_CYAN}[4]${CLR_RESET} 清理命令历史\n"
printf "${CLR_CYAN}[5]${CLR_RESET} 定时任务\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) ui_ops_ports ;; 2) ui_ops_disk ;; 3) ui_ops_clean ;; 4) ui_ops_clean_history ;; 5) ui_ops_cron ;; 0|*) return ;; esac
done
}
ui_mgr(){
while true; do
clear; printf "${CLR_BOLD}--- 脚本管理 ---${CLR_RESET}\n\n"
printf "${CLR_DIM}当前版本:${CLR_RESET} %s (构建于 %s)%s\n\n" "$VPS_VERSION" "$VPS_BUILD_TIME" "$(ops_update_badge)"
printf "${CLR_CYAN}[1]${CLR_RESET} 升级脚本\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 卸载脚本\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
read -r -p "请选择: " choice
case "$choice" in 1) ops_update && read -r -p "按回车返回..." ;; 2) sys_uninstall ;; 0|*) return ;; esac
done
}
docker_is_installed(){ command -v docker >/dev/null 2>&1
}
docker_is_active(){ systemctl is-active --quiet docker 2>/dev/null
}
docker_snapshot(){
if ! docker_is_installed; then
printf "${CLR_BOLD}服务状态:${CLR_RESET} ${CLR_DIM}未安装${CLR_RESET}\n"; return 0
fi
local status="已停止" ver=""; local total=0 running=0 stopped=0 imgs=0
if docker_is_active; then
status="运行中"
local d_info=$(docker info --format '{{.ServerVersion}}|{{.Containers}}|{{.ContainersRunning}}|{{.Images}}' 2>/dev/null || true)
if [ -n "$d_info" ]; then
IFS='|' read -r ver total running imgs <<< "$d_info"; stopped=$((total - running)); [ "$stopped" -lt 0 ] && stopped=0
fi
fi
[ -z "$ver" ] && ver=$(docker -v 2>/dev/null | awk '{print $3}' | tr -d ',')
local compose=$(docker compose version 2>/dev/null | awk '{print $4}'); [ -n "$compose" ] && compose="| Compose: $compose" || compose=""
printf "${CLR_BOLD}服务状态:${CLR_RESET} %s (Docker %s %s)\n" "$status" "$ver" "$compose"
if [ "$status" = "运行中" ]; then
printf "${CLR_BOLD}容器统计:${CLR_RESET} %s 运行中 / %s 已停止 | ${CLR_BOLD}镜像数:${CLR_RESET} %s 个\n" "$running" "$stopped" "$imgs"
fi
local mirror="官方源"; local m=$(docker_get_mirrors); [ -n "$m" ] && mirror="$m"; printf "${CLR_BOLD}当前镜像源:${CLR_RESET} %s\n" "$mirror"
}
docker_get_mirrors(){ [ -f /etc/docker/daemon.json ] || return 0
if command -v jq >/dev/null 2>&1; then
local res=$(jq -r '.["registry-mirrors"] // [] | join(",")' /etc/docker/daemon.json 2>/dev/null || true)
[ -n "$res" ] && [ "$res" != "null" ] && echo "$res"
else
awk '
        /registry-mirrors/ { in_arr=1 }
        in_arr {
            while (match($0, /"https?:\/\/[^"]+"/)) {
                val = substr($0, RSTART+1, RLENGTH-2)
                res = (res ? res "," : "") val
                $0 = substr($0, RSTART + RLENGTH)
            }
            if (/\]/) in_arr=0
        }
        END { if (res) print res }
        ' /etc/docker/daemon.json 2>/dev/null || true
fi
}
docker_install(){ require_root
if docker_is_installed; then
printf "Docker 已安装 (%s)\n" "$(docker -v 2>/dev/null)"; docker_is_active || systemctl enable --now docker; return 0
fi
curl -fsSL https://get.docker.com | sh; systemctl enable --now docker
}
docker_ps(){
if ! docker_is_installed; then
echo "Docker 未安装"; return 0
fi
if ! docker_is_active; then
echo "Docker 守护进程未运行"; return 0
fi
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
}
docker_mirror(){ require_root; local mirrors=("$@"); [ "${#mirrors[@]}" -gt 0 ] || return 0
for m in "${mirrors[@]}"; do
if [[ ! "$m" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
printf "${CLR_RED}错误: 源格式不合法 (%s)${CLR_RESET}\n" "$m" >&2; return 1
fi
done
mkdir -p /etc/docker
if command -v jq >/dev/null 2>&1; then
local tmp=$(mktemp); local base="{}"; [ -s /etc/docker/daemon.json ] && base=$(cat /etc/docker/daemon.json 2>/dev/null || echo "{}")
local json_arr=$(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .)
if echo "$base" | jq --argjson m "$json_arr" '.["registry-mirrors"] = $m' > "$tmp" 2>/dev/null; then
mv "$tmp" /etc/docker/daemon.json
else
rm -f "$tmp"
fi
else
local json_list=""
for m in "${mirrors[@]}"; do
[ -n "$json_list" ] && json_list="$json_list, "; json_list="$json_list\"$m\""
done
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [$json_list]
}
EOF
fi
systemctl restart docker 2>/dev/null || true; printf "${CLR_GREEN}已配置镜像加速: %s${CLR_RESET}\n" "${mirrors[*]}"
}
docker_mirror_fast(){ docker_mirror "https://docker.m.daocloud.io" "https://docker.1ms.run"
}
docker_mirror_daocloud(){ docker_mirror "https://docker.m.daocloud.io"
}
docker_mirror_1ms(){ docker_mirror "https://docker.1ms.run"
}
docker_probe_status(){ local url="${1%/}"
local res=$(curl -s -m 1.5 -o /dev/null -w "%{http_code}:%{time_connect}" "$url/v2/" 2>/dev/null); res="${res:-000:0}"
local code="${res%%:*}"; local time_sec="${res##*:}"
if [ "$code" = "200" ] || [ "$code" = "401" ]; then
local ms=$(awk -v t="$time_sec" 'BEGIN {printf "%.0f", t*1000}'); printf "${CLR_GREEN}[可用 %sms]${CLR_RESET}" "$ms"
else
printf "${CLR_RED}[不可用]${CLR_RESET}"
fi
}
docker_mirror_restore(){ require_root
if [ -f /etc/docker/daemon.json ]; then
if command -v jq >/dev/null 2>&1; then
local tmp=$(mktemp)
if jq 'del(.["registry-mirrors"])' /etc/docker/daemon.json > "$tmp" 2>/dev/null; then
mv "$tmp" /etc/docker/daemon.json
else
rm -f "$tmp"
fi
[ "$(tr -d ' \n\t{}' < /etc/docker/daemon.json 2>/dev/null)" = "" ] && rm -f /etc/docker/daemon.json
else
rm -f /etc/docker/daemon.json
fi
systemctl restart docker 2>/dev/null || true
fi
printf "${CLR_GREEN}已恢复默认镜像源${CLR_RESET}\n"
}
docker_prune(){ require_root
if ! docker_is_active; then
printf "${CLR_RED}错误: Docker 未运行${CLR_RESET}\n" >&2; return 0
fi
docker system prune -f; printf "${CLR_GREEN}已清理无用容器与镜像缓存${CLR_RESET}\n"
}
docker_toggle(){ require_root
if docker_is_active; then
systemctl stop docker docker.socket 2>/dev/null || systemctl stop docker
else
systemctl start docker
fi
}
ui_docker_mirror(){
while true; do
clear; printf "${CLR_BOLD}--- 镜像加速 ---${CLR_RESET}\n\n"; local mirror="官方源"; local cur_endpoint="https://registry-1.docker.io"
local m=$(docker_get_mirrors)
if [ -n "$m" ]; then
mirror="$m"; cur_endpoint="${m%%,*}"
fi
local tdir=$(mktemp -d)
( docker_probe_status "$cur_endpoint" > "$tdir/cur" 2>/dev/null ) &
( docker_probe_status "https://docker.m.daocloud.io" > "$tdir/dao" 2>/dev/null ) &
( docker_probe_status "https://docker.1ms.run" > "$tdir/1ms" 2>/dev/null ) &
wait; local stat_cur=$(cat "$tdir/cur" 2>/dev/null || true); local stat_dao=$(cat "$tdir/dao" 2>/dev/null || true)
local stat_1ms=$(cat "$tdir/1ms" 2>/dev/null || true); rm -rf "$tdir"
printf "${CLR_DIM}当前镜像源:${CLR_RESET} %s %s\n\n" "$mirror" "$stat_cur"; printf "${CLR_CYAN}[1]${CLR_RESET} 推荐加速 (DaoCloud + 1ms)\n"
printf "${CLR_CYAN}[2]${CLR_RESET} DaoCloud 源 %s\n" "$stat_dao"; printf "${CLR_CYAN}[3]${CLR_RESET} 1ms 毫秒源 %s\n" "$stat_1ms"
printf "${CLR_CYAN}[4]${CLR_RESET} 自定义源\n"; printf "${CLR_CYAN}[5]${CLR_RESET} 恢复官方源\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
read -r -p "请选择: " choice
case "$choice" in 1) docker_mirror_fast ;; 2) docker_mirror_daocloud ;; 3) docker_mirror_1ms ;; 4) read -r -p "镜像地址 (如 https://docker.m.daocloud.io): " m && [ -n "$m" ] && docker_mirror "$m" ;; 5) docker_mirror_restore ;; 0|*) return ;; esac
read -r -p "按回车返回..."
done
}
ui_docker_ps(){
while true; do
clear; printf "${CLR_BOLD}--- 容器列表 ---${CLR_RESET}\n\n"
if ! docker_is_active; then
printf "${CLR_RED}Docker 未运行${CLR_RESET}\n\n"; read -r -p "按回车返回..."; return 0
fi
local names=(); printf "  ${CLR_DIM}%-4s %-20s %-26s %s${CLR_RESET}\n" "#" "名称" "状态" "端口 / 镜像"
printf "  %s\n" "------------------------------------------------------------------------"
while IFS=$'\t' read -r c_name c_status c_image c_ports; do
[ -n "$c_name" ] || continue; names+=("$c_name"); local idx=${#names[@]}; local color_status="$c_status"
if [[ "$c_status" =~ ^Up ]]; then
color_status="${CLR_GREEN}${c_status}${CLR_RESET}"
else
color_status="${CLR_RED}${c_status}${CLR_RESET}"
fi
local extra="${c_ports:-$c_image}"; printf "  %-4s %-20s %-38b ${CLR_DIM}%s${CLR_RESET}\n" "$idx" "$c_name" "$color_status" "$extra"
done < <(docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null)
if [ "${#names[@]}" -eq 0 ]; then
printf "  ${CLR_DIM}(无运行中容器)${CLR_RESET}\n"
fi
printf "  %s\n\n" "------------------------------------------------------------------------"
printf "${CLR_CYAN}[1]${CLR_RESET} 启动    ${CLR_CYAN}[2]${CLR_RESET} 停止    ${CLR_CYAN}[3]${CLR_RESET} 重启    ${CLR_CYAN}[4]${CLR_RESET} 删除\n"
printf "${CLR_CYAN}[5]${CLR_RESET} 日志    ${CLR_CYAN}[6]${CLR_RESET} 终端\n\n"
printf "${CLR_CYAN}[7]${CLR_RESET} 资源    ${CLR_CYAN}[8]${CLR_RESET} 网络    ${CLR_CYAN}[9]${CLR_RESET} 重启全部    ${CLR_CYAN}[10]${CLR_RESET} 停止全部\n\n"
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice; local args=($choice); local act="${args[0]:-}"
local target_idx="${args[1]:-}"
case "$act" in
1|2|3|4|5|6)
if [ "${#names[@]}" -eq 0 ]; then
printf "${CLR_YELLOW}无可用容器${CLR_RESET}\n"; read -r -p "按回车返回..."; continue
fi
if [ -z "$target_idx" ]; then
if [ "${#names[@]}" -eq 1 ]; then
target_idx=1
else
read -r -p "容器序号 (1-${#names[@]}, 默认 1): " target_idx; target_idx="${target_idx:-1}"
fi
fi
local target_name=""
if [[ "$target_idx" =~ ^[0-9]+$ ]] && [ "$target_idx" -ge 1 ] && [ "$target_idx" -le "${#names[@]}" ]; then
target_name="${names[$((target_idx-1))]}"
else
target_name="$target_idx"
fi
case "$act" in
1) docker start "$target_name" ;; 2) docker stop "$target_name" ;; 3) docker restart "$target_name" ;;
4)
read -r -p "确认删除容器 $target_name? (y/N): " confirm
case "$confirm" in
[yY][eE][sS]|[yY]) docker rm -f "$target_name" ;; *) echo "已取消" ;;
esac
;;
5)
clear; printf "${CLR_BOLD}--- 容器日志: %s ---${CLR_RESET}\n\n" "$target_name"
docker logs --tail 100 -f "$target_name" 2>&1 || docker logs --tail 100 "$target_name"; ;;
6)
printf "${CLR_BOLD}正在进入 %s 终端 (exit 退出)...${CLR_RESET}\n" "$target_name"
docker exec -it "$target_name" /bin/bash 2>/dev/null || docker exec -it "$target_name" /bin/sh 2>/dev/null || docker exec -it "$target_name" sh
;;
esac
read -r -p "按回车返回..."; ;;
7)
clear; printf "${CLR_BOLD}--- 容器资源占用 ---${CLR_RESET}\n\n"; docker stats --no-stream; read -r -p "按回车返回..."; ;;
8)
clear; printf "${CLR_BOLD}--- 容器网络 ---${CLR_RESET}\n\n"; local all_ids=$(docker ps -aq 2>/dev/null || true)
if [ -n "$all_ids" ]; then
docker inspect --format '{{.Name}} | Network: {{range $k, $v := .NetworkSettings.Networks}}{{$k}} (IP: {{$v.IPAddress}}) {{end}}' $all_ids 2>/dev/null | sed 's/^\///'
else
echo "无可用容器"
fi
echo; read -r -p "按回车返回..."; ;;
9)
docker restart $(docker ps -aq 2>/dev/null) 2>/dev/null || true; read -r -p "按回车返回..."; ;;
10)
docker stop $(docker ps -q 2>/dev/null) 2>/dev/null || true; read -r -p "按回车返回..."; ;; 0|*) return ;;
esac
done
}
ui_docker(){
while true; do
clear; printf "${CLR_BOLD}--- 容器引擎 ---${CLR_RESET}\n\n"; docker_snapshot; echo
if ! docker_is_installed; then
printf "${CLR_CYAN}[1]${CLR_RESET} 安装 Docker 与 Compose\n"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) docker_install && read -r -p "按回车返回..." ;; 0|*) return ;; esac
else
local docker_action="启动服务"; docker_is_active && docker_action="停止服务"; printf "${CLR_CYAN}[1]${CLR_RESET} 容器列表\n"
printf "${CLR_CYAN}[2]${CLR_RESET} 镜像加速\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 清理无用资源\n"
printf "${CLR_CYAN}[4]${CLR_RESET} %s\n" "$docker_action"; printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) ui_docker_ps ;; 2) ui_docker_mirror ;; 3) docker_prune && read -r -p "按回车返回..." ;; 4) docker_toggle; continue ;; 0|*) return ;; esac
fi
done
}
app_init_dir(){ [ -d /opt/vps-sh/apps ] || mkdir -p /opt/vps-sh/apps; chmod 700 /opt/vps-sh/apps 2>/dev/null || true
}
app_valid_name(){ [[ "${1:-}" =~ ^[a-zA-Z0-9_-]+$ ]]
}
app_port_in_use(){ local port="$1"; [ -n "$port" ] || return 1
ss -H -lntu 2>/dev/null | awk -v p=":$port" '$5 ~ (p "$") { found=1 } END { exit(found ? 0 : 1) }'
}
app_start(){ app_valid_name "$1" || return 1; local dir="/opt/vps-sh/apps/$1"; [ -d "$dir" ] || return 1
(cd "$dir" && docker compose up -d)
}
app_stop(){ app_valid_name "$1" || return 1; local dir="/opt/vps-sh/apps/$1"; [ -d "$dir" ] || return 1
(cd "$dir" && docker compose stop)
}
app_restart(){ app_valid_name "$1" || return 1; local dir="/opt/vps-sh/apps/$1"; [ -d "$dir" ] || return 1
(cd "$dir" && docker compose up -d --force-recreate)
}
app_update(){ app_valid_name "$1" || return 1; local dir="/opt/vps-sh/apps/$1"; [ -d "$dir" ] || return 1
(cd "$dir" && docker compose pull && docker compose up -d)
}
app_logs(){ app_valid_name "$1" || return 1; local dir="/opt/vps-sh/apps/$1"; [ -d "$dir" ] || return 1
(cd "$dir" && (docker compose logs --tail 100 -f || docker compose logs --tail 100))
}
app_list_installed(){ local dir="/opt/vps-sh/apps"; [ -d "$dir" ] || return 0; local d
for d in "$dir"/*; do
[ -d "$d" ] || continue
if [ -f "$d/compose.yaml" ] || [ -f "$d/docker-compose.yml" ]; then
basename "$d"
fi
done
}
app_status(){ local name="$1"; local snapshot="${2:-}"; app_valid_name "$name" || { echo "未安装"; return 0; }
local dir="/opt/vps-sh/apps/$name"
if [ ! -d "$dir" ] || { [ ! -f "$dir/compose.yaml" ] && [ ! -f "$dir/docker-compose.yml" ]; }; then
echo "未安装"; return 0
fi
local states=""
if [ -n "$snapshot" ]; then
states=$(awk -F'|' -v p="$name" '($1==p || $2==p) && $3!="" {print $3}' <<< "$snapshot")
else
states=$(docker ps -a --filter "label=com.docker.compose.project=$name" --format '{{.State}}' 2>/dev/null || true)
[ -z "$states" ] && states=$(docker ps -a --filter "name=^/${name}$" --format '{{.State}}' 2>/dev/null || true)
fi
if [ -z "$states" ]; then
echo "已停止"; return 0
fi
local total=0 running=0 restarting=0; local s
for s in $states; do
total=$((total + 1)); [ "$s" = "running" ] && running=$((running + 1)); [ "$s" = "restarting" ] && restarting=$((restarting + 1))
done
if [ "$total" -eq 0 ]; then
echo "已停止"; elif [ "$running" -eq "$total" ]; then echo "运行中"; elif [ "$running" -eq 0 ]; then
[ "$restarting" -gt 0 ] && echo "启动异常" || echo "已停止"
else
echo "部分运行"
fi
}
app_get_port(){ local name="$1"; app_valid_name "$name" || { echo "-"; return 0; }; local env_file="/opt/vps-sh/apps/$name/.env"
if [ -f "$env_file" ]; then
local p=$(awk -F= '$1=="APP_PORT" {print $2; exit}' "$env_file" | tr -d ' "\r'); [ -n "$p" ] && { echo "$p"; return 0; }
fi
local meta=$(app_meta "$name" 2>/dev/null || true)
if [ -n "$meta" ]; then
local p=""; IFS='|' read -r _ p _ <<< "$meta"; [ -n "$p" ] && [ "$p" != "-" ] && { echo "$p"; return 0; }
fi
local compose="/opt/vps-sh/apps/$name/compose.yaml"; [ -f "$compose" ] || compose="/opt/vps-sh/apps/$name/docker-compose.yml"
if [ -f "$compose" ]; then
local p=$(awk '/:[0-9]+/ && match($0, /[0-9]+(\}:|:)[0-9]+/) { s=substr($0, RSTART, RLENGTH); sub(/(\}:|:)[0-9]+/, "", s); print s; exit }' "$compose" 2>/dev/null || true)
[ -n "$p" ] && { echo "$p"; return 0; }
fi
echo "-"
}
app_get_host(){ local name="$1"; app_valid_name "$name" || { echo "0.0.0.0"; return 0; }; local env_file="/opt/vps-sh/apps/$name/.env"
if [ -f "$env_file" ]; then
local h=$(awk -F= '$1=="APP_HOST" {print $2; exit}' "$env_file" | tr -d ' "\r'); [ -n "$h" ] && { echo "$h"; return 0; }
fi
echo "0.0.0.0"
}
app_cloud_fetch(){ local cache="${VPS_CACHE_DIR:-/tmp}/catalog.json"; local now=$(date +%s); local mtime=0
[ -f "$cache" ] && mtime=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)
[ $((now - mtime)) -lt 600 ] && return 0; command -v curl >/dev/null 2>&1 || return 1
curl -fsSLm 5 "$VPS_APP_FEED/index.json" -o "$cache.tmp" 2>/dev/null || \
curl -fsSLm 5 "$VPS_APP_FEED/apps/index.json" -o "$cache.tmp" 2>/dev/null || true
if [ -s "$cache.tmp" ]; then
mv -f "$cache.tmp" "$cache"; return 0
fi
rm -f "$cache.tmp" 2>/dev/null || true; return 1
}
app_cloud_list(){ local cache="${VPS_CACHE_DIR:-/tmp}/catalog.json"; [ -s "$cache" ] || return 0; awk -F'"' '/"id":/{print $4}' "$cache"
}
app_cloud_compose(){ local name="$1"; app_valid_name "$name" || return 1; command -v curl >/dev/null 2>&1 || return 1
curl -fsSLm 10 "$VPS_APP_FEED/apps/$name/compose.yaml"
}
app_meta(){ local name="$1"; app_valid_name "$name" || return 1; local cache="${VPS_CACHE_DIR:-/tmp}/catalog.json"
if [ -s "$cache" ]; then
local entry=$(awk -F'"' -v target="$name" '
        /"id":/ { id=$4; title=""; port=""; tag=""; desc=""; auth=""; url="" }
        /"name":/ { title=$4 }
        /"port":/ { port=$4 }
        /"tag":/ { tag=$4 }
        /"desc":/ { desc=$4 }
        /"auth":/ { auth=$4 }
        /"url":/ { url=$4 }
        /}/ && id==target {
            print title "|" (port != "" ? port : "-") "|" (tag != "" ? tag : desc) "|" desc "|" auth "|" url;
            exit;
        }' "$cache" 2>/dev/null || true)
if [ -n "$entry" ]; then
echo "$entry"; return 0
fi
fi
local local_compose="/opt/vps-sh/apps/$name/compose.yaml"
[ -f "$local_compose" ] || local_compose="/opt/vps-sh/apps/$name/docker-compose.yml"
if [ -f "$local_compose" ]; then
local local_entry=$(awk '
        /^x-vps:[[:space:]]*$/ { in_vps=1; next }
        in_vps && /^[^[:space:]]/ { in_vps=0 }
        in_vps && /^[[:space:]]+[a-zA-Z0-9_-]+:/ {
            sub(/^[[:space:]]+/, "");
            split($0, kv, ":");
            k = tolower(kv[1]);
            sub(/^[a-zA-Z0-9_-]+:[[:space:]]*/, "");
            gsub(/^["'\'']|["'\'']$/, "");
            if (k == "name") title = $0;
            if (k == "port") port = $0;
            if (k == "tag") tag = $0;
            if (k == "desc") desc = $0;
            if (k == "auth") auth = $0;
            if (k == "url") url = $0;
        }
        port == "" {
            if (match($0, /\$\{APP_PORT:-[0-9]+\}/)) {
                s = substr($0, RSTART, RLENGTH);
                sub(/\$\{APP_PORT:-/, "", s);
                sub(/\}/, "", s);
                port = s;
            } else if (match($0, /([0-9\.]+:)*[0-9]+:[0-9]+/)) {
                s = substr($0, RSTART, RLENGTH);
                n = split(s, parts, ":");
                if (n >= 2) {
                    gsub(/[^0-9]/, "", parts[n-1]);
                    port = parts[n-1];
                }
            }
        }
        END {
            if (title != "") {
                print title "|" (port != "" ? port : "-") "|" (tag != "" ? tag : desc) "|" desc "|" auth "|" url;
                exit 0;
            }
            exit 1;
        }' "$local_compose" 2>/dev/null || true)
if [ -n "$local_entry" ]; then
echo "$local_entry"; return 0
fi
fi
return 1
}
app_get_auth(){ local name="$1"; app_valid_name "$name" || return 0; local env_file="/opt/vps-sh/apps/$name/.env"
if [ -f "$env_file" ]; then
local user=$(awk -F= '$1=="APP_USER" {print $2; exit}' "$env_file" | tr -d ' "\r')
local pass=$(awk -F= '$1=="APP_PASSWORD" {print $2; exit}' "$env_file" | tr -d ' "\r')
if [ -n "$pass" ]; then
[ -n "$user" ] && echo "$user / $pass" || echo "$pass"; return 0
fi
fi
local meta=$(app_meta "$name" 2>/dev/null || true)
if [ -n "$meta" ]; then
local a=$(echo "$meta" | cut -d'|' -f5); [ -n "$a" ] && { echo "$a"; return 0; }
fi
echo ""
}
app_install(){ require_root; local name="$1"; local port="${2:-}"; local host="${3:-0.0.0.0}"; [ "$host" = "127.0.0.1" ] || host="0.0.0.0"
if ! app_valid_name "$name"; then
printf "${CLR_RED}错误: 非法应用名称${CLR_RESET}\n" >&2; return 1
fi
local dir="/opt/vps-sh/apps/$name"
if [ -d "$dir" ] && { [ -f "$dir/compose.yaml" ] || [ -f "$dir/docker-compose.yml" ]; }; then
printf "${CLR_RED}错误: 应用 [%s] 已部署于 %s${CLR_RESET}\n" "$name" "$dir" >&2; return 1
fi
if [ -n "$port" ] && [ "$port" != "-" ]; then
if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
printf "${CLR_RED}错误: 端口无效 (1-65535)${CLR_RESET}\n" >&2; return 1
fi
if app_port_in_use "$port"; then
printf "${CLR_RED}错误: 端口 [%s] 已被占用${CLR_RESET}\n" "$port" >&2; return 1
fi
fi
local orig_umask=$(umask); umask 077; app_init_dir; mkdir -p "$dir"
if ! app_cloud_compose "$name" > "$dir/compose.yaml" 2>/dev/null || [ ! -s "$dir/compose.yaml" ]; then
rm -rf "$dir"; umask "$orig_umask"; printf "${CLR_RED}错误: 无法获取应用 [%s] 的模板配置${CLR_RESET}\n" "$name" >&2; return 1
fi
local gen_pwd=""
if grep -q '\${APP_PASSWORD' "$dir/compose.yaml" 2>/dev/null; then
gen_pwd=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 16 || openssl rand -hex 8 2>/dev/null || date +%s%N | head -c 16)
fi
local clean_token=""
if grep -q '\${TUNNEL_TOKEN' "$dir/compose.yaml" 2>/dev/null; then
local raw_token="${TUNNEL_TOKEN:-${APP_TOKEN:-}}"
if [ -z "$raw_token" ] && [ -t 0 ]; then
printf "${CLR_CYAN}请输入 Cloudflare Tunnel Token (输入已隐蔽，回车跳过): ${CLR_RESET}"; read -r -s raw_token; echo
fi
if [ -n "$raw_token" ]; then
clean_token=$(printf '%s' "$raw_token" | tr -dc 'a-zA-Z0-9_\-=')
if [ -n "$clean_token" ]; then
printf "${CLR_GREEN}✓ 令牌已安全接收 (${#clean_token} 字符)${CLR_RESET}\n"
fi
fi
fi
{ printf "APP_HOST=%s\n" "$host"; [ -n "$port" ] && [ "$port" != "-" ] && printf "APP_PORT=%s\n" "$port"
[ -n "$gen_pwd" ] && printf "APP_PASSWORD=%s\n" "$gen_pwd"; [ -n "$clean_token" ] && printf "TUNNEL_TOKEN=%s\n" "$clean_token"
} > "$dir/.env"; umask "$orig_umask"
if (cd "$dir" && docker compose up -d); then
if [ "$host" = "0.0.0.0" ] && [ -n "$port" ] && [ "$port" != "-" ] && fw_is_initialized 2>/dev/null; then
fw_open "$port" 2>/dev/null || true
fi
return 0
else
return 1
fi
}
app_uninstall(){ require_root; local name="$1"; local purge_data="${2:-0}"; app_valid_name "$name" || return 1
local dir="/opt/vps-sh/apps/$name"; [ -d "$dir" ] || return 0; local port=$(app_get_port "$name"); local host=$(app_get_host "$name")
(cd "$dir" && docker compose down -v 2>/dev/null || true)
if [ "$host" = "0.0.0.0" ] && [ -n "$port" ] && [ "$port" != "-" ] && fw_is_initialized 2>/dev/null; then
fw_close "$port" 2>/dev/null || true
fi
if [ "$purge_data" = "1" ]; then
rm -rf "$dir"
else
rm -f "$dir/compose.yaml" "$dir/docker-compose.yml" "$dir/.env" 2>/dev/null || true
fi
}
app_render_col(){ local idx="$1" name="$2" st="$3" tag="$4" target="${5:-39}"; local num=$(printf "[%2d]" "$idx"); local raw_badge=""
local col_badge=""
if [ "$st" = "运行中" ]; then
raw_badge=" [已安装]"; col_badge=" ${CLR_GREEN}[已安装]${CLR_RESET}"; elif [ "$st" = "已停止" ]; then raw_badge=" [已停止]"
col_badge=" ${CLR_RED}[已停止]${CLR_RESET}"; elif [ "$st" = "启动异常" ]; then raw_badge=" [启动异常]"; col_badge=" ${CLR_RED}[启动异常]${CLR_RESET}"
elif [ "$st" = "部分运行" ]; then raw_badge=" [部分运行]"; col_badge=" ${CLR_YELLOW}[部分运行]${CLR_RESET}"
fi
local raw_tag=""; local tag_str=""
if [ -n "$tag" ]; then
raw_tag=" $tag"; tag_str=" ${CLR_DIM}${tag}${CLR_RESET}"
fi
local raw_text="  $num $name$raw_tag$raw_badge"; local m=${#raw_text}; local b=$(printf "%s" "$raw_text" | wc -c)
local w=$(( (m + b) / 2 )); local pad=0; [ "$target" -gt "$w" ] && pad=$((target - w)); local padding=$(printf "%*s" "$pad" "")
printf "  ${CLR_CYAN}%s${CLR_RESET} %s%s%s%s" "$num" "$name" "$tag_str" "$col_badge" "$padding"
}
ui_app_install_single(){ local app="$1"; local meta=$(app_meta "$app" 2>/dev/null || true); local title="$app"; local default_port="8080"
local desc=""; local auth=""; local url=""
if [ -n "$meta" ]; then
local raw_tag=""; IFS='|' read -r title default_port raw_tag desc auth url <<< "$meta"; [ -z "$desc" ] && desc="$raw_tag"
fi
local port="$default_port"; local host="0.0.0.0"; local target_dir="/opt/vps-sh/apps/$app"
while true; do
clear; local mode_desc="${CLR_GREEN}公网直接访问 (0.0.0.0)${CLR_RESET} · 自动放行防火墙"
[ "$host" = "127.0.0.1" ] && mode_desc="${CLR_YELLOW}本地反代模式 (127.0.0.1)${CLR_RESET} · 不暴露公网"
[ "$port" = "-" ] && mode_desc="本地/出站模式 · 无需暴露公网端口"; printf -- "${CLR_BOLD}--- 安装: %s ---${CLR_RESET}\n\n" "$title"
[ -n "$desc" ] && printf "  ${CLR_DIM}说明:${CLR_RESET} %s\n" "$desc"; [ -n "$url" ] && printf "  ${CLR_DIM}链接:${CLR_RESET} %s\n" "$url"
printf "  ${CLR_DIM}端口:${CLR_RESET} %s\n" "$port"; printf "  ${CLR_DIM}网络:${CLR_RESET} %b\n" "$mode_desc"
[ -n "$auth" ] && printf "  ${CLR_DIM}初始凭据:${CLR_RESET} %s\n" "$auth"; printf "  ${CLR_DIM}路径:${CLR_RESET} %s\n\n" "$target_dir"
if [ "$port" != "-" ]; then
printf "${CLR_CYAN}[Enter]${CLR_RESET} 立即部署    "; printf "${CLR_CYAN}[p]${CLR_RESET} 修改端口    "
printf "${CLR_CYAN}[h]${CLR_RESET} 切换网络    "; printf "${CLR_DIM}[0] 取消${CLR_RESET}\n\n"
else
printf "${CLR_CYAN}[Enter]${CLR_RESET} 立即部署    "; printf "${CLR_DIM}[0] 取消${CLR_RESET}\n\n"
fi
read -r -p "请选择: " choice
case "$choice" in
""|[yY]|[yY][eE][sS]|1)
if [ -n "$port" ] && [ "$port" != "-" ] && app_port_in_use "$port"; then
printf "\n${CLR_RED}错误: 端口 [%s] 已被占用，请按 [p] 修改端口${CLR_RESET}\n" "$port"; read -r -p "按回车继续..."; continue
fi
echo; printf "正在拉取并编排 %s...\n\n" "$title"
if app_install "$app" "$port" "$host"; then
printf "\n${CLR_GREEN}✓ 部署完成${CLR_RESET}\n"
if [ -n "$port" ] && [ "$port" != "-" ]; then
if [ "$host" = "0.0.0.0" ]; then
local ip=$(curl -fsSLm 2 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "IP")
printf "  ${CLR_DIM}访问地址:${CLR_RESET} http://%s:%s\n" "$ip" "$port"
else
printf "  ${CLR_DIM}本地地址:${CLR_RESET} http://127.0.0.1:%s (供反向代理使用)\n" "$port"
fi
else
[ -n "$url" ] && printf "  ${CLR_DIM}管理控制台:${CLR_RESET} %s\n" "$url"
fi
local active_auth=$(app_get_auth "$app"); [ -n "$active_auth" ] && printf "  ${CLR_DIM}初始凭据:${CLR_RESET} %s\n" "$active_auth"
if [[ "$active_auth" =~ (日志|log|logs) ]]; then
sleep 2
local sniffed=$( (cd "$target_dir" && docker compose logs 2>&1 | grep -iE 'password|initial.*password' | head -n 1 | tr -d '\r\n') || true )
[ -n "$sniffed" ] && printf "  ${CLR_YELLOW}日志嗅探:${CLR_RESET} %s\n" "$sniffed"
fi
else
printf "\n${CLR_RED}部署失败，请检查 Docker 日志${CLR_RESET}\n"
fi
echo; read -r -p "按回车返回..."; return 0; ;;
p|P)
[ "$port" = "-" ] && continue; read -r -p "请输入映射端口 [$port]: " input_port
if [ -n "$input_port" ]; then
if [[ ! "$input_port" =~ ^[0-9]+$ ]] || [ "$input_port" -lt 1 ] || [ "$input_port" -gt 65535 ]; then
printf "${CLR_RED}端口必须为 1-65535 之间的数字${CLR_RESET}\n"; sleep 1
else
port="$input_port"
fi
fi
;;
h|H)
[ "$port" = "-" ] && continue
if [ "$host" = "0.0.0.0" ]; then
host="127.0.0.1"
else
host="0.0.0.0"
fi
;;
0|q|Q)
return 0; ;;
esac
done
}
ui_app_manage_single(){ local name="$1"; local st=$(app_status "$name")
if [ "$st" = "未安装" ]; then
ui_app_install_single "$name"; return 0
fi
local meta=$(app_meta "$name" 2>/dev/null || true); local title="$name"; local desc="自定义应用"; local url=""
if [ -n "$meta" ]; then
title=$(echo "$meta" | cut -d'|' -f1); desc=$(echo "$meta" | cut -d'|' -f4); [ -z "$desc" ] && desc=$(echo "$meta" | cut -d'|' -f3)
url=$(echo "$meta" | cut -d'|' -f6)
fi
local target_dir="/opt/vps-sh/apps/$name"
while true; do
clear; local st=$(app_status "$name"); local port=$(app_get_port "$name"); local host=$(app_get_host "$name")
local auth=$(app_get_auth "$name"); local net_desc="${host} (公网直接访问) · 防火墙已放行"
[ "$host" = "127.0.0.1" ] && net_desc="${host} (本地反代模式) · 不向外网暴露"; local st_clr="$CLR_DIM"; [ "$st" = "运行中" ] && st_clr="$CLR_GREEN"
[ "$st" = "部分运行" ] && st_clr="$CLR_YELLOW"; [ "$st" = "启动异常" ] && st_clr="$CLR_RED"; [ "$st" = "已停止" ] && st_clr="$CLR_RED"
printf -- "${CLR_BOLD}--- 应用详情 ---${CLR_RESET}\n\n"; printf "  ${CLR_DIM}应用:${CLR_RESET} %s\n" "$name"
printf "  ${CLR_DIM}状态:${CLR_RESET} %b%s%b\n" "$st_clr" "$st" "$CLR_RESET"
if [ "$port" != "-" ]; then
printf "  ${CLR_DIM}端口:${CLR_RESET} %s\n" "$port"; printf "  ${CLR_DIM}网络:${CLR_RESET} %b\n" "$net_desc"
else
printf "  ${CLR_DIM}网络:${CLR_RESET} 本地/出站模式 · 无需暴露公网端口\n"
fi
[ -n "$auth" ] && printf "  ${CLR_DIM}初始凭据:${CLR_RESET} %s\n" "$auth"; [ -n "$url" ] && printf "  ${CLR_DIM}链接:${CLR_RESET} %s\n" "$url"
[ -d "$target_dir/data" ] && printf "  ${CLR_DIM}数据:${CLR_RESET} %s/data\n" "$target_dir"
printf "  ${CLR_DIM}说明:${CLR_RESET} %s\n\n" "$desc"; local act_toggle="[2] 停止"; [ "$st" = "已停止" ] && act_toggle="[2] 启动"
printf "${CLR_CYAN}[1]${CLR_RESET} 重启    ${CLR_CYAN}%s${CLR_RESET}    ${CLR_CYAN}[3]${CLR_RESET} 日志\n" "$act_toggle"
printf "${CLR_CYAN}[4]${CLR_RESET} 更新    ${CLR_CYAN}[5]${CLR_RESET} 卸载    ${CLR_CYAN}[6]${CLR_RESET} 编辑配置\n\n"
if [ "$port" != "-" ]; then
printf "${CLR_CYAN}[p]${CLR_RESET} 修改端口    ${CLR_CYAN}[h]${CLR_RESET} 切换网络    ${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
else
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
fi
read -r -p "请选择: " choice
case "$choice" in
1)
app_restart "$name"; read -r -p "按回车返回..."; ;;
2)
if [ "$st" = "已停止" ]; then
app_start "$name"
else
app_stop "$name"
fi
read -r -p "按回车返回..."; ;;
3)
app_logs "$name"; read -r -p "按回车返回..."; ;;
4)
app_update "$name"; read -r -p "按回车返回..."; ;;
5)
read -r -p "删除数据目录? (y/N): " purge_confirm; local purge=0; [[ "$purge_confirm" =~ ^[yY] ]] && purge=1; app_uninstall "$name" "$purge"
printf "${CLR_GREEN}已卸载${CLR_RESET}\n"; read -r -p "按回车返回..."; return 0; ;;
6)
local editor="${EDITOR:-}"
if [ -z "$editor" ]; then
command -v nano >/dev/null 2>&1 && editor="nano"; [ -z "$editor" ] && command -v vim >/dev/null 2>&1 && editor="vim"
[ -z "$editor" ] && editor="vi"
fi
local compose_file="$target_dir/compose.yaml"; [ -f "$compose_file" ] || compose_file="$target_dir/docker-compose.yml"
"$editor" "$compose_file"; echo; read -r -p "配置已保存，是否重新编排以生效改动? (y/N): " reload_cf
if [[ "$reload_cf" =~ ^[yY] ]]; then
(cd "$target_dir" && docker compose up -d --force-recreate)
printf "${CLR_GREEN}已重新编排生效${CLR_RESET}\n"; read -r -p "按回车返回..."
fi
;;
p|P)
read -r -p "请输入新映射端口 [$port]: " input_port
if [ -n "$input_port" ] && [ "$input_port" != "$port" ]; then
if [[ ! "$input_port" =~ ^[0-9]+$ ]] || [ "$input_port" -lt 1 ] || [ "$input_port" -gt 65535 ]; then
printf "${CLR_RED}端口必须为 1-65535 之间的数字${CLR_RESET}\n"; sleep 1; elif app_port_in_use "$input_port"; then
printf "${CLR_RED}错误: 端口 [%s] 已被占用${CLR_RESET}\n" "$input_port"; sleep 1
else
printf "正在更新端口至 %s...\n" "$input_port"; local env_file="$target_dir/.env"; local tmp_env=$(mktemp)
[ -f "$env_file" ] && grep -v '^APP_PORT=' "$env_file" > "$tmp_env" 2>/dev/null || true; echo "APP_PORT=$input_port" >> "$tmp_env"
mv -f "$tmp_env" "$env_file"; chmod 600 "$env_file"
if [ "$host" = "0.0.0.0" ] && fw_is_initialized 2>/dev/null; then
[ -n "$port" ] && [ "$port" != "-" ] && fw_close "$port" 2>/dev/null || true; fw_open "$input_port" 2>/dev/null || true
fi
(cd "$target_dir" && docker compose up -d)
printf "${CLR_GREEN}端口已更新为 %s 并重载${CLR_RESET}\n" "$input_port"; read -r -p "按回车返回..."
fi
fi
;;
h|H)
local new_host="127.0.0.1"; [ "$host" = "127.0.0.1" ] && new_host="0.0.0.0"; printf "正在切换网络模式至 %s...\n" "$new_host"
local env_file="$target_dir/.env"; local tmp_env=$(mktemp)
[ -f "$env_file" ] && grep -v '^APP_HOST=' "$env_file" > "$tmp_env" 2>/dev/null || true; echo "APP_HOST=$new_host" >> "$tmp_env"
mv -f "$tmp_env" "$env_file"; chmod 600 "$env_file"
if fw_is_initialized 2>/dev/null && [ -n "$port" ] && [ "$port" != "-" ]; then
if [ "$new_host" = "0.0.0.0" ]; then
fw_open "$port" 2>/dev/null || true
else
fw_close "$port" 2>/dev/null || true
fi
fi
(cd "$target_dir" && docker compose up -d)
printf "${CLR_GREEN}网络模式已切换至 %s 并生效${CLR_RESET}\n" "$new_host"; read -r -p "按回车返回..."; ;;
0|*)
return 0; ;;
esac
done
}
ui_app_engine(){ local search_kw=""
while true; do
clear; app_cloud_fetch 2>/dev/null || true; local docker_snapshot=""
command -v docker >/dev/null 2>&1 && docker_snapshot=$(docker ps -a --format '{{.Label "com.docker.compose.project"}}|{{.Names}}|{{.State}}' 2>/dev/null || true)
local catalog=()
for c in $(app_cloud_list); do
catalog+=("$c")
done
local installed=()
for d in $(app_list_installed); do
installed+=("$d")
done
local all_items=()
if [ "${#catalog[@]}" -gt 0 ]; then
for c in "${catalog[@]}"; do
all_items+=("$c")
done
fi
if [ "${#installed[@]}" -gt 0 ]; then
for d in "${installed[@]}"; do
local in_cat=0
if [ "${#catalog[@]}" -gt 0 ]; then
for c in "${catalog[@]}"; do
[ "$c" = "$d" ] && { in_cat=1; break; }
done
fi
[ "$in_cat" -eq 0 ] && all_items+=("$d")
done
fi
local display_items=()
if [ -n "$search_kw" ]; then
if [ "${#all_items[@]}" -gt 0 ]; then
for item in "${all_items[@]}"; do
local meta=$(app_meta "$item" 2>/dev/null || true); local tag=""; [ -n "$meta" ] && IFS='|' read -r _ _ tag _ <<< "$meta"
case "$item $tag" in
*"$search_kw"*) display_items+=("$item") ;;
esac
done
fi
else
if [ "${#all_items[@]}" -gt 0 ]; then
display_items=("${all_items[@]}")
fi
fi
local total=${#display_items[@]}; local inst_count=${#installed[@]}
if [ -n "$search_kw" ]; then
printf -- "${CLR_BOLD}--- 应用市场 (搜索: %s · %d 款) ---${CLR_RESET}\n\n" "$search_kw" "$total"; elif [ "$inst_count" -gt 0 ]; then
printf -- "${CLR_BOLD}--- 应用市场 (%d 款 · %d 已安装) ---${CLR_RESET}\n\n" "$total" "$inst_count"
else
printf -- "${CLR_BOLD}--- 应用市场 (%d 款) ---${CLR_RESET}\n\n" "$total"
fi
local i=0
while [ $i -lt $total ]; do
local idx1=$((i + 1)); local name1="${display_items[$i]}"; local st1=$(app_status "$name1" "$docker_snapshot")
local meta1=$(app_meta "$name1" 2>/dev/null || true); local tag1=""; [ -n "$meta1" ] && IFS='|' read -r _ _ tag1 _ <<< "$meta1"
local c1=$(app_render_col "$idx1" "$name1" "$st1" "$tag1" 39); local c2=""; local next=$((i + 1))
if [ $next -lt $total ]; then
local idx2=$((next + 1)); local name2="${display_items[$next]}"; local st2=$(app_status "$name2" "$docker_snapshot")
local meta2=$(app_meta "$name2" 2>/dev/null || true); local tag2=""; [ -n "$meta2" ] && IFS='|' read -r _ _ tag2 _ <<< "$meta2"
c2=$(app_render_col "$idx2" "$name2" "$st2" "$tag2" 0)
fi
printf "%s%s\n" "$c1" "$c2"; i=$((i + 2))
done
echo
if [ -n "$search_kw" ]; then
printf "${CLR_DIM}[c] 清除搜索    [0] 返回${CLR_RESET}\n\n"
else
printf "${CLR_DIM}[0] 返回${CLR_RESET}\n\n"
fi
read -r -p "选择序号或搜索: " choice
if [ -z "$choice" ] || [ "$choice" = "0" ]; then
return 0
fi
if [ "$choice" = "c" ] || [ "$choice" = "C" ]; then
search_kw=""; continue
fi
if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
local selected="${display_items[$((choice - 1))]}"; local st=$(app_status "$selected" "$docker_snapshot")
if [ "$st" = "未安装" ]; then
ui_app_install_single "$selected"
else
ui_app_manage_single "$selected"
fi
else
search_kw="$choice"
fi
done
}
ui(){
while true; do
clear; printf "${CLR_BOLD}VPS-SH · Linux 运维控制台${CLR_RESET}\n"
printf "${CLR_DIM}版本: %s${CLR_RESET}%s\n\n" "$VPS_VERSION" "$(ops_update_badge)"; sys_snapshot; echo
printf "${CLR_CYAN}[1]${CLR_RESET} 系统配置\n"; printf "${CLR_CYAN}[2]${CLR_RESET} 网络配置\n"; printf "${CLR_CYAN}[3]${CLR_RESET} 安全防护\n"
printf "${CLR_CYAN}[4]${CLR_RESET} 运维监控\n"; printf "${CLR_CYAN}[5]${CLR_RESET} 应用市场\n"; printf "${CLR_CYAN}[6]${CLR_RESET} 容器引擎\n\n"
printf "${CLR_CYAN}[00]${CLR_RESET} 脚本管理\n"; printf "${CLR_DIM}[0]${CLR_RESET}  退出\n\n"; read -r -p "请选择: " choice
case "$choice" in 1) ui_sys ;; 2) ui_net ;; 3) ui_sec ;; 4) ui_ops ;; 5) ui_app_engine ;; 6) ui_docker ;; 00) ui_mgr ;; 0) exit 0 ;; *) ;; esac
done
}
case "${1:-}" in
rm|un|uninstall) sys_uninstall ;; up|update) shift; ops_update "$@" ;; app|apps|market) ui_app_engine ;; docker|d) ui_docker ;;
*)
sys_shortcut 2>/dev/null || true
if [ $# -eq 0 ]; then
if [ -t 1 ] && [ ! -t 0 ] && [ -r /dev/tty ]; then
exec < /dev/tty; elif [ ! -t 0 ]; then exit 0
fi
ui
else
if [ "$(type -t "$1" 2>/dev/null)" = "function" ]; then
case "$1" in sys_*|net_*|sec_*|fw_*|ops_*|docker_*|app_*|ui*) "$@" ;; *) echo "未知命令: $1" >&2; exit 1 ;; esac
else
echo "未知命令: $1" >&2; exit 1
fi
fi
;;
esac
