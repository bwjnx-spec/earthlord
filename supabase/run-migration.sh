#!/bin/bash
# 执行数据库迁移脚本

echo "🗄️  开始执行数据库迁移..."

# 检查是否安装了 Supabase CLI
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI 未安装"
    echo "请运行: brew install supabase/tap/supabase"
    exit 1
fi

echo "✅ Supabase CLI 已安装"

# 检查是否已登录
echo "📝 检查登录状态..."
if ! supabase projects list &> /dev/null; then
    echo "⚠️  未登录到 Supabase"
    echo "正在启动登录流程..."
    supabase login
fi

echo "✅ 已登录到 Supabase"

# 关联项目
echo "🔗 关联项目 xlhkojuliphmvmzhpgzw..."
supabase link --project-ref xlhkojuliphmvmzhpgzw

# 执行 SQL 迁移文件
echo "📤 执行 SQL 迁移..."
supabase db push

if [ $? -eq 0 ]; then
    echo "✅ 数据库迁移成功！"
    echo ""
    echo "📋 执行的操作:"
    echo "   ✓ 启用 PostGIS 扩展"
    echo "   ✓ 创建/更新 territories 表"
    echo "   ✓ 配置 RLS 策略"
    echo "   ✓ 创建索引和触发器"
    echo ""
    echo "🎉 territories 表已设置完成！"
else
    echo "❌ 迁移失败"
    echo ""
    echo "📝 手动执行方法："
    echo "   1. 访问 https://supabase.com/dashboard/project/xlhkojuliphmvmzhpgzw/editor"
    echo "   2. 在 SQL Editor 中执行文件: supabase/migrations/20260119_setup_territories.sql"
    exit 1
fi
