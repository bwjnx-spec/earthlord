#!/bin/bash

# Supabase 连接检测脚本
# 使用方法: bash check_supabase.sh

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║        Supabase 连接状态检测工具                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Supabase URL
SUPABASE_URL="https://xlhkojuliphmvmzhpgzw.supabase.co"

echo "测试目标: $SUPABASE_URL"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 测试 1: DNS 解析
echo "📡 [1/4] 测试 DNS 解析..."
if host xlhkojuliphmvmzhpgzw.supabase.co > /dev/null 2>&1; then
    echo -e "${GREEN}✅ DNS 解析成功${NC}"
    DNS_OK=true
else
    echo -e "${RED}❌ DNS 解析失败${NC}"
    echo "   可能原因：网络连接问题或 DNS 服务器故障"
    DNS_OK=false
fi
echo ""

# 测试 2: ICMP Ping (可能被防火墙阻止)
echo "🏓 [2/4] 测试网络连通性..."
if ping -c 1 -W 3 xlhkojuliphmvmzhpgzw.supabase.co > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 网络可达${NC}"
    PING_OK=true
else
    echo -e "${YELLOW}⚠️  Ping 超时（某些服务器禁用 ICMP，这可能是正常的）${NC}"
    PING_OK=false
fi
echo ""

# 测试 3: HTTPS 连接
echo "🔒 [3/4] 测试 HTTPS/TLS 连接..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$SUPABASE_URL" 2>&1)
CURL_EXIT=$?

if [ $CURL_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ HTTPS 连接成功${NC}"
    echo "   HTTP 状态码: $HTTP_CODE"

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
        echo -e "${GREEN}   ✅ Supabase 服务器正常响应${NC}"
        HTTPS_OK=true
    else
        echo -e "${YELLOW}   ⚠️  收到非预期状态码: $HTTP_CODE${NC}"
        HTTPS_OK=false
    fi
else
    echo -e "${RED}❌ HTTPS 连接失败 (curl 退出码: $CURL_EXIT)${NC}"

    # 详细错误分析
    if [ $CURL_EXIT -eq 6 ]; then
        echo "   错误原因：无法解析主机名"
    elif [ $CURL_EXIT -eq 7 ]; then
        echo "   错误原因：无法连接到服务器"
    elif [ $CURL_EXIT -eq 28 ]; then
        echo "   错误原因：连接超时"
    elif [ $CURL_EXIT -eq 35 ]; then
        echo "   错误原因：SSL/TLS 握手失败"
        echo -e "${RED}   🚨 这很可能意味着 Supabase 项目已暂停或删除！${NC}"
    elif [ $CURL_EXIT -eq 51 ]; then
        echo "   错误原因：SSL 证书验证失败"
    elif [ $CURL_EXIT -eq 60 ]; then
        echo "   错误原因：SSL 证书问题"
    else
        echo "   未知错误"
    fi

    HTTPS_OK=false
fi
echo ""

# 测试 4: 详细的 SSL/TLS 信息
echo "🔐 [4/4] 获取 SSL/TLS 详细信息..."
if command -v openssl > /dev/null 2>&1; then
    SSL_INFO=$(echo | openssl s_client -connect xlhkojuliphmvmzhpgzw.supabase.co:443 -servername xlhkojuliphmvmzhpgzw.supabase.co 2>&1)

    if echo "$SSL_INFO" | grep -q "Verify return code: 0"; then
        echo -e "${GREEN}✅ SSL 证书有效${NC}"

        # 提取证书信息
        if echo "$SSL_INFO" | grep -q "subject="; then
            CERT_SUBJECT=$(echo "$SSL_INFO" | grep "subject=" | head -1)
            echo "   证书: ${CERT_SUBJECT#*=}"
        fi

        SSL_OK=true
    else
        if echo "$SSL_INFO" | grep -q "Connection refused\|connect: Connection refused"; then
            echo -e "${RED}❌ 连接被拒绝${NC}"
            echo -e "${RED}   🚨 Supabase 项目可能已暂停或删除${NC}"
        elif echo "$SSL_INFO" | grep -q "timeout\|timed out"; then
            echo -e "${RED}❌ 连接超时${NC}"
        else
            echo -e "${YELLOW}⚠️  SSL 连接异常${NC}"
        fi
        SSL_OK=false
    fi
else
    echo -e "${YELLOW}⚠️  未安装 openssl，跳过此测试${NC}"
    SSL_OK=true
fi
echo ""

# 汇总结果
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 检测结果汇总:"
echo ""

if [ "$DNS_OK" = true ] && [ "$HTTPS_OK" = true ]; then
    echo -e "${GREEN}✅ 所有测试通过！Supabase 连接正常${NC}"
    echo ""
    echo "📱 iOS App 应该可以正常工作"
    echo "   如果 App 仍然报错，请检查："
    echo "   1. Info.plist 是否正确配置"
    echo "   2. 是否已添加到 Xcode 项目"
    echo "   3. 是否清理并重新构建"
    EXIT_CODE=0
else
    echo -e "${RED}❌ 检测到问题！${NC}"
    echo ""
    echo "🔍 问题诊断:"

    if [ "$DNS_OK" = false ]; then
        echo "   • DNS 解析失败"
        echo "     → 检查网络连接"
        echo "     → 尝试切换 DNS (8.8.8.8)"
    fi

    if [ "$HTTPS_OK" = false ]; then
        echo "   • HTTPS 连接失败"
        echo -e "${RED}     → 很可能是 Supabase 项目已暂停${NC}"
        echo ""
        echo "💡 解决方案:"
        echo "   1. 登录 Supabase Dashboard"
        echo "      https://supabase.com/dashboard"
        echo "   2. 找到项目: xlhkojuliphmvmzhpgzw"
        echo "   3. 如果显示「Paused」，点击 Resume"
        echo "   4. 等待 1-2 分钟后重新测试"
        echo ""
        echo "   如果项目已删除，需要创建新项目"
        echo "   查看：操作步骤_请按顺序执行.md"
    fi

    EXIT_CODE=1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 详细帮助文档:"
echo "   - 快速参考: 快速参考卡.txt"
echo "   - 详细步骤: 操作步骤_请按顺序执行.md"
echo "   - 完整方案: README_TLS_ERROR_SOLUTION.md"
echo ""

exit $EXIT_CODE
