# 🔍 Day 18 - 数据库自检步骤

## 📌 项目信息

**项目 ID**: `xlhkojuliphmvmzhpgzw`
**项目 URL**: `https://xlhkojuliphmvmzhpgzw.supabase.co`
**SQL Editor**: https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/sql/new

✅ 与 iOS 配置文件 (earthlord/earthlord/Views/RootView.swift:10) 一致

---

## 🚀 执行步骤

### 步骤 1: 执行主迁移 SQL

1. 访问 SQL Editor: https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/sql/new
2. 复制文件内容: `supabase/migrations/20260119_setup_territories.sql`
3. 粘贴并点击 **Run**
4. 等待执行完成（应该看到 "Success. No rows returned"）

### 步骤 2: 运行验证脚本

1. 在 SQL Editor 中新建查询
2. 复制文件内容: `supabase/migrations/verify_setup.sql`
3. 粘贴并点击 **Run**
4. 查看验证结果

---

## ✅ 预期验证结果

你应该看到以下输出：

### 1. PostGIS 扩展
```
✅ PostGIS 扩展 | 已启用 - Version: 3.x
```

### 2. territories 表
```
✅ territories 表 | 存在
```

### 3. 字段列表（应该有 16 个字段）
```
id               | uuid          | ✓ nullable | gen_random_uuid()
user_id          | uuid          | ✗ NOT NULL |
name             | text          | ✓ nullable |   ⚠️ 必须是 nullable
path             | jsonb         | ✗ NOT NULL |
polygon          | geography     | ✓ nullable |
bbox_min_lat     | double        | ✓ nullable |
bbox_max_lat     | double        | ✓ nullable |
bbox_min_lon     | double        | ✓ nullable |
bbox_max_lon     | double        | ✓ nullable |
area             | double        | ✗ NOT NULL |
point_count      | integer       | ✓ nullable |
started_at       | timestamptz   | ✓ nullable |
completed_at     | timestamptz   | ✓ nullable |
is_active        | boolean       | ✓ nullable | true
created_at       | timestamptz   | ✓ nullable | now()
updated_at       | timestamptz   | ✓ nullable | now()
```

### 4. name 字段检查
```
⚠️ name 字段检查 | ✅ nullable (正确)
```

**如果显示 "❌ NOT NULL (错误！需要修复)"，执行步骤 3**

### 5. 地理字段检查
```
🌍 地理字段检查 | ✅ 完整 (polygon, bbox x 4)
```

### 6. RLS 检查
```
🔒 RLS 检查 | ✅ 已启用
```

### 7. RLS 策略（应该有 4 个）
```
Users can view all territories      | SELECT
Users can insert their own territories | INSERT
Users can update their own territories | UPDATE
Users can delete their own territories | DELETE
```

### 8. 索引（应该有 5 个）
```
territories_pkey                    | PRIMARY KEY (id)
idx_territories_user_id             | ON user_id
idx_territories_is_active           | ON is_active
idx_territories_created_at          | ON created_at DESC
idx_territories_polygon             | GIST ON polygon
```

### 9. 触发器
```
update_territories_updated_at | UPDATE | BEFORE
```

---

## 🔧 步骤 3: 修复问题（如果需要）

### 如果 name 字段是 NOT NULL

1. 在 SQL Editor 中执行:
   ```sql
   ALTER TABLE public.territories ALTER COLUMN name DROP NOT NULL;
   ```
2. 或者执行文件: `supabase/migrations/fix_name_nullable.sql`
3. 再次运行验证脚本确认修复

### 如果缺少字段

重新执行主迁移 SQL (步骤 1)

### 如果 RLS 未启用

```sql
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;
```

---

## 🎉 成功标准

所有检查项都显示 ✅：

- [x] 📌 项目：xlhkojuliphmvmzhpgzw (与 iOS 配置一致)
- [x] ✅ PostGIS：已启用
- [x] ✅ territories 表：存在，16 个字段
- [x] ✅ name 字段：nullable ✓
- [x] ✅ 地理字段：polygon + bbox 完整
- [x] ✅ RLS：已启用
- [x] ✅ RLS 策略：4 个策略完整
- [x] ✅ 索引：5 个索引
- [x] ✅ 触发器：updated_at 自动更新

**当所有项都 ✅ 时，就可以继续 Day 18-模型了！**

---

## 📞 如果遇到问题

1. 确保你有项目的 Owner 或 Admin 权限
2. 检查 Supabase Dashboard 中的错误信息
3. 尝试先删除现有表再重新创建：
   ```sql
   DROP TABLE IF EXISTS public.territories CASCADE;
   ```
   然后重新执行主迁移 SQL

## 📝 快速验证命令

如果只想快速检查关键项，执行这个简化版：

```sql
-- 快速检查
SELECT
    (SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname='postgis')) as postgis_enabled,
    (SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='territories')) as table_exists,
    (SELECT is_nullable FROM information_schema.columns WHERE table_name='territories' AND column_name='name') as name_nullable,
    (SELECT relrowsecurity FROM pg_class WHERE relname='territories') as rls_enabled,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name='territories') as column_count,
    (SELECT COUNT(*) FROM pg_policy WHERE polrelid='public.territories'::regclass) as policy_count;
```

预期结果：
```
postgis_enabled | table_exists | name_nullable | rls_enabled | column_count | policy_count
true            | true         | YES           | true        | 16           | 4
```
