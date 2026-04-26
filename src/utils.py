import pandas as pd
import numpy as np

def get_target(
    price: pd.Series,
    halflife: float
):  
    alpha = 1 - np.exp(-np.log(2) / halflife) if halflife > 0 else 1.
    return np.log(price.shift(-1).iloc[::-1].ewm(alpha=alpha).mean().iloc[::-1] / price).rename("target")