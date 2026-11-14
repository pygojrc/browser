# browser 兼容性、遥测与维护计划

> 目标仓库：独立的 `browser`；分支 `codex/ms-browser-adaptation`；源码基线 `3b83a34e0ddc6c572d4f3c88add10de1a47541c5`。源码核对为主要依据；检测仅为异版本预调查，须用本提交重测。
> 证据快照 schema 2；具体摘要及受引文件见 §11。GitNexus `ms-browser` 已用 1.6.12 的 `analyze --index-only --pdg` 索引当前 HEAD；生成警告显示部分调用关系和流程截断，源码比图谱优先。

## 1. 目标

在 Linux 上以同环境真实 Chromium 为参照，修复可合理实现的浏览器身份及兼容性差异；彻底停止上游遥测，适配 pygojrc 的 CI 构建、产物和文档。记录引擎级高成本差异，不能承诺不可识别或通过所有站点。

## 2. 当前行为

- [verified] `src/Config.zig:1091` 默认 UA 是 `Lightpanda/1.0`，Client Hints 以 Lightpanda 品牌为静态源；`src/network/HttpClient.zig:485` 统一提供网络与 navigator UA，但 baseline 固定发送 UA-CH full-version-list。
- [verified] `src/browser/webapi/NavigatorUAData.zig:36` 的低熵品牌读取 full version；高熵接口忽略请求 hints。`src/browser/webapi/Navigator.zig:83` 的 appVersion、vendor、硬件值与 UA 非统一身份源；`WorkerNavigator.zig:49` 部分委托 Navigator。
- [verified] `src/server/cdp/domains/emulation.zig:142` CLI/CDP 均有 Mozilla 字符串限制；CDP 的 platform 当前忽略；language 可独立生效。非打印字符及 CR/LF 保护必须保留。
- [verified] `src/telemetry/telemetry.zig:11` 在 debug/test 或环境变量下停发，release 默认启用，可能写 iid；provider `src/telemetry/lightpanda.zig:24` 有上游 URL、队列与线程。`src/Updater.zig:28` 的显式版本检查另访问同域名。
- [verified] `src/server/Server.zig:111` 已支持显式 Unix socket 和 ws+unix 地址；项目尚未证明与 Chromium 注册表或 DrissionPage 兼容。
- [verified] `README.md` 描述无完整图形引擎；PNG/PDF 为文本渲染，不能承诺桌面 Chromium 行为。`AGENTS.md` 要求调试测试处理内存泄漏，先取得预编译 V8。
- [verified] `zig-test.yml`、`release.yml`、`wpt.yml`、`e2e-test.yml`、`cla.yml` 存在上游 secrets、AWS/Slack、上游 repo、self-hosted runner 或发布链。依赖包 `build.zig.zon` 仍需要上游源码，不应盲目改域名。

## 3. 现有实测与适用范围

2026-11-14 用 `/data/bin/lightpanda` 1.1.0-nightly.10619+ed5a25e5d，禁用遥测，`fetch --dump markdown --wait-ms 12000`：Sannysoft 返回 UA Lightpanda/1.0、chrome missing、插件为 0 且类型失败、WebGL context 缺失、CHR_MEMORY FAIL；部分项显示 ok 不意味着整体正常。botstop 停在 scoring；rebrowser 检测表为空，且它注明针对 Chromium，缺少其要求的 automation 触发步骤。三者均非当前源码构建，且无配对同环境 Chrome，不能直接将各结果归因当前 HEAD，也不能当通过率。原始文本暂在 `/tmp/ms-browser-probe-{0,1,2}.txt`，非永久证据。

## 4. 参考与边界

上级项目 `docs/chromium-changes.md` 有 HTTP/JS/Worker、GREASE、语言、canvas 与音频的反例，适合作为一致性约束；此项目独立，不能假定其 C++ 修改可移植或擅自继承 Chromium profile/seed 契约。`botstop.io` 可看细粒度指标，`bot-detector.rebrowser.net` 补充 Chromium/CDP 探针，`bot.sannysoft.com` 适合基本回归；需要同时保留正常 Chromium、未改 browser 和改后 browser，固定网络、语言、时区，记录版本、配置、等待和失败原因。

## 5. 图谱、控制流与数据约束

`setUserAgentOverride` 先校验 UA，再处理 language，最后可能因 reserved 早返回；更改限制须重新定义非法输入原子性和覆盖优先级。`baselineHeaders` 当前静态品牌与动态 UA 相分离；修改需同时管生命周期和多 context 隔离。遥测关闭条件在 `record`，但 provider 仍初始化；去除发送需同时处理实例 ID、线程生命周期和版本检查。[graph] GitNexus 找到 Emulation 与 Network 的 `processMessage` 均调用该入口；[verified] 源码确认 Network 分发至同一处理函数。PDG 查询未产生可用的具体边，不从空结果推断无依赖。索引有候选集上限和流程截断警告，完整调用方仍需源码核对。

## 6. 拟修改

1. **身份及一致性（中成本）**：建立集中、可配置的 Linux Chromium 兼容身份及清楚的版本来源；默认策略和版本绑定在基线采集后明确。由同一数据源提供 UA、UA-CH（major/full/GREASE 分别正确）、platform、appVersion、vendor、HTTP 与页面/Worker；尊重 CLI/CDP 覆盖，保留 header 安全校验。对 `Network/Emulation.setUserAgentOverride` 的 UA、platform、metadata、语言分别规定覆盖、清除和多 context 隔离；缺失能力不能静默伪称支持。根据真实 Chromium 的安全上下文、Accept-CH、重定向、缓存与跨域行为确定 header 发送，而不是无条件发送完整高熵值。
2. **已测低成本兼容项（先验证）**：检查 `window.chrome`、PluginArray/MimeTypeArray 接口、`navigator` 对象描述符与权限、缺失 API 是否能基于真实功能作最小规范实现。只在实际实现可支持时暴露，不能简单填充虚假对象或掩盖功能失败。CHR_MEMORY FAIL 先定位探针原因；webgl 和 canvas 不能单凭检测页假造结果。
3. **删除外部遥测（中成本）**：移除外发路径、后台 sender 和 iid 创建；清查所有调用点与构建引用，可先用无副作用的内部接口降低改动范围，再清理死代码；`version --check` 明确取消上游请求并输出本 fork 不支持或配置独立来源；旧 iid 默认保留且不读取，不主动删除用户数据。保留本地日志、指标和用户主动配置的站点、代理及模型请求，逐项区分。
4. **构建和 workflow（中成本）**：固定项目要求 Zig 0.17.0、Rust、预编译 V8 版本与来源及缓存，优先 Linux x86_64 的可重现 debug/test 和 release；`make download-v8`、`make fmt`、`make test`、`make build` 与 CI 使用同一输入。审计各 workflow 的触发、权限、token、依赖、runner、产物及外部副作用；基本 PR/push/手动任务只依赖公开工具，显式处理 draft 判断。发布改为 pygojrc 仓库内按 tag/手动生成版本化产物和 SHA256，默认不调用上游 AWS/Slack/app/发布仓库；其他平台仅在对应 runner 验证后宣称支持。保留必要上游 V8 等依赖与许可证来源，不盲目替换地址。
5. **高成本能力与开关**：高成本修复逐项做可行性和成本评估，具备可交付的方案时拆分成独立阶段实现，每项提供单独开关；不能因为新增能力而强迫旧站点使用。建议默认关闭未经充分验证的新能力，并提供显式启用/关闭，既有能力的默认值以兼容性验证为准。明确 CLI/配置优先级、browser/context 作用域、冲突行为、重启要求和实际生效状态；无法在运行中安全切换时明确提示重启。以 WebGL 为例，关闭时保留原先无 context 行为、禁用对应 API/资源分配，启用时必须实现可用的 context 与一致的能力，避免只填伪造字段；验证同一站点启用失败、关闭恢复的场景。超出可行成本的引擎项目可暂缓，记录评估依据和迁移方案。
6. **文档和注释**：更新 README、贡献/构建及 help、源码过时注释、workflow 说明、遥测/更新说明，注明 fork 来源、维护者、兼容性边界、发布与验证；保留版权及许可声明。明确独立仓库、配置升级及已知差异。

## 7. 实施顺序

1. 在独立仓库确认源码、编译器、依赖、网络及缓存；按项目指令获取预编译 V8，构建当前提交，记录版本和二进制哈希，跑格式、现有测试与基本启动。
2. 建本地采集页/HTTP echo：收集 HTTP 头、JS/Worker navigator、UA-CH、语言、插件、屏幕及可用 API；同环境有头 Chromium 对照；依次检测 Sannysoft、botstop、rebrowser，记录失败/未完成而非硬算通过。将原始证据与配置保存到合适任务资料位置。
3. 完整跟踪遥测和版本检查，实施移除并验证无外发，再同步文档。
4. 统一身份数据与 CDP 覆盖；逐项实现证据支持且低中成本的可修项，每一项先有复现和目标、后有对照验证。
5. 改造 workflow；在 PR/push/dispatch 至少各验证触发条件，debug/test 与 release 构建、上传及下载产物可用；tag 发布先验证 dry-run/隔离仓库，再启用实际发布。
6. 用相同环境和命令复测本地采集页及检测站，记录差异、站点未完成及成本决策；最后核对 README、注释、CI 和测试。

## 8. 验证策略

- `make fmt`、`make test`、`make build`；开发依赖先 `make download-v8`，测试过滤参考 `AGENTS.md`；当前主机 PATH 无 Zig，命令未运行成功，不得声称已通过。
- 本地服务器断言 UA、Sec-CH-UA/安全上下文/高熵协商、Accept-Language 与 JS/Worker 一致；变更/清除 CDP override、两个 context、重定向、恶意控制字符及旧命令行兼容；覆盖 major/full/GREASE、不同版本和平台。
- 按真实可用性验证插件、类型、方法、迭代、权限与异常；负向用例证明矛盾或缺 API 时探针能识别。
- release 和 debug 在干净 HOME / 网络监控环境运行 serve/fetch/mcp/agent/version --check；确认无上游遥测、无 iid 创建/读取，显式业务请求正常，本地指标保留。
- workflow 静态校验、无秘密 fork 执行及发布产物下载后 `version`、本地 HTTP fetch、CDP TCP/Unix socket smoke；区别本机验证和 GitHub Actions 实际结果。
- 对每项高成本能力验证默认值、开启、关闭、无效配置、相互隔离、启动与关闭生命周期；用具备问题页面的 fixture 验证关闭后恢复加载。
- 对照检测采集以项目内原始资料为基础，清楚标识 browser 二进制版本、站点加载状态、环境和是否由客户端连接；既不依赖单一评分，也不把不执行当成功。

## 9. 风险与成本划分

- **纳入**：真实数据源统一、UA/CH、已支持的语言/覆盖、遥测和版本检查、可构建 CI、文档；兼容对象限能够实现规范行为的部分。
- **先调查再决定**：CDP 覆盖完整度、窗口几何、插件与权限、TLS/HTTP 差异、字体和音频：每项给复现、影响范围、实现量及回归后决定。
- **高成本分期**：真实 WebGL/GPU、完整图形渲染、扩展及桌面系统等先做可行性评估；成本可接受的分阶段纳入并带独立开关、失败回退与站点回归。超过可接受成本者暂缓，说明证据、成本及影响；不可用编造值冒充。全 Chromium Web API 和通过所有站点不作为承诺。
- 声称 Chromium 身份可能与缺失 Web API、TLS、图形能力相矛盾，修复优先可验证一致性；上游大规模测试和真实网站会变化，分数不是完成标准。

## 10. 涉及文件

`src/Config.zig`、`src/network/HttpClient.zig`、`src/browser/webapi/{Navigator,WorkerNavigator,NavigatorUAData}.zig`、`src/server/cdp/domains/{emulation,browser}.zig`、`src/server/http.zig`、`src/{App,main,Updater}.zig`、`src/telemetry/`、相关调用和测试；`.github/workflows/`、`.github/actions/install/`、`Makefile`、`build.zig.zon`、`README.md`、`AGENTS.md` 等依据实际范围增减。浏览器检测用脚本与记录放独立仓库内约定位置，避免误修改上层项目。

## 11. 可复用实施上下文

```json
{
  "implementation_context": {
    "task_summary": "Linux Chromium compatibility, remove external telemetry, pygojrc CI and documentation",
    "acceptance_criteria": [
      "Build current commit and establish baseline",
      "No upstream telemetry or update-check traffic",
      "Identity consistency and safe override semantics",
      "CI build and artifact smoke tests",
      "Document measured and deferred differences"
    ],
    "evidence_provenance": {
      "schema_version": 2,
      "head_commit": "3b83a34e0ddc6c572d4f3c88add10de1a47541c5",
      "generated_plan_path": "docs/plans/2026-11-14-gitnexus-plan-browser-compatibility-maintenance.md",
      "global_dirty_digest": {
        "algorithm": "sha256",
        "canonicalization": "gitnexus-evidence-provenance-v2 NUL-framed UTF-8 records",
        "value": "0a9c85780067d9afcd0764f307b60891e3cee927ee11eaeb5ec7826d10fd82cd"
      },
      "cited_path_manifest": [
        {
          "path": ".github/actions/install/action.yml",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:8f5f7411ece469d75b4e43b1367eb86965ef0a29947f369d153e2661a1c91157",
          "index_digest": "sha256:8f5f7411ece469d75b4e43b1367eb86965ef0a29947f369d153e2661a1c91157",
          "worktree_digest": "sha256:8f5f7411ece469d75b4e43b1367eb86965ef0a29947f369d153e2661a1c91157",
          "untracked_digest": "absent"
        },
        {
          "path": ".github/workflows/cla.yml",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:1b975719dd2ce156bd6c1401a4931f311ba0a5f182c8d922299c0238c27c298c",
          "index_digest": "sha256:1b975719dd2ce156bd6c1401a4931f311ba0a5f182c8d922299c0238c27c298c",
          "worktree_digest": "sha256:1b975719dd2ce156bd6c1401a4931f311ba0a5f182c8d922299c0238c27c298c",
          "untracked_digest": "absent"
        },
        {
          "path": ".github/workflows/e2e-test.yml",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:b25105028d11316fde40509dee5ed97eca187729b58f93728d14a1edea30bc8e",
          "index_digest": "sha256:b25105028d11316fde40509dee5ed97eca187729b58f93728d14a1edea30bc8e",
          "worktree_digest": "sha256:b25105028d11316fde40509dee5ed97eca187729b58f93728d14a1edea30bc8e",
          "untracked_digest": "absent"
        },
        {
          "path": ".github/workflows/release.yml",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:f7d11e23b671da764e0417189ab78d899368851296e75cf432725f10357b15e1",
          "index_digest": "sha256:f7d11e23b671da764e0417189ab78d899368851296e75cf432725f10357b15e1",
          "worktree_digest": "sha256:f7d11e23b671da764e0417189ab78d899368851296e75cf432725f10357b15e1",
          "untracked_digest": "absent"
        },
        {
          "path": ".github/workflows/wpt.yml",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:0fb82b534e1acadaf8d060bfe9ca464309dc05aa6ca1e0ea4157a0f9750bb644",
          "index_digest": "sha256:0fb82b534e1acadaf8d060bfe9ca464309dc05aa6ca1e0ea4157a0f9750bb644",
          "worktree_digest": "sha256:0fb82b534e1acadaf8d060bfe9ca464309dc05aa6ca1e0ea4157a0f9750bb644",
          "untracked_digest": "absent"
        },
        {
          "path": ".github/workflows/zig-test.yml",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:a67f7908b7426401748d63ffc82a71bcf73bb46d3d916899be6e4c24234eef15",
          "index_digest": "sha256:a67f7908b7426401748d63ffc82a71bcf73bb46d3d916899be6e4c24234eef15",
          "worktree_digest": "sha256:a67f7908b7426401748d63ffc82a71bcf73bb46d3d916899be6e4c24234eef15",
          "untracked_digest": "absent"
        },
        {
          "path": "AGENTS.md",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:b62edf851b2ca4205b176c9b1faf146360e559c828222612927ba0a96d043d8b",
          "index_digest": "sha256:b62edf851b2ca4205b176c9b1faf146360e559c828222612927ba0a96d043d8b",
          "worktree_digest": "sha256:b62edf851b2ca4205b176c9b1faf146360e559c828222612927ba0a96d043d8b",
          "untracked_digest": "absent"
        },
        {
          "path": "Makefile",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:d6b345d015bba12278209e649eb19bcf3208442fa2a247dc15309f60bf46fda0",
          "index_digest": "sha256:d6b345d015bba12278209e649eb19bcf3208442fa2a247dc15309f60bf46fda0",
          "worktree_digest": "sha256:d6b345d015bba12278209e649eb19bcf3208442fa2a247dc15309f60bf46fda0",
          "untracked_digest": "absent"
        },
        {
          "path": "README.md",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:5b1678e9b8ad87ea3ed968a1e5c630b7e484f753204a0ae91641e74c275b76f9",
          "index_digest": "sha256:5b1678e9b8ad87ea3ed968a1e5c630b7e484f753204a0ae91641e74c275b76f9",
          "worktree_digest": "sha256:5b1678e9b8ad87ea3ed968a1e5c630b7e484f753204a0ae91641e74c275b76f9",
          "untracked_digest": "absent"
        },
        {
          "path": "build.zig.zon",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:71506a89ef5fce825eec1c0a14545a50cfde40dd552a2eea1ba142001818881f",
          "index_digest": "sha256:71506a89ef5fce825eec1c0a14545a50cfde40dd552a2eea1ba142001818881f",
          "worktree_digest": "sha256:71506a89ef5fce825eec1c0a14545a50cfde40dd552a2eea1ba142001818881f",
          "untracked_digest": "absent"
        },
        {
          "path": "src/App.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:721eeec9c83e00e5d47fa0f3d2d4fd61b736784238a652c2b8572c1509c335cf",
          "index_digest": "sha256:721eeec9c83e00e5d47fa0f3d2d4fd61b736784238a652c2b8572c1509c335cf",
          "worktree_digest": "sha256:721eeec9c83e00e5d47fa0f3d2d4fd61b736784238a652c2b8572c1509c335cf",
          "untracked_digest": "absent"
        },
        {
          "path": "src/Config.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:5b377c59dcc870e6610b1062a3b007fabbcb6be66a20db1dca7c26839e3d9667",
          "index_digest": "sha256:5b377c59dcc870e6610b1062a3b007fabbcb6be66a20db1dca7c26839e3d9667",
          "worktree_digest": "sha256:5b377c59dcc870e6610b1062a3b007fabbcb6be66a20db1dca7c26839e3d9667",
          "untracked_digest": "absent"
        },
        {
          "path": "src/Updater.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:78b2073ac6eebe239965cdcbfde4ddd0d00606e9bc0f5a132a6e5a4c3508687f",
          "index_digest": "sha256:78b2073ac6eebe239965cdcbfde4ddd0d00606e9bc0f5a132a6e5a4c3508687f",
          "worktree_digest": "sha256:78b2073ac6eebe239965cdcbfde4ddd0d00606e9bc0f5a132a6e5a4c3508687f",
          "untracked_digest": "absent"
        },
        {
          "path": "src/browser/webapi/Navigator.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:f2eaf2100c744fd04e7e2d2d88c361eafd4e5b7b15b54b709bba829b8730e09b",
          "index_digest": "sha256:f2eaf2100c744fd04e7e2d2d88c361eafd4e5b7b15b54b709bba829b8730e09b",
          "worktree_digest": "sha256:f2eaf2100c744fd04e7e2d2d88c361eafd4e5b7b15b54b709bba829b8730e09b",
          "untracked_digest": "absent"
        },
        {
          "path": "src/browser/webapi/NavigatorUAData.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:b55e17b154818310fdbb1ab7bff5c1600194f03082a3d313114572ffe9e07b04",
          "index_digest": "sha256:b55e17b154818310fdbb1ab7bff5c1600194f03082a3d313114572ffe9e07b04",
          "worktree_digest": "sha256:b55e17b154818310fdbb1ab7bff5c1600194f03082a3d313114572ffe9e07b04",
          "untracked_digest": "absent"
        },
        {
          "path": "src/browser/webapi/WorkerNavigator.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:9bf11156a5c72b893db9f9d6ee7664eeb3dfcf2acf7a664cd2a064ad0ecf40a6",
          "index_digest": "sha256:9bf11156a5c72b893db9f9d6ee7664eeb3dfcf2acf7a664cd2a064ad0ecf40a6",
          "worktree_digest": "sha256:9bf11156a5c72b893db9f9d6ee7664eeb3dfcf2acf7a664cd2a064ad0ecf40a6",
          "untracked_digest": "absent"
        },
        {
          "path": "src/main.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:70f838f18b7e5e33946f4878bc7976c4f635ed4c0178e07318a4c2aed972f6e7",
          "index_digest": "sha256:70f838f18b7e5e33946f4878bc7976c4f635ed4c0178e07318a4c2aed972f6e7",
          "worktree_digest": "sha256:70f838f18b7e5e33946f4878bc7976c4f635ed4c0178e07318a4c2aed972f6e7",
          "untracked_digest": "absent"
        },
        {
          "path": "src/network/HttpClient.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:e6eb8ebc1b47c61806a1dc2c13ef5afd2992ad2218bb52aeead4f4a07d9bd6a5",
          "index_digest": "sha256:e6eb8ebc1b47c61806a1dc2c13ef5afd2992ad2218bb52aeead4f4a07d9bd6a5",
          "worktree_digest": "sha256:e6eb8ebc1b47c61806a1dc2c13ef5afd2992ad2218bb52aeead4f4a07d9bd6a5",
          "untracked_digest": "absent"
        },
        {
          "path": "src/server/Server.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:6b6936e15c71dc1d46bd714e90375e0e1b0e54b5759e40430afb86b08806f5b6",
          "index_digest": "sha256:6b6936e15c71dc1d46bd714e90375e0e1b0e54b5759e40430afb86b08806f5b6",
          "worktree_digest": "sha256:6b6936e15c71dc1d46bd714e90375e0e1b0e54b5759e40430afb86b08806f5b6",
          "untracked_digest": "absent"
        },
        {
          "path": "src/server/cdp/domains/browser.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:ce81ef36ed40420038ca0de550b163552d8603c04081a54ffe82aeca585139fe",
          "index_digest": "sha256:ce81ef36ed40420038ca0de550b163552d8603c04081a54ffe82aeca585139fe",
          "worktree_digest": "sha256:ce81ef36ed40420038ca0de550b163552d8603c04081a54ffe82aeca585139fe",
          "untracked_digest": "absent"
        },
        {
          "path": "src/server/cdp/domains/emulation.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:9cd4e1db7a5c120d43164b9b8eed1ead7b1521257a6c61593e41266a0d4824e6",
          "index_digest": "sha256:9cd4e1db7a5c120d43164b9b8eed1ead7b1521257a6c61593e41266a0d4824e6",
          "worktree_digest": "sha256:9cd4e1db7a5c120d43164b9b8eed1ead7b1521257a6c61593e41266a0d4824e6",
          "untracked_digest": "absent"
        },
        {
          "path": "src/server/http.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:f16474b21868a872bd01f16151e5978a4363be2f63035af3eaa0d8aa92c054f7",
          "index_digest": "sha256:f16474b21868a872bd01f16151e5978a4363be2f63035af3eaa0d8aa92c054f7",
          "worktree_digest": "sha256:f16474b21868a872bd01f16151e5978a4363be2f63035af3eaa0d8aa92c054f7",
          "untracked_digest": "absent"
        },
        {
          "path": "src/telemetry/lightpanda.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:4bfd1d42fe43b3e873e0ef2c5861ce05437562538c6671aee04a60c22f96f3cf",
          "index_digest": "sha256:4bfd1d42fe43b3e873e0ef2c5861ce05437562538c6671aee04a60c22f96f3cf",
          "worktree_digest": "sha256:4bfd1d42fe43b3e873e0ef2c5861ce05437562538c6671aee04a60c22f96f3cf",
          "untracked_digest": "absent"
        },
        {
          "path": "src/telemetry/telemetry.zig",
          "object_kind": {
            "head": "regular",
            "index": "regular",
            "worktree": "regular",
            "untracked": "absent"
          },
          "state": "clean",
          "rename_from": null,
          "rename_to": null,
          "head_digest": "sha256:5ed8273c9a1fd26841b4599f3a1dcecf9da31e94e2c108f38049080ad91aee72",
          "index_digest": "sha256:5ed8273c9a1fd26841b4599f3a1dcecf9da31e94e2c108f38049080ad91aee72",
          "worktree_digest": "sha256:5ed8273c9a1fd26841b4599f3a1dcecf9da31e94e2c108f38049080ad91aee72",
          "untracked_digest": "absent"
        }
      ]
    },
    "primary_symbols": [
      {
        "symbol": "HttpHeaders",
        "file": "src/Config.zig",
        "role": "UA and hints defaults"
      },
      {
        "symbol": "baselineHeaders",
        "file": "src/network/HttpClient.zig",
        "role": "network headers"
      },
      {
        "symbol": "setUserAgentOverride",
        "file": "src/server/cdp/domains/emulation.zig",
        "role": "CDP override"
      },
      {
        "symbol": "TelemetryT",
        "file": "src/telemetry/telemetry.zig",
        "role": "telemetry lifecycle"
      },
      {
        "symbol": "inform",
        "file": "src/Updater.zig",
        "role": "independent update request"
      }
    ],
    "related_symbols": [],
    "execution_path": [
      "Config -> HttpClient -> network and Navigator/Worker",
      "App -> Telemetry -> sender",
      "main version check -> Updater"
    ],
    "pdg_constraints": [],
    "architectural_patterns": [],
    "files_to_modify": [],
    "tests": [
      {
        "file": "src/server/cdp/domains/emulation.zig",
        "scenarios": [
          "valid Chrome UA accepted",
          "unsafe header rejected",
          "override and language lifecycle"
        ]
      }
    ],
    "verification_commands": [
      "make download-v8",
      "make fmt",
      "make test",
      "make build"
    ],
    "risks": [
      "Rendering engine limitations",
      "Spoofed UA and incomplete API mismatches",
      "Upstream CI secrets and scheduled side effects"
    ],
    "assumptions": [
      "Rebuild exact checkout before attributing runtime observations",
      "Confirm graph Zig and PDG coverage"
    ],
    "open_questions": [
      "Chromium identity version policy",
      "Which additional runners and release channels are needed"
    ],
    "avoid": [
      "Do not conflate parent GitNexus index with nested repository",
      "Do not falsify graphics or claim untested support",
      "Do not remove copyright or user data"
    ]
  }
}
```

## 12. 假设、待确认与暂缓

- 默认 Linux x86_64 是首个验收目标；其他平台不因修改 UA 自动视为兼容。版本策略默认参考当前可验证的项目 Chromium 版本，避免依赖不断变化的在线版本；实现前确认可维护的版本更新机制。
- 发布默认是 GitHub Actions artifact 加手动/tag GitHub Release；Docker、Homebrew、S3、WPT 专用 runner 与实时模型回归需独立资源，未准备前禁用其自动副作用并记录，而非伪造成功。
- 图谱已识别 Zig 符号，但存在调用图和流程截断，PDG 尚未得到可用边；执行前以源码和测试补齐并重新核对影响。
- 登录 profile 持久化、外层注册表接入、跨平台指纹、GPU/TLS 大规模重构均不作为本轮默认交付，除非调查显示必要且成本合理。

## 13. 完成标准

源码构建的二进制可运行；新旧测试与目标环境的 CI 通过并有真实产物；不依赖环境变量阻止上游遥测和版本检查外发；UA/Client Hints/语言/Worker 与 CLI/CDP 覆盖按对照测试一致且输入安全；已选择差异有复现、修复和负向回归；实施的高成本能力有独立开关及关闭恢复测试，暂缓项或未完成检测项在文档有原因与证据；文档、帮助和注释与最终行为一致。
