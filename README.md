# AcheFood SaaS V1

Plataforma SaaS B2B para descoberta de fornecedores, demandas, cotações e conexões comerciais no setor alimentício.

## Estado desta entrega

- Next.js App Router + React + TypeScript estrito.
- Tailwind CSS 4 disponível e tokens visuais oficiais em CSS.
- Landing page responsiva baseada nos layouts aprovados.
- Login responsivo com e-mail/senha e Google OAuth via Supabase.
- Cadastro, recuperação de senha, callback OAuth e onboarding inicial.
- Dashboard do cliente responsivo com estados vazios seguros (sem métricas falsas).
- Migration inicial para `profiles`, empresas multiusuário, RBAC, RLS e auditoria.
- Protótipo HTML anterior preservado em `index.html` como referência legada.

## Executar localmente

```bash
pnpm install
copy .env.example .env.local
pnpm dev
```

Abra `http://localhost:3000`.

## Supabase

Preencha apenas as chaves públicas no `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

Nunca exponha `SUPABASE_SERVICE_ROLE_KEY` no navegador. A migration atual está em `supabase/migrations/202609020001_foundation.sql`. Ela deve ser validada primeiro em um projeto de desenvolvimento.

No Supabase Auth, configure a Site URL, a Redirect URL `/auth/callback`, o provedor Google (se usado) e a política de confirmação de e-mail do piloto.

## Verificações

```bash
pnpm typecheck
pnpm lint
pnpm build
```

## Limites atuais

- Status de validação (03/09/2026): instalação npm bloqueada por erro `ENOENT` ao criar dependências em `node_modules`; build, lint e teste de navegador desta revisão não executados.
- Callback corrigido para recusar código ausente, erro OAuth ou troca sem sessão. Cadastro mapeia perfis em português para os valores do enum do banco. Alterações ainda precisam de teste integrado.
- Onboarding ainda não persiste dados; recuperação de senha está incompleta e o dashboard ainda não possui proteção de sessão. Não publicar como produto pronto.
- Sem credenciais Supabase, autenticação e persistência ficam desativadas de forma explícita.
- A migration ainda não foi aplicada a um projeto Supabase real nesta entrega.
- Busca, catálogo, oportunidades, conexões e Admin possuem rotas reservadas, mas as fatias funcionais completas continuam no roadmap.
- Termos e Política de Privacidade exigem revisão jurídica antes de produção.
