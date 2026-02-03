-- ============================================
-- Day 22: player_locations 表设置
-- 玩家位置追踪，用于附近玩家检测
-- ============================================

-- 确保 PostGIS 已启用
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 1. 创建更新时间触发器函数（如果不存在）
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 2. 创建 player_locations 表
CREATE TABLE IF NOT EXISTS public.player_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    is_online BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT player_locations_user_unique UNIQUE (user_id)
);

-- 3. 创建索引
CREATE INDEX IF NOT EXISTS idx_player_locations_location ON public.player_locations USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_player_locations_online ON public.player_locations (is_online, last_seen_at);

-- 4. 启用 RLS
ALTER TABLE public.player_locations ENABLE ROW LEVEL SECURITY;

-- 删除现有策略（如果存在）
DROP POLICY IF EXISTS "Users can view own location" ON public.player_locations;
DROP POLICY IF EXISTS "Users can insert own location" ON public.player_locations;
DROP POLICY IF EXISTS "Users can update own location" ON public.player_locations;

-- 用户只能查看自己的位置
CREATE POLICY "Users can view own location"
    ON public.player_locations
    FOR SELECT
    USING (auth.uid() = user_id);

-- 用户只能插入自己的位置
CREATE POLICY "Users can insert own location"
    ON public.player_locations
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 用户只能更新自己的位置
CREATE POLICY "Users can update own location"
    ON public.player_locations
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 5. 创建 RPC 函数（隐私保护：只返回数量）
CREATE OR REPLACE FUNCTION public.count_nearby_online_players(
    center_lat DOUBLE PRECISION,
    center_lon DOUBLE PRECISION,
    radius_meters DOUBLE PRECISION DEFAULT 1000,
    online_threshold_minutes INTEGER DEFAULT 5
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM public.player_locations
        WHERE user_id != auth.uid()
          AND is_online = true
          AND last_seen_at > (now() - (online_threshold_minutes || ' minutes')::INTERVAL)
          AND ST_DWithin(
              location,
              ST_SetSRID(ST_MakePoint(center_lon, center_lat), 4326)::GEOGRAPHY,
              radius_meters
          )
    );
END;
$$;

-- 授权给已认证用户
GRANT EXECUTE ON FUNCTION public.count_nearby_online_players TO authenticated;

-- 6. 创建更新时间触发器
DROP TRIGGER IF EXISTS update_player_locations_updated_at ON public.player_locations;
CREATE TRIGGER update_player_locations_updated_at
    BEFORE UPDATE ON public.player_locations
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
