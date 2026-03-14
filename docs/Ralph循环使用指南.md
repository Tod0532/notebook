# Ralph Wiggum 循环使用指南

> 持续迭代的 AI 开发方法 - 用同样的提示词反复优化，直到任务完成

---

## 📖 什么是 Ralph Wiggum 技巧？

Ralph Wiggum 技巧是一种**迭代式AI开发方法论**，核心思想是：

1. **用同一个提示词**反复喂给 Claude
2. Claude 每次都能看到上一次修改的文件
3. 通过**自引用**（Self-Reference）持续改进
4. 直到达到预设的完成条件

### 核心循环

```bash
while :; do
  cat PROMPT.md | claude-code --continue
done
```

---

## 🚀 基本用法

### 启动循环

```bash
/ralph-loop "任务描述" [选项]
```

### 可用选项

| 选项 | 说明 | 示例 |
|------|------|------|
| `--max-iterations <n>` | 最大迭代次数 | `--max-iterations 10` |
| `--completion-promise <文本>` | 完成信号标签 | `--completion-promise "完成"` |

---

## 💡 使用示例

### 示例 1: APK 大小优化

```bash
/ralph-loop "优化慧记APK大小：1.启用split-per-abi构建 2.压缩图片为WebP 3.移除未使用依赖。完成后输出<promise>APK优化完成</promise>" --completion-promise "APK优化完成" --max-iterations 5
```

**工作流程**：
1. 尝试优化配置
2. 构建 APK
3. 检查大小
4. 如果不够小，继续优化
5. 达到目标或达到最大次数后停止

### 示例 2: 完成 TODO 项

```bash
/ralph-loop "完成慧记项目中所有高优先级TODO项：1.实现屏幕常亮 2.积分检查 3.小组件数据源。完成后输出<promise>全部完成</promise>" --max-iterations 8
```

### 示例 3: 代码重构

```bash
/ralph-loop "重构笔记模块，使用Repository模式分离数据层和UI层。完成后输出<promise>重构完成</promise>" --max-iterations 10
```

---

## 🎯 完成信号（Promise）

Ralph 循环需要知道何时停止。有两种方式：

### 方式 1: 完成 Promise 标签

在提示词中指定完成标签，Claude 输出该标签时循环停止：

```html
<promise>任务完成</promise>
```

### 方式 2: 最大迭代次数

设置 `--max-iterations`，达到次数后自动停止。

**推荐**：同时使用两种方式作为保险。

---

## 🛑 停止循环

```bash
/cancel-ralph
```

---

## ✅ 适用场景

| 场景 | 是否适用 | 原因 |
|------|----------|------|
| 性能优化 | ✅ | 可以反复测试和调整 |
| 代码重构 | ✅ | 有明确目标，可以逐步改进 |
| Bug 修复 | ✅ | 可以尝试多种方案 |
| 完成TODO | ✅ | 有明确的任务清单 |
| UI设计 | ❌ | 需要人工审美判断 |
| 需求分析 | ❌ | 需要与用户讨论 |
| 一次性操作 | ❌ | 无需迭代 |

---

## 📋 慧记项目推荐任务

### 高优先级

```bash
# APK 大小优化
/ralph-loop "优化APK大小从74MB降到40MB以下：1.启用shrink 2.split-per-abi构建 3.图片转WebP。完成后输出<promise>APK优化完成</promise>" --max-iterations 5

# 完成 TODO 项
/ralph-loop "完成所有TODO：gps_tracking_page.dart屏幕常亮、gacha_service积分检查、widget_helper数据源。完成后输出<promise>TODO完成</promise>" --max-iterations 8

# 错误处理增强
/ralph-loop "统一错误处理：替换所有裸catch为具体异常类型，添加详细日志。完成后输出<promise>错误处理完成</promise>" --max-iterations 6
```

### 中优先级

```bash
# Riverpod v3 升级
/ralph-loop "升级Riverpod到v3.1.0，修复所有破坏性变更。完成后输出<promise>升级完成</promise>" --max-iterations 10

# 搜索体验优化
/ralph-loop "优化笔记搜索：添加搜索历史、结果高亮、空状态。完成后输出<promise>搜索优化完成</promise>" --max-iterations 5
```

---

## 🔍 工作原理

### 自引用机制

Ralph 循环不是 "Claude 自己跟自己对话"，而是：

1. **相同的提示词**每次都一样
2. **文件内容改变** - Claude 的修改被保存
3. **Git 历史** - Claude 可以看到之前的尝试
4. **持续改进** - 每次迭代都在前一次基础上优化

```
迭代1: 尝试方案A → 失败
迭代2: 看到方案A失败 → 尝试方案B → 失败
迭代3: 看到方案A、B都失败 → 尝试方案C → 成功！
```

---

## ⚠️ 注意事项

1. **明确任务目标** - 描述越清晰，效果越好
2. **设置完成条件** - 否则可能无限循环
3. **设置最大次数** - 防止陷入死循环
4. **检查中间结果** - 定期查看进度
5. **准备取消命令** - 随时可以 `/cancel-ralph`

---

## 📚 参考资源

- **原始技术**: https://ghuntley.com/ralph/
- **Ralph Orchestrator**: https://github.com/mikeyobrien/ralph-orchestrator

---

*文档创建时间：2026-02-08*
