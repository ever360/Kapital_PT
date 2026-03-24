-- Tabla para historial de pagos de suscripción/plan de empresas (pago por rutas)
CREATE TABLE IF NOT EXISTS public.pagos_empresa (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id uuid NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
  monto numeric(12,2) NOT NULL DEFAULT 0,
  rutas_contratadas integer NOT NULL DEFAULT 0,
  fecha_pago timestamptz NOT NULL DEFAULT now(),
  fecha_vencimiento timestamptz,
  metodo_pago text DEFAULT 'efectivo',
  notas text,
  registrado_por uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indice para buscar pagos por empresa
CREATE INDEX IF NOT EXISTS idx_pagos_empresa_empresa_id ON public.pagos_empresa(empresa_id);

-- RLS
ALTER TABLE public.pagos_empresa ENABLE ROW LEVEL SECURITY;

-- Los usuarios autenticados pueden leer pagos de su empresa
CREATE POLICY "Users can read pagos of their empresa"
  ON public.pagos_empresa
  FOR SELECT
  TO authenticated
  USING (true);

-- Solo master y super_admin pueden insertar
CREATE POLICY "Authenticated users can insert pagos_empresa"
  ON public.pagos_empresa
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Service role full access
CREATE POLICY "Service role full access pagos_empresa"
  ON public.pagos_empresa
  FOR ALL
  TO service_role
  USING (true);
