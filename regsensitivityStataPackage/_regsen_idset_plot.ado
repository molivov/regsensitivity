*! version 1.2.0 Paul Diegert, Matt Masten, Alex Poirier 29sept24

// PROGRAM: Plot Identified Set
// DESCRIPTION: Post-estimation command to plot identified set
// INPUTS: [see help]
program _regsen_idset_plot
	
	version 15
	
	syntax [anything] [, noBreakdown ///
			     boundpatterns(string) /// 
			     boundcolors(string) ///
			     boundoptions(string) ///
			     breakdownoptions(string) ///
			     title(string asis) subtitle(string asis) ///
			     xtitle(string) ytitle(string) ///
			     graphregion(string) bgcolor(string) ///
			     ylabel(string) yrange(numlist) ywidth(integer -1) ///
			     name(string) ///
			     legoptions(string) ///
			     noLEGend *]		
	
	local oster 0
	if "`e(sparam1)'" == "Delta" {
		local oster 1
	}
	matrix idset = e(idset)
	/* if `oster' {
		matrix idset = e(idset1)
	} 
	else {
		matrix idset = e(idset)	
	} */

	// =========================================================================
	// 1. Temp names
	// =========================================================================
	
	tempname idset bmed stdx idset_beta_only
	tempfile active_data
	
	quietly save `active_data'
	quietly clear
	
	// =========================================================================
	// 2. Process input
	// =========================================================================
	
	if "`e(sparam1_option)'" == "eq" & `ywidth' < 0 & "`yrange'" == ""{
		// if plotting oster with equal, get the range in the 
		// calculated results if nothing else specified
		matrix `idset' = idset
		mata: yrange = minmax(st_matrix("`idset'"))
		mata: st_local("yrange", strofreal(yrange[1]) + ///
		                         " " + strofreal(yrange[2]))
	}
	else if `ywidth' < 0{
		// if ywidth not given and not plotting oster equal, get the
		// width as the 95th percentile of the values
		matrix `idset' = idset
		local varx = e(sumstats)["Var(X)", 1]
		local beta_med = e(sumstats)["Beta(medium)", 1]
		matrix `idset_beta_only' = `idset'[1..., "bmin".."bmax"]
		mata: ywidth = ywidth_default(st_matrix("`idset_beta_only'"), `varx', `beta_med', .95)
		mata: st_local("ywidth", strofreal(ywidth))
	}
	if "`yrange'" != ""{
		// use yrange directly if given
		tokenize `yrange'
		local ymin `1'
		local ymax `2'
		local ylabmin = ceil(`ymin')
		local ylabmax = floor(`ymax')
		local ylabmid = round(e(sumstats)["Beta(medium)", 1])
		if !(`ylabmid' < `ylabmax' & `ylabmid' > `ylabmin'){
			local ylabmid 
		}
		else{
			local labdist = min(`ylabmax' - `ylabmid', `ylabmid' - `ylabmin')
			local labdistmax = `ylabmax' - `ylabmin'
			if `labdist' < `labdistmax' * .05{
				local ylabmid 
			} 
		}
		local ylabel "`ylabmin' `ylabmid' `ylabmax', norescale nogrid angle(0) notick"
	}
	else {
		// otherwise get yrange from ywidth
		scalar `stdx' = sqrt(e(sumstats)["Var(X)", 1])
		scalar `bmed' = e(sumstats)["Beta(medium)", 1]
		local ylabmid = round(`bmed')
		local ylabwidth = floor(`stdx' * `ywidth')
		local ylabmin = `ylabmid' - `ylabwidth'
		local ylabmax = `ylabmid' + `ylabwidth'
		local ymin = `bmed' - (`stdx' * `ywidth')
		local ymax = `bmed' + (`stdx' * `ywidth')
		local ylabel "`ylabmin' `ylabmid' `ylabmax', nogrid angle(0) notick"

	}
	
	local n_nonscalar_params : word count `e(nonscalar_sparam)'
	
	if (`e(sparam_product)') &  (`n_nonscalar_params' > 1){
		local i = 1
		foreach param in `e(nonscalar_sparam)' {
			matrix `idset' = idset
			matrix `idset' = `idset'[1..., "`param'"]
			mata: idset = st_matrix("`idset'")
			mata: vals = uniqrows(idset)
			mata: st_matrix("sparam`i'_vals", vals)
			mata: st_local("nsparam`i'", strofreal(rows(vals)))
			local i = `i' + 1
		}
	}
	else { 
		local nsparam1 = rowsof(idset)
		local nsparam2 = 1
	}
	
	// default to no legend
	local leg `"legend(off)"'
	if "`legoptions'" == ""{
		local legoptions pos(3) cols(1) subtitle(`e(sparam2)')
	}
	else {
		local legoptions `legoptions' subtitle(`e(sparam2)') 
	}
	
	// process breakdown point
	if "`breakdown'" == ""{
		local yl = `e(hypoval)'
		if `yl' >= . {
			local yl = 0
		}
		if "`breakdownoptions'" == ""{
			local breakdownline `"yline(`yl',lcolor(black) lwidth(vthin)) "'
		}
		else {
			local breakdownline `"yline(`yl', `breakdownoptions') "'
		}
	}

	
	// process line patterns and colors for bounds
	if "`boundpatterns'" == ""{
		local boundpatterns solid dash dot dash_dot shortdash /*
		*/shortdash_dot longdash longdash_dot "_-" /*
		*/"_--" "_-#.-"
	}
	else {
		local npatterns : word count `boundpatterns'
		if `npatterns' == 1 {
			local b `boundpatterns'
			local boundpatterns `b' `b' `b' `b' `b' `b' `b' `b' `b' `b' `b'
		}
	}
	if "`boundcolors'" == ""{
		local boundcolors gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0 gs0
	}
	else {
		local ncolors : word count `boundpatterns'
		if `ncolors' == 1 {
			local b `boundcolors'
			local boundcolors `b' `b' `b' `b' `b' `b' `b' `b' `b' `b' `b'
		}
	}
	
	// process legend for multiple plots
	if `nsparam2' > 1 {
		forvalues i= 1/`nsparam2' {
			local cval = sparam2_vals[`i', 1]
			local line_num = `i' * 2
			local leg_lab `"`leg_lab' label(`line_num' "`cval'") "'
			local leg_ord `"`leg_ord' `line_num'"'
		}
		local leg `"legend(order(`leg_ord') `leg_lab' `legoptions'"'
		if !regexm(`"`leg'"', " pos\(.*\)") {
			local leg `"`leg' pos("bottom")"'
		}
		local leg `"`leg')"'
	}
	
	
	// title default (note: this is a hack because you can't include
	// notitle and title(string) as options - they both use the title macro,
	// instead this will manually check the extra options for a notitle option)
	local notitle_name notitle
	local notitle: list notitle_name in options
	if `notitle' {
		local options: list options - notitle_name
	}
	if `"`subtitle'"' != "" | `"`title'"' != "" {
		break
	}
	else if `notitle'{
		local subtitle 
	}
	else if "`e(analysis)'" == "DMP (2022)" {
		local subtitle `""Regression Sensitivity Analysis (DMP 2022), Bounds""' 
	}
	else if "`e(analysis)'" == "Oster (2019)"{
		local subtitle `""Regression Sensitivity Analysis (Oster 2019), Bounds ""' 
	} 
	
	// process overall display options with defaults
	local poptions xtitle ytitle /*
	             */graphregion plotregion /*
		     */ylabel yscale /*
		     */xlabel xscale /*
		     */name
	local defaults `e(sparam1)' `e(param)' /*
	             */"color(white)" "color(white) margin(b=3 l=0 t=3 r=0)" /*
	             */",nogrid angle(0) notick" "extend" /*
		     */",nogrid angle(0) notick" "noextend" /*
		     */`e(param)' 
	local noptions : word count `poptions'
	forvalues i = 1/`noptions'{
		local option : word `i' of `poptions'
		local default : word `i' of `defaults'
		if "``option''" == ""{
			local `option' `default'
		}
	}
	
	// process additional formatting options
	// NOTE: the syntax of combining graphs (using ||) seems to be sensitive 
	//       to an extra space so need to have no space if there are no options 
	//       but a space after the options if there are.
	if `"`'options'"' != ""{
		local options "`options' "
	}
	
	// Overide to drop legend if option specified
	if "`legend'" == "nolegend" {
		local leg `"legend(off)"'
	}
	
	local plotspecs title(`title') subtitle(`subtitle') xtitle(`xtitle') ytitle(`ytitle') /*
		   */ graphregion(`graphregion') plotregion(`plotregion') /*
		   */ ylabel(`ylabel') yscale(`yscale') /* 
		   */ name(`name', replace) /*
		   */ `options'	/*
		   */ `breakdownline'

	
	
	// =========================================================================
	// 3. Main plot
	// =========================================================================
	
	// sparam2
	if `oster' {
		local bmin_i 3
		local bmax_i 4
	}
	else {
		local bmin_i 4
		local bmax_i 5
	}

	if "`e(sparam1_option)'" == "eq" {
		local rmax = e(sparam2_vals)[1,1]
		plot_oster , rmax(`rmax') bmin(`ymin') bmax(`ymax') plotspecs(`plotspecs')
	}
	else {
		// save identified set values to active dataset
		forvalues i= 1/`nsparam2' {
			local st = (`i' - 1) * `nsparam1' + 1
			local en = `i' * `nsparam1'
			matrix `idset' = idset
			matrix `idset' = (`idset'[`st'..`en',1], `idset'[`st'..`en',`bmin_i'..`bmax_i'])
			matrix colnames `idset' = rx`i' lower`i' upper`i'
			quietly svmat `idset', names(col)
		}
	
		forvalues i=1/`nsparam2'{
			local lp : word `i' of `boundpatterns'
			local lc : word `i' of `boundcolors'
			local newplot_ub `"(line upper`i' rx`i', lc(`lc') lp(`lp') `boundoptions')"'
			local newplot_lb `"(line lower`i' rx`i', lc(`lc') lp(`lp') `boundoptions')"'
			local lineplots `"`lineplots' `newplot_ub' `newplot_lb'"'
			quietly replace lower`i' = . if lower`i' < `ymin'
			quietly replace upper`i' = . if upper`i' > `ymax'
		}
		
		twoway `lineplots', `plotspecs' `leg' xlabel(`xlabel') xscale(`xscale') 
				
	}
		
	quietly use `active_data', clear

end

// PROGRAM: Plot Identified Set for Oster (2019)
// DESCRIPTION: Plot identified set for setting where Delta = d exactly.
// IMPLEMENTATION NOTES:
//     - This is implemented by calculating the Beta -> Delta(Beta) function
//       and rotating it 90 degrees. However, a quirk of Stata is that switching
//       the axes is only possibly when using `twoway function`. Therefore, 
//       we input the Beta -> Delta(Beta) function directly as a function to
//       twoway.
//     - The range of Delta is set by the values in the call to regsensitivity bounds
//     - The range of Beta is also set by the values to the call to regsensitivity
//       bounds unless overriden by an input of `ywidth` or `yrange`.
program define plot_oster

	syntax , [rmax(real 1) dmin(real -1) dmax(real 1) /// 
	          bmin(real -5) bmax(real 5) plotspecs(string asis)] 
	
	local bs  = e(sumstats)[1, 1]
	local bm  = e(sumstats)[2, 1]
	local rs  = e(sumstats)[3, 1]
	local rm  = e(sumstats)[4, 1]
	local vy  = e(sumstats)[5, 1]
	local vx  = e(sumstats)[6, 1]
	local vxr = e(sumstats)[7, 1]
	
	local func ( 							///
			(`bm' - x) * (`rm' - `rs') * `vy' * `vxr'   	///
			+ (`bm' - x) * `vx' * `vxr' * 			///
			(`bs' - `bm')^2					///
			+ 2 * (`bm' - x)^2 * (`vxr' * 			///
			(`bs' - `bm') * `vx')				///
			+ ((`bm' - x)^3) * 				///
			((`vxr' * `vx' - `vxr'^2))			///
		) / (							///
			(`rmax' - `rm') * `vy' * (`bs' - `bm') * `vx'	///
			+ (`bm' - x) * (`rmax' - `rm') * `vy' * 	///
			  (`vx' - `vxr')				///
			+ ((`bm' - x)^2) * 				///
			  (`vxr' * (`bs' - `bm') * `vx')		///
			+ ((`bm' - x)^3) * 				///
			  (`vxr' * `vx' - `vxr'^2)			///
		)
	
	mata: dminmax = minmax(st_matrix("e(idset1)")[,1])
	mata: st_local("dmin", strofreal(dminmax[1]))
	mata: st_local("dmax", strofreal(dminmax[2]))
	
	local func cond(`func' < `dmax', `func', .)
	local func cond(`func' > `dmin', `func', .)
	
	local dlabl = ceil(`dmin')
	local dlabu = floor(`dmax')
	local dlab `dlabl' 0 `dlabu'
	
	matrix segs = (`bmin', e(roots), `bmax')
	local nsegs : colsof(segs)
	
	local deltaplots
	forvalues i=2/`nsegs'{
		local ld = segs[1, `=`i' - 1'] +.000001
		local ud = segs[1, `i'] - .000001
		local deltaplots `deltaplots' function y=`func', range(`ld' `ud') /*
		               */ n(1000) lwidth(.3) lcolor(black) horizontal
		if `i' < `nsegs' {
			local deltaplots `deltaplots' ||
		}
	}
	graph twoway `deltaplots' legend(off) xlabel(`dlab') n(1000) `plotspecs'
	
end

mata:

real colvector quantiles(
	real colvector y, 
	real colvector p
){
	ys = sort(y, 1)
	n = rows(ys)

	q = J(rows(p), 1, .)
	for (j = 1; j <= rows(p); j++){
	    i = 1
	    while((i/n) < p[j]) i++
	    q[j] = ys[i]
	}
	return(q)
}

real scalar ywidth_default(
	real matrix idset,
	real scalar varx,
	real scalar beta_med,
	real scalar p
){
	idset = select(idset, idset[,2] :< .)
	ywidth = quantiles(idset[,2], (p))
	ywidth = ((ywidth - beta_med) / sqrt(varx)) + .1 
	return(ywidth)
}

end


