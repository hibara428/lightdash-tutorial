with users as (
    select * from {{ ref('stg_users') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

order_totals as (
    select
        oi.order_id,
        o.user_id,
        o.ordered_at,
        sum(oi.sale_price) as order_amount
    from order_items oi
    inner join orders o
        on oi.order_id = o.order_id
    where o.status not in ('Cancelled', 'Returned')
    group by 1, 2, 3
),

customer_orders as (
    select
        user_id,
        count(distinct order_id)    as number_of_orders,
        sum(order_amount)           as total_spent,
        min(ordered_at)             as first_order_date,
        max(ordered_at)             as latest_order_date
    from order_totals
    group by 1
),

final as (
    select
        u.user_id,
        u.first_name,
        u.last_name,
        u.email,
        u.age,
        u.gender,
        u.city,
        u.country,
        u.registered_at,
        coalesce(co.number_of_orders, 0)    as number_of_orders,
        coalesce(co.total_spent, 0.0)       as total_spent,
        co.first_order_date,
        co.latest_order_date
    from users u
    left join customer_orders co
        on u.user_id = co.user_id
)

select * from final
