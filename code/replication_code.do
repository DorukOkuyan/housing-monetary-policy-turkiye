*===============================================================================
* Replication code for:
* Household Leverage and Monetary Transmission in High-Inflation Housing Markets
*
* Author: Doruk Okuyan
*
* Note:
* This do-file should be run from the root folder of the GitHub repository:
* housing-monetary-policy-turkiye/
*
* Bloomberg analyst forecast data are proprietary and are not included in this
* replication package.
*===============================================================================

clear all
set more off

*===============================================================================
* REQUIRED PACKAGES
*===============================================================================

cap which esttab
if _rc ssc install estout, replace

cap which xtscc
if _rc ssc install xtscc, replace

cap which ftools
if _rc ssc install ftools, replace

cap which reghdfe
if _rc ssc install reghdfe, replace

*===============================================================================
* SETTINGS
*===============================================================================

global root "`c(pwd)'"

local datapath "$root/data/paper_data.xlsx"
local sheetname "Prepared Data for Regression"

local graphpath "$root/output/figures"
local tablepath "$root/output/tables"

cap mkdir "$root/output"
cap mkdir "`graphpath'"
cap mkdir "`tablepath'"

local H = 24 
local P_hp = 12
local P_exp = 1
local P_rent = 6

local shock "residuals_mps"
local controls "L.unemp_sa L.bist_mth_gwt_rate L.usdtry_mth_gwt_rate L.pol_rate L.gold_mth_gwt_rate"

local crit90 = 1.645
local crit68 = 1.0
local crit = `crit90'

set scheme s2color
graph set window fontface "Times New Roman"

*===============================================================================
* 1. IMPORT DATA & EXTRACT MP SHOCK
*===============================================================================

import excel "`datapath'", sheet("`sheetname'") firstrow clear

keep if date >= td(01jan2015)

* Regression for Bloomberg forecasts shock orthogonalization

* Note:
* Bloomberg analyst forecast data are proprietary and are not included in this
* replication package. The variable mp_surp is the monetary policy surprise
* constructed from Bloomberg analyst forecast errors. Users with Bloomberg access
* should construct/provide this variable before running the orthogonalization step.

eststo clear
eststo bloomberg: reg mp_surp cpi_sa_fd cpi_exp_12mth_fd cpi_exp_24mth_fd ///
    gdp_gwt_exp_12mth_fd ipi_sa_gwt_fd cap_utl_sa_fd unemp_sa_fd ///
    usd_exp_12mth_pct_chg exc_rate_pct_chg stck_prc_pct_chg 
predict residuals_mps, residuals


esttab bloomberg using "`tablepath'/Appendix_Table.tex", replace ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    nomtitles label booktabs ///
    collabels(none) ///
    varlabels( ///
        cpi_sa_fd "\addlinespace CPI (SA, $\Delta$)" ///
        cpi_exp_12mth_fd "CPI Expectations, 12-month ($\Delta$)" ///
        cpi_exp_24mth_fd "CPI Expectations, 24-month ($\Delta$)" ///
        gdp_gwt_exp_12mth_fd "\addlinespace GDP Growth Expectations, 12-month ($\Delta$)" ///
        ipi_sa_gwt_fd "Industrial Production Growth (SA, $\Delta$)" ///
        cap_utl_sa_fd "Capacity Utilisation (SA, $\Delta$)" ///
        unemp_sa_fd "Unemployment Rate (SA, $\Delta$)" ///
        usd_exp_12mth_pct_chg "\addlinespace USD/TRY Expectations, 12-month (\% chg)" ///
        exc_rate_pct_chg "Exchange Rate (\% chg)" ///
        stck_prc_pct_chg "Stock Price (\% chg)" ///
        _cons "\addlinespace Constant" ///
    ) ///
    stats(N r2_a F, fmt(%9.0g %9.3f %9.2f) ///
        labels("\addlinespace Observations" "Adjusted \$R^2\$" "\$F\$-statistic")) ///
    nonotes ///
    prehead("\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
            "\begin{tabular}{l*{2}{c}}" ///
            "\toprule" ///
            "& Bloomberg Surprise \\") ///
    posthead("\midrule") ///
    prefoot("\midrule") ///
    postfoot("\bottomrule" ///
             "\multicolumn{3}{l}{\footnotesize Standard errors in parentheses. \sym{*} \(p<0.10\), \sym{**} \(p<0.05\), \sym{***} \(p<0.01\)}\\" ///
             "\multicolumn{3}{l}{\footnotesize SA: Seasonally adjusted}\\" ///
             "\end{tabular}")

			 

gen ym = mofd(date)
format ym %tm
sort ym
isid ym
tsset ym



*===============================================================================
* HAMILTON-DETREND LEVERAGE AT QUARTERLY FREQUENCY, INTERPOLATE TO MONTHLY
*===============================================================================

preserve

* Import the quarterly Household Leverage sheet
import excel "`datapath'", sheet("Household Leverage") firstrow clear

rename Date date_q
rename TotalLiabilities liab_q
rename TotalAssets assets_q

* Compute leverage
gen leverage_q = liab_q / assets_q

gen year_q    = real(substr(date_q, 1, 4))
gen qnum      = real(substr(date_q, 6, 1))
gen q         = yq(year_q, qnum)
format q %tq
drop year_q qnum

drop if missing(leverage_q)
sort q
isid q
tsset q

gen lev_lead_q = F8.leverage_q
reg lev_lead_q L0.leverage_q L1.leverage_q L2.leverage_q L3.leverage_q
predict cycle_q_at_t, residuals

*Shift residuals from regressor-time (t) to regressand-time (t+8)
gen cycle_q = L8.cycle_q_at_t
drop cycle_q_at_t

gen ym_anchor = mofd(dofq(q)) + 2
format ym_anchor %tm

keep ym_anchor cycle_q
rename ym_anchor ym
drop if missing(cycle_q)
sort ym
tempfile quarterly_cycle
save `quarterly_cycle'

restore

* merge quarterly cycle onto monthly dataset
merge 1:1 ym using `quarterly_cycle', keep(master match) nogen

* linearly interpolate to fill in monthly values between quarter-end anchors
sort ym
ipolate cycle_q ym, gen(detrended_leverage_hamilton)
drop cycle_q


sum detrended_leverage_hamilton

sum ym if !missing(detrended_leverage_hamilton)
local nat_start = r(min)
local nat_end = r(max)

twoway (line detrended_leverage_hamilton ym if ym >= `nat_start' & ym <= `nat_end', ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("", size(vlarge)) ///
		 ytitle("") ///
         tlabel(`nat_start'(12)`nat_end', labsize(vlarge) angle(45) format(%tmCY)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.3f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_detrended_leverage.pdf", replace




*===============================================================================
* 2. DESCRIPTIVE TIME SERIES PLOTS
*===============================================================================

sum ym if !missing(hh_leverage)
local lev_start = r(min)
local lev_end = r(max)

twoway (line hh_leverage ym if ym >= `lev_start' & ym <= `lev_end', ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , xtitle("", size(vlarge)) ///
         ytitle("") ///
         tlabel(`lev_start'(24)`lev_end', labsize(vlarge) angle(45) format(%tmCY)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.2f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_hh_leverage.pdf", replace

twoway (line residuals_mps ym if ym >= tm(2015m1), ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("", size(vlarge)) ///
         ytitle("Shock (p.p.)", size(vlarge)) ///
         tlabel(2015m1(24)2025m12, labsize(vlarge) format(%tmCY)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_mp_shock.pdf", replace


gen ln_real_house = ln(house_p_index / cpi)
gen rhp_growth12 = (ln_real_house - L12.ln_real_house) * 100

twoway (line rhp_growth12 ym if ym >= tm(2016m1), ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("", size(vlarge)) ///
         ytitle("12-month growth (%)", size(vlarge)) ///
         tlabel(2016m1(24)2025m12, labsize(vlarge) format(%tmCY)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.0f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_rhp_growth.pdf", replace

gen ln_real_rent = ln(new_tenant_rent_index / cpi)
gen rrent_growth12 = (ln_real_rent - L12.ln_real_rent) * 100

twoway (line rrent_growth12 ym if ym >= tm(2019m1), ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("", size(vlarge)) ///
         ytitle("12-month growth (%)", size(vlarge)) ///
         tlabel(2019m1(12)2025m12, labsize(vlarge) format(%tmCY)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.0f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_rrent_growth.pdf", replace


gen prob_buying_pct = prob_buying_house_in1year_sa * 100

twoway (line prob_buying_pct ym if ym >= tm(2015m1), ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , xtitle("", size(vlarge)) ///
         ytitle("Probability (%)", size(vlarge)) ///
         tlabel(2015m1(24)2025m12, labsize(vlarge) format(%tmCY)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.0f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_prob_buying.pdf", replace

*===============================================================================
*  A: AGGREGATE STATE-DEPENDENT LOCAL PROJECTIONS
*===============================================================================

gen real_house = house_p_index / cpi
gen real_rent = new_tenant_rent_index / cpi
gen ln_hpi = ln(real_house)
gen ln_rent = ln(real_rent)

gen L_hh_lev = L.detrended_leverage_hamilton
sum L_hh_lev
gen state_agg = (L_hh_lev - r(mean)) / r(sd)

gen mp_x_state_agg = `shock' * state_agg

forvalues h = 0/`H' {
    gen dy_hp`h' = F`h'.ln_hpi - L.ln_hpi
}
forvalues h = 0/`H' {
    gen dy_exp`h' = F`h'.prob_buying_house_in1year_sa - L.prob_buying_house_in1year_sa
}
forvalues h = 0/`H' {
    gen dy_rent`h' = F`h'.ln_rent - L.ln_rent
}

forvalues p = 1/`P_hp' {
    local pp = `p' + 1
    gen dly_hp`p' = L`p'.ln_hpi - L`pp'.ln_hpi
}
forvalues p = 1/`P_exp' {
    local pp = `p' + 1
    gen dly_exp`p' = L`p'.prob_buying_house_in1year_sa - L`pp'.prob_buying_house_in1year_sa
}
forvalues p = 1/`P_rent' {
    local pp = `p' + 1
    gen dly_rent`p' = L`p'.ln_rent - L`pp'.ln_rent
}

local lagvars_hp ""
forvalues p = 1/`P_hp' {
    local lagvars_hp "`lagvars_hp' dly_hp`p'"
}
local lagvars_exp ""
forvalues p = 1/`P_exp' {
    local lagvars_exp "`lagvars_exp' dly_exp`p'"
}
local lagvars_rent ""
forvalues p = 1/`P_rent' {
    local lagvars_rent "`lagvars_rent' dly_rent`p'"
}

*===============================================================================
* A1. AGGREGATE LP -- HP BASELINE
*===============================================================================
local nrows = `H' + 1
matrix C_hp_base = J(`nrows', 3, .)
forvalues h = 0/`H' {
    local nw_lag = `h' + 1
    local row = `h' + 1
    newey dy_hp`h' `shock' `lagvars_hp' `controls', lag(`nw_lag')
    if _rc == 0 {
        matrix C_hp_base[`row', 1] = `h'
        matrix C_hp_base[`row', 2] = _b[`shock']
        matrix C_hp_base[`row', 3] = _se[`shock']
    }
}

*===============================================================================
* A1b. AGGREGATE LP -- HP STATE-DEPENDENT
*===============================================================================
matrix C_hp = J(`nrows', 6, .)
forvalues h = 0/`H' {
    local nw_lag = `h' + 1
    local row = `h' + 1
    newey dy_hp`h' `shock' mp_x_state_agg state_agg `lagvars_hp' `controls', lag(`nw_lag')
    if _rc == 0 {
        matrix C_hp[`row', 1] = `h'
        matrix C_hp[`row', 2] = _b[`shock']
        matrix C_hp[`row', 3] = _se[`shock']
        matrix C_hp[`row', 4] = _b[mp_x_state_agg]
        matrix C_hp[`row', 5] = _se[mp_x_state_agg]
        matrix V = e(V)
        matrix C_hp[`row', 6] = V["`shock'", "mp_x_state_agg"]
    }
}


*===============================================================================
* A2. AGGREGATE LP -- BUYING PROBABILITY BASELINE
*===============================================================================
matrix C_exp_base = J(`nrows', 3, .)
forvalues h = 0/`H' {
    local nw_lag = `h' + 1
    local row = `h' + 1
    newey dy_exp`h' `shock' `lagvars_exp' `controls', lag(`nw_lag')
    if _rc == 0 {
        matrix C_exp_base[`row', 1] = `h'
        matrix C_exp_base[`row', 2] = _b[`shock']
        matrix C_exp_base[`row', 3] = _se[`shock']
    }
}

*===============================================================================
* A2b. AGGREGATE LP -- BUYING PROBABILITY STATE-DEPENDENT
*===============================================================================
matrix C_exp = J(`nrows', 6, .)
forvalues h = 0/`H' {
    local nw_lag = `h' + 1
    local row = `h' + 1
    newey dy_exp`h' `shock' mp_x_state_agg state_agg `lagvars_exp' `controls', lag(`nw_lag')
    if _rc == 0 {
        matrix C_exp[`row', 1] = `h'
        matrix C_exp[`row', 2] = _b[`shock']
        matrix C_exp[`row', 3] = _se[`shock']
        matrix C_exp[`row', 4] = _b[mp_x_state_agg]
        matrix C_exp[`row', 5] = _se[mp_x_state_agg]
        matrix V = e(V)
        matrix C_exp[`row', 6] = V["`shock'", "mp_x_state_agg"]
    }
}

*===============================================================================
* A3. AGGREGATE LP -- RENT BASELINE
*===============================================================================
matrix C_rent_base = J(`nrows', 3, .)
forvalues h = 0/`H' {
    local nw_lag = `h' + 1
    local row = `h' + 1
    newey dy_rent`h' `shock' `lagvars_rent' `controls', lag(`nw_lag')
    if _rc == 0 {
        matrix C_rent_base[`row', 1] = `h'
        matrix C_rent_base[`row', 2] = _b[`shock']
        matrix C_rent_base[`row', 3] = _se[`shock']
    }
}

*===============================================================================
* A3b. AGGREGATE LP -- RENT STATE-DEPENDENT
*===============================================================================
matrix C_rent = J(`nrows', 6, .)
forvalues h = 0/`H' {
    local nw_lag = `h' + 1
    local row = `h' + 1
    newey dy_rent`h' `shock' mp_x_state_agg state_agg `lagvars_rent' `controls', lag(`nw_lag')
    if _rc == 0 {
        matrix C_rent[`row', 1] = `h'
        matrix C_rent[`row', 2] = _b[`shock']
        matrix C_rent[`row', 3] = _se[`shock']
        matrix C_rent[`row', 4] = _b[mp_x_state_agg]
        matrix C_rent[`row', 5] = _se[mp_x_state_agg]
        matrix V = e(V)
        matrix C_rent[`row', 6] = V["`shock'", "mp_x_state_agg"]
    }
}


*===============================================================================
* A6. AGGREGATE IRF PLOTS
*===============================================================================

capture program drop plot_agg_baseline
program define plot_agg_baseline
    args matname ytitle filename crit90 H graphpath

    local crit68 = 1.0

    preserve
    clear
    local nrows = `H' + 1
    set obs `nrows'

    svmat `matname'
    rename `matname'1 horizon
    rename `matname'2 b_base
    rename `matname'3 se_base

    foreach v in b_base se_base {
        replace `v' = `v' * 100
    }

    gen b_lo90 = b_base - `crit90' * se_base
    gen b_hi90 = b_base + `crit90' * se_base
    gen b_lo68 = b_base - `crit68' * se_base
    gen b_hi68 = b_base + `crit68' * se_base

    twoway (rarea b_lo90 b_hi90 horizon, ///
               fcolor("24 105 109%12") lwidth(none)) ///
           (rarea b_lo68 b_hi68 horizon, ///
               fcolor("24 105 109%25") lwidth(none)) ///
           (line b_base horizon, ///
               lcolor("24 105 109") lwidth(medthick)) ///
           , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
             xtitle("Months", size(vlarge)) ///
             ytitle("`ytitle'", size(vlarge)) ///
             xlabel(0(6)`H', labsize(vlarge)) ///
             ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
             legend(off) ///
             graphregion(color(white) margin(small)) ///
             plotregion(color(white) margin(medsmall))
    graph export "`graphpath'/`filename'.pdf", replace

    restore
end

capture program drop plot_agg_irf
program define plot_agg_irf
    args matname ytitle filename crit90 H graphpath

    local crit68 = 1.0

    preserve
    clear
    local nrows = `H' + 1
    set obs `nrows'

    svmat `matname'
    rename `matname'1 horizon
    rename `matname'2 b_mps
    rename `matname'3 se_mps
    rename `matname'4 b_int
    rename `matname'5 se_int
    rename `matname'6 cov_mps_int

    foreach v in b_mps se_mps b_int se_int {
        replace `v' = `v' * 100
    }
    replace cov_mps_int = cov_mps_int * 10000

    gen b_int_lo90 = b_int - `crit90' * se_int
    gen b_int_hi90 = b_int + `crit90' * se_int
    gen b_int_lo68 = b_int - `crit68' * se_int
    gen b_int_hi68 = b_int + `crit68' * se_int

    twoway (rarea b_int_lo90 b_int_hi90 horizon, ///
               fcolor("24 105 109%12") lwidth(none)) ///
           (rarea b_int_lo68 b_int_hi68 horizon, ///
               fcolor("24 105 109%25") lwidth(none)) ///
           (line b_int horizon, ///
               lcolor("24 105 109") lwidth(medthick)) ///
           , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
             xtitle("Months", size(vlarge)) ///
             ytitle("`ytitle'", size(vlarge)) ///
             xlabel(0(6)`H', labsize(vlarge)) ///
             ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
             legend(off) ///
             graphregion(color(white) margin(small)) ///
             plotregion(color(white) margin(medsmall))
    graph export "`graphpath'/`filename'_int.pdf", replace

    gen b_high = b_mps + b_int
    gen b_low  = b_mps - b_int
    gen se_high = sqrt(se_mps^2 + se_int^2 + 2 * cov_mps_int)
    gen se_low  = sqrt(se_mps^2 + se_int^2 - 2 * cov_mps_int)

    gen b_high_lo90 = b_high - `crit90' * se_high
    gen b_high_hi90 = b_high + `crit90' * se_high
    gen b_high_lo68 = b_high - `crit68' * se_high
    gen b_high_hi68 = b_high + `crit68' * se_high

    gen b_low_lo90  = b_low - `crit90' * se_low
    gen b_low_hi90  = b_low + `crit90' * se_low
    gen b_low_lo68  = b_low - `crit68' * se_low
    gen b_low_hi68  = b_low + `crit68' * se_low

    twoway (rarea b_high_lo90 b_high_hi90 horizon, ///
               fcolor("192 57 43%10") lwidth(none)) ///
           (rarea b_high_lo68 b_high_hi68 horizon, ///
               fcolor("192 57 43%22") lwidth(none)) ///
           (rarea b_low_lo90 b_low_hi90 horizon, ///
               fcolor("44 62 80%10") lwidth(none)) ///
           (rarea b_low_lo68 b_low_hi68 horizon, ///
               fcolor("44 62 80%22") lwidth(none)) ///
           (line b_high horizon, ///
               lcolor("192 57 43") lwidth(medthick)) ///
           (line b_low horizon, ///
               lcolor("44 62 80") lwidth(medthick)) ///
           , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
             xtitle("Months", size(vlarge)) ///
             ytitle("`ytitle'", size(vlarge)) ///
             xlabel(0(6)`H', labsize(vlarge)) ///
             ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
             legend(off) ///
             graphregion(color(white) margin(small)) ///
             plotregion(color(white) margin(medsmall))
    graph export "`graphpath'/`filename'_state.pdf", replace

    restore
end


plot_agg_baseline C_hp_base "Response (%)" "irf_agg_hp_base" `crit90' `H' "`graphpath'"
plot_agg_baseline C_exp_base "Response (p.p.)" "irf_agg_exp_base" `crit90' `H' "`graphpath'"
plot_agg_baseline C_rent_base "Response (%)" "irf_agg_rent_base" `crit90' `H' "`graphpath'"

plot_agg_irf C_hp "Response (%)" "irf_agg_hp" `crit90' `H' "`graphpath'"
plot_agg_irf C_exp "Response (p.p.)" "irf_agg_exp" `crit90' `H' "`graphpath'"
plot_agg_irf C_rent "Response (%)" "irf_agg_rent" `crit90' `H' "`graphpath'"



*===============================================================================
*  PART B: PANEL STATE-DEPENDENT LOCAL PROJECTIONS
*===============================================================================

tsset, clear

*===============================================================================
* B1. RESHAPE TO LONG PANEL
*===============================================================================

rename tr10_housing hp_1
rename tr21_housing hp_2
rename tr22_housing hp_3
rename tr31_housing hp_4
rename tr32_housing hp_5
rename tr33_housing hp_6
rename tr41_housing hp_7
rename tr42_housing hp_8
rename tr51_housing hp_9
rename tr52_housing hp_10
rename tr61_housing hp_11
rename tr62_housing hp_12
rename tr63_housing hp_13
rename tr7_housing  hp_14
rename tr8_housing  hp_15
rename tr9_housing  hp_16
rename tra_housing  hp_17
rename trb_housing  hp_18
rename trc_housing  hp_19

rename TR10_housing_debt_ratio debt_1
rename TR21_housing_debt_ratio debt_2
rename TR22_housing_debt_ratio debt_3
rename TR31_housing_debt_ratio debt_4
rename TR32_housing_debt_ratio debt_5
rename TR33_housing_debt_ratio debt_6
rename TR41_housing_debt_ratio debt_7
rename TR42_housing_debt_ratio debt_8
rename TR51_housing_debt_ratio debt_9
rename TR52_housing_debt_ratio debt_10
rename TR61_housing_debt_ratio debt_11
rename TR62_housing_debt_ratio debt_12
rename TR63_housing_debt_ratio debt_13
rename TR7_housing_debt_ratio  debt_14
rename TR8_housing_debt_ratio  debt_15
rename TR9_housing_debt_ratio  debt_16
rename TRA_housing_debt_ratio  debt_17
rename TRB_housing_debt_ratio  debt_18
rename TRC_housing_debt_ratio  debt_19

rename tr10_rent    rent_1
rename tr21_rent    rent_2
rename tr22_rent    rent_3
rename tr31_rent    rent_4
rename tr32_rent    rent_5
rename tr33_rent    rent_6
rename tr41_rent    rent_7
rename tr42_rent    rent_8
rename tr_51_rent   rent_9
rename tr52_rent    rent_10
rename tr61_rent    rent_11
rename tr62_rent    rent_12
rename tr63_rent    rent_13
rename tr7_rent     rent_14
rename tr8_rent     rent_15
rename tr9_rent     rent_16
rename tra_rent     rent_17
rename trb_rent     rent_18
rename trc_rent     rent_19

keep ym date residuals_mps ///
     hp_1-hp_19 debt_1-debt_19 rent_1-rent_19 ///
     unemp_sa usdtry_mth_gwt_rate bist_mth_gwt_rate pol_rate cpi gold_mth_gwt_rate ///
     house_p_index

reshape long hp_ debt_ rent_, i(ym) j(region_id)
rename hp_ housing_price
rename debt_ housing_debt_ratio
rename rent_ rent_index





*===============================================================================
* B2. PANEL SETUP
*===============================================================================

sort region_id ym
xtset region_id ym

gen real_housing = housing_price / cpi
gen ln_hp = ln(real_housing)
gen real_rent_reg = rent_index / cpi
gen ln_rent_reg = ln(real_rent_reg)



*===============================================================================
* B2a. HAMILTON-DETREND REGIONAL HOUSING DEBT RATIO (quarterly source data)
*===============================================================================

preserve
import excel "$root/data/regional_housing_debt_ratio_quarterly.xlsx", firstrow clear

* Build Stata quarterly date
gen q = yq(year, quarter)
format q %tq

* Map region string to numeric ID matching your panel
gen region_id = .
replace region_id = 1  if region == "TR10"
replace region_id = 2  if region == "TR21"
replace region_id = 3  if region == "TR22"
replace region_id = 4  if region == "TR31"
replace region_id = 5  if region == "TR32"
replace region_id = 6  if region == "TR33"
replace region_id = 7  if region == "TR41"
replace region_id = 8  if region == "TR42"
replace region_id = 9  if region == "TR51"
replace region_id = 10 if region == "TR52"
replace region_id = 11 if region == "TR61"
replace region_id = 12 if region == "TR62"
replace region_id = 13 if region == "TR63"
replace region_id = 14 if region == "TR7"
replace region_id = 15 if region == "TR8"
replace region_id = 16 if region == "TR9"
replace region_id = 17 if region == "TRA"
replace region_id = 18 if region == "TRB"
replace region_id = 19 if region == "TRC"

drop region
xtset region_id q

* Hamilton (2018) at quarterly frequency: h=8, p=4
gen lev_lead_q = F8.housing_debt_ratio
gen cycle_q_at_t = .

forvalues r = 1/19 {
    quietly reg lev_lead_q L0.housing_debt_ratio L1.housing_debt_ratio ///
        L2.housing_debt_ratio L3.housing_debt_ratio if region_id == `r'
    quietly predict resid_tmp if region_id == `r' & e(sample), residuals
    quietly replace cycle_q_at_t = resid_tmp if region_id == `r' & !missing(resid_tmp)
    drop resid_tmp
}

* Shift residuals from regressor-time t to regressand-time t+8 within each region
gen cycle_q = L8.cycle_q_at_t
drop cycle_q_at_t lev_lead_q

* Anchor each quarter to its last month
gen ym_anchor = mofd(dofq(q)) + 2
format ym_anchor %tm

keep ym_anchor region_id cycle_q
rename ym_anchor ym
drop if missing(cycle_q)
sort region_id ym
tempfile regional_cycle
save `regional_cycle'

restore

* Merge onto monthly panel
merge 1:1 region_id ym using `regional_cycle', keep(master match) nogen

* Linearly interpolate within each region
sort region_id ym
by region_id: ipolate cycle_q ym, gen(detrended_housing_debt)
drop cycle_q

* Standardize and create state variable
sum detrended_housing_debt
scalar mean_debt = r(mean)
scalar sd_debt   = r(sd)
gen state_reg = (L.detrended_housing_debt - mean_debt) / sd_debt

local shock "residuals_mps"
gen mp_x_state_reg = `shock' * state_reg





*===============================================================================
* B2b. EXPORT REGIONAL HOUSING DEBT RATIO GRAPHS (matched window)
*===============================================================================

* Find the date range where detrended series exists
sum ym if !missing(detrended_housing_debt)
local start_ym = r(min)
local end_ym = r(max)
di "Detrended series spans: " %tm `start_ym' " to " %tm `end_ym'

* Graph 1: Raw housing debt ratio across 19 regions, restricted to detrended window
twoway ///
    (line housing_debt_ratio ym if region_id == 1  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 2  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 3  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 4  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 5  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 6  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 7  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 8  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 9  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 10 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 11 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 12 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 13 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 14 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 15 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 16 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 17 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 18 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line housing_debt_ratio ym if region_id == 19 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    , xtitle("", size(vlarge)) ///
	ytitle("") ///
      tlabel(`start_ym'(12)`end_ym', labsize(vlarge) angle(45) format(%tmCY)) ///
      ylabel(, labsize(vlarge) angle(horizontal) format(%9.2f) nogrid) ///
      legend(off) ///
      graphregion(color(white) margin(small)) ///
      plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_regional_housing_debt_raw.pdf", replace

* Graph 2: Hamilton-detrended housing debt ratio across 19 regions
twoway ///
    (line detrended_housing_debt ym if region_id == 1  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 2  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 3  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 4  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 5  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 6  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 7  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 8  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 9  & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 10 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 11 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 12 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 13 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 14 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 15 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 16 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 17 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 18 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    (line detrended_housing_debt ym if region_id == 19 & ym >= `start_ym' & ym <= `end_ym', lcolor(gs8) lwidth(thin)) ///
    , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
      xtitle("", size(vlarge)) ///
	  ytitle("") ///
      tlabel(`start_ym'(12)`end_ym', labsize(vlarge) angle(45) format(%tmCY)) ///
      ylabel(, labsize(vlarge) angle(horizontal) format(%9.3f) nogrid) ///
      legend(off) ///
      graphregion(color(white) margin(small)) ///
      plotregion(color(white) margin(medsmall))
graph export "`graphpath'/ts_regional_housing_debt_detrended.pdf", replace





*===============================================================================
* B3. PANEL DEPENDENT VARIABLES AND LAGS
*===============================================================================

forvalues h = 0/`H' {
    gen dy`h' = F`h'.ln_hp - L.ln_hp
}
forvalues h = 0/`H' {
    gen dy_rrent`h' = F`h'.ln_rent_reg - L.ln_rent_reg
}
forvalues p = 1/`P_hp' {
    local pp = `p' + 1
    gen dly`p' = L`p'.ln_hp - L`pp'.ln_hp
}
forvalues p = 1/`P_rent' {
    local pp = `p' + 1
    gen dly_rrent`p' = L`p'.ln_rent_reg - L`pp'.ln_rent_reg
}

local lagvars ""
forvalues p = 1/`P_hp' {
    local lagvars "`lagvars' dly`p'"
}

local lagvars_rrent ""
forvalues p = 1/`P_rent' {
    local lagvars_rrent "`lagvars_rrent' dly_rrent`p'"
}

*===============================================================================
* B4. PANEL LP -- HP BASELINE
*===============================================================================

local nrows = `H' + 1
matrix B_base = J(`nrows', 3, .)

forvalues h = 0/`H' {
    local dk_lag = `h' + 1
    local row = `h' + 1
    capture noisily xtscc dy`h' `shock' `lagvars' `controls', fe lag(`dk_lag')
    if _rc == 0 {
        matrix B_base[`row', 1] = `h'
        matrix B_base[`row', 2] = _b[`shock']
        matrix B_base[`row', 3] = _se[`shock']
    }
}

*===============================================================================
* B5. PANEL LP -- HP STATE-DEPENDENT
*===============================================================================

matrix B_state = J(`nrows', 6, .)

forvalues h = 0/`H' {
    local dk_lag = `h' + 1
    local row = `h' + 1
    capture noisily xtscc dy`h' `shock' mp_x_state_reg state_reg `lagvars' `controls', fe lag(`dk_lag')
    if _rc == 0 {
        matrix B_state[`row', 1] = `h'
        matrix B_state[`row', 2] = _b[`shock']
        matrix B_state[`row', 3] = _se[`shock']
        matrix B_state[`row', 4] = _b[mp_x_state_reg]
        matrix B_state[`row', 5] = _se[mp_x_state_reg]
        matrix V = e(V)
        matrix B_state[`row', 6] = V["`shock'", "mp_x_state_reg"]
    }
}


*===============================================================================
* B5c. PANEL LP -- RENT BASELINE
*===============================================================================

matrix B_rent_base = J(`nrows', 3, .)

forvalues h = 0/`H' {
    local dk_lag = `h' + 1
    local row = `h' + 1
    capture noisily xtscc dy_rrent`h' `shock' `lagvars_rrent' `controls', fe lag(`dk_lag')
    if _rc == 0 {
        matrix B_rent_base[`row', 1] = `h'
        matrix B_rent_base[`row', 2] = _b[`shock']
        matrix B_rent_base[`row', 3] = _se[`shock']
    }
}

*===============================================================================
* B5d. PANEL LP -- RENT STATE-DEPENDENT
*===============================================================================

matrix B_rent_state = J(`nrows', 6, .)

forvalues h = 0/`H' {
    local dk_lag = `h' + 1
    local row = `h' + 1
    capture noisily xtscc dy_rrent`h' `shock' mp_x_state_reg state_reg `lagvars_rrent' `controls', fe lag(`dk_lag')
    if _rc == 0 {
        matrix B_rent_state[`row', 1] = `h'
        matrix B_rent_state[`row', 2] = _b[`shock']
        matrix B_rent_state[`row', 3] = _se[`shock']
        matrix B_rent_state[`row', 4] = _b[mp_x_state_reg]
        matrix B_rent_state[`row', 5] = _se[mp_x_state_reg]
        matrix V = e(V)
        matrix B_rent_state[`row', 6] = V["`shock'", "mp_x_state_reg"]
    }
}

*===============================================================================
* B6. PANEL LP -- TWO-WAY FIXED EFFECTS (ROBUSTNESS, CLUSTERED BY REGION)
*===============================================================================

matrix B_twfe = J(`nrows', 3, .)

forvalues h = 0/`H' {
    local row = `h' + 1
    capture noisily reghdfe dy`h' mp_x_state_reg state_reg `lagvars', ///
        absorb(region_id ym) vce(cluster region_id)
    if _rc == 0 {
        matrix B_twfe[`row', 1] = `h'
        matrix B_twfe[`row', 2] = _b[mp_x_state_reg]
        matrix B_twfe[`row', 3] = _se[mp_x_state_reg]
    }
}

*===============================================================================
* B6b. PANEL LP -- RENT TWO-WAY FIXED EFFECTS (ROBUSTNESS, CLUSTERED BY REGION)
*===============================================================================

matrix B_rent_twfe = J(`nrows', 3, .)

forvalues h = 0/`H' {
    local row = `h' + 1
    capture noisily reghdfe dy_rrent`h' mp_x_state_reg state_reg `lagvars_rrent', ///
        absorb(region_id ym) vce(cluster region_id)
    if _rc == 0 {
        matrix B_rent_twfe[`row', 1] = `h'
        matrix B_rent_twfe[`row', 2] = _b[mp_x_state_reg]
        matrix B_rent_twfe[`row', 3] = _se[mp_x_state_reg]
    }
}

*===============================================================================
* B7. REGION-BY-REGION LPs (spaghetti plot + map CSV)
*===============================================================================

matrix R_all = J(19 * (`H' + 1), 3, .)
local mrow = 0

forvalues r = 1/19 {
    preserve
    keep if region_id == `r'
    tsset ym
    forvalues h = 0/`H' {
        local nw_lag = `h' + 1
        local mrow = `mrow' + 1
        capture noisily newey dy`h' `shock' `lagvars' `controls', lag(`nw_lag')
        if _rc == 0 {
            matrix R_all[`mrow', 1] = `r'
            matrix R_all[`mrow', 2] = `h'
            matrix R_all[`mrow', 3] = _b[`shock']
        }
        else {
            matrix R_all[`mrow', 1] = `r'
            matrix R_all[`mrow', 2] = `h'
            matrix R_all[`mrow', 3] = .
        }
    }
    restore
}

preserve
clear
local totalrows = 19 * (`H' + 1)
set obs `totalrows'
svmat R_all
rename R_all1 region_id
rename R_all2 horizon
rename R_all3 b_region
replace b_region = b_region * 100
reshape wide b_region, i(horizon) j(region_id)

local nrows = `H' + 1
gen b_avg = .
forvalues h = 0/`H' {
    local row = `h' + 1
    local val = B_base[`row', 2] * 100
    replace b_avg = `val' if horizon == `h'
}

twoway (line b_region1 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region2 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region3 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region4 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region5 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region6 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region7 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region8 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region9 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region10 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region11 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region12 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region13 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region14 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region15 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region16 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region17 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region18 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_region19 horizon, lcolor(gs12) lwidth(thin)) ///
       (line b_avg horizon, lcolor("24 105 109") lwidth(thick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_all_regions.pdf", replace
restore




*===============================================================================
* B7b. REGION-BY-REGION RENT LPs (for rent map)
*===============================================================================

matrix R_rent_all = J(19 * (`H' + 1), 3, .)
local mrow_r = 0

forvalues r = 1/19 {
    preserve
    keep if region_id == `r'
    tsset ym
    forvalues h = 0/`H' {
        local nw_lag = `h' + 1
        local mrow_r = `mrow_r' + 1
        capture noisily newey dy_rrent`h' `shock' `lagvars_rrent' `controls', lag(`nw_lag')
        if _rc == 0 {
            matrix R_rent_all[`mrow_r', 1] = `r'
            matrix R_rent_all[`mrow_r', 2] = `h'
            matrix R_rent_all[`mrow_r', 3] = _b[`shock']
        }
        else {
            matrix R_rent_all[`mrow_r', 1] = `r'
            matrix R_rent_all[`mrow_r', 2] = `h'
            matrix R_rent_all[`mrow_r', 3] = .
        }
    }
    restore
}

*===============================================================================
* B8. EXPORT REGION-LEVEL DATA FOR PYTHON MAPS
*===============================================================================

local rlabel1  "TR10"
local rlabel2  "TR21"
local rlabel3  "TR22"
local rlabel4  "TR31"
local rlabel5  "TR32"
local rlabel6  "TR33"
local rlabel7  "TR41"
local rlabel8  "TR42"
local rlabel9  "TR51"
local rlabel10 "TR52"
local rlabel11 "TR61"
local rlabel12 "TR62"
local rlabel13 "TR63"
local rlabel14 "TR7"
local rlabel15 "TR8"
local rlabel16 "TR9"
local rlabel17 "TRA"
local rlabel18 "TRB"
local rlabel19 "TRC"

preserve
collapse (mean) housing_debt_ratio, by(region_id)
rename housing_debt_ratio avg_credit

gen b_h6 = .
gen b_h12 = .
gen b_h18 = .
gen b_h24 = .
gen region_label = ""

local H = 24
forvalues r = 1/19 {
    local row_h6  = (`r' - 1) * (`H' + 1) + 7
    local row_h12 = (`r' - 1) * (`H' + 1) + 13
    local row_h18 = (`r' - 1) * (`H' + 1) + 19
    local row_h24 = (`r' - 1) * (`H' + 1) + 25
    replace b_h6  = R_all[`row_h6', 3]  * 100 if region_id == `r'
    replace b_h12 = R_all[`row_h12', 3] * 100 if region_id == `r'
    replace b_h18 = R_all[`row_h18', 3] * 100 if region_id == `r'
    replace b_h24 = R_all[`row_h24', 3] * 100 if region_id == `r'
    replace region_label = "`rlabel`r''" if region_id == `r'
}

export delimited region_id region_label avg_credit b_h6 b_h12 b_h18 b_h24 ///
    using "`graphpath'/region_irf_coefficients.csv", replace
restore

preserve
collapse (mean) housing_debt_ratio, by(region_id)
rename housing_debt_ratio avg_credit

gen r_h6 = .
gen r_h12 = .
gen r_h18 = .
gen r_h24 = .
gen region_label = ""

local H = 24
forvalues r = 1/19 {
    local row_h6  = (`r' - 1) * (`H' + 1) + 7
    local row_h12 = (`r' - 1) * (`H' + 1) + 13
    local row_h18 = (`r' - 1) * (`H' + 1) + 19
    local row_h24 = (`r' - 1) * (`H' + 1) + 25
    replace r_h6  = R_rent_all[`row_h6', 3]  * 100 if region_id == `r'
    replace r_h12 = R_rent_all[`row_h12', 3] * 100 if region_id == `r'
    replace r_h18 = R_rent_all[`row_h18', 3] * 100 if region_id == `r'
    replace r_h24 = R_rent_all[`row_h24', 3] * 100 if region_id == `r'
    replace region_label = "`rlabel`r''" if region_id == `r'
}

export delimited region_id region_label avg_credit r_h6 r_h12 r_h18 r_h24 ///
    using "`graphpath'/region_rent_irf_coefficients.csv", replace
restore

*===============================================================================
* B9. PANEL IRF PLOTS
*===============================================================================

preserve
clear
set obs `nrows'
svmat B_twfe
rename B_twfe1 horizon
rename B_twfe2 b_int
rename B_twfe3 se_int
foreach v in b_int se_int {
    replace `v' = `v' * 100
}
gen b_int_lo90 = b_int - `crit90' * se_int
gen b_int_hi90 = b_int + `crit90' * se_int
gen b_int_lo68 = b_int - `crit68' * se_int
gen b_int_hi68 = b_int + `crit68' * se_int
twoway (rarea b_int_lo90 b_int_hi90 horizon, ///
           fcolor("192 57 43%12") lwidth(none)) ///
       (rarea b_int_lo68 b_int_hi68 horizon, ///
           fcolor("192 57 43%25") lwidth(none)) ///
       (line b_int horizon, ///
           lcolor("192 57 43") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_twfe_interaction.pdf", replace
restore

preserve
clear
set obs `nrows'
svmat B_base
rename B_base1 horizon
rename B_base2 b_base
rename B_base3 se_base
gen b_base_lo90 = b_base - `crit90' * se_base
gen b_base_hi90 = b_base + `crit90' * se_base
gen b_base_lo68 = b_base - `crit68' * se_base
gen b_base_hi68 = b_base + `crit68' * se_base
foreach v in b_base b_base_lo90 b_base_hi90 b_base_lo68 b_base_hi68 {
    replace `v' = `v' * 100
}
twoway (rarea b_base_lo90 b_base_hi90 horizon, ///
           fcolor("24 105 109%12") lwidth(none)) ///
       (rarea b_base_lo68 b_base_hi68 horizon, ///
           fcolor("24 105 109%25") lwidth(none)) ///
       (line b_base horizon, ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_baseline.pdf", replace
restore

preserve
clear
set obs `nrows'
svmat B_state
rename B_state1 horizon
rename B_state2 b_mps
rename B_state3 se_mps
rename B_state4 b_int
rename B_state5 se_int
rename B_state6 cov_mps_int
foreach v in b_mps se_mps b_int se_int {
    replace `v' = `v' * 100
}
replace cov_mps_int = cov_mps_int * 10000

gen b_int_lo90 = b_int - `crit90' * se_int
gen b_int_hi90 = b_int + `crit90' * se_int
gen b_int_lo68 = b_int - `crit68' * se_int
gen b_int_hi68 = b_int + `crit68' * se_int
twoway (rarea b_int_lo90 b_int_hi90 horizon, ///
           fcolor("24 105 109%12") lwidth(none)) ///
       (rarea b_int_lo68 b_int_hi68 horizon, ///
           fcolor("24 105 109%25") lwidth(none)) ///
       (line b_int horizon, ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_interaction.pdf", replace

gen b_high = b_mps + b_int
gen b_low  = b_mps - b_int
gen se_high = sqrt(se_mps^2 + se_int^2 + 2 * cov_mps_int)
gen se_low  = sqrt(se_mps^2 + se_int^2 - 2 * cov_mps_int)

gen b_high_lo90 = b_high - `crit90' * se_high
gen b_high_hi90 = b_high + `crit90' * se_high
gen b_high_lo68 = b_high - `crit68' * se_high
gen b_high_hi68 = b_high + `crit68' * se_high

gen b_low_lo90  = b_low - `crit90' * se_low
gen b_low_hi90  = b_low + `crit90' * se_low
gen b_low_lo68  = b_low - `crit68' * se_low
gen b_low_hi68  = b_low + `crit68' * se_low

twoway (rarea b_high_lo90 b_high_hi90 horizon, ///
           fcolor("192 57 43%10") lwidth(none)) ///
       (rarea b_high_lo68 b_high_hi68 horizon, ///
           fcolor("192 57 43%22") lwidth(none)) ///
       (rarea b_low_lo90 b_low_hi90 horizon, ///
           fcolor("44 62 80%10") lwidth(none)) ///
       (rarea b_low_lo68 b_low_hi68 horizon, ///
           fcolor("44 62 80%22") lwidth(none)) ///
       (line b_high horizon, ///
           lcolor("192 57 43") lwidth(medthick)) ///
       (line b_low horizon, ///
           lcolor("44 62 80") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_high_vs_low.pdf", replace
restore

preserve
clear
set obs `nrows'
svmat B_rent_base
rename B_rent_base1 horizon
rename B_rent_base2 b_base
rename B_rent_base3 se_base
gen b_base_lo90 = b_base - `crit90' * se_base
gen b_base_hi90 = b_base + `crit90' * se_base
gen b_base_lo68 = b_base - `crit68' * se_base
gen b_base_hi68 = b_base + `crit68' * se_base
foreach v in b_base b_base_lo90 b_base_hi90 b_base_lo68 b_base_hi68 {
    replace `v' = `v' * 100
}
twoway (rarea b_base_lo90 b_base_hi90 horizon, ///
           fcolor("24 105 109%12") lwidth(none)) ///
       (rarea b_base_lo68 b_base_hi68 horizon, ///
           fcolor("24 105 109%25") lwidth(none)) ///
       (line b_base horizon, ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_rent_baseline.pdf", replace
restore

preserve
clear
set obs `nrows'
svmat B_rent_state
rename B_rent_state1 horizon
rename B_rent_state2 b_mps
rename B_rent_state3 se_mps
rename B_rent_state4 b_int
rename B_rent_state5 se_int
rename B_rent_state6 cov_mps_int
foreach v in b_mps se_mps b_int se_int {
    replace `v' = `v' * 100
}
replace cov_mps_int = cov_mps_int * 10000

gen b_int_lo90 = b_int - `crit90' * se_int
gen b_int_hi90 = b_int + `crit90' * se_int
gen b_int_lo68 = b_int - `crit68' * se_int
gen b_int_hi68 = b_int + `crit68' * se_int
twoway (rarea b_int_lo90 b_int_hi90 horizon, ///
           fcolor("24 105 109%12") lwidth(none)) ///
       (rarea b_int_lo68 b_int_hi68 horizon, ///
           fcolor("24 105 109%25") lwidth(none)) ///
       (line b_int horizon, ///
           lcolor("24 105 109") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_rent_interaction.pdf", replace

gen b_high = b_mps + b_int
gen b_low  = b_mps - b_int
gen se_high = sqrt(se_mps^2 + se_int^2 + 2 * cov_mps_int)
gen se_low  = sqrt(se_mps^2 + se_int^2 - 2 * cov_mps_int)

gen b_high_lo90 = b_high - `crit90' * se_high
gen b_high_hi90 = b_high + `crit90' * se_high
gen b_high_lo68 = b_high - `crit68' * se_high
gen b_high_hi68 = b_high + `crit68' * se_high

gen b_low_lo90  = b_low - `crit90' * se_low
gen b_low_hi90  = b_low + `crit90' * se_low
gen b_low_lo68  = b_low - `crit68' * se_low
gen b_low_hi68  = b_low + `crit68' * se_low

twoway (rarea b_high_lo90 b_high_hi90 horizon, ///
           fcolor("192 57 43%10") lwidth(none)) ///
       (rarea b_high_lo68 b_high_hi68 horizon, ///
           fcolor("192 57 43%22") lwidth(none)) ///
       (rarea b_low_lo90 b_low_hi90 horizon, ///
           fcolor("44 62 80%10") lwidth(none)) ///
       (rarea b_low_lo68 b_low_hi68 horizon, ///
           fcolor("44 62 80%22") lwidth(none)) ///
       (line b_high horizon, ///
           lcolor("192 57 43") lwidth(medthick)) ///
       (line b_low horizon, ///
           lcolor("44 62 80") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_rent_high_vs_low.pdf", replace
restore

preserve
clear
set obs `nrows'
svmat B_rent_twfe
rename B_rent_twfe1 horizon
rename B_rent_twfe2 b_int
rename B_rent_twfe3 se_int
foreach v in b_int se_int {
    replace `v' = `v' * 100
}
gen b_int_lo90 = b_int - `crit90' * se_int
gen b_int_hi90 = b_int + `crit90' * se_int
gen b_int_lo68 = b_int - `crit68' * se_int
gen b_int_hi68 = b_int + `crit68' * se_int
twoway (rarea b_int_lo90 b_int_hi90 horizon, ///
           fcolor("192 57 43%12") lwidth(none)) ///
       (rarea b_int_lo68 b_int_hi68 horizon, ///
           fcolor("192 57 43%25") lwidth(none)) ///
       (line b_int horizon, ///
           lcolor("192 57 43") lwidth(medthick)) ///
       , yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
         xtitle("Months", size(vlarge)) ///
         ytitle("Response (%)", size(vlarge)) ///
         xlabel(0(6)`H', labsize(vlarge)) ///
         ylabel(, labsize(vlarge) angle(horizontal) format(%9.1f) nogrid) ///
         legend(off) ///
         graphregion(color(white) margin(small)) ///
         plotregion(color(white) margin(medsmall))
graph export "`graphpath'/irf_panel_rent_twfe_interaction.pdf", replace
restore

*===============================================================================
* SUMMARY TABLES
*===============================================================================

di _n "=========================================="
di "AGGREGATE LP: Real HP Baseline (no state)"
di "=========================================="
di "Horizon | Avg (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = C_hp_base[`row', 2] * 100
    local s1 = C_hp_base[`row', 3] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1'
}

di _n "=========================================="
di "AGGREGATE LP: Real Housing Prices x HH Leverage"
di "=========================================="
di "Horizon | Avg (x100) | SE | Int (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = C_hp[`row', 2] * 100
    local s1 = C_hp[`row', 3] * 100
    local b2 = C_hp[`row', 4] * 100
    local s2 = C_hp[`row', 5] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1' " | " %9.3f `b2' " | " %7.3f `s2'
}

di _n "=========================================="
di "AGGREGATE LP: Buying Probability Baseline (no state)"
di "=========================================="
di "Horizon | Avg (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = C_exp_base[`row', 2] * 100
    local s1 = C_exp_base[`row', 3] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1'
}

di _n "=========================================="
di "AGGREGATE LP: Buying Probability x HH Leverage"
di "=========================================="
di "Horizon | Avg (x100) | SE | Int (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = C_exp[`row', 2] * 100
    local s1 = C_exp[`row', 3] * 100
    local b2 = C_exp[`row', 4] * 100
    local s2 = C_exp[`row', 5] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1' " | " %9.3f `b2' " | " %7.3f `s2'
}

di _n "=========================================="
di "AGGREGATE LP: Real Rent Baseline (no state)"
di "=========================================="
di "Horizon | Avg (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = C_rent_base[`row', 2] * 100
    local s1 = C_rent_base[`row', 3] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1'
}

di _n "=========================================="
di "AGGREGATE LP: Real Rent x HH Leverage"
di "=========================================="
di "Horizon | Avg (x100) | SE | Int (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = C_rent[`row', 2] * 100
    local s1 = C_rent[`row', 3] * 100
    local b2 = C_rent[`row', 4] * 100
    local s2 = C_rent[`row', 5] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1' " | " %9.3f `b2' " | " %7.3f `s2'
}


di _n "=========================================="
di "PANEL LP: Real HP Baseline (no state)"
di "=========================================="
di "Horizon | Avg (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = B_base[`row', 2] * 100
    local s1 = B_base[`row', 3] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1'
}

di _n "=========================================="
di "PANEL LP: Regional HP x Credit Intensity (19 regions)"
di "=========================================="
di "Horizon | Avg (x100) | SE | Int (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = B_state[`row', 2] * 100
    local s1 = B_state[`row', 3] * 100
    local b2 = B_state[`row', 4] * 100
    local s2 = B_state[`row', 5] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1' " | " %9.3f `b2' " | " %7.3f `s2'
}


di _n "=========================================="
di "PANEL LP: Two-Way FE -- Interaction Only (19 regions)"
di "=========================================="
di "Horizon | Int (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = B_twfe[`row', 2] * 100
    local s1 = B_twfe[`row', 3] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1'
}

di _n "=========================================="
di "PANEL LP: Real Rent Baseline (no state)"
di "=========================================="
di "Horizon | Avg (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = B_rent_base[`row', 2] * 100
    local s1 = B_rent_base[`row', 3] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1'
}

di _n "=========================================="
di "PANEL LP: Regional Rent x Credit Intensity (19 regions)"
di "=========================================="
di "Horizon | Avg (x100) | SE | Int (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = B_rent_state[`row', 2] * 100
    local s1 = B_rent_state[`row', 3] * 100
    local b2 = B_rent_state[`row', 4] * 100
    local s2 = B_rent_state[`row', 5] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1' " | " %9.3f `b2' " | " %7.3f `s2'
}

di _n "=========================================="
di "PANEL LP: Rent Two-Way FE -- Interaction Only (19 regions)"
di "=========================================="
di "Horizon | Int (x100) | SE"
di "------------------------------------------"
forvalues h = 0/`H' {
    local row = `h' + 1
    local b1 = B_rent_twfe[`row', 2] * 100
    local s1 = B_rent_twfe[`row', 3] * 100
    di %4.0f `h' " | " %9.3f `b1' " | " %7.3f `s1'
}
