*! version 1.0.0  lsaplot: Event Study with Aesthetic & Robustness
*! Author: Li San'an
*! Date: 2025

capture program drop lsaplot
program define lsaplot
    version 14.0
    
    * ----------------------------------------------------
    * Syntax Parsing
    * ----------------------------------------------------
    syntax varlist(min=1 numeric fv) [if] [in], ///
        Treat(varname) ///      Treatment time variable (e.g. policy year)
        ID(varname) ///         Panel ID
        Time(varname) ///       Panel Time
        [ ///
        Start(string) ///       Plot window start (relative time)
        End(string) ///         Plot window end (relative time)
        Base(integer -1) ///    Reference period
        LEvel(integer 95) ///   Confidence Interval Level
        CLuster(varname) ///    Standard Error Clustering
        Absorb(string) ///      High-Dimensional FE (invokes reghdfe)
        NoGraph ///             Suppress plotting
        KeepData ///            Keep plotting data in memory
        Title(string) ///       Custom graph title
        BIN                     ///  Mode: Bin endpoints (Accumulate)
        TRIM                    ///  Mode: Trim endpoints (Drop)
        ]

    * ----------------------------------------------------
    * 1. Conflict Check & Setup
    * ----------------------------------------------------
    if "`bin'" != "" & "`trim'" != "" {
        di as error "Error: Options 'bin' and 'trim' are mutually exclusive."
        exit 198
    }

    * Font Best Effort (Windows Only typically)
    capture graph set window fontface "Times New Roman"
    capture graph set window fontfacemono "Times New Roman"
    capture graph set window fontfacesans "Times New Roman"

    * ----------------------------------------------------
    * 2. Engine Strategy
    * ----------------------------------------------------
    * Default: XTREG (Classic TWFE)
    local engine "xtreg"
    local use_time_dummy "yes"
    local run_absorb ""

    * A. Custom Absorb Mode
    if "`absorb'" != "" {
        local engine "reghdfe"
        local use_time_dummy "no"
        local run_absorb "`absorb'"
    }
    
    * B. Auto-switch Mode (if cluster breaks xtreg)
    else {
        if "`cluster'" != "" & "`cluster'" != "`id'" {
            local engine "reghdfe"
            local use_time_dummy "no"
            local run_absorb "`id' `time'"
            di as txt "Note [lsaplot]: Non-nested cluster detected. Using 'reghdfe'."
        }
        else {
            local engine "xtreg"
            local use_time_dummy "yes"
        }
    }

    * ----------------------------------------------------
    * 3. Dependencies
    * ----------------------------------------------------
    set more off
    local depvar : word 1 of `varlist'
    local controls : subinstr local varlist "`depvar'" ""
    
    if "`engine'" == "reghdfe" {
        capture which reghdfe
        if _rc {
            di as error "Error [lsaplot]: 'reghdfe' required (ssc install reghdfe)."
            exit 199
        }
    }
    if "`engine'" == "xtreg" {
        capture xtset
        if _rc {
            di as error "Error [lsaplot]: Data not xtset. Run 'xtset `id' `time''."
            exit 198
        }
    }

    * ----------------------------------------------------
    * 4. Data Processing
    * ----------------------------------------------------
    marksample touse
    if "`cluster'" != "" {
        capture confirm variable `cluster'
        if _rc { 
            di as error "Error: Cluster variable '`cluster'' not found."
            exit 111 
        }
        quietly replace `touse' = 0 if missing(`cluster')
    }
    
    preserve
    quietly keep if `touse'
    
    * Generate Relative Time
    tempvar rel_t
    quietly gen `rel_t' = `time' - `treat'
    quietly replace `rel_t' = . if `treat' == 0 | `treat' == .
    
    quietly summarize `rel_t'
    if r(N) == 0 {
        di as error "Error [lsaplot]: No treated observations found."
        restore
        exit 2000
    }

    * Define Window
    local min_d = r(min)
    local max_d = r(max)
    local s_win = cond("`start'" == "", `min_d', real("`start'"))
    local e_win = cond("`end'"   == "", `max_d', real("`end'"))

    if `s_win' > `e_win' {
         local temp = `s_win'
         local s_win = `e_win'
         local e_win = `temp'
    }

    * Bin / Trim Logic
    if "`trim'" != "" {
        di as txt "Mode [lsaplot]: TRIMMING outside [`s_win', `e_win']"
        quietly drop if (`rel_t' < `s_win' | `rel_t' > `e_win') & `rel_t' != .
    }
    else if "`bin'" != "" {
        di as txt "Mode [lsaplot]: BINNING endpoints to [`s_win', `e_win']"
        quietly replace `rel_t' = `s_win' if `rel_t' <= `s_win' & `rel_t' != .
        quietly replace `rel_t' = `e_win' if `rel_t' >= `e_win' & `rel_t' != .
    }

    * Padding Calculation
    local scale_min = `s_win' - 0.2
    local scale_max = `e_win' + 0.2

    capture drop _ls_ev_*
    local d_vars ""
    local v_count 0
    
    forvalues k = `s_win'/`e_win' {
        if `k' != `base' {
            if `k' < 0  local name "m`=abs(`k')'"
            else        local name "p`k'"
            
            quietly count if `rel_t' == `k'
            if r(N) > 0 {
                quietly gen byte _ls_ev_`name' = (`rel_t' == `k')
                local d_vars "`d_vars' _ls_ev_`name'"
                local v_count = `v_count' + 1
            }
        }
    }
    
    if `v_count' == 0 {
        di as error "Error: No dummies generated."
        restore
        exit 2001
    }

    * ----------------------------------------------------
    * 5. Regression Execution
    * ----------------------------------------------------
    local vce_cmd "robust"
    if "`cluster'" != "" {
        local vce_cmd "cluster `cluster'"
    }

    if "`engine'" == "xtreg" {
        di as txt "Running xtreg (TWFE)..."
        capture noisily xtreg `depvar' `d_vars' `controls' i.`time', fe vce(`vce_cmd')
    }
    else {
        di as txt "Running reghdfe..."
        if "`use_time_dummy'" == "yes" {
            capture noisily reghdfe `depvar' `d_vars' `controls' i.`time', absorb(`run_absorb') vce(`vce_cmd')
        }
        else {
            capture noisily reghdfe `depvar' `d_vars' `controls', absorb(`run_absorb') vce(`vce_cmd')
        }
    }

    if _rc != 0 {
        di as error _n ">>> [lsaplot] Regression Failed (RC=`_rc') <<<"
        restore
        exit _rc
    }

    * ----------------------------------------------------
    * 6. Results Extraction
    * ----------------------------------------------------
    tempfile plot_data
    tempname memhold
    postfile `memhold' rel_time coef lb ub using "`plot_data'", replace
    
    local alpha = (100 - `level') / 100
    capture local df = e(df_r)
    if _rc!=0 | "`df'"=="" | "`df'"=="." {
        local t_crit = invnormal(1 - `alpha'/2)
    }
    else {
        local t_crit = invttail(`df', `alpha'/2)
    }

    forvalues k = `s_win'/`e_win' {
        if `k' == `base' {
            post `memhold' (`k') (0) (0) (0)
        }
        else {
            if `k' < 0  local name "m`=abs(`k')'"
            else        local name "p`k'"
            
            capture local b = _b[_ls_ev_`name']
            if _rc == 0 {
                 local se = _se[_ls_ev_`name']
                 if `se' == 0 | `se' == . {
                     post `memhold' (`k') (.) (.) (.)
                 }
                 else {
                     local low = `b' - `t_crit' * `se'
                     local high = `b' + `t_crit' * `se'
                     post `memhold' (`k') (`b') (`low') (`high')
                 }
            }
            else {
                 post `memhold' (`k') (.) (.) (.)
            }
        }
    }
    postclose `memhold'

    * ----------------------------------------------------
    * 7. "San'an Style" Plotting
    * ----------------------------------------------------
    if "`nograph'" == "" {
        use "`plot_data'", clear
        sort rel_time
        
        * --- Variable Construction First (Anti-Crash Logic) ---
        if "`title'" == "" {
             local t_str "Event Study Estimates"
        }
        else {
             local t_str "`title'"
        }
        local sub_str "Dependent Variable: `depvar'"
        
        local m_str ""
        if "`bin'" != "" local m_str "(Binned)"
        if "`trim'" != "" local m_str "(Trimmed)"
        
        local c_str "Robust"
        if "`cluster'" != "" local c_str "Cluster: `cluster'"
        
        local n_str "lsaplot: `engine'`m_str' | `c_str' | `level'% CI"
        
        di as txt "Rendering Figure..."
        
        twoway ///
        (rcap lb ub rel_time, lc(gs7) lp(solid) lw(medthin) msize(small)) ///
        (line coef rel_time, lc(black) lp(solid) lw(medthin)) ///
        (scatter coef rel_time, mc(dknavy) msymbol(O) msize(medium)), ///
        yline(0, lc(black) lp(dash) lw(vthin)) ///
        xline(`base', lc(cranberry) lp(dash) lw(medthin)) ///
        legend(off) ///
        title(`"`t_str'"', size(medium) color(black)) ///
        subtitle(`"`sub_str'"', size(small)) ///
        xtitle("Time Relative to Event", margin(small)) ///
        ytitle("Estimate", margin(small)) ///
        xlabel(`s_win'(1)`e_win', grid glcolor(gs15) glpattern(solid) labsize(small)) ///
        ylabel(, grid glcolor(gs15) glpattern(solid) angle(0) labsize(small)) ///
        graphregion(color(white) margin(medsmall)) ///
        plotregion(lcolor(black) lw(vthin) margin(medium)) ///
        xscale(range(`scale_min' `scale_max')) ///
        note(`"`n_str'"', size(vsmall))
    }

    if "`keepdata'" != "" {
        restore, not
    }
    else {
        restore
    }
end