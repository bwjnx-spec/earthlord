# 📦 Day 18 - territories 表设置完成

## 🎯 当前状态

已准备好所有数据库迁移文件，等待在 Supabase Dashboard 中执行。

## 📁 已创建的文件

| 文件 | 说明 |
|------|------|
| `migrations/20260119_setup_territories.sql` | ⭐ 主迁移 SQL（启用 PostGIS + 创建表 + RLS） |
| `migrations/verify_setup.sql` | 🔍 验证脚本（检查所有设置） |
| `migrations/fix_name_nullable.sql` | 🔧 修复脚本（如果 name 不是 nullable） |
| `MIGRATION_GUIDE.md` | 📖 详细迁移指南 |
| `VERIFICATION_STEPS.md` | ✅ 验证步骤说明 |
| `run-migration.sh` | 🚀 自动执行脚本（需要 Supabase CLI） |

---

## 🚀 执行流程（3 步）

### 第 1 步：执行迁移 ⭐

访问 SQL Editor：
```
https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/sql/new
```

复制并执行文件：`migrations/20260119_setup_territories.sql`

预期结果：`Success. No rows returned`

---

### 第 2 步：运行验证 🔍

在 SQL Editor 中新建查询，执行：`migrations/verify_setup.sql`

或者执行这个快速检查：

```sql
SELECT
    (SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname='postgis')) as postgis_enabled,
    (SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='territories')) as table_exists,
    (SELECT is_nullable FROM information_schema.columns WHERE table_name='territories' AND column_name='name') as name_nullable,
    (SELECT relrowsecurity FROM pg_class WHERE relname='territories') as rls_enabled,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='territories') as column_count,
    (SELECT COUNT(*) FROM pg_policy WHERE polrelid='public.territories'::regclass) as policy_count;
```

**预期结果：**
```
postgis_enabled | table_exists | name_nullable | rls_enabled | column_count | policy_count
true            | true         | YES           | true        | 16           | 4
```

---

### 第 3 步：修复问题（如果需要） 🔧

**如果 name_nullable 显示 NO：**
```sql
ALTER TABLE public.territories ALTER COLUMN name DROP NOT NULL;
```

然后重新运行验证。

---

## ✅ 验证清单

执行完成后，应该满足：

- [x] 📌 项目 ID：xlhkojuliphmvmzhpgzw（与 iOS 配置一致）
- [x] ✅ PostGIS：已启用
- [x] ✅ territories 表：16 个字段完整
- [x] ⚠️ **name 字段：nullable** （最重要！）
- [x] ✅ 地理字段：polygon + bbox_min/max_lat/lon
- [x] ✅ RLS：已启用
- [x] ✅ RLS 策略：4 个（SELECT, INSERT, UPDATE, DELETE）
- [x] ✅ 索引：5 个（user_id, is_active, created_at, polygon, pk）
- [x] ✅ 触发器：updated_at 自动更新

---

## 📋 territories 表字段说明

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | uuid | PK | 主键 |
| user_id | uuid | NOT NULL, FK | 用户 ID |
| **name** | **text** | **nullable** ⚠️ | **领地名称（必须可空！）** |
| path | jsonb | NOT NULL | 路径点数组 |
| polygon | geography | nullable | 多边形 |
| bbox_min_lat | double | nullable | 边界框 |
| bbox_max_lat | double | nullable | 边界框 |
| bbox_min_lon | double | nullable | 边界框 |
| bbox_max_lon | double | nullable | 边界框 |
| area | double | NOT NULL | 面积（平方米） |
| point_count | integer | nullable | 点数 |
| started_at | timestamptz | nullable | 开始时间 |
| completed_at | timestamptz | nullable | 完成时间 |
| is_active | boolean | nullable | 是否活跃（默认 true） |
| created_at | timestamptz | nullable | 创建时间（自动） |
| updated_at | timestamptz | nullable | 更新时间（自动） |

---

## ⚠️ 重要提醒

**name 字段必须是 nullable！**

如果 name 是 NOT NULL，上传领地时会报错：
```
null value in column "name" violates not-null constraint
```

因为 iOS 应用在上传时不会立即提供 name（用户稍后命名）。

---

## 🎉 完成后

当所有验证项都是 ✅ 时，就可以继续 **Day 18-模型** 了！

iOS 应用将能够：
- ✓ 上传圈地路径和多边形
- ✓ 计算面积和边界框
- ✓ 查看所有用户的领地
- ✓ 管理自己的领地

---

## 📞 需要帮助？

查看详细文档：
- `MIGRATION_GUIDE.md` - 迁移指南
- `VERIFICATION_STEPS.md` - 验证步骤

或访问 Supabase Dashboard：
https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw
