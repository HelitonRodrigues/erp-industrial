// Leitura de fichas por foto (Gemini). Chave em secret GEMINI_API_KEY.
// body: {prompt, imagens?:[dataURL], urls?:[https...], json?:true, modelo?}  |  {ping:true}
// Tenta varios modelos em sequencia quando um esta sobrecarregado (503/429) ou indisponivel (404).
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });
const BASE = 'https://generativelanguage.googleapis.com/v1beta';
const FILA = ['gemini-3.8-flash', 'gemini-3.5-flash', 'gemini-flash-latest', 'gemini-3.1-flash-lite'];
const esperar = (ms: number) => new Promise((r) => setTimeout(r, ms));

function b64(buf: ArrayBuffer) {
  const u = new Uint8Array(buf); let s = '';
  for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode(...u.subarray(i, i + 0x8000));
  return btoa(s);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const key = Deno.env.get('GEMINI_API_KEY');
  if (!key) return J({ ok: false, erro: 'GEMINI_API_KEY ausente' }, 500);
  const H = { 'x-goog-api-key': key, 'Content-Type': 'application/json' };
  let body: any = {};
  try { body = await req.json(); } catch (_) {}

  if (body.ping) {
    const r = await fetch(`${BASE}/models?pageSize=200`, { headers: H });
    const t = await r.text();
    let nomes: string[] = [];
    try { nomes = (JSON.parse(t).models || []).map((m: any) => m.name).filter((n: string) => /gemini/.test(n)); } catch (_) {}
    return J({ ok: r.ok, status: r.status, modelos: nomes, erro: r.ok ? null : t.slice(0, 500) });
  }

  const parts: any[] = [{ text: body.prompt || 'Descreva a imagem.' }];
  for (const img of (body.imagens || [])) {
    const m = String(img).match(/^data:([^;]+);base64,(.*)$/);
    parts.push({ inline_data: { mime_type: m ? m[1] : 'image/jpeg', data: m ? m[2] : img } });
  }
  for (const u of (body.urls || [])) {
    try {
      const r = await fetch(u);
      if (!r.ok) return J({ ok: false, erro: 'Não consegui abrir a foto (' + r.status + ')' }, 400);
      parts.push({ inline_data: { mime_type: r.headers.get('content-type') || 'image/jpeg', data: b64(await r.arrayBuffer()) } });
    } catch (e) { return J({ ok: false, erro: 'Não consegui abrir a foto: ' + String(e) }, 400); }
  }
  const gen: any = { temperature: 0 };
  if (body.json !== false) gen.responseMimeType = 'application/json';
  const payload = JSON.stringify({ contents: [{ role: 'user', parts }], generationConfig: gen });

  const env = Deno.env.get('GEMINI_MODEL');
  const fila = body.modelo ? [body.modelo, ...FILA.filter((x) => x !== body.modelo)] : (env ? [env, ...FILA.filter((x) => x !== env)] : FILA);
  const tentativas: any[] = [];
  for (let volta = 0; volta < 2; volta++) {
    for (const modelo of fila) {
      const r = await fetch(`${BASE}/models/${modelo}:generateContent`, { method: 'POST', headers: H, body: payload });
      const d = await r.json().catch(() => ({}));
      if (r.ok) {
        const texto = (d.candidates?.[0]?.content?.parts || []).filter((p: any) => !p.thought).map((p: any) => p.text || '').join('');
        let dados: any = null;
        try { dados = JSON.parse(texto.replace(/^```json\s*|```\s*$/g, '')); } catch (_) {}
        return J({ ok: true, modelo, texto, dados, uso: d.usageMetadata || null, tentativas });
      }
      tentativas.push({ modelo, status: r.status, erro: String(d?.error?.message || '').slice(0, 160) });
      if (![429, 500, 503, 404].includes(r.status)) return J({ ok: false, status: r.status, erro: d?.error?.message || d, tentativas }, 502);
    }
    await esperar(3000);
  }
  return J({ ok: false, erro: 'Leitor ocupado no momento. Tente de novo em 1 minuto ou digite os valores.', tentativas }, 503);
});
