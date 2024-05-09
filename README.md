---
author: Koren, Miklós (https://koren.mk)
date: 2024-05-09
version: 0.8.0
title: XT2TREATMENTS - event study with two treatments
description: |
    Computes the average treatment effect on the treated (ATT), where the control is another treatment happening at the same time.
url: https://github.com/codedthinking/xt2treatments
requires: Stata version 18
---
# `xt2treatments` estimates event studies with two treatments


# Syntax

- `xt2treatments` varname [*if*], **treatment**(varname) **control**(varname), [**pre**(#) **post**(#) **baseline**(*string*) **weight**(varname) **graph**]

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
**weight** | Variable to use as weights in the estimation.
**graph** (optional) | Plot the event study graph with the default settings of `hetdid_coefplot`.

# Background
`xthdidregress` estimates ATT against various control groups. However, it does not allow for two treatments. 

When the control group is another treatment happening at the same time, the ATT is the difference between the treatment and the control. 

# Remarks
The command returns, as part of `e()`, the coefficients and standard errors. See `ereturn list` after running the command. Typical post-estimation commands can be used, such as `outreg2` or `estout`.

# Authors
- Miklós Koren (Central European University, https://koren.mk), *maintainer*

# License and Citation
You are free to use this package under the terms of its [license](https://github.com/codedthinking/xt2treatments/blob/main/LICENSE). If you use it, please cite the software package in your work:

- Koren, Miklós. (2024). XT2TREATMENTS - event study with two treatments (Version 0.1.0) [Computer software]
