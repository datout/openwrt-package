# openwrt-package

openwrt 插件聚合仓库：用于把多个常用插件/依赖同步到不同分支（例如 `Lede`）。

当前 `Lede` 分支已包含：

- Passwall（LuCI）
- Passwall 依赖包（openwrt-passwall-packages，含 sing-box / geoview 等）

同步逻辑见：`.github/workflows/sync-feeds.yml` + `scripts/sync_branch.sh`。
