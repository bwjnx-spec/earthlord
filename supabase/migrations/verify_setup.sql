-- ============================================
-- Day 18: 数据库设置验证脚本
-- ============================================
-- 在 Supabase SQL Editor 中执行此脚本来验证设置

-- 1. 检查 PostGIS 扩展
SELECT
    '✅ PostGIS 扩展' as check_item,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = 'postgis'
        ) THEN '已启用 - Version: ' || PostGIS_Version()
        ELSE '❌ 未启用'
    END as status;

-- 2. 检查 territories 表是否存在
SELECT
    '✅ territories 表' as check_item,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'territories'
        ) THEN '存在'
        ELSE '❌ 不存在'
    END as status;

-- 3. 检查 territories 表的所有字段
SELECT
    '📋 字段列表' as section,
    column_name,
    data_type,
    CASE WHEN is_nullable = 'YES' THEN '✓ nullable' ELSE '✗ NOT NULL' END as nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'territories'
ORDER BY ordinal_position;

-- 4. ⚠️ 重点检查：name 字段是否 nullable
SELECT
    '⚠️ name 字段检查' as check_item,
    CASE
        WHEN is_nullable = 'YES' THEN '✅ nullable (正确)'
        ELSE '❌ NOT NULL (错误！需要修复)'
    END as status
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'territories'
    AND column_name = 'name';

-- 5. 检查必需的地理字段
SELECT
    '🌍 地理字段检查' as check_item,
    string_agg(column_name, ', ') as existing_columns,
    CASE
        WHEN COUNT(*) >= 5 THEN '✅ 完整 (polygon, bbox x 4)'
        ELSE '❌ 不完整'
    END as status
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'territories'
    AND column_name IN ('polygon', 'bbox_min_lat', 'bbox_max_lat', 'bbox_min_lon', 'bbox_max_lon');

-- 6. 检查其他重要字段
SELECT
    '📊 其他字段检查' as check_item,
    string_agg(column_name, ', ') as existing_columns,
    CASE
        WHEN COUNT(*) >= 3 THEN '✅ 完整 (point_count, is_active, area)'
        ELSE '❌ 不完整'
    END as status
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'territories'
    AND column_name IN ('point_count', 'is_active', 'area', 'started_at', 'completed_at');

-- 7. 检查 RLS 是否启用
SELECT
    '🔒 RLS 检查' as check_item,
    CASE
        WHEN relrowsecurity THEN '✅ 已启用'
        ELSE '❌ 未启用'
    END as status
FROM pg_class
WHERE relname = 'territories' AND relnamespace = 'public'::regnamespace;

-- 8. 检查 RLS 策略
SELECT
    '🔐 RLS 策略' as section,
    policyname as policy_name,
    cmd as command,
    CASE
        WHEN qual IS NOT NULL THEN 'USING: ' || pg_get_expr(qual, polrelid)
        ELSE 'No USING clause'
    END as using_clause
FROM pg_policy
WHERE polrelid = 'public.territories'::regclass
ORDER BY policyname;

-- 9. 检查索引
SELECT
    '📑 索引检查' as section,
    indexname as index_name,
    indexdef as definition
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'territories'
ORDER BY indexname;

-- 10. 检查触发器
SELECT
    '⚡ 触发器检查' as section,
    trigger_name,
    event_manipulation as event,
    action_timing as timing
FROM information_schema.triggers
WHERE event_object_table = 'territories'
ORDER BY trigger_name;

-- 最终汇总
SELECT
    '🎉 设置汇总' as summary,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'territories') as total_columns,
    (SELECT COUNT(*) FROM pg_policy WHERE polrelid = 'public.territories'::regclass) as total_policies,
    (SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'territories') as total_indexes;
