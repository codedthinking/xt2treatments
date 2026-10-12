clear all
set more off
set seed 9732

do "xt2treatments.ado"

set obs 160
generate long i = ceil(_n / 5)
generate byte t = mod(_n - 1, 5) + 1
generate byte cohort = cond(i <= 16, 3, 4)
generate byte treated = mod(i, 2)
generate byte treatment = treated & t >= cohort
generate byte control = !treated & t >= cohort
generate byte eventtime = t - cohort
generate double effect = 0
replace effect = 2 if cohort == 3 & eventtime == 0
replace effect = 4 if cohort == 3 & eventtime == 1
replace effect = 6 if cohort == 3 & eventtime == 2
replace effect = 10 if cohort == 4 & eventtime == 0
replace effect = 20 if cohort == 4 & eventtime == 1
generate double noise = (mod(floor((i - 1) / 2), 4) - 1.5) * (t != cohort - 1) / 10
generate double y = treated * effect + noise
generate double aw = cond(cohort == 4 & treated, 3, 1)
generate double aw_scaled = 10 * aw
generate double one = 1
xtset i t

* Unit analytical weights reproduce unweighted estimates and covariance.
quietly xt2treatments y [aw=one], treatment(treatment) control(control) pre(1) post(2) weighting(proportional)
matrix b_one = e(b)
matrix V_one = e(V)
assert "`e(wtype)'" == "aweight"
assert "`e(wexp)'" == "= one"
quietly xt2treatments y, treatment(treatment) control(control) pre(1) post(2) weighting(proportional)
matrix b_unweighted = e(b)
matrix V_unweighted = e(V)
mata: st_numscalar("b_diff", max(abs(st_matrix("b_unweighted") :- st_matrix("b_one"))))
mata: st_numscalar("V_diff", max(abs(st_matrix("V_unweighted") :- st_matrix("V_one"))))
assert b_diff < 1e-10
assert V_diff < 1e-10

* Analytical weights enter proportional cohort-time aggregation.
quietly xt2treatments y [aw=aw], treatment(treatment) control(control) pre(1) post(2) weighting(proportional)
matrix b_proportional = e(b)
assert abs(b_proportional[1, 2] - 22/3) < 1e-6
assert abs(b_proportional[1, 3] - 44/3) < 1e-6
assert abs(b_proportional[1, 4] - 6) < 1e-6

* Analytical weights enter optimal cohort-time aggregation.
quietly xt2treatments y [aw=aw], treatment(treatment) control(control) pre(1) post(2) weighting(optimal)
matrix b_optimal = e(b)
assert abs(b_optimal[1, 2] - 34/5) < 1e-6
assert abs(b_optimal[1, 3] - 68/5) < 1e-6
assert abs(b_optimal[1, 4] - 6) < 1e-6

* Scaling all analytical weights leaves estimates and covariance unchanged.
matrix V_aw = e(V)
quietly xt2treatments y [aw=aw_scaled], treatment(treatment) control(control) pre(1) post(2) weighting(optimal)
matrix b_scaled = e(b)
matrix V_scaled = e(V)
mata: st_numscalar("b_scale_diff", max(abs(st_matrix("b_optimal") :- st_matrix("b_scaled"))))
mata: st_numscalar("V_scale_diff", max(abs(st_matrix("V_aw") :- st_matrix("V_scaled"))))
assert b_scale_diff < 1e-10
assert V_scale_diff < 1e-10

* Zero and missing weights exclude observations from every calculation.
generate double aw_zero = aw
replace aw_zero = 0 if i == 1
quietly xt2treatments y [aw=aw_zero], treatment(treatment) control(control) pre(1) post(2) weighting(optimal)
quietly count if e(sample) & i == 1
assert r(N) == 0
matrix b_zero = e(b)
matrix V_zero = e(V)
quietly xt2treatments y [aw=aw] if i != 1, treatment(treatment) control(control) pre(1) post(2) weighting(optimal)
mata: st_numscalar("b_zero_diff", max(abs(st_matrix("b_zero") :- st_matrix("e(b)"))))
mata: st_numscalar("V_zero_diff", max(abs(st_matrix("V_zero") :- st_matrix("e(V)"))))
assert b_zero_diff < 1e-10
assert V_zero_diff < 1e-10

generate double aw_missing = aw
replace aw_missing = . if i == 2
quietly xt2treatments y [aw=aw_missing], treatment(treatment) control(control) pre(1) post(2) weighting(optimal)
quietly count if e(sample) & i == 2
assert r(N) == 0
matrix b_missing = e(b)
matrix V_missing = e(V)
quietly xt2treatments y [aw=aw] if i != 2, treatment(treatment) control(control) pre(1) post(2) weighting(optimal)
mata: st_numscalar("b_missing_diff", max(abs(st_matrix("b_missing") :- st_matrix("e(b)"))))
mata: st_numscalar("V_missing_diff", max(abs(st_matrix("V_missing") :- st_matrix("e(V)"))))
assert b_missing_diff < 1e-10
assert V_missing_diff < 1e-10

* Negative analytical weights fail before estimation.
replace aw = -1 if i == 1 & t == 1
capture noisily xt2treatments y [aw=aw], treatment(treatment) control(control) pre(1) post(2) weighting(optimal)
assert _rc == 402

display "ANALYTICAL_WEIGHT_TESTS_PASSED"
