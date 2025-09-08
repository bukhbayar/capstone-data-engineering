{{ config(
    materialized='table'
) }}


with dedup_customer as (
    -- This CTE is intended to deduplicate customer records based on customer_code
    SELECT
      c.*,
      RANK() OVER (PARTITION BY customer_code ORDER BY id_number DESC) as customer_rank
    FROM
        {{ source('raw', 'customers') }} c
),

raw_customers as (
    SELECT
        customer_code,
        first_name,
        last_name,
        id_number,
        date_of_birth,
        gender,
        email,
        phone_number,
        province,
        city,
        postal_code,
        income_bracket,
        employment_status,
        credit_score,
        primary_bank,
        primary_branch
    FROM
        dedup_customer
    WHERE
        customer_rank = 1
)

SELECT
    customer_code,
    first_name,
    last_name,
    id_number,
    date_of_birth,
    gender,
    email,
    phone_number,
    province,
    city,
    postal_code,
    income_bracket,
    employment_status,
    credit_score,
    primary_bank,
    primary_branch
FROM raw_customers