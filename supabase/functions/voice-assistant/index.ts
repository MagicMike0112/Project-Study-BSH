// supabase/functions/voice-assistant/index.ts

// 1. 引入依赖 (使用固定版本以确保稳定性)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'

// 2. 定义类型接口 (消除 TypeScript 报错)
interface RequestBody {
  text: string;
}

interface AIResult {
  action: "add" | "eat" | "check" | "unknown";
  item: string | null;
  quantity: number;
  category: string;
  reply: string;
}

// 3. 设置 CORS 头 (允许跨域访问)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  // 处理预检请求 (Browser Preflight)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. 检查环境变量
    const openAiKey = Deno.env.get('OPENAI_API_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

    if (!openAiKey || !supabaseUrl || !supabaseAnonKey) {
      throw new Error('Server configuration error: Missing environment variables.')
    }

    // 2. 检查 Auth Header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing Authorization header')
    }

    // 3. 获取请求内容
    const { text } = await req.json() as RequestBody
    if (!text) {
      throw new Error('No text provided')
    }

    console.log(`🎤 Received voice command: "${text}"`)

    // 4. 调用 OpenAI GPT-4o-mini
    const aiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openAiKey}`
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: `You are a smart home inventory assistant. 
            Analyze the user's input and extract structured data in JSON.
            Current Date: ${new Date().toISOString()}
            
            Return a JSON object with these fields:
            - action: "add" (buy/get/stock), "eat" (consume/drink/use), "check" (query), or "unknown"
            - item: string (e.g. "Milk"), or null if unknown
            - quantity: number (default 1, infer from text like "a couple" -> 2)
            - category: string (infer one: "Fruit", "Veggies", "Meat", "Dairy", "Carbs", "Drinks", "Snacks", "General")
            - reply: A short, friendly confirmation message (e.g. "Added 3 Apples to inventory.")`
          },
          { role: "user", content: text }
        ],
        response_format: { type: "json_object" }, // 强制 JSON 格式
        temperature: 0.3 // 低温度，更精准
      })
    })

    const aiData = await aiResponse.json()
    
    if (aiData.error) {
      console.error("OpenAI API Error:", aiData.error)
      throw new Error(`OpenAI Error: ${aiData.error.message}`)
    }

    // 解析 AI 结果
    const content = aiData.choices[0].message.content
    const result: AIResult = JSON.parse(content)
    console.log("🤖 AI Parsed Result:", result)

    // 5. 初始化 Supabase 客户端 (使用用户身份)
    const supabaseClient = createClient(
      supabaseUrl,
      supabaseAnonKey,
      { global: { headers: { Authorization: authHeader } } }
    )

    // 6. 执行数据库操作
    if (result.action === 'add' && result.item) {
      // 获取当前用户
      const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
      if (userError || !user) throw new Error('User authentication failed')

      // 获取家庭 ID
      const { data: member, error: memberError } = await supabaseClient
        .from('family_members')
        .select('family_id')
        .eq('user_id', user.id)
        .single() // 假设用户只在一个家庭

      if (memberError || !member) {
        throw new Error('Family not found. Please join a family first.')
      }

      // 插入数据
      const { error: insertError } = await supabaseClient.from('inventory_items').insert({
        name: result.item,
        quantity: result.quantity,
        category: result.category, // AI 自动推断的分类
        unit: 'pcs', // 默认单位，未来可以让 AI 推断 'kg', 'L'
        location: 'fridge', // 默认位置
        status: 'good',
        family_id: member.family_id,
        user_id: user.id
      })

      if (insertError) {
        console.error("DB Insert Error:", insertError)
        throw new Error("Failed to save to database")
      }
    }

    // 7. 返回成功响应
    return new Response(
      JSON.stringify({ 
        message: result.reply, 
        data: result 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error("❌ Function Error:", error)
    
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'Unknown error',
        message: "Sorry, something went wrong. Please try again." 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 // 返回 500 状态码以便前端捕获
      }
    )
  }
})