import Link from "next/link";
import type { Plan } from "@/lib/commercial/types";

const rows = [["company_profile","Cadastro da empresa"],["catalog","Cadastro de catálogo"],["products_limit","Quantidade de produtos"],["users_limit","Número de usuários"],["csv_import","Importação CSV/Excel"],["search_visibility","Aparecer nas buscas"],["radius_search","Buscar por raio"],["buyer_contacts","Receber contatos de compradores"],["opportunities","Receber oportunidades"],["eu_tenho",'Responder "EU TENHO"'],["analytics","Métricas de desempenho"],["commercial_page","Página comercial personalizada"],["search_highlight","Destaque nos resultados"],["support_level","Suporte"]] as const;
const sorted = (plans: Plan[]) => plans.filter(p => p.is_active).sort((a,b) => a.sort_order-b.sort_order);

export function featureText(plan: Plan, key: string): string {
  const feature = plan.plan_features.find(f => f.feature_key === key);
  if (feature && !feature.enabled) return "Não incluso";
  if (key === "products_limit" || key === "users_limit") {
    const value = feature ? feature.limit_value : key === "products_limit" ? plan.product_limit : plan.included_users;
    return value === null ? "Ilimitados" : value.toLocaleString("pt-BR");
  }
  if (!feature) return "Não informado";
  if (typeof feature.config_json?.label === "string" && feature.config_json.label.trim()) return feature.config_json.label;
  return feature.limit_value === null ? "Incluso" : `Até ${feature.limit_value.toLocaleString("pt-BR")}`;
}

function Action({ plan }: { plan: Plan }) {
  const href = plan.is_enterprise ? "/enterprise" : plan.is_free ? "/cadastro?plano=free" : `/cadastro?plano=${encodeURIComponent(plan.slug)}&tipo=fornecedor`;
  const label = plan.is_enterprise ? "Falar com nosso time" : plan.is_free ? "Continuar grátis" : plan.trial_available ? "Teste grátis por 30 dias" : "Escolher plano";
  return <Link href={href} className={`af-btn ${plan.is_featured ? "af-btn-primary" : "af-btn-secondary"}`}>{label}</Link>;
}

function PlanCard({ plan }: { plan: Plan }) {
  return <article className={`commercial-card af-card${plan.is_featured ? " is-featured" : ""}`}>
    {plan.is_featured && <span className="commercial-recommended">Recomendado</span>}
    <h3>{plan.name}</h3><p className="commercial-description">{plan.description}</p>
    <p className="commercial-price">{plan.is_enterprise ? "Sob consulta" : plan.price_monthly === null ? "Preço não informado" : new Intl.NumberFormat("pt-BR",{style:"currency",currency:"BRL"}).format(plan.price_monthly)}{!plan.is_enterprise && plan.price_monthly !== null && <small>/mês</small>}</p>
    <ul><li>Produtos: {featureText(plan,"products_limit")}</li><li>Usuários incluídos: {featureText(plan,"users_limit")}</li><li>Suporte: {featureText(plan,"support_level")}</li></ul><Action plan={plan} />
  </article>;
}

function Unavailable() {
  return <div className="commercial-unavailable" role="status"><h3>Planos temporariamente indisponíveis</h3><p>Não foi possível carregar a configuração comercial. Tente novamente mais tarde. Nenhum preço ou limite está sendo estimado.</p></div>;
}

export function HomePlans({ plans }: { plans: Plan[] }) {
  const paid = sorted(plans).filter(p => !p.is_free && !p.is_enterprise);
  return <section id="planos" className="commercial-section"><div className="container"><div className="commercial-heading"><span className="eyebrow">30 dias grátis</span><h2>Planos para impulsionar <span>seu negócio.</span></h2><p>Escolha o plano ideal para o tamanho da sua operação e experimente o AcheFood por 30 dias.</p></div>
    {paid.length ? <div className="commercial-grid">{paid.map(p => <PlanCard key={p.id} plan={p} />)}</div> : <Unavailable />}
    <div className="commercial-links"><Link href="/planos">Compare todos os recursos →</Link><p>Prefere continuar gratuitamente? <Link href="/planos#free">Conheça o plano grátis.</Link></p></div><p className="commercial-fineprint">Trial disponível para novos usuários elegíveis. Ao final, escolha continuar grátis ou contratar um plano. Sem cobrança automática sem sua autorização.</p>
  </div></section>;
}

export function PlansContent({ plans }: { plans: Plan[] }) {
  const visible = sorted(plans).filter(p => !p.is_enterprise);
  const enterprise = sorted(plans).find(p => p.is_enterprise);
  return <><section className="commercial-hero container"><span className="eyebrow">30 dias grátis</span><h1>Escolha o plano ideal <span>para sua empresa.</span></h1><p>Comece com 30 dias grátis.<br />Depois escolha como deseja continuar.</p><a href="#comparacao" className="af-btn af-btn-primary">Comparar recursos →</a></section>
    <section className="container" aria-label="Planos disponíveis">{visible.length ? <div className="commercial-grid commercial-grid-full">{visible.map(p => <div id={p.is_free ? "free" : undefined} key={p.id}><PlanCard plan={p} /></div>)}</div> : <Unavailable />}</section>
    {visible.length > 0 && <section id="comparacao" className="commercial-section container"><div className="commercial-heading"><h2>Compare os recursos inclusos <span>em cada plano</span></h2><p>Recursos e limites refletem a configuração atual da plataforma.</p></div>
      <div className="commercial-table-wrap"><table className="commercial-table"><caption>Comparação dos planos AcheFood</caption><thead><tr><th scope="col">Recursos</th>{visible.map(p => <th scope="col" key={p.id}>{p.name}</th>)}</tr></thead><tbody>{rows.map(([key,label]) => <tr key={key}><th scope="row">{label}</th>{visible.map(p => <td key={p.id}>{featureText(p,key)}</td>)}</tr>)}</tbody></table></div>
      <div className="commercial-accordion">{visible.map(p => <details key={p.id}><summary>{p.name}<span>Ver recursos</span></summary><dl>{rows.map(([key,label]) => <div key={key}><dt>{label}</dt><dd>{featureText(p,key)}</dd></div>)}</dl><Action plan={p} /></details>)}</div>
    </section>}
    <section className="commercial-how commercial-section"><div className="container"><div className="commercial-heading"><h2>Como <span>funciona</span></h2></div><div className="commercial-how-grid">
      <article className="af-card"><h3>30 dias grátis</h3><p>Todos os novos usuários elegíveis podem experimentar o AcheFood durante 30 dias.</p><p>Ao final, escolha continuar gratuitamente ou contratar um dos planos disponíveis. O trial não é o plano Free.</p></article>
      <article className="af-card"><h3>Conta empresarial multiusuário</h3><p>Crie diferentes usuários para sua equipe com níveis de acesso, conforme os limites do plano contratado.</p></article>
      <article className="af-card"><h3>Pagamento seguro</h3><p>A contratação paga depende de um gateway habilitado pela plataforma e da sua autorização. Nenhuma cobrança é feita apenas por iniciar ou encerrar o trial.</p></article>
      <article className="af-card"><h3>Precisa de mais?</h3><p>Usuários adicionais, produtos e recursos sob medida.</p><Link href="/enterprise">Fale com nosso time comercial →</Link></article>
    </div></div></section>
    {enterprise && <section className="container commercial-enterprise"><div><span>Precisa de mais?</span><h2>Conheça o AcheFood {enterprise.name}.</h2><p>{enterprise.description}</p><strong>Sob consulta</strong></div><Link className="af-btn af-btn-primary" href="/enterprise">Falar com nosso time →</Link></section>}
    <p className="container commercial-fineprint commercial-bottom-note">Ao mudar de plano, seus dados não serão apagados. Novas operações poderão depender dos limites do plano escolhido.</p>
  </>;
}
