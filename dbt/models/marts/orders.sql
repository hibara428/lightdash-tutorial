with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

order_item_details as (
    select
        oi.order_id,
        oi.sale_price,
        p.category
    from order_items oi
    left join products p
        on oi.product_id = p.product_id
),

order_aggregates as (
    select
        order_id,
        count(*)                                        as item_count,
        sum(sale_price)                                 as total_amount,
        approx_top_count(category, 1)[offset(0)].value as top_category
    from order_item_details
    group by 1
),

final as (
    select
        o.order_id,
        o.user_id,
        o.status,
        o.ordered_at,
        o.shipped_at,
        o.delivered_at,
        o.returned_at,
        coalesce(oa.item_count, 0)      as item_count,
        coalesce(oa.total_amount, 0.0)  as total_amount,
        oa.top_category
    from orders o
    left join order_aggregates oa
        on o.order_id = oa.order_id
)

select * from final
