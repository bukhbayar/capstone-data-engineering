{{ config(
    materialized='incremental',
    incremental_strategy='append',
    unique_key='customer_code',
    on_schema_change='sync_all_columns',
    alias='warehouse_customers'
) }}

WITH customers AS (
    SELECT
        customer_code,
        first_name,
        last_name,
        CONCAT(first_name, ' ', last_name) AS full_name,
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
        {{ ref('customers') }}
)

SELECT
    customer_code,
    first_name,
    last_name,
    full_name,
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
FROM customers c
