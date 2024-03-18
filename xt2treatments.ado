program xt2treatments, eclass
syntax varname, treatment(varname) control(varname) [if] [in]
* read panel structure
xtset
local group = r(panelvar)
local time = r(timevar)
local y `varname'

tempvar yg  evert everc time_g dy

egen `evert' = max(`treatment'), by(`group')
egen `everc' = max(`control'), by(`group')

* no two treatment can happen to the same group
assert !(`evert' & `everc')

egen `time_g' = min(cond(`treatment' | `control', `time' - 1, .)), by(`group')
* everyone receives treatment
assert !missing(`time_g')

levelsof `time_g', local(gs)
levelsof `time', local(ts)

egen `yg' = mean(cond(`eventtime' == -1, `y', .)), by(`group')
generate `dy' = `y' - `yg'

foreach g in `gs' {
    foreach t in `ts' {
        generate att_`g'_`t' = cond(`time' == `t' & `group' == `g', `evert', 0)
    }
}
reghdfe `dy' att_*, a(`time_g'##`time') cluster(`group')
end