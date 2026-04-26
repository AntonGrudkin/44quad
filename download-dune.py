import pandas as pd
from dune_client.client import DuneClient

dune = DuneClient()

print('Downloading Uniswap imbalances...')
with open('queries/query_uni_imbal.sql', 'r') as f:
    result = dune.run_sql(f.read())
    df = pd.DataFrame(result.result.rows)
df.to_pickle('data/uniswap_flow_1m.pkl')

print('Downloading Uniswap mints...')
with open('queries/query_uni_mints.sql', 'r') as f:
    result = dune.run_sql(f.read())
    df = pd.DataFrame(result.result.rows)
df.to_pickle('data/eth_uniswap_mints_all.pkl')

print('Downloading CEX flows...')
with open('queries/query_cex.sql', 'r') as f:
    result = dune.run_sql(f.read())
    df = pd.DataFrame(result.result.rows)
df.to_pickle('data/cex.pkl')


