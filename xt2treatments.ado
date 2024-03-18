*! version 0.2.0 18mar2024
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

tempvar yg  evert everc time_g dy
tempname Wevent W0 attgt colsum bad_coef bad_Var b V summation

quietly egen `evert' = max(`treatment'), by(`group')
quietly egen `everc' = max(`control'), by(`group')

* no two treatment can happen to the same group
assert !(`evert' & `everc')

quietly egen `time_g' = min(cond(`treatment' | `control', `time', .)), by(`group')
* everyone receives treatment
assert !missing(`time_g')

quietly levelsof `time_g', local(gs)
quietly levelsof `time', local(ts)

quietly egen `yg' = mean(cond(`time' == `time_g' - 1, `y', .)), by(`group')
quietly generate `dy' = `y' - `yg'

capture drop att_*_*
local G : word count `gs'
local T : word count `ts'
local GT = `G' * `T'
foreach g in `gs' {
    foreach t in `ts' {
        quietly generate byte att_`g'_`t' = cond(`time' == `t' & `time_g' == `g', `evert', 0)
    }
}

***** This is the actual estimation
quietly reghdfe `dy' att_*_*, a(`time_g'##`time') cluster(`group') nocons
matrix `bad_coef' = e(b)
matrix `bad_Var' = e(V)
tempvar esample
* exclude observations outside of the event window
quietly generate `esample' = e(sample) & inrange(`time' - `time_g', -`pre', `post')
quietly count if `esample'
local Nobs = r(N)
******

capture drop att_*_*
local names : colfullnames(`bad_coef'), quoted

matrix `Wevent' = J(`GT', `K', 0.0)
matrix rownames `Wevent' = `names'
local i = 0
foreach g in `gs' {
    foreach t in `ts' {
        local i = `i' + 1
        local e = `t' - `g'
        local j = `e' + `pre' + 1
        if (`j' > 0) & (`j' <= `K') {
            matrix `Wevent'[`i', `j'] = 1.0
        }
    }
}
* each column should sum to 1 so that the matrix computes an average
matrix `summation' = J(`GT', `GT', 1)
matrix `colsum' = `summation' * `Wevent'
* do elementwise division
forvalues row = 1/`GT' {
    forvalues col = 1/`K' {
        matrix `Wevent'[`row', `col'] = `Wevent'[`row', `col'] / `colsum'[`row', `col']
    }
}

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
matrix `b' = `bad_coef' * `Wevent' * `W0''
matrix `V' = `W0' * `Wevent'' * `bad_Var' * `Wevent' * `W0''

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