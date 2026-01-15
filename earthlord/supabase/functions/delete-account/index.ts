import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // 1. 获取 Authorization header 中的 JWT token
    const authHeader = req.headers.get('Authorization')

    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: '未授权：缺少 Authorization header'
        }),
        {
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // 2. 使用用户的 JWT token 创建 Supabase 客户端来验证身份
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // 验证用户身份
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: '未授权：无效的 token'
        }),
        {
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('用户身份验证成功:', user.email)
    console.log('准备删除用户 ID:', user.id)

    // 3. 使用 service_role key 创建管理员客户端来删除用户
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

    // 删除用户
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id)

    if (deleteError) {
      console.error('删除用户失败:', deleteError)
      return new Response(
        JSON.stringify({
          success: false,
          error: `删除用户失败: ${deleteError.message}`
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('用户删除成功:', user.id)

    // 4. 返回成功响应
    return new Response(
      JSON.stringify({
        success: true,
        message: '账户已成功删除',
        deleted_user_id: user.id,
        deleted_user_email: user.email ?? '未知'
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('删除账户时发生错误:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: `服务器错误: ${error.message}`
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})
