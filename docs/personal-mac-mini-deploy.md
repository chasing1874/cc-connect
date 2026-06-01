# Mac mini 部署个人 Fork 版 cc-connect

这份文档用于在另一台 Mac mini 上部署你自己的 fork 版本，而不是官方 npm / brew 安装包。

推荐分支策略：

- `main`：干净同步 `upstream/main`。
- `codex/pr/*`：每个准备提给上游的 PR 分支。
- `personal/stable`：你自己的生产稳定分支。上游暂未合入、但你要先自用的 PR，可以先 merge 到这里。

日常生产部署只从 `personal/stable` 构建。

## 1. 前置准备

安装系统构建工具：

```bash
xcode-select --install
```

安装基础依赖：

```bash
brew install git go node
```

如果要构建带 Web Admin UI 的完整二进制，保留 Node/npm 即可；`make build` 会进入 `web/` 执行 npm 构建。

安装并登录你要使用的 agent CLI。至少需要：

```bash
# Claude Code，按你当前机器的安装方式装到 npm 全局即可
npm install -g @anthropic-ai/claude-code
claude --version

# Codex
npm install -g @openai/codex
codex --version
```

然后分别完成登录或鉴权：

```bash
claude
codex
```

确认当前 shell 能找到这些命令：

```bash
which claude
which codex
which go
which node
```

重要：`cc-connect daemon install` 会把当前 shell 的 `PATH` 写进 launchd plist。一定要在 `claude`、`codex` 都能被 `which` 找到的 shell 里安装 daemon。

## 2. 克隆个人 Fork

建议目录：

```bash
mkdir -p ~/code
cd ~/code
git clone git@github.com:chasing1874/cc-connect.git
cd cc-connect
```

配置上游仓库：

```bash
git remote add upstream git@github.com:chenhg5/cc-connect.git 2>/dev/null || true
git fetch origin upstream --prune
```

切到生产稳定分支：

```bash
git switch personal/stable
git pull --ff-only origin personal/stable
```

如果 Mac mini 上暂时拉不到 `personal/stable`，先在主力机推送：

```bash
cd /Users/jiangziyou/code/cc-connect
git switch personal/stable
git push -u origin personal/stable
```

## 3. 准备项目工作目录

你的当前配置里两个项目都指向同一个工作目录：

```toml
work_dir = "/Users/jiangziyou/code/manju/dramaflow"
```

Mac mini 上也要有这个目录，或者把配置里的 `work_dir` 改成 Mac mini 实际路径。

示例：

```bash
mkdir -p ~/code/manju
cd ~/code/manju
git clone <your-dramaflow-repo-url> dramaflow
```

然后确认：

```bash
ls ~/code/manju/dramaflow
```

## 4. 构建 cc-connect

完整构建，带 Web Admin UI：

```bash
cd ~/code/cc-connect
make build AGENTS=codex,claudecode PLATFORMS_INCLUDE=feishu,weixin
```

如果你不需要内置 Web UI，可以构建更轻的 no-web 版本：

```bash
make build-noweb AGENTS=codex,claudecode PLATFORMS_INCLUDE=feishu,weixin
```

安装到稳定路径：

```bash
mkdir -p ~/.local/bin
cp ./cc-connect ~/.local/bin/cc-connect
chmod +x ~/.local/bin/cc-connect
```

确保 `~/.local/bin` 在 PATH 前面：

```bash
grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
hash -r
```

确认命中的是你自己构建的版本：

```bash
which cc-connect
cc-connect --version
```

期望路径：

```text
/Users/<mac-mini-user>/.local/bin/cc-connect
```

## 5. 配置文件

配置文件放在：

```text
~/.cc-connect/config.toml
```

创建目录：

```bash
mkdir -p ~/.cc-connect
chmod 700 ~/.cc-connect
```

可以从主力机复制一份，再替换密钥和路径：

```bash
scp ~/.cc-connect/config.toml <mac-mini-host>:~/.cc-connect/config.toml
```

复制后设置权限：

```bash
chmod 600 ~/.cc-connect/config.toml
```

### 配置模板

下面模板按你当前生产配置整理。所有密钥都用占位符表示，复制到 Mac mini 后需要替换。

```toml
data_dir = ""
attachment_send = ""
language = "zh"
idle_timeout_mins = 120

[[projects]]
  name = "cc-weixin"
  show_context_indicator = true
  reply_footer = true
  inject_sender = true
  admin_from = "WEIXIN_USER_ID,FEISHU_OPEN_ID"

  [projects.agent]
    type = "claudecode"

    [projects.agent.options]
      mode = "bypassPermissions"
      work_dir = "/Users/<mac-mini-user>/code/manju/dramaflow"

  [[projects.platforms]]
    type = "weixin"

    [projects.platforms.options]
      account_id = "YOUR_WEIXIN_ACCOUNT_ID"
      allow_from = "WEIXIN_USER_ID"
      base_url = "https://ilinkai.weixin.qq.com"
      token = "YOUR_WEIXIN_TOKEN"

  [[projects.platforms]]
    type = "feishu"

    [projects.platforms.options]
      allow_from = "FEISHU_OPEN_ID"
      app_id = "YOUR_FEISHU_APP_ID"
      app_secret = "YOUR_FEISHU_APP_SECRET"
      enable_feishu_card = true
      thread_isolation = true
      feishu_thread_isolation_mode = "thread_only"

[[projects]]
  name = "codex-feishu"
  show_context_indicator = true
  reply_footer = true
  inject_sender = false
  admin_from = "FEISHU_OPEN_ID"

  [projects.agent]
    type = "codex"

    [projects.agent.options]
      mode = "suggest"
      work_dir = "/Users/<mac-mini-user>/code/manju/dramaflow"

  [[projects.platforms]]
    type = "feishu"

    [projects.platforms.options]
      allow_from = "FEISHU_OPEN_ID"
      app_id = "YOUR_CODEX_FEISHU_APP_ID"
      app_secret = "YOUR_CODEX_FEISHU_APP_SECRET"
      enable_feishu_card = true
      thread_isolation = true
      feishu_thread_isolation_mode = "thread_only"

[log]
  level = "info"

[speech]
  enabled = false
  provider = ""
  language = ""

  [speech.openai]
    api_key = ""
    base_url = ""
    model = ""

  [speech.groq]
    api_key = ""
    model = ""

  [speech.qwen]
    api_key = ""
    base_url = ""
    model = ""

  [speech.gemini]
    api_key = ""
    model = ""

[tts]
  enabled = false
  provider = ""
  voice = ""
  tts_mode = ""
  max_text_len = 0

  [tts.openai]
    api_key = ""
    base_url = ""
    model = ""

  [tts.qwen]
    api_key = ""
    base_url = ""
    model = ""

  [tts.minimax]
    api_key = ""
    base_url = ""
    model = ""

  [tts.mimo]
    api_key = ""
    base_url = ""
    model = ""

[display]
  mode = "full"
  card_mode = "rich"
  thinking_messages = true
  thinking_max_len = 300
  tool_max_len = 500
  tool_messages = true

[stream_preview]
  enabled = true
  interval_ms = 1500

[instant_reply]
  content = ""

[rate_limit]
  max_messages = 20
  window_secs = 60

[cron]
  session_mode = ""

[webhook]
  port = 0

[bridge]
  enabled = true
  port = 9810
  token = "GENERATE_A_RANDOM_BRIDGE_TOKEN"
  cors_origins = ["*"]

[management]
  enabled = true
  port = 9820
  token = "GENERATE_A_RANDOM_MANAGEMENT_TOKEN"
  cors_origins = ["*"]
```

生成 `bridge.token` 和 `management.token`：

```bash
openssl rand -hex 32
openssl rand -hex 32
```

### 关键配置说明

`show_context_indicator = true`

在回复里显示上下文比例，例如 `[ctx: ~14%]`。

`reply_footer = true`

在回复末尾显示类似 Codex 的状态行，包括模型、推理档位、剩余上下文、工作目录等。

`inject_sender = true`

把发送者身份注入给 agent。多人群聊里建议打开。你当前 `cc-weixin` 打开，`codex-feishu` 关闭。

`admin_from`

允许谁执行高权限命令，例如 `/dir`、`/shell`、`/restart`、`/upgrade`。不要随便设成 `*`。

`mode = "bypassPermissions"`

Claude Code 会跳过权限确认，适合你信任的自用环境；如果开放给更多人，建议改成更保守的模式。

`mode = "suggest"`

Codex 项目使用较保守的建议模式。

`enable_feishu_card = true`

启用飞书卡片展示。需要飞书应用权限和事件订阅正常。

`thread_isolation = true`

开启飞书群聊会话隔离能力。

`feishu_thread_isolation_mode = "thread_only"`

这是你 fork 里的新增模式：普通群聊和普通 Reply 保持主会话，只有飞书原生 Reply in Thread / 话题消息带 `ThreadId` 时才开独立子会话。

`[display]`

控制思考、工具调用和回复展示方式。你当前使用完整展示：

```toml
mode = "full"
card_mode = "rich"
thinking_messages = true
tool_messages = true
```

`[stream_preview]`

开启流式预览，当前每 1500ms 更新一次。

`[bridge]`

对外部 adapter 提供 WebSocket bridge，默认端口 `9810`。

`[management]`

开启管理 API，默认端口 `9820`。如果 Mac mini 不需要被外部管理，可以设为：

```toml
[management]
  enabled = false
```

## 6. 启动 daemon

先确认配置能加载。可以前台跑一次，看到启动日志后用 `Ctrl+C` 停止：

```bash
cc-connect --config ~/.cc-connect/config.toml
```

安装并启动 launchd daemon：

```bash
cc-connect daemon install --config ~/.cc-connect/config.toml --force
```

查看状态：

```bash
cc-connect daemon status
```

看日志：

```bash
cc-connect daemon logs -f
```

重启：

```bash
cc-connect daemon restart --force
```

停止：

```bash
cc-connect daemon stop
```

卸载 daemon：

```bash
cc-connect daemon uninstall
```

## 7. 多机器部署注意事项

不要让两台机器同时使用同一个 Feishu app / Weixin token 长期在线，除非你明确知道平台会如何分发事件。

更稳的方式：

- 主力机和 Mac mini 只保留一台生产 daemon 在线。
- 如果两台都要在线，给 Mac mini 准备单独的 Feishu bot / Weixin 配置。
- 如果只是迁移到 Mac mini，先在旧机器执行：

```bash
cc-connect daemon stop
```

然后再在 Mac mini 启动。

## 8. 日常更新

在 Mac mini 上更新你的个人 fork 稳定版：

```bash
cd ~/code/cc-connect
git fetch origin upstream --prune
git switch personal/stable
git pull --ff-only origin personal/stable

make build AGENTS=codex,claudecode PLATFORMS_INCLUDE=feishu,weixin
cp ./cc-connect ~/.local/bin/cc-connect
cc-connect daemon restart --force
```

当上游合入某个 PR 后，在主力机或 Mac mini 上维护分支：

```bash
git fetch origin upstream --prune

git switch main
git merge --ff-only upstream/main
git push origin main

git switch personal/stable
git merge --no-ff main
git push origin personal/stable
```

如果你又做了一个未合入上游的新 PR：

```bash
# PR 分支仍然从 upstream/main 开
git switch -c codex/pr/new-feature upstream/main

# 做完并提 PR 后，合进自用稳定分支
git switch personal/stable
git merge --no-ff codex/pr/new-feature
git push origin personal/stable
```

## 9. 常见问题

### daemon 显示 Stopped

看日志：

```bash
cc-connect daemon logs -n 120
```

如果看到：

```text
claudecode: "claude" CLI not found in PATH
```

说明安装 daemon 时 launchd 没拿到正确 PATH。先确认当前 shell 能找到：

```bash
which claude
which codex
```

然后重新安装 daemon：

```bash
cc-connect daemon install --config ~/.cc-connect/config.toml --force
```

### 端口冲突

检查端口：

```bash
lsof -i :9810
lsof -i :9820
```

如果冲突，改配置里的 `[bridge].port` 或 `[management].port`，或者禁用对应功能。

### 收到重复消息

通常是两台机器同时跑了同一个 bot 凭证。停止旧机器：

```bash
cc-connect daemon stop
```

### 飞书 Thread 没有隔离

确认配置在对应 Feishu platform 下：

```toml
thread_isolation = true
feishu_thread_isolation_mode = "thread_only"
```

并确认用户是在飞书原生话题 / Reply in Thread 里发消息。普通 Reply 不会开子会话，这是这个模式的预期行为。

