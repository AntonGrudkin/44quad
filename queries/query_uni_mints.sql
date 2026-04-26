with stable_tokens as (
    select *
    from (
        values
            (0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48, 'USDC'),
            (0xdac17f958d2ee523a2206206994597c13d831ec7, 'USDT'),
            (0x6b175474e89094c44da98b954eedeac495271d0f, 'DAI')
    ) as t(token_address, symbol)
),

pools as (
    select
        p.pool,
        p.token0,
        p.token1,
        p.fee,
        erc0.symbol as token0_symbol,
        erc0.decimals as token0_decimals,
        erc1.symbol as token1_symbol,
        erc1.decimals as token1_decimals,
        case when s0.token_address is not null then 1 else 0 end as token0_is_stable,
        case when s1.token_address is not null then 1 else 0 end as token1_is_stable
    from uniswap_v3_ethereum.factory_evt_poolcreated p
    left join tokens.erc20 erc0
        on p.token0 = erc0.contract_address
       and erc0.blockchain = 'ethereum'
    left join tokens.erc20 erc1
        on p.token1 = erc1.contract_address
       and erc1.blockchain = 'ethereum'
    left join stable_tokens s0
        on p.token0 = s0.token_address
    left join stable_tokens s1
        on p.token1 = s1.token_address
),

target_pools as (
    select
        *,
        case when token0_is_stable = 1 then false else true end as zero_to_one
    from pools
    where token0_is_stable + token1_is_stable = 1
      and (
            token0 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
         or token1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
      )
),

mints as (
    select
        m.evt_block_time as block_time,
        m.contract_address as pool,
        p.fee,
        p.zero_to_one,

        case 
            when p.zero_to_one then m.tickLower
            else -m.tickUpper
        end as tickLower,  
        case 
            when p.zero_to_one then m.tickUpper
            else -m.tickLower
        end as tickUpper,

        case 
            when p.zero_to_one then p.token0_decimals - p.token1_decimals 
            else p.token1_decimals - p.token0_decimals 
        end as decimals_diff,

        case
            when p.zero_to_one then cast(m.amount0 as double) / pow(10, p.token0_decimals)
            else cast(m.amount1 as double) / pow(10, p.token1_decimals)
        end as token_amount,

        case
            when p.zero_to_one then cast(m.amount1 as double) / pow(10, p.token1_decimals)
            else cast(m.amount0 as double) / pow(10, p.token0_decimals)
        end as stable_amount

    from uniswap_v3_ethereum.Pair_evt_Mint m
    inner join target_pools p
        on m.contract_address = p.pool
    where m.evt_block_time > timestamp '2022-01-01'
      and (
            (coalesce(m.amount0, 0) = 0 and coalesce(m.amount1, 0) > 0)
         or (coalesce(m.amount1, 0) = 0 and coalesce(m.amount0, 0) > 0)
      )
)

select *
from mints
order by block_time