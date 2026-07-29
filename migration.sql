-- 1. Add Wali/Guardian name to Siswa table
ALTER TABLE public.siswa ADD COLUMN IF NOT EXISTS nama_wali text;

-- 2. Create Insentif Guru table (daily incentive rates)
CREATE TABLE IF NOT EXISTS public.insentif_guru (
  id serial PRIMARY KEY,
  guru_id integer REFERENCES public.guru(id) ON DELETE CASCADE,
  unit_id integer REFERENCES public.unit_pendidikan(id) ON DELETE CASCADE,
  nominal integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(guru_id, unit_id)
);

-- 3. Create app_settings table if not exists (for banner configuration)
CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamp with time zone DEFAULT now()
);

-- Seed banner setting if not already present
INSERT INTO public.app_settings (key, value)
VALUES ('dashboard_banner', 'Selamat datang di GMQ Super App!')
ON CONFLICT (key) DO NOTHING;
