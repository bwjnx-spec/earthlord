-- ============================================
-- Day 18: territories 表设置
-- ============================================

-- 第一步：启用 PostGIS 扩展
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 第二步：创建或更新 territories 表
CREATE TABLE IF NOT EXISTS public.territories (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    name text,  -- ⚠️ 必须是 nullable！
    path jsonb NOT NULL,
    polygon geography(Polygon, 4326),
    bbox_min_lat double precision,
    bbox_max_lat double precision,
    bbox_min_lon double precision,
    bbox_max_lon double precision,
    area double precision NOT NULL,
    point_count integer,
    started_at timestamptz,
    completed_at timestamptz,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT territories_pkey PRIMARY KEY (id),
    CONSTRAINT territories_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_territories_user_id ON public.territories(user_id);
CREATE INDEX IF NOT EXISTS idx_territories_is_active ON public.territories(is_active);
CREATE INDEX IF NOT EXISTS idx_territories_created_at ON public.territories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_territories_polygon ON public.territories USING GIST(polygon);

-- 第三步：配置 RLS (Row Level Security)
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

-- 删除现有策略（如果存在）
DROP POLICY IF EXISTS "Users can view all territories" ON public.territories;
DROP POLICY IF EXISTS "Users can insert their own territories" ON public.territories;
DROP POLICY IF EXISTS "Users can update their own territories" ON public.territories;
DROP POLICY IF EXISTS "Users can delete their own territories" ON public.territories;

-- 所有人可以查看领地
CREATE POLICY "Users can view all territories"
    ON public.territories
    FOR SELECT
    USING (true);

-- 用户只能创建自己的领地
CREATE POLICY "Users can insert their own territories"
    ON public.territories
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 用户只能更新自己的领地
CREATE POLICY "Users can update their own territories"
    ON public.territories
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 用户只能删除自己的领地
CREATE POLICY "Users can delete their own territories"
    ON public.territories
    FOR DELETE
    USING (auth.uid() = user_id);

-- 创建更新时间触发器函数
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 添加触发器
DROP TRIGGER IF EXISTS update_territories_updated_at ON public.territories;
CREATE TRIGGER update_territories_updated_at
    BEFORE UPDATE ON public.territories
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
