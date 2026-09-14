-- Schema: projeto de análise de churn e retenção
-- Simula um produto recorrente semanal (ex: assinatura ou serviço financeiro)

DROP TABLE IF EXISTS weekly_activity;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id         INTEGER PRIMARY KEY,
    signup_date          TEXT NOT NULL,
    city                  TEXT NOT NULL,
    plan                  TEXT NOT NULL CHECK (plan IN ('basic', 'standard', 'premium')),
    acquisition_channel   TEXT NOT NULL
);

CREATE TABLE weekly_activity (
    customer_id      INTEGER NOT NULL,
    week_start_date   TEXT NOT NULL,
    week_index        INTEGER NOT NULL,
    status             TEXT NOT NULL CHECK (status IN ('active', 'churned')),
    amount_paid        REAL NOT NULL,
    PRIMARY KEY (customer_id, week_index),
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

CREATE INDEX idx_weekly_activity_customer ON weekly_activity (customer_id);
CREATE INDEX idx_weekly_activity_week ON weekly_activity (week_index);
