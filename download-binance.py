import time
import requests
import pandas as pd
from pathlib import Path

BASE_URL = "https://fapi.binance.com/fapi/v1/klines"

def get_klines(
    symbol: str,
    interval: str = "1h",
    start_time: int = None,
    end_time: int = None,
    limit: int = 1500,
    sleep: float = 0.2,
) -> pd.DataFrame:
    """
    Download Binance USD-M Futures klines.

    Parameters
    ----------
    symbol : str
        e.g. "ETHUSDT"
    interval : str
        e.g. "1m", "5m", "1h", "1d"
    start_time : int
        in milliseconds
    end_time : int
        in milliseconds
    limit : int
        max 1500 per request
    sleep : float
        delay between requests

    Returns
    -------
    pd.DataFrame
    """

    all_data = []
    current_start = start_time

    while True:
        params = {
            "symbol": symbol,
            "interval": interval,
            "limit": limit,
        }

        if current_start is not None:
            params["startTime"] = current_start
        if end_time is not None:
            params["endTime"] = end_time

        for attempt in range(3):
            try:
                response = requests.get(BASE_URL, params=params, timeout=10)
                response.raise_for_status()
                data = response.json()
                break
            except Exception as e:
                if attempt == 2:
                    raise
                time.sleep(1)

        if not data:
            break

        all_data.extend(data)

        last_open_time = data[-1][0]
        if end_time and last_open_time >= end_time:
            break

        current_start = last_open_time + 1

        time.sleep(sleep)

        if len(data) < limit:
            break

    columns = [
        "open_time",
        "open",
        "high",
        "low",
        "close",
        "volume",
        "close_time",
        "quote_volume",
        "n_trades",
        "taker_buy_base",
        "taker_buy_quote",
        "ignore",
    ]

    df = pd.DataFrame(all_data, columns=columns)

    numeric_cols = [
        "open", "high", "low", "close", "volume",
        "quote_volume", "taker_buy_base", "taker_buy_quote"
    ]

    df[numeric_cols] = df[numeric_cols].astype(float)
    df["n_trades"] = df["n_trades"].astype(int)

    df["open_time"] = pd.to_datetime(df["open_time"], unit="ms", utc=True)
    df["close_time"] = pd.to_datetime(df["close_time"], unit="ms", utc=True)

    df = df.sort_values("open_time").drop_duplicates("open_time")

    return df.reset_index(drop=True)

if __name__ == "__main__":
    Path('data').mkdir(exist_ok=True)
    print('Downloading 1m klines...')
    df = get_klines(
        symbol="ETHUSDT",
        interval="1m",
        start_time=int(pd.Timestamp("2022-01-01").timestamp() * 1000),
        end_time=int(pd.Timestamp("2026-02-01").timestamp() * 1000),
    )
    print(f'Downloaded {len(df)} rows')
    df.to_pickle("data/ethusdt_1m.pkl")
    
    print('Downloading 1h klines...')
    df = get_klines(
        symbol="ETHUSDT",
        interval="1h",
        start_time=int(pd.Timestamp("2022-01-01").timestamp() * 1000),
        end_time=int(pd.Timestamp("2026-02-01").timestamp() * 1000),
    )
    print(f'Downloaded {len(df)} rows')
    df.to_pickle("data/ethusdt_1h.pkl")