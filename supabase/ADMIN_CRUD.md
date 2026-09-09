# Contrato do painel administrativo

A migration `202609090001_admin_crud.sql` disponibiliza RPCs autenticadas para o painel. Todas usam `security definer`, `search_path=''` e chamam `require_super_admin()`. Um usuário comum recebe SQLSTATE `42501`.

## RPCs

- `admin_list_companies(search_term, status_filter, page_limit, page_offset)` retorna `{items,total,limit,offset}`.
- `admin_save_company(target_company, company_data)` cria quando o UUID é nulo e atualiza parcialmente quando informado.
- `admin_list_users(search_term, status_filter, page_limit, page_offset)` agrega `auth.users`, perfil, papel administrativo e vínculos empresariais.
- `admin_update_user(target_user, profile_data)` atualiza somente campos de perfil permitidos. Não altera senha, e-mail ou papel administrativo.
- `admin_save_company_member(target_company, target_user, member_role_value, member_status_value)` cria ou atualiza o vínculo empresarial. Impede remover o último proprietário ativo.
- `admin_list_products(search_term, company_filter, status_filter, page_limit, page_offset)` retorna `{items,total,limit,offset}`.
- `admin_save_product(target_product, product_data)` cria ou atualiza parcialmente.
- `admin_archive_product(target_product)` faz exclusão lógica; produtos não são apagados fisicamente.
- `admin_list_plans()` agrega recursos e quantidade de assinaturas ativas.
- `admin_create_plan(plan_data, features_data)` cria um plano com a matriz completa das 17 features.
- `admin_save_plan(target_plan, plan_data, features_data)` já existe na migration comercial e continua sendo o contrato de edição de plano existente.
- `admin_deactivate_plan(target_plan)` retira o plano de novas vendas sem apagar assinaturas históricas. O plano gratuito base não pode ser desativado.
- `admin_get_reports(period_start, period_end)` retorna totais, aquisições do período, assinaturas por plano e empresas por status; o intervalo máximo é 366 dias.

## Segurança e operação

- As tabelas continuam com RLS habilitado e sem política administrativa ampla. A elevação fica limitada às RPCs.
- Toda criação/alteração administrativa escreve em `audit_logs` na mesma transação.
- Empresa e produto usam status para suspensão/arquivamento; não há exclusão física administrativa.
- O próprio super admin não pode se suspender por `admin_update_user`.
- Suspender um perfil controla o estado no aplicativo, mas não bane a identidade em `auth.users`. Banimento, troca de e-mail e redefinição de senha devem usar a Admin API do Supabase em uma rota de servidor protegida.
- A migration não cria usuários em `auth.users`: convites/cadastro continuam no Supabase Auth para que senha e confirmação nunca trafeguem por RPC SQL.

## Validação remota recomendada

Depois de aplicar a migration no projeto correto, validar em transação descartável:

1. super admin chama todas as RPCs de leitura;
2. usuário autenticado comum recebe `42501` em todas elas;
3. criação e atualização de empresa/produto geram exatamente um `audit_logs` cada;
4. tentativa de auto-suspensão do super admin falha;
5. `page_limit=201` e período superior a 366 dias falham com `22023`.
