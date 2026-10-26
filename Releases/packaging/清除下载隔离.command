#!/bin/zsh
set -eu
app="/Applications/Finder2right.app"
result=0
printf 'Finder2right 清除下载隔离\n仅删除此 App 内的 com.apple.quarantine 属性，保留其他扩展属性。\n不修改系统全局来源限制，不跟随符号链接。\n\n'
if [[ ! -d "$app" || -L "$app" ]]; then
  printf '未找到有效的 %s\n请先将 Finder2right 拖入 Applications，再运行此脚本。\n' "$app"
  result=1
elif [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)" != local.finder2right ]]; then
  printf 'App 标识不符合预期，已停止处理。\n'
  result=1
else
  printf '仅当你确认安装包来源可信且未遭篡改时继续。\n若系统检测到恶意软件或提示 App 将损坏电脑，请停止使用。\n'
  read -r 'reply?输入 y 确认处理 Finder2right，其他输入取消：' || reply=""
  if [[ "$reply" != y && "$reply" != Y ]]; then
    printf '已取消。\n'
  elif sudo /usr/bin/xattr -r -s -d com.apple.quarantine "$app"; then
    printf '\n已完成，请从「应用程序」重新打开 Finder2right。\n'
  else
    printf '\n未能完成处理，请检查终端中的错误信息。\n'
    result=1
  fi
fi
printf '\n按回车结束…'
read -r reply || true
exit "$result"
