SELECT
    date_trunc('hour', block_time) AS ts_hour,
    sum(amount_usd) AS dex_volume_usd,
    count(*) AS n_swaps,
    sum(CASE WHEN token_bought_symbol = 'WETH' THEN amount_usd ELSE 0 END) AS weth_bought_usd,
    sum(CASE WHEN token_sold_symbol = 'WETH' THEN amount_usd ELSE 0 END) AS weth_sold_usd
FROM dex.trades
WHERE blockchain = 'ethereum'
  AND project = 'uniswap'
  AND block_time >= TIMESTAMP '2022-01-01'
  AND block_time <  TIMESTAMP '2026-01-01'
  AND (
        token_bought_symbol = 'WETH'
        OR token_sold_symbol = 'WETH'
      )
GROUP BY 1
ORDER BY 1