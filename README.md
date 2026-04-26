# 44quad Test Assignment

## Installation and Launching
```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export DUNE_API_KEY="[Dune API key]"
python download-binance.py
python download-dune.py
```

## Introduction
On micro-level, on-chain activity usually tends to follow CEX price discovery process due to higher latencies and other infrastructural factors. Most of micro-level on-chain signals derived from immediate execution flow are arbitraged away almost instantly. However, while arbitrage activity operates on short timeframes, inventory and capital allocation operate on longer ones.

Thus, alpha signals from on-chain data should focus on slower processes, where information may not yet be fully reflected in price.

## Target and Evaluation Methodology
We define the target as a forward exponentially smoothed return of the asset price:
$$
T_\lambda(P)_t = \ln\left(\frac{\text{EMA}^+_\lambda(P_{t+1})}{P_t}\right)
$$
where we denote by $\text{EMA}^+_\lambda$ forward exponential smoothing with a half-life period $\lambda$, i.e. each further point is weighted with an exponentially decaying coefficient depending on the forward time interval. It is also important to mention, that we do not encounter point $P_t$ in that EMA – we will get back to it a bit further.

The motivation for picking such signal is simple: raw returns are dominated by noise at the sampling frequency. By applying exponential smoothing forward in time, we approximate the low-frequency component of future price evolution. 

We focus on signals that exhibit directional predictive power, evaluated through their correlation with forward-looking targets across multiple half-life scales.

It is worth mentioning, what specific kind of behavior we are looking for here. We will consider several classes of economically motivated signals. However, it is crucial to determine whether economically motivated hypothesis has a predictive power – so, formally speaking, we need to distinguish descriptive and predictive signals. This is what we will try to achieve, exploring the correlation between the signal and a family of forward-looking targets parameterized by EMA half-life.

If the signal contains genuine predictive information at some time scale, we expect the correlation curve to exhibit a maximum at a non-trivial half-life (i.e. $\lambda > 0$). In contrast, if the signal primarily captures contemporaneous market dynamics, the correlation is expected to be strongest at the shortest horizons and decay as the target becomes smoother and more forward-looking.

To confirm that, we also compare the signal with immediate price returns. A strong relationship between signal and local returns, combined with a monotonic decay of signal-target correlation across half-lives, indicates that the feature is mainly descriptive: it reflects current trading pressure rather than providing standalone predictive information.

More formally, note that
$$
T_0(P)_t = \ln\left(\frac{P_{t+1}}{P_t}\right) = \Delta \ln P_{t+1}.
$$
which is simply a forward return. So, if we observe a low correlation with $T_0(P)$, we then check the correlation of the signal and $\Delta P_t = \ln(P_t / P_{t-1})$. If we see the strong correlation there, then we are concluding that the signal is only explaining the past price dynamics (i.e. both signal and price returns are explained by some underlying process). 

It is also important to mention, that at large half-lives, the target becomes highly autocorrelated and dominated by low-frequency trends, reducing the effective sample size and making correlations less informative as indicators of predictive power. Since our focus is on mid-frequency trading strategies, we restrict attention to target half-lives in the range of 0–1 week. Within this interval, we expect predictive signals to exhibit a clear extremum in correlation, indicating alignment with forward price dynamics at relevant trading horizons. 

This framework allows us to systematically filter signals by distinguishing between reactive microstructure effects and genuinely forward-looking components.

## Signals

We evaluate several classes of signals derived from on-chain and cross-venue activity, moving from fast, reactive features to slower capital allocation metrics. Each notebook follows a consistent framework: construct an economically motivated signal, analyze its behavior across time scales, and determine whether it reflects predictive structure or merely descriptive market dynamics.

---

### DEX Trade Flow Imbalance  
*See `1_trade_flow_imbalance.ipynb`*

We begin with a classic microstructure feature: trade flow imbalance on Uniswap V3, defined as the normalized difference between buy and sell volume.

The intuition is straightforward — persistent imbalance may indicate directional demand pressure. However, empirical analysis shows that the signal is strongly coupled to contemporaneous price movements and exhibits no stable alignment with forward-looking targets across time scales.

As a result, trade flow imbalance is best interpreted as a **reactive feature capturing immediate market pressure**, rather than a source of predictive information.

---

### Out-of-Range Liquidity Signals  
*See `2_out_of_range_mints.ipynb`*

We then shift from trades to liquidity allocation, analyzing out-of-range mints where LPs deploy capital outside the current price.

This class of signals is motivated by the idea that liquidity placement reflects **deliberate positioning decisions**, potentially encoding expectations about future price regions.

We construct two features:
- a **volume imbalance** between liquidity placed above and below the current price,
- a **price consensus** signal capturing the spatial distribution of liquidity.

Compared to trade flow, these signals exhibit weaker coupling to immediate returns and capture slower structural dynamics. However, within the tested horizon, they do not demonstrate stable predictive behavior.

Overall, out-of-range mint activity appears to reflect **liquidity structure rather than directional forecasting**, and may require longer horizons or additional conditioning to become informative.

---

### CEX Flow Imbalance  
*See `3_cex_flows.ipynb`*

Finally, we consider cross-venue capital flows, focusing on transfers to and from centralized exchanges.

These flows proxy changes in available trading supply, and therefore represent slower, macro-level allocation decisions rather than local execution dynamics.

Empirically, this signal differs from purely on-chain features: it exhibits a clear time-scale-dependent structure and weaker dependence on contemporaneous returns. This behavior is consistent with the presence of a forward-looking component at intermediate horizons.

While further validation is required, CEX flow imbalance emerges as the most promising candidate among the tested signals, suggesting that cross-venue capital movement may carry predictive information not captured by DEX microstructure alone.


## Discussion

Across the evaluated signals, we observe a clear distinction between reactive microstructure features and slower structural dynamics. Trade flow imbalance is strongly coupled to contemporaneous price movements and does not provide predictive information. Out-of-range liquidity signals capture structural aspects of capital allocation, but do not exhibit stable predictive behavior within the tested horizon. In contrast, CEX flow imbalance demonstrates time-scale-dependent structure consistent with the presence of a forward-looking component.

These results highlight the importance of aligning signal construction with the underlying economic process and its natural time scale. Signals derived from immediate execution tend to reflect price impact, while signals related to capital movement and inventory shifts may contain slower information not immediately incorporated into price.

Several directions for further work follow naturally:

- **Out-of-sample validation**: evaluate the stability of observed relationships across time and market regimes.
- **Temporal alignment**: refine lag structure between signals and targets, especially for cross-venue flows.
- **Feature conditioning**: isolate higher-conviction events (e.g. large mints, extreme flows) to reduce noise.
- **Cross-signal combinations**: combine microstructure and capital flow signals to capture both local and structural dynamics.
- **Extended horizons**: evaluate slower signals within a dedicated low-frequency framework.

Overall, the presented framework provides a systematic approach to filtering signals by distinguishing between descriptive and predictive behavior, and identifying candidates for further investigation.