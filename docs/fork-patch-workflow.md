# Fork Patch Workflow

这份文档约定我们在 `chasing1874/cc-connect` fork 上的分支和 patch 规则。目标是：自己能先用，同时尽量降低以后跟进 `chenhg5/cc-connect` 上游时的冲突成本。

## Remotes

- `upstream`: `git@github.com:chenhg5/cc-connect.git`
- `origin`: `git@github.com:chasing1874/cc-connect.git`

`upstream` 只拉取，不推送。`main` 保持为上游镜像。

## Branches

- `main`: 镜像 `upstream/main`。不在这里写任何自定义 commit。
- `codex/fork-tooling`: fork 专用脚本和规范。只放不打算提交给上游的维护文件。
- `codex/work/<topic>`: 自用功能分支。从 `main` 出发，只放真实功能 patch；不要合入 fork tooling，避免手滑开 PR 时把维护文件带上。
- `codex/pr/<topic>`: 上游 PR 分支。必须从干净的 `main` 切出，只包含准备提交给上游的最小改动。

当前建议主题名：

- `codex/work/thread-id-isolation`
- `codex/pr/thread-id-isolation`

## Sync Routine

推荐先把同步脚本安装到本地 ignored 路径。仓库根目录的 `scripts/` 已被上游 `.gitignore` 忽略，因此不会进入 PR：

```bash
mkdir -p scripts
cp tools/fork-sync.sh scripts/fork-sync.sh
chmod +x scripts/fork-sync.sh
```

只同步镜像 main：

```bash
scripts/fork-sync.sh --main-only
```

同步 fork tooling：

```bash
tools/fork-sync.sh --branch codex/fork-tooling --base main --push
```

同步自用 patch 分支：

```bash
scripts/fork-sync.sh --branch codex/work/thread-id-isolation --base main --push
```

`git rerere` 已启用。解决过的同类冲突会被 Git 记录，后续 rebase 时会尽量自动复用。

## PR Branch Routine

PR 分支不要从自用分支直接推。先从干净 main 切，再 cherry-pick 可上游的 commit：

```bash
git switch main
git merge --ff-only upstream/main
git switch -c codex/pr/thread-id-isolation
git cherry-pick <commit-1> <commit-2>
go test ./platform/feishu ./core
git push -u origin codex/pr/thread-id-isolation
```

如果自用分支里混入了 fork-only 文件、临时调试、个人配置，不要带进 PR 分支。

## Patch Rules

- 默认行为不变。新增能力必须默认关闭，或通过新配置显式开启。
- 小步提交。一个 commit 只做一个可解释的行为变化。
- 优先局部修改。Feishu thread 问题优先限制在 `platform/feishu/`、对应测试和配置示例里。
- 不做大范围格式化，不重排无关代码，不批量改注释。
- 不提交个人配置、构建产物、二进制、日志、截图、临时脚本输出。
- 新用户可见文案要走 i18n；配置项要补 `config.example.toml`。
- 行为改动必须配测试，尤其覆盖旧行为不回归。

## Thread Isolation Patch Shape

上游当前 `thread_isolation` 偏向按 `RootId` / root message 隔离。我们的目标 patch 应该做成兼容模式，而不是直接推翻旧语义。

建议配置：

```toml
thread_isolation = true
thread_isolation_mode = "root"       # default, current behavior
# thread_isolation_mode = "thread_id" # isolate only real Feishu topic/thread messages
```

建议测试矩阵：

- `thread_isolation_mode = "root"` 时保持现有 `RootId` 行为。
- `thread_isolation_mode = "thread_id"` 且 `ThreadId` 非空时，session key 使用 thread id。
- `thread_isolation_mode = "thread_id"` 且只有普通 `ParentId` / `RootId` reply 时，不创建 thread session。
- `auto_thread` 与 isolation mode 保持解耦：它只负责是否自动创建话题，不负责定义 session 隔离语义。

## Conflict Policy

- 开始写代码前先运行 `scripts/fork-sync.sh --main-only`。
- 自用分支每天或每次改动前 rebase 一次。
- PR 分支尽量晚创建，或者每次从最新 main 重新 cherry-pick。
- 如果同一个文件冲突反复出现，优先把我们的改动收缩成更小的 helper 或更靠近原逻辑的小 hunk。
- 如果上游实现了相同能力，优先删除我们的 patch，改为适配上游配置。
