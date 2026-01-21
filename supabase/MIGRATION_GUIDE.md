# territories 表迁移指南

## 方法一：通过 Supabase Dashboard（推荐）

1. 访问 Supabase SQL Editor:
   ```
   https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/sql/new
   ```

2. 复制并执行文件内容：
   - 打开文件: `supabase/migrations/20260119_setup_territories.sql`
   - 复制全部内容
   - 粘贴到 SQL Editor
   - 点击 "Run" 按钮执行

## 方法二：安装 Supabase CLI 后执行

```bash
# 1. 安装 Supabase CLI
brew install supabase/tap/supabase

# 2. 登录
supabase login

# 3. 执行迁移脚本
cd supabase
./run-migration.sh
```

## 迁移内容

这个迁移文件会：

✓ **启用 PostGIS 扩展** - 用于地理数据处理
✓ **创建 territories 表** - 包含以下字段：
  - `id` (uuid, 主键)
  - `user_id` (uuid, 外键关联 auth.users)
  - `name` (text, nullable) ⚠️ 重要：必须是 nullable！
  - `path` (jsonb, 存储路径点)
  - `polygon` (geography, 多边形)
  - `bbox_min_lat`, `bbox_max_lat`, `bbox_min_lon`, `bbox_max_lon` (边界框)
  - `area` (double, 面积)
  - `point_count` (integer, 点数)
  - `started_at`, `completed_at` (时间戳)
  - `is_active` (boolean, 默认 true)
  - `created_at`, `updated_at` (自动时间戳)

✓ **配置 RLS 策略**：
  - 所有人可查看领地
  - 用户只能创建/修改/删除自己的领地

✓ **创建索引**：
  - user_id, is_active, created_at, polygon (GIST 索引)

✓ **创建触发器**：
  - 自动更新 updated_at 字段

## 验证迁移成功

执行完成后，在 SQL Editor 中运行：

```sql
-- 查看表结构
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'territories'
ORDER BY ordinal_position;

-- 查看 RLS 策略
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'territories';

-- 验证 PostGIS 扩展
SELECT PostGIS_Version();
```

## 重要提示

⚠️ **name 字段必须是 nullable！**
- 如果 name 字段是 NOT NULL，上传领地时会报错
- 错误信息：`null value in column "name" violates not-null constraint`

## 下一步

迁移成功后，就可以在 iOS 应用中上传领地数据了！
