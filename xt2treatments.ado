*! version 0.10.0 12oct2026
program xt2treatments, eclass
version 18.0

syntax varname(numeric) [if] [aweight], treatment(varname numeric) control(varname numeric) [, pre(integer 1) post(integer 3) baseline(string) weighting(string) cluster(varname) graph]
* read panel structure
xtset
local group = r(panelvar)
local time = r(timevar)
local y `varlist'

if ("`baseline'" == "") {
    local baseline "-1"
}
if ("`weighting'" == "") {
    local weighting "equal"
}
if ("`cluster'" == "") {
    local cluster "`group'"
}
local T1 = `pre'-1
local K = `pre'+`post'+1

marksample touse

tempvar awvar
local awopt
if ("`weight'" != "") {
    quietly generate double `awvar' `exp' if `touse'
    capture assert `awvar' >= 0 if `touse' & !missing(`awvar')
    if (_rc) {
        display in red "Analytical weights must be nonnegative"
        error 402
    }
    quietly replace `touse' = 0 if missing(`awvar') | `awvar' == 0
    local awopt "[aw=`awvar']"
}
else {
    quietly generate double `awvar' = 1 if `touse'
}

tempvar yg awnum awden evert everc time_g dy eventtime n_g n_gt
tempname w W0 bad_coef bad_Var b V Wcum Wsum D A0 A1 C

quietly egen `evert' = max(cond(`touse', `treatment', 0)), by(`group')
quietly egen `everc' = max(cond(`touse', `control', 0)), by(`group')

* no two treatment can happen to the same group
capture assert !(`evert' & `everc') if `touse'
if (_rc) {
    display in red "Some groups receive both treatments"
    inspect `group' if `evert' & `everc' & `touse'
    error(459)
}

quietly egen `time_g' = min(cond(`treatment' | `control', `time', .)) if `touse', by(`group')
* everyone receives treatment
capture assert !missing(`time_g')  if `touse'
if (_rc) {
    display in red "Some groups do not receive any treatment"
    inspect `group' if !`evert' & !`everc' & `touse'
    error(459)
}

quietly generate `eventtime' = `time' - `time_g'  if `touse'
quietly egen `n_gt' = count(1)  if `touse', by(`time_g' `time') 
quietly egen `n_g' = max(`n_gt')  if `touse', by(`time_g')

quietly levelsof `time_g'  if `touse', local(gs)
quietly levelsof `time'  if `touse', local(ts)

local G : word count `gs'
local T : word count `ts'
local N = `G' * (`T' - 1)

matrix `w' = J(`G', `T', 0.0)
forvalues g = 1/`G' {
    forvalues t = 2/`T' {
        local time_t : word `t' of `ts'
        local cohort : word `g' of `gs'
        local e = `time_t' - `cohort'
        if inrange(`e', -`pre', `post') {
            quietly summarize `awvar' if `time_g' == `cohort' & `touse' & `everc' & `time_t' == `time', meanonly
            scalar `A0' = r(sum)
            quietly summarize `awvar' if `time_g' == `cohort' & `touse' & `evert' & `time_t' == `time', meanonly
            scalar `A1' = r(sum)
            if ("`weighting'" == "equal") {
                * if either group has no positive weight, we cannot estimate a treatment effect
                matrix `w'[`g', `t'] = cond(`A0' * `A1' == 0, 0.0, 1.0)
            }
            if ("`weighting'" == "proportional") {
                matrix `w'[`g', `t'] = cond(`A0' * `A1' == 0, 0.0, `A0' + `A1')
            }
            if ("`weighting'" == "optimal") {
                matrix `w'[`g', `t'] = cond(`A0' * `A1' == 0, 0.0, `A0' * `A1' / (`A0' + `A1'))
            }
        }
    }
}

quietly egen `awnum' = total(cond(`eventtime' == -1, `awvar' * `y', .)) if `touse', by(`group')
quietly egen `awden' = total(cond(`eventtime' == -1, `awvar', .)) if `touse', by(`group')
capture assert `awden' > 0 if `touse'
if (_rc) {
    display in red "Some groups have no positive analytical weight in the baseline period"
    error 2000
}
quietly generate `yg' = `awnum' / `awden' if `touse'
quietly generate `dy' = `y' - `yg' if `touse'

capture drop _att_*
capture drop _base_*
forvalues g = 1/`G' {
    forvalues t = 2/`T' {
        local running_time : word `t' of `ts'
        local treatment_time : word `g' of `gs'
        quietly generate byte _att_`g'_`t' = cond(`time_g' == `treatment_time' & `time' == `running_time', `evert', 0) if `touse'
        quietly generate byte _base_`g'_`t' = cond(`time_g' == `treatment_time' & `time' == `running_time', `everc', 0) if `touse'
    }
}

***** This is the actual estimation
quietly reghdfe `dy' _att_*_* _base_*_* `awopt' if `touse', cluster(`cluster') nocons
matrix `bad_coef' = e(b)
matrix `bad_Var' = e(V)

local GT = `G' * (`T' - 1)
assert colsof(`bad_coef') == 2 * `GT'
assert colsof(`bad_Var') == 2 * `GT'

* convert treated and control means into cohort-time treatment effects
matrix `C' = (I(`GT') \ -I(`GT'))
matrix `bad_coef' = `bad_coef' * `C'
matrix `bad_Var' = `C'' * `bad_Var' * `C'

matrix `Wcum' = J(`GT', `K', 0)
local i = 1
forvalues g = 1/`G' {
    forvalues t = 2/`T' {
        local time_t : word `t' of `ts'
        local start : word `g' of `gs'
        local e = `time_t' - `start'
        if inrange(`e', -`pre', `post') {
            matrix `Wcum'[`i', `e' + `pre' + 1] = `w'[`g', `t']
        }
        local i = `i' + 1
    }
}
matrix `Wsum' = J(1, `GT', 1) * `Wcum' 
matrix `D' = diag(`Wsum')
matrix `Wcum' = `Wcum' * inv(`D')

tempvar esample
* exclude observations outside of the event window
quietly generate `esample' = e(sample) 
quietly replace `esample' = 0 if !`touse'
quietly count if `esample'
local Nobs = r(N)
******

capture drop _att_*
capture drop _base_*

if ("`baseline'" == "average") {
    matrix `W0' = I(`K') - (J(`K', `pre', 1/`pre'), J(`K', `post'+1, 0))
}
else if ("`baseline'" == "atet") {
    matrix `W0' = (J(1, `pre', -1/`pre'), J(1, `post'+1, 1/(`post'+1)))
}
else {
    if (!inrange(`baseline', -`pre', -1)) {
        display in red "Baseline must be between -`pre' and -1"
        error 198
    }
    matrix `W0' = I(`K')
    local bl = `pre' + `baseline' + 1
    forvalues i = 1/`K' {
        matrix `W0'[`i', `bl'] = `W0'[`i', `bl'] - 1.0
    }
}
matrix `b' = `bad_coef' * `Wcum' * `W0''
matrix `V' = `W0' * `Wcum'' * `bad_Var' * `Wcum' * `W0''
if ("`baseline'" == "atet") {
    local colnames "ATET"
}
else {
    * label coefficients
    forvalues t = -`pre'/`post' {
        local colnames `colnames' `t'
    }
}
matrix colname `b' = `colnames'
matrix colname `V' = `colnames'
matrix rowname `V' = `colnames'

local level 95
tempname coefplot
matrix `coefplot' = J(`K', 4, .)
matrix colname `coefplot' = xvar b ll ul
local tlabels ""
forvalues t = -`pre'/`post' {
    local tlabels `tlabels' `t'
    local i = `t' + `pre' + 1
    matrix `coefplot'[`i', 1] = `t''
    matrix `coefplot'[`i', 2] = `b'[1, `i']
    matrix `coefplot'[`i', 3] = `b'[1, `i'] + invnormal((100-`level')/200) * sqrt(`V'[`i', `i'])
    matrix `coefplot'[`i', 4] = `b'[1, `i'] - invnormal((100-`level')/200) * sqrt(`V'[`i', `i'])
}

ereturn post `b' `V', obs(`Nobs') esample(`esample')
ereturn local depvar `y'
ereturn local cmd xt2treatments
ereturn local cmdline xt2treatments `0'
if ("`weight'" != "") {
    ereturn local wtype "`weight'"
    ereturn local wexp "`exp'"
}

_coef_table_header, title(Event study relative to `baseline') width(62)
display
_coef_table, bmat(e(b)) vmat(e(V)) level(`level') 	///
    depname(`depvar') coeftitle(ATET)

if ("`graph'" == "graph") {
    hetdid_coefplot, mat(`coefplot') title(Event study relative to `baseline') ///
        ylb(`y') xlb("Length of exposure to the treatment") ///
        yline(0) legend(off) level(`level') yline(0,  extend) ytick(0, add) ylabel(0, add) xlabel(`tlabels')
}

end

