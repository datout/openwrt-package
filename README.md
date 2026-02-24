# openwrt-package

openwrt 插件聚合仓库：用于把多个常用插件/依赖同步到不同分支（例如 `Lede`）。

当前 `Lede` 分支已包含：

- Passwall（LuCI）
- Passwall 依赖包（openwrt-passwall-packages，含 sing-box / geoview 等）

同步逻辑见：`.github/workflows/sync-feeds.yml` + `scripts/sync_branch.sh`。


当前也支持同步 `Immortalwrt` 分支（用于 ImmortalWrt 源码编译），该分支包含 Nikki（`luci-app-nikki` + `nikki/mihomo`），并携带 `packages_lang_golang`（Go 1.26）快照，方便在 23.05/24.10 等稳定分支上提升 Go 版本。
