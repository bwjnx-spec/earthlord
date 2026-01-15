// Supabase Edge Function: delete-account
// 用于删除用户账户的边缘函数

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🗑️ 开始删除账户流程')

    // 1. 获取 Authorization header 中的 JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      console.log('❌ 缺少 Authorization header')
      return new Response(
        JSON.stringify({
          error: '未授权',
          message: '缺少 Authorization header'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 2. 创建 Supabase 客户端（使用用户的 JWT）
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // 3. 验证用户身份并获取用户 ID
    console.log('   验证用户身份...')
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      console.log('❌ 用户验证失败:', userError?.message)
      return new Response(
        JSON.stringify({
          error: '认证失败',
          message: userError?.message || '无法获取用户信息'
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`   ✅ 用户验证成功: ${user.id}`)
    console.log(`   用户邮箱: ${user.email}`)

    // 4. 创建管理员客户端（使用 service_role key）
    console.log('   使用 service_role 权限删除用户...')
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // 5. 删除用户
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
      user.id
    )

    if (deleteError) {
      console.log('❌ 删除用户失败:', deleteError.message)
      return new Response(
        JSON.stringify({
          error: '删除失败',
          message: deleteError.message
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('✅ 用户删除成功')

    // 6. 返回成功响应
    return new Response(
      JSON.stringify({
        success: true,
        message: '账户已成功删除',
        deleted_user_id: user.id,
        deleted_user_email: user.email
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.log('❌ 发生意外错误:', error.message)
    return new Response(
      JSON.stringify({
        error: '服务器错误',
        message: error.message
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
