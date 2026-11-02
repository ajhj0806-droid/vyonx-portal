// IOT CITY — logins do portal (criar, trocar senha, excluir) e criação do 1º administrador.
// Roda com a chave de serviço; quem chama é conferido aqui dentro (verify_jwt desligado porque
// a chave publicável do navegador não é JWT).
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const resp = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const erro = (msg: string, status = 400) => resp({ erro: msg }, status);

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const emailOk = (e: unknown) => typeof e === 'string' && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
const senhaOk = (s: unknown) => typeof s === 'string' && s.length >= 8;

// O Supabase Auth recusa senha fraca ou vazada em inglês. Quem cadastra cliente
// não tem de decifrar "known to be weak and easy to guess" para entender que a
// senha caiu em vazamento e que basta escolher outra.
function traduzSenha(e: { message?: string; code?: string } | null): string | null {
  if (!e) return null;
  const m = e.message || '';
  if (e.code === 'weak_password' || /known to be weak|easy to guess|pwned|leaked|weak.?password/i.test(m))
    return 'Esta senha foi recusada: ela aparece em vazamentos públicos conhecidos, ou é fraca demais. '
         + 'Escolha outra — uma frase longa funciona melhor do que uma palavra com números no fim.';
  return null;
}

async function chamador(req: Request) {
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token || token.startsWith('sb_')) return null;
  const { data } = await admin.auth.getUser(token);
  if (!data.user) return null;
  const { data: pu } = await admin.from('portal_usuario').select('papel,ativo').eq('user_id', data.user.id).maybeSingle();
  return { user: data.user, papel: pu && pu.ativo ? pu.papel : null };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return erro('Use POST.', 405);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return erro('Corpo inválido.'); }
  const acao = b.acao;

  // 1º administrador: só enquanto não houver nenhum e só para e-mail autorizado
  if (acao === 'primeiro_admin') {
    const email = String(b.email || '').trim().toLowerCase();
    if (!emailOk(email)) return erro('E-mail inválido.');
    if (!senhaOk(b.senha)) return erro('A senha precisa ter pelo menos 8 caracteres.');
    const { count } = await admin.from('portal_usuario').select('user_id', { count: 'exact', head: true }).eq('papel', 'admin').eq('ativo', true);
    if ((count ?? 0) > 0) return erro('O administrador já foi criado. Entre com e-mail e senha.', 409);
    const { data: sem } = await admin.from('portal_semente').select('email').eq('email', email).maybeSingle();
    if (!sem) return erro('Este e-mail não está autorizado a criar o administrador.', 403);
    const { data: u, error } = await admin.auth.admin.createUser({ email, password: b.senha as string, email_confirm: true });
    if (error || !u.user) return erro(traduzSenha(error) || error?.message || 'Falha ao criar o login.');
    const { error: e2 } = await admin.from('portal_usuario').insert({ user_id: u.user.id, email, nome: 'Administrador', papel: 'admin' });
    if (e2) { await admin.auth.admin.deleteUser(u.user.id); return erro(e2.message); }
    return resp({ ok: true });
  }

  const c = await chamador(req);
  if (!c || c.papel !== 'admin') return erro('Somente o administrador do portal.', 403);

  if (acao === 'criar') {
    const email = String(b.email || '').trim().toLowerCase();
    const papel = b.papel === 'admin' ? 'admin' : 'cliente';
    if (!emailOk(email)) return erro('E-mail inválido.');
    if (!senhaOk(b.senha)) return erro('A senha inicial precisa ter pelo menos 8 caracteres.');
    const { data: u, error } = await admin.auth.admin.createUser({ email, password: b.senha as string, email_confirm: true });
    if (error || !u.user) return erro(
      /already|registered|exists/i.test(error?.message || '') ? 'Já existe um login com este e-mail.'
      : (traduzSenha(error) || error?.message || 'Falha ao criar o login.'));
    const nome = String(b.nome || '').trim().slice(0, 80) || null;
    const { error: e2 } = await admin.from('portal_usuario').insert({ user_id: u.user.id, email, nome, papel });
    if (e2) { await admin.auth.admin.deleteUser(u.user.id); return erro(e2.message); }
    return resp({ ok: true, user_id: u.user.id });
  }

  if (acao === 'senha') {
    if (!senhaOk(b.senha)) return erro('A senha precisa ter pelo menos 8 caracteres.');
    const { data: pu } = await admin.from('portal_usuario').select('user_id').eq('user_id', String(b.user_id || '')).maybeSingle();
    if (!pu) return erro('Usuário não encontrado no portal.', 404);
    const { error } = await admin.auth.admin.updateUserById(pu.user_id, { password: b.senha as string });
    return error ? erro(traduzSenha(error) || error.message) : resp({ ok: true });
  }

  if (acao === 'excluir') {
    const id = String(b.user_id || '');
    if (id === c.user.id) return erro('Você não pode excluir o próprio login.');
    const { data: pu } = await admin.from('portal_usuario').select('user_id').eq('user_id', id).maybeSingle();
    if (!pu) return erro('Usuário não encontrado no portal.', 404);
    const { error } = await admin.auth.admin.deleteUser(id);
    return error ? erro(/administrador/.test(error.message) ? 'O portal precisa de pelo menos um administrador ativo.' : error.message) : resp({ ok: true });
  }

  return erro('Ação desconhecida.');
});
