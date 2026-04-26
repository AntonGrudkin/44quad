WITH
params AS (
    SELECT
        CAST('2024-01-01' AS timestamp) AS start_time,
        CAST('2026-01-01' AS timestamp) AS end_time,
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 AS weth_token
),

total_transfers AS (
    SELECT
        date_trunc('hour', block_time) AS timestamp,
        SUM(amount) AS total_transfer_amount,
        SUM(amount_usd) AS total_transfer_usd,
        COUNT(*) AS transfer_count
    FROM tokens.transfers t
    CROSS JOIN params p
    WHERE t.blockchain = 'ethereum'
      AND t.block_time >= p.start_time
      AND t.block_time <  p.end_time
      AND t.contract_address = p.weth_token
    GROUP BY 1
),

cex_agg AS (
    SELECT
        date_trunc('hour', block_time) AS timestamp,
        SUM(CASE WHEN flow_type = 'Inflow'  THEN amount     ELSE 0 END) AS cex_in_amount,
        SUM(CASE WHEN flow_type = 'Outflow' THEN amount     ELSE 0 END) AS cex_out_amount,
        SUM(CASE WHEN flow_type = 'Inflow'  THEN amount_usd ELSE 0 END) AS cex_in_usd,
        SUM(CASE WHEN flow_type = 'Outflow' THEN amount_usd ELSE 0 END) AS cex_out_usd,
        COUNT(CASE WHEN flow_type = 'Inflow'  THEN 1 END) AS cex_in_count,
        COUNT(CASE WHEN flow_type = 'Outflow' THEN 1 END) AS cex_out_count
    FROM cex.flows f
    CROSS JOIN params p
    WHERE f.blockchain = 'ethereum'
      AND f.block_time >= p.start_time
      AND f.block_time <  p.end_time
      AND f.token_address = p.weth_token
    GROUP BY 1
),

dex_agg AS (
    SELECT
        date_trunc('hour', block_time) AS timestamp,

        SUM(CASE
                WHEN token_bought_address = p.weth_token THEN token_bought_amount
                ELSE 0
            END) AS dex_buy_amount,

        SUM(CASE
                WHEN token_sold_address = p.weth_token THEN token_sold_amount
                ELSE 0
            END) AS dex_sell_amount,

        COUNT(*) AS dex_trade_count
    FROM dex.trades d
    CROSS JOIN params p
    WHERE d.blockchain = 'ethereum'
      AND d.block_time >= p.start_time
      AND d.block_time <  p.end_time
      AND (
            d.token_bought_address = p.weth_token
         OR d.token_sold_address   = p.weth_token
      )
    GROUP BY 1
),

timeline AS (
    SELECT timestamp FROM total_transfers
    UNION
    SELECT timestamp FROM cex_agg
    UNION
    SELECT timestamp FROM dex_agg
)

SELECT
    tl.timestamp,

    COALESCE(tt.total_transfer_amount, 0) AS total_transfer_amount,
    COALESCE(tt.total_transfer_usd, 0)    AS total_transfer_usd,
    COALESCE(tt.transfer_count, 0)        AS transfer_count,

    COALESCE(c.cex_in_amount, 0)  AS cex_in_amount,
    COALESCE(c.cex_out_amount, 0) AS cex_out_amount,
    COALESCE(c.cex_in_usd, 0)     AS cex_in_usd,
    COALESCE(c.cex_out_usd, 0)    AS cex_out_usd,
    COALESCE(c.cex_in_count, 0)   AS cex_in_count,
    COALESCE(c.cex_out_count, 0)  AS cex_out_count,

    
    CASE
        WHEN COALESCE(c.cex_in_count, 0) + COALESCE(c.cex_out_count, 0) > 0
        THEN COALESCE(c.cex_in_count, 0) /
             (COALESCE(c.cex_in_count, 0) + COALESCE(c.cex_out_count, 0))
        ELSE NULL
    END AS air_count_proxy,

    COALESCE(d.dex_buy_amount, 0)  AS dex_buy_amount,
    COALESCE(d.dex_sell_amount, 0) AS dex_sell_amount,
    COALESCE(d.dex_trade_count, 0) AS dex_trade_count,

    COALESCE(d.dex_buy_amount, 0) - COALESCE(d.dex_sell_amount, 0) AS dex_net_amount,

    COALESCE(tt.total_transfer_usd, 0)
      - (COALESCE(c.cex_in_usd, 0) + COALESCE(c.cex_out_usd, 0)) AS p2p_transfer_usd_proxy,

    CASE
        WHEN COALESCE(tt.total_transfer_usd, 0) > 0
        THEN (
            COALESCE(tt.total_transfer_usd, 0)
            - (COALESCE(c.cex_in_usd, 0) + COALESCE(c.cex_out_usd, 0))
        ) / COALESCE(tt.total_transfer_usd, 0)
        ELSE NULL
    END AS p2p_dominance_proxy

FROM timeline tl
LEFT JOIN total_transfers tt ON tl.timestamp = tt.timestamp
LEFT JOIN cex_agg c          ON tl.timestamp = c.timestamp
LEFT JOIN dex_agg d          ON tl.timestamp = d.timestamp
ORDER BY tl.timestamp