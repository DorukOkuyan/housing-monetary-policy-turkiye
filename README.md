# State-Dependent Monetary Transmission to Housing Markets: Evidence from Türkiye

This repository contains replication code and non-proprietary processed data for the paper:

**State-Dependent Monetary Transmission to Housing Markets: Evidence from Türkiye**

## Author

Doruk Okuyan

## Data

The repository includes processed non-proprietary data used in the analysis.

The public datasets used in the paper are obtained from:

- Central Bank of the Republic of Türkiye
- Turkish Statistical Institute
- Banking Regulation and Supervision Agency

Bloomberg analyst forecast data are proprietary and are not included in this repository. Therefore, the monetary policy surprise variable, `mp_surp`, is also not included.

To fully replicate the results, users with access to Bloomberg should obtain the median analyst forecast of the policy rate before each Monetary Policy Committee meeting and construct the relevant variable.

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

- `code/replication_code.do`

The code should be run from the root folder of the repository.

Required Stata packages:

- `estout`
- `xtscc`
- `reghdfe`
- `ftools`

Note: The Stata code requires `mp_surp` to exist in `data/paper_data.xlsx`. Since Bloomberg forecasts are proprietary, users must construct this variable separately before running the replication code.

## Repository structure

```text
housing-monetary-policy-turkiye/
├── README.md
│
├── code/
│   └── replication_code.do
│
├── data/
│   ├── paper_data.xlsx
│   └── regional_housing_debt_ratio_quarterly.xlsx
│
└── output/
    ├── figures/
    │   └── *.pdf
    └── tables/
        └── *.tex
