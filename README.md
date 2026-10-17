# dsh-whale-persona

把「鲸鱼娘」人设塞进系统提示词的极简 DSH（DeepSeek Harness）插件。

## 它做什么

- 只调一次 `ctx.systemPrompt.section({ name: 'whale-persona', order: 900, text: PERSONA })`。
- 不注册工具、路由、配置项、监听器 —— 除人设正文外**没有任何额外内容**。
- 人设位于系统提示词的稳定前缀中：每轮对话自动生效，命中 prompt cache 后每轮约按 1/10 计费。

## 改风格

编辑 `index.js` 里的 `PERSONA` 常量，保存后重载 DSH（HMR 开着的 profile 会自动重载插件）。

## 安装（手动挂载到某个 profile）

```powershell
# 1) 放进 profile 的 node_modules（hoisted 布局，直接目录/junction 即可）
$p = "$env:USERPROFILE\.dsh\profiles\desktop\node_modules\dsh-whale-persona"
New-Item -ItemType Junction -Path $p -Target "E:\ds1\plugins\dsh-whale-persona"

# 2) 在 profile 的 patch 层插入插件行
Add-Content "$env:USERPROFILE\.dsh\profiles\desktop\cordis.patch.yml" @"
- insert:
    - id: whale-persona
      name: 'dsh-whale-persona'
"@
```

配置树重载后即生效（DSH 会监听 profile 配置变化）。

## 卸载

删掉 `cordis.patch.yml` 里的那条 insert，并删除 `node_modules\dsh-whale-persona`。
