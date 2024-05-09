{smcl}


{marker xt2treatments-estimates-event-studies-with-two-treatments}{...}
{title:{cmd:xt2treatments} estimates event studies with two treatments}


{marker syntax}{...}
{title:Syntax}

{text}{phang2}{cmd:xt2treatments} varname [{it:if}], {bf:treatment}(varname) {bf:control}(varname), [{bf:pre}(#) {bf:post}(#) {bf:baseline}({it:string}) {bf:weight}(varname) {bf:graph}]{p_end}


{pstd}{cmd:xt2treatments} estimates average treatment effects on the treated (ATT) when there are two treatments. The first treatment is the treatment of interest, and the second treatment is the control.{p_end}

{pstd}The package can be installed with{p_end}

{p 8 16 2}net install xt2treatments, from(https://raw.githubusercontent.com/codedthinking/xt2treatments/main/) replace


{marker options}{...}
{title:Options}


{marker options-1}{...}
{dlgtab:Options}

{synoptset tabbed}{...}
{synopthdr:Option}
{synoptline}
{synopt:{bf:treatment}}Dummy variable indicating the treatment of interest.{p_end}
{synopt:{bf:control}}Dummy variable indicating the control treatment.{p_end}
{synopt:{bf:pre}}Number of periods before treatment to include in the estimation (default 1){p_end}
{synopt:{bf:post}}Number of periods after treatment to include in the estimation (default 3){p_end}
{synopt:{bf:baseline}}Either a negative number between {cmd:-pre} and {cmd:-1} or {cmd:average}, or {cmd:atet}. If {cmd:-k}, the baseline is the kth period before the treatment. If {cmd:average}, the baseline is the average of the pre-treatment periods. If {cmd:atet}, the regression table reports the average of the post-treatment periods minus the average of the pre-treatment periods. Default is {cmd:-1}.{p_end}
{synopt:{bf:weight}}Variable to use as weights in the estimation.{p_end}
{synopt:{bf:graph} (optional)}Plot the event study graph with the default settings of {cmd:hetdid_coefplot}.{p_end}
{synoptline}


{marker background}{...}
{title:Background}

{pstd}{cmd:xthdidregress} estimates ATT against various control groups. However, it does not allow for two treatments.{p_end}

{pstd}When the control group is another treatment happening at the same time, the ATT is the difference between the treatment and the control.{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}The command returns, as part of {cmd:e()}, the coefficients and standard errors. See {cmd:ereturn list} after running the command. Typical post-estimation commands can be used, such as {cmd:outreg2} or {cmd:estout}.{p_end}


{marker authors}{...}
{title:Authors}

{text}{phang2}Miklós Koren (Central European University, {browse "https://koren.mk"}), {it:maintainer}{p_end}



{marker license-and-citation}{...}
{title:License and Citation}

{pstd}You are free to use this package under the terms of its {browse "https://github.com/codedthinking/xt2treatments/blob/main/LICENSE"}. If you use it, please cite the software package in your work:{p_end}

{text}{phang2}Koren, Miklós. (2024). XT2TREATMENTS - event study with two treatments (Version 0.1.0) [Computer software]{p_end}
