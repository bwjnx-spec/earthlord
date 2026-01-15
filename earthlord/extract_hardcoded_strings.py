#!/usr/bin/env python3
"""
提取代码中硬编码的中文字符串
"""

import re
import json
from pathlib import Path
from collections import OrderedDict

# 项目根目录
PROJECT_ROOT = Path(__file__).parent

def extract_chinese_strings():
    """从Swift代码中提取硬编码的中文字符串"""
    chinese_strings = set()

    # 搜索模式
    patterns = [
        r'Text\("([^"]*[\u4e00-\u9fff][^"]*)"\)',  # Text("中文")
        r'placeholder:\s*"([^"]*[\u4e00-\u9fff][^"]*)"',  # placeholder: "中文"
        r'title:\s*"([^"]*[\u4e00-\u9fff][^"]*)"',  # title: "中文"
        r'subtitle:\s*"([^"]*[\u4e00-\u9fff][^"]*)"',  # subtitle: "中文"
    ]

    # 搜索所有Swift文件
    swift_files = list((PROJECT_ROOT / "earthlord").rglob("*.swift"))

    for swift_file in swift_files:
        # 跳过测试文件和注释文件
        if 'Test' in swift_file.name or 'Preview' in swift_file.name:
            continue

        try:
            content = swift_file.read_text(encoding='utf-8')

            for pattern in patterns:
                matches = re.findall(pattern, content)
                for match in matches:
                    # 清理字符串，移除插值
                    if '\\(' not in match:  # 跳过包含字符串插值的
                        chinese_strings.add(match)

        except Exception as e:
            print(f"Error reading {swift_file}: {e}")

    return sorted(chinese_strings)

def create_translations(chinese_strings):
    """为中文字符串创建英文翻译"""
    translations = OrderedDict()

    # 预定义的翻译映射
    translation_map = {
        "地球新主": "Earth Lord",
        "登录": "Sign In",
        "注册": "Sign Up",
        "邮箱": "Email",
        "密码": "Password",
        "忘记密码？": "Forgot Password?",
        "或": "Or",
        "输入邮箱获取验证码": "Enter your email to receive verification code",
        "6位验证码": "6-digit code",
        "验证码已发送到 ": "Verification code has been sent to ",
        "没收到验证码？": "Didn't receive the code?",
        "秒后重发": " seconds to resend",
        "重新发送": "Resend",
        "设置登录密码": "Set Login Password",
        "密码（至少6位）": "Password (at least 6 characters)",
        "确认密码": "Confirm Password",
        "密码至少需要6位": "Password must be at least 6 characters",
        "两次密码不一致": "Passwords do not match",
        "输入注册邮箱获取验证码": "Enter your email to receive verification code",
        "设置新密码": "Set New Password",
        "新密码（至少6位）": "New password (at least 6 characters)",
        "确认新密码": "Confirm New Password",
        "或者使用以下方式登录": "Or sign in with",
        "使用 Apple 登录": "Sign in with Apple",
        "使用 Google 登录": "Sign in with Google",
        "地图": "Map",
        "探索和圈占领地": "Explore and claim territory",
        "领地": "Territory",
        "管理你的领地": "Manage your territory",
        "网络诊断工具": "Network Diagnostics",
        "测试 Supabase 连接和诊断问题": "Test Supabase connection and diagnose issues",
        "Supabase 连接测试": "Supabase Connection Test",
        "测试数据库连接状态": "Test database connection status",
        "开发工具": "Dev Tools",
        "测试 Supabase 服务器连接": "Test Supabase server connection",
        "测试目标": "Test Target",
        "测试结果": "Test Results",
        "可能的问题": "Possible Issues",
        "💡 提示：查看 SUPABASE_CONNECTION_ISSUE.md 获取详细解决方案": "💡 Tip: Check SUPABASE_CONNECTION_ISSUE.md for detailed solutions",
    }

    for s in chinese_strings:
        # 尝试从映射中获取翻译
        if s in translation_map:
            translations[s] = translation_map[s]
        else:
            # 如果没有预定义翻译，使用原文（需要手动翻译）
            translations[s] = f"[TO TRANSLATE] {s}"

    return translations

def main():
    print("🔍 提取硬编码的中文字符串...\n")

    # 提取字符串
    chinese_strings = extract_chinese_strings()

    print(f"找到 {len(chinese_strings)} 个硬编码的中文字符串:\n")
    for s in chinese_strings:
        print(f"   - {s}")

    # 创建翻译
    print(f"\n📝 生成翻译...\n")
    translations = create_translations(chinese_strings)

    # 保存到文件
    output_file = PROJECT_ROOT / "hardcoded_strings_translations.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(translations, f, ensure_ascii=False, indent=2)

    print(f"✅ 翻译已保存到: {output_file}\n")

    # 显示翻译预览
    print("翻译预览:")
    for zh, en in list(translations.items())[:10]:
        print(f"   {zh} → {en}")
    if len(translations) > 10:
        print(f"   ... 还有 {len(translations) - 10} 个")

if __name__ == "__main__":
    main()
