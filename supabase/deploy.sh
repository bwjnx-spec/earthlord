#!/bin/bash
# Supabase 边缘函数部署脚本

echo "🚀 开始部署 Supabase 边缘函数..."

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

# 部署 delete-account 函数
echo "📤 部署 delete-account 函数..."
supabase functions deploy delete-account --no-verify-jwt

if [ $? -eq 0 ]; then
    echo "✅ delete-account 函数部署成功！"
    echo ""
    echo "📋 函数信息:"
    echo "   名称: delete-account"
    echo "   URL: https://xlhkojuliphmvmzhpgzw.supabase.co/functions/v1/delete-account"
    echo ""
    echo "🔧 下一步:"
    echo "   1. 在 Supabase Dashboard 中配置环境变量"
    echo "   2. 测试函数是否正常工作"
else
    echo "❌ 部署失败，请检查错误信息"
    exit 1
fi
