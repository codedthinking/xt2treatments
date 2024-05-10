*! version 0.8.1 10may2024
program xt2treatments, eclass
syntax varname [if], treatment(varname) control(varname) [, pre(integer 1) post(integer 3) baseline(string) weighting(string) graph]
if ("`baseline'" == "") {
    local baseline "-1"
}
if ("`weighting'" == "") {
    local weighting "equal"
}
local T1 = `pre'-1
local K = `pre'+`post'+1

marksample touse

* read panel structure
xtset
local group = r(panelvar)
local time = r(timevar)
local y `varlist'

tempvar yg  evert everc time_g dy eventtime n_g n_gt
tempname w W0 bad_coef bad_Var b V Wcum Wsum D  

quietly egen `evert' = max(cond(`touse', `treatment', 0)), by(`group')
quietly egen `everc' = max(cond(`touse', `control', 0)), by(`group')

* no two treatment can happen to the same group
assert !(`evert' & `everc') if `touse'

quietly egen `time_g' = min(cond(`treatment' | `control', `time', .)) if `touse', by(`group')
* everyone receives treatment
assert !missing(`time_g')  if `touse'
quietly generate `eventtime' = `time' - `time_g'  if `touse'
quietly egen `n_gt' = count(1)  if `touse', by(`time_g' `time') 
quietly egen `n_g' = max(`n_gt')  if `touse', by(`time_g')

quietly levelsof `time_g'  if `touse', local(gs)
quietly levelsof `time'  if `touse', local(ts)

local G : word count `gs'
local T : word count `ts'
local N = `G' * (`T' - 1)

tempname n1 n0
matrix `w' = J(`G', 1, .)
forvalues g = 1/`G' {
    local cohort : word `g' of `gs'
    if ("`weighting'" == "equal") {
        matrix `w'[`g', 1] = 1.0
    }
    if ("`weighting'" == "proportional") {
        quietly count if `time_g' == `cohort' & (`touse')
        matrix `w'[`g', 1] = r(N)
    }
    if ("`weighting'" == "optimal") {
        quietly count if `time_g' == `cohort' & (`touse') & `everc'
        scalar `n0' = r(N)
        quietly count if `time_g' == `cohort' & (`touse') & `evert'
        scalar `n1' = r(N)
        matrix `w'[`g', 1] = `n0' * `n1' / (`n0' + `n1')
    }
}

quietly egen `yg' = mean(cond(`eventtime' == -1, `y', .)) if `touse', by(`group')
quietly generate `dy' = `y' - `yg' if `touse'

capture drop _att_*
forvalues g = 1/`G' {
    forvalues t = 2/`T' {
        local running_time : word `t' of `ts'
        local treatment_time : word `g' of `gs'
        quietly generate byte _att_`g'_`t' = cond(`time_g' == `treatment_time' & `time' == `running_time', `evert', 0) if `touse'
    }
}

***** This is the actual estimation
quietly reghdfe `dy' _att_*_* if `touse', a(`time_g'##`time') cluster(`group') nocons
matrix `bad_coef' = e(b)
matrix `bad_Var' = e(V)

local GT = colsof(`bad_coef')

assert `GT' == `G' * `=`T'-1'
assert colsof(`bad_Var') == `GT'

matrix `Wcum' = J(`GT', `K', 0)
local i = 1
forvalues g = 1/`G' {
    forvalues t = 2/`T' {
        local time : word `t' of `ts'
        local start : word `g' of `gs'
        local e = `time' - `start'
        if inrange(`e', -`pre', `post') {
            matrix `Wcum'[`i', `e' + `pre' + 1] = `w'[`g', 1]
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

