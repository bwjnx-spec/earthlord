#!/bin/bash

echo "🚀 开始部署 delete-account 边缘函数..."

# 1. 登录 Supabase (如果未登录)
echo "步骤 1: 检查 Supabase CLI 登录状态..."
supabase login

# 2. 链接到项目
echo "步骤 2: 链接到 Supabase 项目..."
supabase link --project-ref xlhkojuliphmvmzhpgzw

# 3. 部署函数
echo "步骤 3: 部署 delete-account 函数..."
supabase functions deploy delete-account --no-verify-jwt

echo "✅ 部署完成!"
echo ""
echo "📝 后续步骤:"
echo "1. 在 Supabase Dashboard 中设置环境变量"
echo "2. 测试边缘函数"
