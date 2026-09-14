# Análise de Churn e Retenção — Produto Recorrente Semanal

Projeto de portfólio em SQL simulando a análise de uma base de clientes de um
produto com cobrança recorrente semanal (ex: assinatura, serviço financeiro).
O cenário é inspirado em problemas reais de análise de retenção que times de
CRM e Dados enfrentam no dia a dia.

## Contexto do negócio

Uma empresa fictícia tem ~600 clientes distribuídos em 3 planos (basic,
standard, premium), captados por 4 canais de aquisição diferentes, em 6
cidades. Cada cliente é cobrado semanalmente enquanto estiver ativo. O
objetivo é entender **por que e quando os clientes cancelam**, para orientar
ações de retenção.

## Estrutura dos dados

- `customers`: cadastro de cada cliente (data de entrada, cidade, plano, canal de aquisição)
- `weekly_activity`: status do cliente (`active`/`churned`) e valor pago a cada semana

O dataset é **sintético**, gerado em `generate_data.py`, com regras de risco
de churn diferentes por plano (planos mais baratos têm mais rotatividade) e
um efeito de "churn precoce" (risco maior nas duas primeiras semanas —
padrão comum em produtos reais, ligado a onboarding).

## Como rodar

```bash
python3 generate_data.py   # gera churn_retention.db a partir de schema.sql
sqlite3 churn_retention.db < queries.sql   # ou rode cada query separadamente
```

## Perguntas de negócio respondidas (`queries.sql`)

| # | Pergunta | Técnica SQL usada |
|---|----------|--------------------|
| 1 | Qual a taxa de churn geral da base hoje? | Window function (`ROW_NUMBER`) para pegar o status mais recente |
| 2 | Como o churn evolui semana a semana? | `LAG()` para comparar status entre semanas |
| 3 | Qual a curva de retenção por coorte de entrada? | CTEs encadeadas + cohort analysis |
| 4 | O churn varia por plano? | JOIN + agregação condicional |
| 5 | Algum canal de aquisição traz clientes que ficam menos tempo? | Agregação com `MIN`/`MAX` de semana ativa |
| 6 | Qual o LTV médio por plano? | `SUM` agregado por cliente e depois por plano |
| 7 | Quais cidades têm maior churn? | `RANK()` sobre taxa de churn agregada |
| 8 | Que % do churn acontece nas 2 primeiras semanas? | Classificação de "churn precoce" via CASE |

## Principais conclusões (a partir dos dados sintéticos)

- O plano **basic** tem a maior taxa de churn entre os três planos — sinal de
  que clientes de entrada precisam de mais incentivo para migrar de plano ou
  de uma esteira de retenção dedicada.
- Uma parcela relevante dos cancelamentos acontece já nas duas primeiras
  semanas, o que aponta para **problema de onboarding** mais do que
  insatisfação de longo prazo — esses dois problemas pedem ações bem
  diferentes.
- A curva de retenção por coorte mostra que a maior queda acontece logo nas
  primeiras semanas após o cadastro, estabilizando depois — padrão clássico
  de "curva de churn em L".

## Próximos passos possíveis

- Conectar essas queries a um dashboard no Power BI para acompanhamento contínuo
- Adicionar uma tabela de eventos de suporte/atendimento para cruzar churn com qualidade de atendimento
- Testar a mesma análise com um dataset público real (ex: Olist ou Telco Customer Churn, no Kaggle)

## Arquivos

- `schema.sql` — definição das tabelas (DDL)
- `generate_data.py` — geração dos dados sintéticos
- `queries.sql` — as 8 queries de análise, comentadas
- `churn_retention.db` — banco SQLite já populado, pronto para explorar
