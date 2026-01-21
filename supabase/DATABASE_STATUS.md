# 🔍 Day 18 - 数据库状态检查

## ⚠️ 当前状态

**无法使用 MCP 工具自动检查**
- 系统中未安装 Supabase MCP Server
- 需要手动在 Supabase Dashboard 中执行验证

---

## 📌 项目信息

```
项目 ID: xlhkojuliphmvmzhpgzw
项目 URL: https://xlhkojuliphmvmzhpgzw.supabase.co
配置位置: earthlord/earthlord/Views/RootView.swift:10
```

✅ **项目 ID 与 iOS 配置一致**

---

## 🚀 需要你手动执行的步骤

### 1️⃣ 执行迁移 SQL

访问：https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/sql/new

复制并执行：
```bash
supabase/migrations/20260119_setup_territories.sql
```

### 2️⃣ 运行验证

执行快速验证查询：

```sql
-- 快速验证所有关键项
SELECT
    '📌 项目' as item,
    current_database() as value,
    '✅' as status
UNION ALL
SELECT
    '✅ PostGIS',
    CASE WHEN EXISTS(SELECT 1 FROM pg_extension WHERE extname='postgis')
        THEN PostGIS_Version() ELSE '❌ 未启用' END,
    CASE WHEN EXISTS(SELECT 1 FROM pg_extension WHERE extname='postgis')
        THEN '✅' ELSE '❌' END
UNION ALL
SELECT
    '✅ territories 表',
    CASE WHEN EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='territories')
        THEN (SELECT COUNT(*)::text || ' 个字段' FROM information_schema.columns WHERE table_name='territories')
        ELSE '❌ 不存在' END,
    CASE WHEN EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='territories')
        THEN '✅' ELSE '❌' END
UNION ALL
SELECT
    '⚠️ name 字段',
    CASE WHEN EXISTS(
        SELECT 1 FROM information_schema.columns
        WHERE table_name='territories' AND column_name='name' AND is_nullable='YES'
    ) THEN 'nullable ✓' ELSE '❌ NOT NULL (需要修复)' END,
    CASE WHEN EXISTS(
        SELECT 1 FROM information_schema.columns
        WHERE table_name='territories' AND column_name='name' AND is_nullable='YES'
    ) THEN '✅' ELSE '❌' END
UNION ALL
SELECT
    '✅ RLS',
    CASE WHEN EXISTS(
        SELECT 1 FROM pg_class WHERE relname='territories' AND relrowsecurity=true
    ) THEN '已启用' ELSE '❌ 未启用' END,
    CASE WHEN EXISTS(
        SELECT 1 FROM pg_class WHERE relname='territories' AND relrowsecurity=true
    ) THEN '✅' ELSE '❌' END
UNION ALL
SELECT
    '✅ RLS 策略',
    (SELECT COUNT(*)::text || ' 个策略' FROM pg_policy WHERE polrelid='public.territories'::regclass),
    CASE WHEN (SELECT COUNT(*) FROM pg_policy WHERE polrelid='public.territories'::regclass) >= 4
        THEN '✅' ELSE '❌' END;
```

### 3️⃣ 查看结果

预期输出：

```
📌 项目           | xlhkojuliphmvmzhpgzw      | ✅
✅ PostGIS        | 3.x.x                     | ✅
✅ territories 表 | 16 个字段                  | ✅
⚠️ name 字段      | nullable ✓                | ✅
✅ RLS            | 已启用                     | ✅
✅ RLS 策略       | 4 个策略                   | ✅
```

---

## 🔧 如果发现问题

### 如果 name 字段不是 nullable

执行修复：
```sql
ALTER TABLE public.territories ALTER COLUMN name DROP NOT NULL;
```

### 如果字段不完整

重新执行主迁移 SQL。

### 如果 RLS 未启用

```sql
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;
```

---

## 🎉 完成标准

**当所有项都显示 ✅ 时：**

```
📌 项目：xlhkojuliphmvmzhpgzw (project_id)
✅ PostGIS：已启用
✅ territories 字段：完整 (16 个)
✅ name 字段：nullable ✓
✅ RLS：已启用
✅ RLS 策略：4 个完整

🎉 可以继续 Day 18-模型！
```

---

## 📝 验证完成后

请在这里记录结果，然后就可以继续下一步了：

- [ ] 已执行迁移 SQL
- [ ] 已运行验证查询
- [ ] 所有检查项都是 ✅
- [ ] name 字段确认是 nullable
- [ ] 准备好继续 Day 18-模型

---

## 🛠️ 安装 Supabase MCP（可选，供未来使用）

如果想要自动化检查，可以安装 Supabase MCP Server：

1. 安装 Supabase CLI：
   ```bash
   brew install supabase/tap/supabase
   ```

2. 配置 MCP Server（参考 Supabase MCP 文档）

这样下次就可以用 MCP 工具直接查询数据库了。
