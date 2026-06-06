with source as (
    select * from {{ source('thelook_ecommerce', 'order_items') }}
),

renamed as (
    select
        id          as item_id,
        order_id,
        user_id,
        product_id,
        status,
        sale_price,
        created_at  as ordered_at
    from source
)

select * from renamed
