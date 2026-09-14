"""
Gera dados sintéticos simulando um produto recorrente semanal (ex: assinatura,
serviço financeiro recorrente) para praticar análise de churn e retenção em SQL.

Estrutura:
- customers: cadastro dos clientes
- weekly_activity: status do cliente a cada semana (active / churned / paused)
"""

import sqlite3
import random
from datetime import date, timedelta

random.seed(42)

DB_PATH = "churn_retention.db"
N_WEEKS = 26
START_DATE = date(2025, 1, 6)  # segunda-feira
N_CUSTOMERS = 600

CITIES = ["São Paulo", "Rio de Janeiro", "Belo Horizonte", "Curitiba", "Salvador", "Recife"]
PLANS = ["basic", "standard", "premium"]
CHANNELS = ["organic", "paid_social", "referral", "email"]

# risco de churn base por plano (premium retém melhor, basic tem mais rotatividade)
PLAN_CHURN_RISK = {"basic": 0.10, "standard": 0.06, "premium": 0.03}
PLAN_PRICE = {"basic": 29.90, "standard": 59.90, "premium": 99.90}


def week_dates(n):
    return [START_DATE + timedelta(weeks=i) for i in range(n)]


def generate_customers(n):
    customers = []
    for cid in range(1, n + 1):
        # espalha as datas de cadastro ao longo das primeiras 20 semanas
        signup_week = random.randint(0, N_WEEKS - 6)
        signup_date = START_DATE + timedelta(weeks=signup_week)
        plan = random.choices(PLANS, weights=[0.5, 0.35, 0.15])[0]
        customers.append({
            "customer_id": cid,
            "signup_date": signup_date.isoformat(),
            "signup_week": signup_week,
            "city": random.choice(CITIES),
            "plan": plan,
            "acquisition_channel": random.choices(
                CHANNELS, weights=[0.35, 0.30, 0.20, 0.15]
            )[0],
        })
    return customers


def generate_weekly_activity(customers):
    weeks = week_dates(N_WEEKS)
    rows = []
    for c in customers:
        status = "active"
        churn_week = None
        for w_idx, w_date in enumerate(weeks):
            if w_idx < c["signup_week"]:
                continue  # cliente ainda não existia
            weeks_since_signup = w_idx - c["signup_week"]

            if status == "active":
                base_risk = PLAN_CHURN_RISK[c["plan"]]
                # risco maior nas primeiras semanas (típico de churn inicial)
                early_multiplier = 2.5 if weeks_since_signup <= 2 else 1.0
                risk = base_risk * early_multiplier
                if random.random() < risk:
                    status = "churned"
                    churn_week = w_idx

            amount = PLAN_PRICE[c["plan"]] if status == "active" else 0.0
            rows.append({
                "customer_id": c["customer_id"],
                "week_start_date": w_date.isoformat(),
                "week_index": w_idx,
                "status": status,
                "amount_paid": round(amount, 2),
            })

            if status == "churned":
                # depois do churn, só registra mais 1 semana como churned e para
                if churn_week is not None and w_idx > churn_week:
                    break
    return rows


def main():
    customers = generate_customers(N_CUSTOMERS)
    activity = generate_weekly_activity(customers)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    with open("schema.sql", "r", encoding="utf-8") as f:
        cur.executescript(f.read())

    cur.executemany(
        """INSERT INTO customers
           (customer_id, signup_date, city, plan, acquisition_channel)
           VALUES (:customer_id, :signup_date, :city, :plan, :acquisition_channel)""",
        customers,
    )

    cur.executemany(
        """INSERT INTO weekly_activity
           (customer_id, week_start_date, week_index, status, amount_paid)
           VALUES (:customer_id, :week_start_date, :week_index, :status, :amount_paid)""",
        activity,
    )

    conn.commit()
    conn.close()
    print(f"Gerados {len(customers)} clientes e {len(activity)} registros semanais em {DB_PATH}")


if __name__ == "__main__":
    main()
