-- ============================================
-- 修复 name 字段：确保是 nullable
-- ============================================
-- 如果验证脚本显示 name 字段是 NOT NULL，执行此脚本修复

ALTER TABLE public.territories
ALTER COLUMN name DROP NOT NULL;

-- 验证修复结果
SELECT
    '✅ name 字段已修复' as result,
    column_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'territories'
    AND column_name = 'name';
