// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';

interface PendingPayload {
  user_id?: string;
  nombre?: string;
  email?: string;
  telefono?: string;
  created_at?: string;
}

function withCors(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    },
  });
}

async function getGoogleAccessToken(
  clientEmail: string,
  privateKey: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const alg = 'RS256';

  const key = await importPKCS8(privateKey, alg);
  const jwt = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg, typ: 'JWT' })
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .sign(key);

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const txt = await tokenRes.text();
    throw new Error(`No se pudo obtener access_token: ${txt}`);
  }

  const tokenJson = await tokenRes.json();
  return tokenJson.access_token as string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return withCors({ ok: true });
  if (req.method !== 'POST') {
    return withCors({ error: 'Method not allowed' }, 405);
  }

  try {
    let projectId = Deno.env.get('FIREBASE_PROJECT_ID') ?? '';
    let clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? '';
    let privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '';

    // Opción 1 (recomendada): FIREBASE_PRIVATE_KEY_B64 = private key en Base64 puro
    // Evita problemas de saltos de línea al pasar la key por CLI
    const privateKeyB64 = Deno.env.get('FIREBASE_PRIVATE_KEY_B64');
    if (privateKeyB64) {
      try {
        privateKey = atob(privateKeyB64.trim());
      } catch (_) {
        console.error('FIREBASE_PRIVATE_KEY_B64 no es Base64 válido, intentando FIREBASE_SERVICE_ACCOUNT_BASE64...');
      }
    }

    // Opción 2: JSON completo del service account (raw o en Base64)
    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    const serviceAccountB64 = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_BASE64');
    if (serviceAccountRaw || serviceAccountB64) {
      try {
        let source = serviceAccountRaw ?? '';
        if (!source && serviceAccountB64) {
          source = atob(serviceAccountB64.trim());
        }
        const serviceAccount = JSON.parse(source) as {
          project_id?: string;
          client_email?: string;
          private_key?: string;
        };
        projectId = serviceAccount.project_id || projectId;
        clientEmail = serviceAccount.client_email || clientEmail;
        privateKey = serviceAccount.private_key || privateKey;
      } catch (_) {
        return withCors(
          { error: 'FIREBASE_SERVICE_ACCOUNT/FIREBASE_SERVICE_ACCOUNT_BASE64 inválido' },
          500,
        );
      }
    }

    if (!projectId || !clientEmail || !privateKey) {
      return withCors(
        {
          error:
            'Faltan credenciales Firebase. Usa FIREBASE_PRIVATE_KEY_B64 o FIREBASE_SERVICE_ACCOUNT_BASE64 o FIREBASE_PROJECT_ID + FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY',
        },
        500,
      );
    }

    // Normalizar posibles formatos del private key en secrets:
    // - quitar comillas externas si las hay
    // - convertir \n literales a saltos de línea reales
    // - re-armar el PEM en caso de que los saltos internos se perdieran
    privateKey = privateKey
      .replace(/^["']|["']$/g, '')   // quitar comillas externas
      .replace(/\\n/g, '\n')          // \n literal → newline real
      .replace(/\r\n/g, '\n')         // normalizar CRLF
      .trim();

    // Si el PEM perdió sus saltos internos (todo en una línea), rearmarlo
    if (!privateKey.includes('\n') && privateKey.includes('-----BEGIN')) {
      privateKey = privateKey
        .replace('-----BEGIN RSA PRIVATE KEY-----', '-----BEGIN RSA PRIVATE KEY-----\n')
        .replace('-----END RSA PRIVATE KEY-----', '\n-----END RSA PRIVATE KEY-----')
        .replace('-----BEGIN PRIVATE KEY-----', '-----BEGIN PRIVATE KEY-----\n')
        .replace('-----END PRIVATE KEY-----', '\n-----END PRIVATE KEY-----');

      // Re-insertar saltos cada 64 caracteres en el cuerpo del PEM
      const pemLines = privateKey.split('\n');
      const header = pemLines[0];
      const footer = pemLines[pemLines.length - 1];
      const body = pemLines.slice(1, -1).join('');
      const bodyFormatted = body.match(/.{1,64}/g)?.join('\n') ?? body;
      privateKey = `${header}\n${bodyFormatted}\n${footer}`;
    }

    const body = (await req.json()) as PendingPayload;
    const nombre = body.nombre ?? 'Usuario';
    const email = body.email ?? 'Sin email';
    const telefono = body.telefono ?? 'Sin teléfono';

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: masters, error: mastersError } = await supabase
      .from('profiles')
      .select('id')
      .eq('rol', 'master');

    if (mastersError) {
      throw new Error(`Error consultando masters: ${mastersError.message}`);
    }

    if (!masters || masters.length === 0) {
      return withCors({ ok: true, sent: 0, reason: 'No hay masters' });
    }

    const masterIds = masters.map((m: { id: string }) => m.id);

    // Obtener TODOS los tokens de TODOS los dispositivos de los masters
    const { data: deviceTokens, error: dtError } = await supabase
      .from('device_tokens')
      .select('user_id, fcm_token')
      .in('user_id', masterIds);

    // Fallback: si la tabla device_tokens no existe o está vacía, usar profiles.fcm_token
    let tokens: string[] = [];
    if (dtError || !deviceTokens || deviceTokens.length === 0) {
      const { data: profileTokens } = await supabase
        .from('profiles')
        .select('fcm_token')
        .eq('rol', 'master')
        .not('fcm_token', 'is', null);
      tokens = (profileTokens || []).map((p: { fcm_token: string }) => p.fcm_token);
    } else {
      tokens = deviceTokens.map((d: { fcm_token: string }) => d.fcm_token);
    }

    if (tokens.length === 0) {
      return withCors({ ok: true, sent: 0, reason: 'No hay tokens master' });
    }

    const accessToken = await getGoogleAccessToken(clientEmail, privateKey);

    let sent = 0;
    const failed: Array<{ tokenSuffix: string; status: number; body: string }> = [];

    for (const token of tokens) {
      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: {
                title: 'Nueva solicitud pendiente',
                body: `${nombre} solicitó aprobación`,
              },
              data: {
                type: 'new_pending_user',
                user_id: body.user_id ?? '',
                nombre,
                email,
                telefono,
                created_at: body.created_at ?? '',
              },
              webpush: {
                notification: {
                  icon: '/icons/kapital_192.png',
                  badge: '/icons/kapital_192.png',
                },
              },
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'kapital_push_channel',
                  sound: 'default',
                  default_sound: true,
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: 'default',
                    badge: 1,
                  },
                },
              },
            },
          }),
        },
      );

      if (fcmRes.ok) {
        sent += 1;
      } else {
        const errorBody = await fcmRes.text();
        failed.push({
          tokenSuffix: token.slice(-12),
          status: fcmRes.status,
          body: errorBody,
        });
        console.error('FCM send failed', {
          tokenSuffix: token.slice(-12),
          status: fcmRes.status,
          body: errorBody,
        });
      }
    }

    return withCors({ ok: true, sent, failedCount: failed.length, failed });
  } catch (e) {
    return withCors({ error: (e as Error).message }, 500);
  }
});
