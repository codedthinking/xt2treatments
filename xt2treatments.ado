*! version 0.5.0 28mar2024
program xt2treatments, eclass
syntax varname, treatment(varname) control(varname) [, pre(integer 1) post(integer 3) baseline(string) ]
if ("`baseline'" == "") {
    local baseline "-1"
}   
local T1 = `pre'-1
local K = `pre'+`post'+1

* read panel structure
xtset
local group = r(panelvar)
local time = r(timevar)
local y `varlist'

tempvar yg  evert everc time_g dy eventtime n_g n_gt pw
tempname Wevent W0 attgt colsum bad_coef bad_Var b V summation

quietly egen `evert' = max(`treatment'), by(`group')
quietly egen `everc' = max(`control'), by(`group')

* no two treatment can happen to the same group
assert !(`evert' & `everc')

quietly egen `time_g' = min(cond(`treatment' | `control', `time', .)), by(`group')
* everyone receives treatment
assert !missing(`time_g')
quietly generate `eventtime' = `time' - `time_g'
quietly egen `n_gt' = count(1), by(`time_g' `time')
quietly egen `n_g' = max(`n_gt'), by(`time_g')
quietly generate `pw' = `n_g' / `n_gt'

quietly levelsof `time_g', local(gs)
quietly levelsof `time', local(ts)

quietly egen `yg' = mean(cond(`eventtime' == -1, `y', .)), by(`group')
quietly generate `dy' = `y' - `yg'

capture drop _att_*
forvalues t = `pre'(-1)1 {
    quietly generate byte _att_m`t' = cond(`eventtime' == -`t', `evert', 0)
}
forvalues t = 0(1)`post' {
    quietly generate byte _att_`t' = cond(`eventtime' == `t', `evert', 0)
}

***** This is the actual estimation
quietly reghdfe `dy' _att_* if inrange(`eventtime', -`pre', `post'), a(`eventtime') cluster(`group') nocons
matrix `bad_coef' = e(b)
matrix `bad_Var' = e(V)
tempvar esample
* exclude observations outside of the event window
quietly generate `esample' = e(sample) 
quietly count if `esample'
local Nobs = r(N)
******

capture drop _att_*
local names : colfullnames(`bad_coef'), quoted

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
matrix `b' = `bad_coef' * `W0''
matrix `V' = `W0' * `bad_Var' * `W0''
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

ereturn post `b' `V', obs(`Nobs') esample(`esample')
ereturn local depvar `y'
ereturn local cmd xt2treatments
ereturn local cmdline xt2treatments `0'

_coef_table_header, title(Event study relative to `baseline') width(62)
display
_coef_table, bmat(e(b)) vmat(e(V)) level(`level') 	///
    depname(`depvar') coeftitle(ATET)
end
