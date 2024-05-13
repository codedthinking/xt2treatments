---
author: Koren, Miklós (https://koren.mk)
date: 2024-05-12
version: 0.8.3
title: XT2TREATMENTS - event study with two treatments
description: |
    Computes the average treatment effect on the treated (ATT), where the control is another treatment happening at the same time.
url: https://github.com/codedthinking/xt2treatments
requires: Stata version 18
---
# `xt2treatments` estimates event studies with two treatments


# Syntax

- `xt2treatments` varname [*if*], **treatment**(varname) **control**(varname), [**pre**(#) **post**(#) **baseline**(*string*) **weighting**(string) **graph**]

`xt2treatments` estimates average treatment effects on the treated (ATT) when there are two treatments. The first treatment is the treatment of interest, and the second treatment is the control. 

The package can be installed with
```
net install xt2treatments, from(https://raw.githubusercontent.com/codedthinking/xt2treatments/main/) replace
```

# Options
## Options
Option | Description
-------|------------
**treatment** | Dummy variable indicating the treatment of interest.
**control** | Dummy variable indicating the control treatment.
**pre** | Number of periods before treatment to include in the estimation (default 1)
**post** | Number of periods after treatment to include in the estimation (default 3)
**baseline** | Either a negative number between `-pre` and `-1` or `average`, or `atet`. If `-k`, the baseline is the kth period before the treatment. If `average`, the baseline is the average of the pre-treatment periods. If `atet`, the regression table reports the average of the post-treatment periods minus the average of the pre-treatment periods. Default is `-1`.
**weighting** | Method to weight different cohorts in the estimation.
**graph** (optional) | Plot the event study graph with the default settings of `hetdid_coefplot`.

## Weighting methods
Method | Description
-------|------------
**equal** (default) | Each cohort is weighted equally.
**proportional** | Cohorts are weighted linearly by the number of observations, (n0 + n1), where n0 is the number of controls, n1 is the number of treated units.
**optimal** | Cohorts are weighted by the inverse of the standard error of the treatment effect estimate of the cohort, (n0 * n1) / (n0 + n1).

# Examples
```
use test/testdata.dta, clear
xtset i t
xt2treatments y, treatment(treatmentB) control(treatmentA) pre(1) post(3) weighting(equal)
xt2treatments y, treatment(treatmentB) control(treatmentA) pre(3) post(3) weighting(optimal) graph
```

# Background
`xthdidregress` estimates ATT against various control groups. However, it does not allow for two treatments. 

When the control group is another treatment happening at the same time, the ATT is the difference between the treatment and the control. 

# Remarks
The command returns, as part of `e()`, the coefficients and standard errors. See `ereturn list` after running the command. Typical post-estimation commands can be used, such as `outreg2` or `estout`.

# Authors
- Miklós Koren (Central European University, https://koren.mk), *maintainer*

# License and Citation
You are free to use this package under the terms of its [license](https://github.com/codedthinking/xt2treatments/blob/main/LICENSE). If you use it, please cite the software package in your work:

- Koren, Miklós. (2024). XT2TREATMENTS - event study with two treatments [Computer software]. Avilable at https://github.com/codedthinking/xt2treatments
