# Os avisos do advisor que ficam de propósito

O linter de segurança do Supabase (Database → Advisors) aponta cinco coisas neste
projeto. Quatro são intencionais e **uma delas, se “corrigida”, derruba o portal**.
Este arquivo existe para ninguém arrumar por engano.

Última revisão: 01/11/2026.

---

## 1. `anon` executa `portal_admin()`, `portal_cliente()`, `portal_papel()` — **não mexer**

É a armadilha. Parece grave e é necessário.

A política de leitura de `portal_app` é `TO anon, authenticated` e chama essas
funções. Em Postgres, a política é avaliada **com o papel de quem consulta** —
então, para um visitante sem login enxergar os botões da abertura, o papel `anon`
precisa poder executar `portal_admin()` e `portal_cliente()`.

Revogar o `execute` de `anon` não "fecha" nada: faz toda consulta a `portal_app`
falhar com permissão negada, e a abertura do portal fica vazia.

O que as funções devolvem é só o papel de **quem está chamando** (`auth.uid()`).
Um anônimo recebe `null`. Não há o que vazar.

`portal_precisa_admin()` é pública pelo mesmo motivo prático: a tela de primeiro
acesso precisa perguntar isso antes de existir qualquer login.

## 2. `authenticated` executa `idg_coletas_recentes()` — intencional

Ela é `SECURITY DEFINER` justamente porque precisa ler `net._http_response`, que
um usuário comum não alcança. A checagem está dentro: `where public.portal_admin()`.
Quem não é admin recebe zero linhas, não erro — e `portal_admin()` enxerga o JWT
de quem chamou mesmo dentro de uma função definer, que é o padrão do Supabase.

## 3. `idg_coleta_execucao` e `portal_semente` com RLS e sem política — intencional

É o jeito de dizer "ninguém lê isto pela API". RLS ligada sem nenhuma política
nega tudo; só `service_role` e `postgres` passam (o coletor e as migrações).
Criar política aqui seria abrir, não fechar.

## 4. Proteção contra senha vazada desligada — **pendente, só o Airton resolve**

Supabase Auth → Settings → "Leaked password protection". Confere a senha contra
o HaveIBeenPwned na hora de cadastrar. É um botão no painel; não dá para ligar
por SQL nem por migração.

---

## O que NÃO é aviso do advisor, mas é a lição de 01/11

View sem `security_invoker` roda com os privilégios de quem a criou e **ignora o
RLS das tabelas base**. O advisor não pegou; foi um teste com a chave publicável
que pegou (ver `005_idg_view_respeita_rls.sql`). Toda view nova nasce com
`with (security_invoker = true)`, e recriar uma view perde a opção e os grants.
