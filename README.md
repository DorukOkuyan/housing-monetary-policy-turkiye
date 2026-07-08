# Monetary Tightening, Household Leverage, and Housing Markets in a High-Inflation Economy

This repository contains replication code and non-proprietary processed data for the paper:

**Monetary Tightening, Household Leverage, and Housing Markets in a High-Inflation Economy**

## Author

Doruk Okuyan

## Data

The repository includes processed non-proprietary data used in the analysis.

The public datasets used in the paper are obtained from:

- Central Bank of the Republic of Türkiye
- Turkish Statistical Institute
- Banking Regulation and Supervision Agency

Bloomberg analyst forecast data are proprietary and are not included in this repository. Users with access to Bloomberg analyst forecast data should place the relevant proprietary file in a local `data_private/` folder. This folder is excluded from the repository.

## Variable dictionary

| Variable | Description |
|---|---|
| date | Monthly date. |
| mp_surp | Monetary policy surprise, defined as the policy rate decision minus the Bloomberg median analyst forecast. |
| pol_rate | One-week repo policy rate. |
| pol_rate_exp | Median expected policy rate before the MPC meeting. |
| cpi | Consumer price index. |
| cpi_sa_fd | Change in seasonally adjusted CPI inflation. |
| cpi_exp_12mth_fd | Change in 12-month-ahead inflation expectations. |
| cpi_exp_24mth_fd | Change in 24-month-ahead inflation expectations. |
| gdp_gwt_exp_12mth_fd | Change in 12-month-ahead GDP growth expectations. |
| ipi_sa_gwt_fd | Change in seasonally and calendar adjusted industrial production growth. |
| cap_utl_sa_fd | Change in seasonally adjusted capacity utilization. |
| unemp_sa_fd | Change in seasonally adjusted unemployment rate. |
| usd_exp_12mth_pct_chg | Percent change in 12-month-ahead USD/TRY expectations. |
| exc_rate_pct_chg | Percent change in the USD/TRY exchange rate before the MPC meeting (3-day average). |
| stck_prc_pct_chg | Percent change in stock prices before the MPC meeting (3-day average). |
| unemp_sa | Seasonally adjusted unemployment rate. |
| bist_mth_gwt_rate | Monthly growth rate of the BIST stock price index. |
| usdtry_mth_gwt_rate | Monthly growth rate of the USD/TRY exchange rate. |
| gold_mth_gwt_rate | Monthly growth rate of ounce gold prices. |
| house_p_index | National residential property price index. |
| new_tenant_rent_index | National new tenant rent index. |
| prob_buying_house_in1year_sa | Seasonally adjusted probability of buying or building a house in the next 12 months. |
| hh_leverage | Household leverage, defined as total household liabilities divided by total household assets. |
| tr10_housing ... trc_housing | Regional residential property price indices. |
| tr10_rent ... trc_rent | Regional new tenant rent indices. |
| TR10_housing_debt_ratio ... TRC_housing_debt_ratio | Regional housing credit intensity, defined as housing loans divided by total individual credit. |

## Code

The Stata code is stored in the `code/` folder.

Main script:

- `code/local_projections.do`

The code should be run from the root folder of the repository.

Required Stata packages:

- `estout`
- `xtscc`
- `reghdfe`
- `ftools`

## Repository structure

```text
data/
    data.xlsx

code/
    local_projections.do
