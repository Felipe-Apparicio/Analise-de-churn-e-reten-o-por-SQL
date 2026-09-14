-- =====================================================================
-- ANÁLISE DE CHURN E RETENÇÃO
-- Produto recorrente semanal (ex: assinatura / serviço financeiro)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Qual é a taxa de churn geral da base hoje?
-- (clientes churned / total de clientes que já passaram pela base)
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT customer_id)                                        AS total_clientes,
    COUNT(DISTINCT CASE WHEN status = 'churned' THEN customer_id END)  AS clientes_churned,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN status = 'churned' THEN customer_id END)
        / COUNT(DISTINCT customer_id), 2
    ) AS taxa_churn_pct
FROM (
    -- pega o status mais recente de cada cliente
    SELECT customer_id, status,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY week_index DESC) AS rn
    FROM weekly_activity
) ultimo_status
WHERE rn = 1;


-- ---------------------------------------------------------------------
-- 2) Como evolui a taxa de churn semanal ao longo do tempo?
-- (quantos clientes ativos viraram churn em cada semana)
-- ---------------------------------------------------------------------
WITH status_por_semana AS (
    SELECT customer_id, week_index, status,
           LAG(status) OVER (PARTITION BY customer_id ORDER BY week_index) AS status_semana_anterior
    FROM weekly_activity
)
SELECT
    week_index,
    COUNT(CASE WHEN status = 'churned' AND status_semana_anterior = 'active' THEN 1 END) AS novos_churns,
    COUNT(CASE WHEN status = 'active' THEN 1 END)                                        AS ativos_na_semana
FROM status_por_semana
GROUP BY week_index
ORDER BY week_index;


-- ---------------------------------------------------------------------
-- 3) Curva de retenção por coorte de cadastro (cohort analysis)
-- % de clientes ainda ativos N semanas após o cadastro, por mês de entrada
-- ---------------------------------------------------------------------
WITH cohort AS (
    SELECT
        c.customer_id,
        strftime('%Y-%m', c.signup_date) AS cohort_month,
        wa.week_index - (
            SELECT MIN(week_index) FROM weekly_activity WHERE customer_id = c.customer_id
        ) AS semanas_desde_cadastro,
        wa.status
    FROM customers c
    JOIN weekly_activity wa ON wa.customer_id = c.customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS clientes_na_cohort
    FROM cohort
    WHERE semanas_desde_cadastro = 0
    GROUP BY cohort_month
)
SELECT
    co.cohort_month,
    co.semanas_desde_cadastro,
    COUNT(DISTINCT CASE WHEN co.status = 'active' THEN co.customer_id END) AS clientes_ativos,
    cs.clientes_na_cohort,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN co.status = 'active' THEN co.customer_id END)
        / cs.clientes_na_cohort, 1
    ) AS retencao_pct
FROM cohort co
JOIN cohort_size cs ON cs.cohort_month = co.cohort_month
GROUP BY co.cohort_month, co.semanas_desde_cadastro
ORDER BY co.cohort_month, co.semanas_desde_cadastro;


-- ---------------------------------------------------------------------
-- 4) Churn é maior em algum plano específico?
-- ---------------------------------------------------------------------
WITH ultimo_status AS (
    SELECT customer_id, status,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY week_index DESC) AS rn
    FROM weekly_activity
)
SELECT
    c.plan,
    COUNT(DISTINCT c.customer_id) AS total_clientes,
    COUNT(DISTINCT CASE WHEN us.status = 'churned' THEN c.customer_id END) AS clientes_churned,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN us.status = 'churned' THEN c.customer_id END)
        / COUNT(DISTINCT c.customer_id), 2
    ) AS taxa_churn_pct
FROM customers c
JOIN ultimo_status us ON us.customer_id = c.customer_id AND us.rn = 1
GROUP BY c.plan
ORDER BY taxa_churn_pct DESC;


-- ---------------------------------------------------------------------
-- 5) E por canal de aquisição? Algum canal traz clientes que ficam menos tempo?
-- ---------------------------------------------------------------------
WITH tempo_de_vida AS (
    SELECT
        customer_id,
        MAX(week_index) - MIN(week_index) + 1 AS semanas_ativo
    FROM weekly_activity
    GROUP BY customer_id
)
SELECT
    c.acquisition_channel,
    COUNT(*)                              AS total_clientes,
    ROUND(AVG(tv.semanas_ativo), 1)        AS media_semanas_ativo
FROM customers c
JOIN tempo_de_vida tv ON tv.customer_id = c.customer_id
GROUP BY c.acquisition_channel
ORDER BY media_semanas_ativo DESC;


-- ---------------------------------------------------------------------
-- 6) LTV (Lifetime Value) médio por plano
-- soma do que cada cliente pagou ao longo de toda sua vida na base
-- ---------------------------------------------------------------------
WITH ltv_cliente AS (
    SELECT customer_id, SUM(amount_paid) AS ltv
    FROM weekly_activity
    GROUP BY customer_id
)
SELECT
    c.plan,
    ROUND(AVG(l.ltv), 2)  AS ltv_medio,
    ROUND(MIN(l.ltv), 2)  AS ltv_minimo,
    ROUND(MAX(l.ltv), 2)  AS ltv_maximo
FROM customers c
JOIN ltv_cliente l ON l.customer_id = c.customer_id
GROUP BY c.plan
ORDER BY ltv_medio DESC;


-- ---------------------------------------------------------------------
-- 7) Ranking de cidades por taxa de churn (para priorizar ações locais)
-- ---------------------------------------------------------------------
WITH ultimo_status AS (
    SELECT customer_id, status,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY week_index DESC) AS rn
    FROM weekly_activity
)
SELECT
    c.city,
    COUNT(DISTINCT c.customer_id) AS total_clientes,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN us.status = 'churned' THEN c.customer_id END)
        / COUNT(DISTINCT c.customer_id), 2
    ) AS taxa_churn_pct,
    RANK() OVER (
        ORDER BY 100.0 * COUNT(DISTINCT CASE WHEN us.status = 'churned' THEN c.customer_id END)
        / COUNT(DISTINCT c.customer_id) DESC
    ) AS ranking_churn
FROM customers c
JOIN ultimo_status us ON us.customer_id = c.customer_id AND us.rn = 1
GROUP BY c.city
ORDER BY taxa_churn_pct DESC;


-- ---------------------------------------------------------------------
-- 8) Churn "precoce": qual % dos clientes cancela nas 2 primeiras semanas?
-- (sinal de problema de onboarding, não de insatisfação de longo prazo)
-- ---------------------------------------------------------------------
WITH tempo_de_vida AS (
    SELECT
        customer_id,
        MAX(week_index) - MIN(week_index) + 1 AS semanas_ativo,
        MAX(CASE WHEN status = 'churned' THEN 1 ELSE 0 END) AS churnou
    FROM weekly_activity
    GROUP BY customer_id
)
SELECT
    COUNT(*)                                                              AS total_churns,
    SUM(CASE WHEN semanas_ativo <= 2 THEN 1 ELSE 0 END)                   AS churns_precoces,
    ROUND(
        100.0 * SUM(CASE WHEN semanas_ativo <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS pct_churn_precoce
FROM tempo_de_vida
WHERE churnou = 1;
