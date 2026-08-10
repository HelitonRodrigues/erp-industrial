# Item 4.5 — Migração base64 → Storage (guia da sessão dedicada)

> **Rascunho de referência.** Nada aqui roda sozinho. Só executar numa sessão dedicada,
> **com backup fresco na mão** (protocolo #5). Ordem: (1) checar bucket → (2) mergear o
> branch da frota → (3) backfill em DRY-RUN → (4) backfill de verdade → (5) backup do bucket.

## 0. Pré-voo (obrigatório)

1. **Backup fresco.** Dispare o workflow `backup.yml` manualmente (Actions → Run workflow)
   ou confirme o dump da noite. Baixe o artifact e guarde antes de qualquer backfill.
2. **`git pull`** na main.

## 1. Conferir o bucket `documentos` (o mesmo que o bpf.html já usa)

No Supabase → Storage → bucket `documentos`:
- Existe? (o bpf.html usa; deve existir)
- **Public** (leitura pública)? O código usa `getPublicUrl` — se o bucket for privado, o
  `<img src>`/`<a href>` dá 403. Para docs de veículo, público é aceitável (URL longa/opaca).
- **Policy de upload para `authenticated`?** Sem ela, o upload autenticado falha e o código
  cai no fallback base64 (não quebra, mas não migra). SQL para checar as policies do Storage:

```sql
select name, definition, command, roles
from storage.policies
where bucket_id = 'documentos';
```

Se faltar policy de INSERT/SELECT para `authenticated`, criar pelo painel (Storage → Policies)
ou via SQL (ajuste conforme o já existente do bpf, para não duplicar).

## 2. Mergear o branch da frota (depois do teste autenticado)

Branch: `feat/frota-docs-storage` (commit `0592e4a`). **Só mergear após** testar logado:
subir um doc **>4MB** num veículo e confirmar que foi pro Storage (doc fica com `url`/
`path_storage`, não `data`), e que docs antigos ainda abrem.

```bash
git checkout main
git merge feat/frota-docs-storage
git push          # Vercel deploya
```

## 3. Backfill dos documentos base64 JÁ existentes → Storage

> Roda no **console do navegador**, **logado como SADM** em `frota.html` (usa o `_supabase`
> autenticado da página). **DRY-RUN por padrão** — só mostra o que FARIA. Só troca
> `DRY_RUN=false` depois de conferir o relatório do dry-run **e com backup na mão**.
> Migra só documentos base64 **> 4MB** (mesma régua do código novo; os ≤4MB seguem em base64).

```js
(async () => {
  const DRY_RUN = true;                 // <<< troque para false só com backup fresco
  const LIMIAR = 4 * 1024 * 1024;       // só migra base64 acima disso
  const tamB64 = s => Math.floor((s.length - (s.indexOf(',') + 1)) * 3 / 4); // bytes ~ do dataURL
  const { data: veics, error } = await _supabase.from('frota_veiculos').select('id, placa, documentos');
  if (error) { console.error('Falha ao ler frota:', error); return; }
  let migrados = 0, pulados = 0, erros = 0;
  for (const v of (veics || [])) {
    let docs = Array.isArray(v.documentos) ? v.documentos
             : (typeof v.documentos === 'string' ? JSON.parse(v.documentos || '[]') : []);
    let mudou = false;
    for (let i = 0; i < docs.length; i++) {
      const d = docs[i];
      if (!d || !d.data || !String(d.data).startsWith('data:')) { continue; }   // já é url ou vazio
      if (tamB64(d.data) <= LIMIAR) { pulados++; continue; }                     // pequeno: fica base64
      const path = `frota/backfill_${v.id}_${i}_${(d.nome || 'doc').replace(/[^\w.\-]/g, '_')}`;
      console.log(`${DRY_RUN ? '[DRY] ' : ''}migrar ${v.placa} · ${d.nome} (${(tamB64(d.data)/1048576).toFixed(1)}MB) → ${path}`);
      if (DRY_RUN) { migrados++; continue; }
      try {
        const blob = await (await fetch(d.data)).blob();
        const { error: upErr } = await _supabase.storage.from('documentos').upload(path, blob, { upsert: true });
        if (upErr) { console.error('upload falhou', v.placa, d.nome, upErr); erros++; continue; }
        const { data: pub } = _supabase.storage.from('documentos').getPublicUrl(path);
        docs[i] = { nome: d.nome, tipo: d.tipo, tamanho: d.tamanho, isImg: d.isImg, adicionado: d.adicionado,
                    url: pub?.publicUrl || null, path_storage: path };
        mudou = true; migrados++;
      } catch (e) { console.error('erro', v.placa, d.nome, e); erros++; }
    }
    if (mudou && !DRY_RUN) {
      const { error: updErr } = await _supabase.from('frota_veiculos').update({ documentos: docs }).eq('id', v.id);
      if (updErr) { console.error('update falhou', v.placa, updErr); erros++; }
      else console.log(`✔ ${v.placa} atualizado`);
    }
  }
  console.log(`\n=== ${DRY_RUN ? 'DRY-RUN' : 'EXECUTADO'} === migrados(>4MB): ${migrados} · pulados(≤4MB): ${pulados} · erros: ${erros}`);
})();
```

**Depois do backfill real:** recarregue o `frota.html`, abra alguns veículos e confirme que
os documentos migrados abrem (agora via URL do Storage). Só então considere os base64
antigos aposentáveis.

> Mesma lógica serve para os outros alvos, trocando tabela/coluna:
> `linhas_producao.foto` (1 campo, não array — já comprimido pela fase 1, backfill opcional),
> `manutencao.fotos_servico`, `terceiros_remessas.itens[].fotos[]` / `terceiros_servicos.anexos[]`.
> Fazer **um módulo por vez**, cada um com seu dry-run.

## 4. Backup do bucket no `backup.yml` (rascunho — NÃO wire ainda)

O `backup.yml` atual só faz `pg_dump`. O Storage fica de fora. Passo a **adicionar quando
tiver o secret** (o dump do Postgres NÃO traz os arquivos do bucket). Precisa de credencial
de Storage — o mais simples é a **S3 access key** do projeto (Supabase → Storage → S3
connection) como secrets `SUPABASE_S3_ENDPOINT`, `SUPABASE_S3_KEY`, `SUPABASE_S3_SECRET`.

Rascunho de step (colar depois do dump do Postgres, revisar antes):

```yaml
      - name: Backup Storage bucket (documentos)
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.SUPABASE_S3_KEY }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.SUPABASE_S3_SECRET }}
          AWS_DEFAULT_REGION: sa-east-1
        run: |
          aws s3 sync \
            s3://documentos ./storage-documentos \
            --endpoint-url "${{ secrets.SUPABASE_S3_ENDPOINT }}"
          tar -czf storage-$(date +%Y%m%d).tar.gz ./storage-documentos
      # e incluir o .tar.gz no mesmo upload-artifact do dump
```

> ⚠️ Não commitar esse step na `main` sem testar num run (um step que falha derruba o job
> inteiro do backup, que hoje funciona). Testar em branch/dispatch antes.

## 5. Migração aditiva (protocolo #3)

Cada módulo: (1) código escreve no novo formato (url) e lê `data||url`; (2) backfill dos
antigos; (3) semanas depois, quando `data` estiver vazio em todos, remover o fallback base64.
Não dropar nada antes do backfill 100% confirmado.
