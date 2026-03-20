-- Tabla para almacenar multiples FCM tokens por usuario (multi-dispositivo)
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  platform text NOT NULL DEFAULT 'unknown',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, fcm_token)
);

-- Indice para buscar tokens por user_id rapidamente
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);

-- RLS: solo el propio usuario puede insertar/borrar sus tokens
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own tokens"
  ON public.device_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Permitir al service_role leer todos (para la Edge Function)
CREATE POLICY "Service role can read all tokens"
  ON public.device_tokens
  FOR SELECT
  TO service_role
  USING (true);
