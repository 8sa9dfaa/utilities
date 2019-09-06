#pragma rtGlobals=1		// Use modern global access method.
#pragma hide=1

 //   XPST - a macro package for peak fitting with Igor Pro
 //   Copyright (C) 2011  Martin Schmid, University Erlangen

//Fit function definition

//The gauss curves are defined in the following way:
//				
//  [ Area *  sqrt{ 4ln(2) / (pi) }   / fwhm  ] * exp( - 4ln(2) * { ( x-x0 ) / fwhm }^2 )  =  Amplitude*exp( - { (x-x0) / width }^2 )
//
//this is possible since the area of a Gauss curve is:    Amplitude*width*sqrt(pi)

//Functions in this file
// Gauss1    to    Gauss4
// VoigtGLS1 to VoigtGLS4



function FitMultiVoigtSK(pw,yw,xw): FitFunc
	wave pw, yw, xw
	duplicate /o yw ShirleyStep  //this wave needs to be removed after the fit has completed
	wave ShirleyStep = ShirleyStep
	duplicate /o yw HGB
	wave hgb=HGB
	duplicate /o yw individualPeak
	wave peak = individualPeak
	
	variable i, index
	variable numPeaks = (numpnts(pw)-5)/6    //use the length of the coefficient wave
	variable totalArea
	variable FWHMoffset = 0 //  0.00001
	variable partialArea =0
	variable pointlength
	variable temp
	variable areaPeak
	yw = 0
	
	
	variable faulty = 0   //this one marks, if there was something wrong
	NVAR reported = root:STFitAssVar:WrongReported   //this one marks, if the wrong set has been reported so far
	
	for (i = 0; i < numPeaks; i +=1)
	index = 6*i +5
		if (pw[index] < 0 || pw[index+2] < 0 || pw[index+3] < -0.001 || pw[index+3] >1.001) 
			
			if (reported == 0)
			//DoAlert 0, "The parameter values went bad during the fit, maybe you optimize too many parameters at once?\rThe faulty parameter set was sent to the command line"
				print " "
				print "Problematic parameters: Area, Width <0 and GLratio outside the interval [0,1]."
				print " "
				print "Peak/Multiplet #          ", i+1
				print "----------------------------------------------"
				print "Area (normalized)         ", pw[index]
				print "Position                       ", pw[index+1]
				print "Width                          ", pw[index+2]
				print "GLratio                        ", pw[index+3]
				print "Asymmetry                  ", pw[index+4]
				print "Asymmetry Translation ", pw[index+5]
				print " "
				
			endif
			faulty = 1
		endif
	endfor
	
	if (faulty != 0)
		if (reported ==0)
			DoAlert 0, "Some of the parameters took physically wrong values during the fit, maybe you optimize too many parameters at once?\rHowever, the fit may still recover ....\rThe faulty parameter set was sent to the command line."		
			print "For a stable fit you should hold as many parameters as possible constant. If you let everything open for variation, you get a very unstable fit."
			print "The following situation is the most stable one: 'GL-ratio', 'Asymmetry', and 'Asymmetry Translation' frozen."
			print "The GL ratio is particularly 'fragile', optimize this one only if you already got a decent fit as start value. Also use the Asymmetry Translation not too liberally."
			print " "
			print "If the parameters take physically not justified values during the fit, the function changes its appearance significantly! "	
		endif
		reported = 1
	//	killwaves /Z ShirleyStep,HGB, individualPeaks
	//	yw = Nan
	//	return 0
	endif
	

	//those are only the peaks
	for (i = 0; i < numPeaks; i +=1)
		index = 6*i +5

		temp = pw[index + 3]// 0.02 + 0.98* ((pw[index+3]) - floor((pw[index+3])) )   //exactly 0 or 1 are really bad
		

		//pw[index] = abs(pw[index])
		//pw[index+2] = (pw[index+2]) + 0.001
		peak = 0
		peak += (temp>=0)*(temp)* ( 2  / pi ) * ( ( 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) / ( (  2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) )^2 + 4 * ( xw - pw[index+1] )^2 ) )  
		peak += (temp <= 1)*(1 - temp) * (1 / ( gPf * ( 2 * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] ) / ( 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) )^2 ) 
		if (abs(pw[index+4]) > 0.1)  //otherwise it is normalized anyway
			areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1],pw[index+2],pw[index+3],pw[index+4],pw[index+5])
			if (numtype(areaPeak)==0)
					peak /= areaPeak
			else
				 peak = 0
				 continue
			endif
			peak *= integrationCorrection* pw[index]
		else
			peak *= pw[index]  //this correction factor accounts for the limited accuracy of the numerical integration here
		endif
		
		yw += peak
	endfor
	
	
	pointLength = numpnts(yw)
	//print "Laenge der yw:", pointLength
	totalArea = sum(yw) 
	partialArea = 0		
	if (xw[0] < xw[2] )  //binding energy increases with point index
		for (i=0; i<pointLength; i += 1) 

			partialArea += abs(yw[i]) 
			if (totalArea > 0)
				ShirleyStep[i] =partialArea/totalArea
			endif
		endfor
	else                     //binding energy decreases with point index
		for (i=0; i<pointLength; i += 1)
			partialArea += abs(yw[pointLength-1-i])
			if (totalArea >0)
				ShirleyStep[pointLength-1-i] =partialArea/totalArea 
			endif
		endfor
	endif
	
	
	//for ( i = 0; i < numPeaks; i += 1)
	//index = 6*i +5
	//yw += 1e-3*pw[3]*pw[index]*(xw-pw[index+1])^2*(xw>pw[index+1])
	//endfor
	
	//integrate the shirely step again to obtain the HGBackground with the parameter pw[3]
	partialArea = 0
	totalArea = sum(ShirleyStep) 
	if (xw[0] < xw[2] )   //binding energy increases with point index
		for ( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[i])
			hgb[i] = partialArea/totalArea	
		endfor
	else                     //binding energy decreases with point index
		for( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[pointLength-1-i])
			hgb[pointLength-1-i] = partialArea/totalArea	
		endfor
	endif
	
	//hgb *= pw[3]
	//ShirleyStep *= pw[4]
	yw +=  pw[3]*hgb
	yw +=  pw[4]*ShirleyStep   //this is necessary, as bgywStart always comes in a range between 0 and 1
	////and now the slope
	yw += pw[0]  + pw[1]*xw + pw[2]*xw^2
	//print numpnts(yw)
//	for (i=0; i<numpnts(yw); i +=1)
	//	temp=yw[i]
	//	if (numtype(temp) != 0)
	//		print "Nan detected"
	//		if (i==0) 
	//			yw[i]=yw[1]	
	//		else		
	//			yw[i]=yw[i-1]
	//		endif
	//	endif
//	endfor
	
 	killwaves /Z ShirleyStep,HGB,individualPeak
end




///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Doublet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Doublet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Doublet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Doublet



function FitDoubletVoigtSK(pw,yw,xw): FitFunc
	wave pw, yw, xw
	
	variable numCoef =9         ///////////// number of coefficients  Ext-Multiplet = 33
	variable numSubPeaks = 2  ///////////  number of coefficients  Ext-Multiplet = 10
	
	
	variable i, index
	variable numPeaks = (numpnts(pw)-5)/numCoef    //use the length of the coefficient wave      Ext-Multiplet  15->33
	

	
	variable totalArea
	variable FWHMoffset =  0 // 0.00001
	variable partialArea =0
	variable pointlength
	variable temp
	variable areaPeak = 0
	variable faulty = 0   //this one marks, if there was something wrong
	yw = 0
	NVAR reported = root:STFitAssVar:WrongReported   //this one marks, if the wrong set has been reported so far

	//fit a multiplet with 10 peaks  
	duplicate /o yw ShirleyStep  //this wave needs to be removed after the fit has completed
	wave ShirleyStep = ShirleyStep
	duplicate /o yw HGB
	wave hgb=HGB
	duplicate /o yw individualPeak
	wave peak=individualPeak
	
	
	
	//those are only the peaks
	for (i = 0; i < numPeaks; i +=1)
	index =numCoef*i +5  // Ext-Multiplet  15->33
		if (pw[index] < 0 || pw[index+2] < 0 || pw[index+3] < -0.001 || pw[index+3] >1.001) 
			
			if (reported == 0)
			//DoAlert 0, "The parameter values went bad during the fit, maybe you optimize too many parameters at once?\rThe faulty parameter set was sent to the command line"
				print " "
				print "Problematic parameters: Area, Width <0 and GLratio outside the interval [0,1]."
				print " "
				print "Peak/Multiplet #          ", i+1
				print "----------------------------------------------"
				print "Area (normalized)         ", pw[index]
				print "Position                       ", pw[index+1]
				print "Width                          ", pw[index+2]
				print "GLratio                        ", pw[index+3]
				print "Asymmetry                  ", pw[index+4]
				print "Asymmetry Translation ", pw[index+5]
				print " "
				
			endif
			faulty = 1
		endif
	endfor
	
	if (faulty != 0)
		if (reported ==0)
			DoAlert 0, "Some of the parameters took physically wrong values during the fit, maybe you optimize too many parameters at once?\rHowever, the fit may still recover ....\rThe faulty parameter set was sent to the command line."		
			print "For a stable fit you should hold as many parameters as possible constant. If you let everything open for variation, you get a very unstable fit."
			print "The following situation is the most stable one: 'GL-ratio', 'Asymmetry', and 'Asymmetry Translation' frozen."
			print "The GL ratio is particularly 'fragile', optimize this one only if you already got a decent fit as start value. Also use the Asymmetry Translation not too liberally."
			print " "
			print "If the parameters take physically not justified values during the fit, the function changes its appearance significantly! "	
		endif
		reported = 1
	//	killwaves /Z ShirleyStep,HGB, individualPeaks
	//	yw = Nan
	//	return 0
	endif
	
	//pw[index+12] != 0 &&  pw[index+4] >= 0.01 && pw[index+2]*pw[index+14] > 1e-3 && pw[index+3] > 1e-3 && pw[index+3] < 0.9999  && pw[index+5] < 10 
	for (i = 0; i < numPeaks; i +=1)
		index = numCoef*i +5     // Ext-Multiplet  15->33

		peak = 0


		temp = pw[index + 3] 
		
			peak += (temp >= 0 )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) / ( ( FWHMoffset + 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) )^2 + 4 * ( xw - pw[index+1] )^2 ) )  
			peak += ( temp <= 1  )*(1 - temp) * ((1) / ( gPf * ( 2 * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] ) / ( FWHMoffset + 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) )^2 ) 
			
			//if (pw[index+2]<0)
			//	peak = 0
			//	continue
			//endif
			
			if (pw[index+4] >= 0.01 )   //otherwise it is normalized anyway
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1],pw[index+2],pw[index+3],pw[index+4],pw[index+5])
				if (numtype(areaPeak)==0)
					peak /= areaPeak
				else 	
					//if this is the case, go to the next for iteration without adding this peak to yw
				 	continue
				endif
				peak *= integrationCorrection*pw[index]   //the integration is not from -inf to +inf, so the actual value is a bit larger
			else
				peak *= pw[index]
			endif
		
			yw += peak
			peak = 0
		
		
			//now add the second multiplet peak
			//pw[index+6] = ratio21
			//pw[index+7] = dist21
			//pw[index+8] = broad21
			peak += (temp >= 0  )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+8] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+8] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7]) ) ) )^2 + 4 * ( xw - pw[index+1] - pw[index+7] )^2 ) )  
			peak += ( temp <= 1 )*(1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+8] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+7]) / ( FWHMoffset + 2 * pw[index+8] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7] ) ) ) ) )^2 ) 
	
			if (pw[index+6] != 0 && abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+7],pw[index+2]*pw[index+8],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				
				peak *=  integrationCorrection*pw[index]*pw[index+6]
			else
				peak *= pw[index]*pw[index+6]
			endif
			yw += peak
			peak =0
			
			
	
	
	
	endfor
	
	
	pointLength = numpnts(yw)
	//print "Laenge der yw:", pointLength
	totalArea = sum(yw)  //to avoid division by zero
	partialArea = 0		
	if (xw[0] < xw[2] )  //binding energy increases with point index
		for (i=0; i<pointLength; i += 1) 

			partialArea += abs(yw[i]) 
			if (totalArea > 0 )
			ShirleyStep[i] =partialArea/totalArea
			endif
		endfor
	else                     //binding energy decreaeses with point index
		for (i=0; i<pointLength; i += 1)
			partialArea += abs(yw[pointLength-1-i])
			if (totalArea >0)
				ShirleyStep[pointLength-1-i] =partialArea/totalArea 
			endif
		endfor
	endif
	
	
	//integrate the shirely step again to obtain the HGBackground with the parameter pw[3]
	partialArea = 0
	totalArea = sum(ShirleyStep) 
	if (xw[0] < xw[2] )   //binding energy increases with point index
		for ( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[i])
			if (totalArea > 0)
				hgb[i] = partialArea/totalArea	
			endif
		endfor
	else                     //binding energy decreaeses with point index
		for( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[pointLength-1-i])
			if (totalArea > 0)
				hgb[pointLength-1-i] = partialArea/totalArea
			endif	
		endfor
	endif
	

	yw +=  pw[3]*hgb
	yw +=  pw[4]*ShirleyStep   //this is necessary, as bgywStart always comes in a range between 0 and 1
	////and now the slope
	yw += pw[0]  + pw[1]*xw + pw[2]*xw^2

 	killwaves /Z ShirleyStep,HGB, individualPeaks
end













///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Multiplet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Multiplet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Multiplet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Multiplet


function FitMultipletVoigtSK(pw,yw,xw): FitFunc
	wave pw, yw, xw
	
	variable i, index
	variable numPeaks = (numpnts(pw)-5)/15    //use the length of the coefficient wave
	variable totalArea
	variable FWHMoffset =  0 // 0.00001
	variable partialArea =0
	variable pointlength
	variable temp
	variable areaPeak = 0
	variable faulty = 0   //this one marks, if there was something wrong
	yw = 0
	NVAR reported = root:STFitAssVar:WrongReported   //this one marks, if the wrong set has been reported so far

	//fit a multiplet with 4 peaks
	duplicate /o yw ShirleyStep  //this wave needs to be removed after the fit has completed
	wave ShirleyStep = ShirleyStep
	duplicate /o yw HGB
	wave hgb=HGB
	duplicate /o yw individualPeak
	wave peak=individualPeak
	
	
	
	//those are only the peaks
	for (i = 0; i < numPeaks; i +=1)
	index =15*i +5
		if (pw[index] < 0 || pw[index+2] < 0 || pw[index+3] < -0.001 || pw[index+3] >1.001) 
			
			if (reported == 0)
			//DoAlert 0, "The parameter values went bad during the fit, maybe you optimize too many parameters at once?\rThe faulty parameter set was sent to the command line"
				print " "
				print "Problematic parameters: Area, Width <0 and GLratio outside the interval [0,1]."
				print " "
				print "Peak/Multiplet #          ", i+1
				print "----------------------------------------------"
				print "Area (normalized)         ", pw[index]
				print "Position                       ", pw[index+1]
				print "Width                          ", pw[index+2]
				print "GLratio                        ", pw[index+3]
				print "Asymmetry                  ", pw[index+4]
				print "Asymmetry Translation ", pw[index+5]
				print " "
				reported =1
			endif
			faulty = 1
		endif
	endfor
	
	if (faulty != 0)
		if (reported ==0)
			DoAlert 0, "Some of the parameters took physically wrong values during the fit, maybe you optimize too many parameters at once?\rHowever, the fit may still recover ....\rThe faulty parameter set was sent to the command line."		
			print "For a stable fit you should hold as many parameters as possible constant. If you let everything open for variation, you get a very unstable fit."
			print "The following situation is the most stable one: 'GL-ratio', 'Asymmetry', and 'Asymmetry Translation' frozen."
			print "The GL ratio is particularly 'fragile', optimize this one only if you already got a decent fit as start value. Also use the Asymmetry Translation not too liberally."
			print " "
			print "If the parameters take physically not justified values during the fit, the function changes its appearance significantly! "	
		endif
		reported = 1
	//	killwaves /Z ShirleyStep,HGB, individualPeaks
	//	yw = Nan
	//	return 0
	endif
	
	//pw[index+12] != 0 &&  pw[index+4] >= 0.01 && pw[index+2]*pw[index+14] > 1e-3 && pw[index+3] > 1e-3 && pw[index+3] < 0.9999  && pw[index+5] < 10 
	for (i = 0; i < numPeaks; i +=1)
		index = 15*i +5

		peak = 0


		temp = pw[index + 3] 
		
			peak += (temp >= 0 )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) / ( ( FWHMoffset + 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) )^2 + 4 * ( xw - pw[index+1] )^2 ) )  
			peak += ( temp <= 1  )*(1 - temp) * ((1) / ( gPf * ( 2 * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] ) / ( FWHMoffset + 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) )^2 ) 
			
			//if (pw[index+2]<0)
			//	peak = 0
			//	continue
			//endif
			
			if (pw[index+4] >= 0.01 )   //otherwise it is normalized anyway
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1],pw[index+2],pw[index+3],pw[index+4],pw[index+5])
				if (numtype(areaPeak)==0)
					peak /= areaPeak
				else 	
					//if this is the case, go to the next for iteration without adding this peak to yw
				 	continue
				endif
				peak *= integrationCorrection*pw[index]   //the integration is not from -inf to +inf, so the actual value is a bit larger
			else
				peak *= pw[index]
			endif
		
			yw += peak
			peak = 0
		
		
			//now add the second multiplet peak
			//pw[index+6] = ratio21
			//pw[index+7] = dist21
			//pw[index+8] = broad21
			peak += (temp >= 0  )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+8] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+8] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7]) ) ) )^2 + 4 * ( xw - pw[index+1] - pw[index+7] )^2 ) )  
			peak += ( temp <= 1 )*(1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+8] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+7]) / ( FWHMoffset + 2 * pw[index+8] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7] ) ) ) ) )^2 ) 
	
			if (pw[index+6] != 0 && abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+7],pw[index+2]*pw[index+8],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				
				peak *=  integrationCorrection*pw[index]*pw[index+6]
			else
				peak *= pw[index]*pw[index+6]
			endif
			yw += peak
			peak =0
		
			//now do the third peak
			//6 > 9
			//7 >10
			//8 > 11
			peak +=(temp >= 0 )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+11] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+10] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+11] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -pw[index+10]) ) ) )^2 + 4 * ( xw - pw[index+1]  -  pw[index+10] )^2 ) )  
			peak +=(temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+11] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+10]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] -  pw[index+10]) / ( FWHMoffset + 2 * pw[index+11] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  -pw[index+10] ) ) ) ) )^2 ) 
	
			if (pw[index+9] != 0  && abs(pw[index+4]) >= 0.01  )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+10],pw[index+2]*pw[index+11],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				
				peak *= integrationCorrection* pw[index]*pw[index+9]
			else
				peak *= pw[index]*pw[index+9]
			endif
			yw += peak
			peak = 0
			//and now the fourth
			// 9>12
			//10>13
			//11>14
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+14] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+13] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+14] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+13]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+13] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+14] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+13]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+13]) / ( FWHMoffset + 2 * pw[index+14] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+13] ) ) ) ) )^2 ) 
		
			if (pw[index+12] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+13],pw[index+2]*pw[index+14],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+12]
			else
				peak *= pw[index]*pw[index+12]
			endif
			
			
			yw += peak
			peak = 0
	
	endfor
	
	
	pointLength = numpnts(yw)
	//print "Laenge der yw:", pointLength
	totalArea = sum(yw)  //to avoid division by zero
	partialArea = 0		
	if (xw[0] < xw[2] )  //binding energy increases with point index
		for (i=0; i<pointLength; i += 1) 

			partialArea += abs(yw[i]) 
			if (totalArea > 0 )
			ShirleyStep[i] =partialArea/totalArea
			endif
		endfor
	else                     //binding energy decreases with point index
		for (i=0; i<pointLength; i += 1)
			partialArea += abs(yw[pointLength-1-i])
			if (totalArea >0)
				ShirleyStep[pointLength-1-i] =partialArea/totalArea 
			endif
		endfor
	endif
	
	
	//integrate the shirely step again to obtain the HGBackground with the parameter pw[3]
	partialArea = 0
	totalArea = sum(ShirleyStep) 
	if (xw[0] < xw[2] )   //binding energy increases with point index
		for ( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[i])
			if (totalArea > 0)
				hgb[i] = partialArea/totalArea	
			endif
		endfor
	else                     //binding energy decreases with point index
		for( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[pointLength-1-i])
			if (totalArea > 0)
				hgb[pointLength-1-i] = partialArea/totalArea
			endif	
		endfor
	endif
	

	yw +=  pw[3]*hgb
	yw +=  pw[4]*ShirleyStep   //this is necessary, as bgywStart always comes in a range between 0 and 1
	////and now the slope
	yw += pw[0]  + pw[1]*xw + pw[2]*xw^2

 	killwaves /Z ShirleyStep,HGB, individualPeaks
end






///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Ext-	Multiplet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Ext-	Multiplet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Ext-	Multiplet
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////		Ext-	Multiplet

function FitExtMultipletVoigtSK(pw,yw,xw): FitFunc
	wave pw, yw, xw
	
	variable numCoef =33         ///////////// number of coefficients  Ext-Multiplet = 33
	variable numSubPeaks = 10  ///////////  number of coefficients  Ext-Multiplet = 10
	
	
	variable i, index
	variable numPeaks = (numpnts(pw)-5)/numCoef    //use the length of the coefficient wave      Ext-Multiplet  15->33
	

	
	variable totalArea
	variable FWHMoffset =  0 // 0.00001
	variable partialArea =0
	variable pointlength
	variable temp
	variable areaPeak = 0
	variable faulty = 0   //this one marks, if there was something wrong
	yw = 0
	NVAR reported = root:STFitAssVar:WrongReported   //this one marks, if the wrong set has been reported so far

	//fit a multiplet with 10 peaks  
	duplicate /o yw ShirleyStep  //this wave needs to be removed after the fit has completed
	wave ShirleyStep = ShirleyStep
	duplicate /o yw HGB
	wave hgb=HGB
	duplicate /o yw individualPeak
	wave peak=individualPeak
	
	
	
	//those are only the peaks
	for (i = 0; i < numPeaks; i +=1)
	index =numCoef*i +5  // Ext-Multiplet  15->33
		if (pw[index] < 0 || pw[index+2] < 0 || pw[index+3] < -0.001 || pw[index+3] >1.001) 
			
			if (reported == 0)
			//DoAlert 0, "The parameter values went bad during the fit, maybe you optimize too many parameters at once?\rThe faulty parameter set was sent to the command line"
				print " "
				print "Problematic parameters: Area, Width <0 and GLratio outside the interval [0,1]."
				print " "
				print "Peak/Multiplet #          ", i+1
				print "----------------------------------------------"
				print "Area (normalized)         ", pw[index]
				print "Position                       ", pw[index+1]
				print "Width                          ", pw[index+2]
				print "GLratio                        ", pw[index+3]
				print "Asymmetry                  ", pw[index+4]
				print "Asymmetry Translation ", pw[index+5]
				print " "
				
			endif
			faulty = 1
		endif
	endfor
	
	if (faulty != 0)
		if (reported ==0)
			DoAlert 0, "Some of the parameters took physically wrong values during the fit, maybe you optimize too many parameters at once?\rHowever, the fit may still recover ....\rThe faulty parameter set was sent to the command line."		
			print "For a stable fit you should hold as many parameters as possible constant. If you let everything open for variation, you get a very unstable fit."
			print "The following situation is the most stable one: 'GL-ratio', 'Asymmetry', and 'Asymmetry Translation' frozen."
			print "The GL ratio is particularly 'fragile', optimize this one only if you already got a decent fit as start value. Also use the Asymmetry Translation not too liberally."
			print " "
			print "If the parameters take physically not justified values during the fit, the function changes its appearance significantly! "	
		endif
		reported = 1
	//	killwaves /Z ShirleyStep,HGB, individualPeaks
	//	yw = Nan
	//	return 0
	endif
	
	//pw[index+12] != 0 &&  pw[index+4] >= 0.01 && pw[index+2]*pw[index+14] > 1e-3 && pw[index+3] > 1e-3 && pw[index+3] < 0.9999  && pw[index+5] < 10 
	for (i = 0; i < numPeaks; i +=1)
		index = numCoef*i +5     // Ext-Multiplet  15->33

		peak = 0


		temp = pw[index + 3] 
		
			peak += (temp >= 0 )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) / ( ( FWHMoffset + 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) )^2 + 4 * ( xw - pw[index+1] )^2 ) )  
			peak += ( temp <= 1  )*(1 - temp) * ((1) / ( gPf * ( 2 * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5] ) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] ) / ( FWHMoffset + 2 * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]) ) ) ) )^2 ) 
			
			//if (pw[index+2]<0)
			//	peak = 0
			//	continue
			//endif
			
			if (pw[index+4] >= 0.01 )   //otherwise it is normalized anyway
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1],pw[index+2],pw[index+3],pw[index+4],pw[index+5])
				if (numtype(areaPeak)==0)
					peak /= areaPeak
				else 	
					//if this is the case, go to the next for iteration without adding this peak to yw
				 	continue
				endif
				peak *= integrationCorrection*pw[index]   //the integration is not from -inf to +inf, so the actual value is a bit larger
			else
				peak *= pw[index]
			endif
		
			yw += peak
			peak = 0
		
		
			//now add the second multiplet peak
			//pw[index+6] = ratio21
			//pw[index+7] = dist21
			//pw[index+8] = broad21
			peak += (temp >= 0  )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+8] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+8] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7]) ) ) )^2 + 4 * ( xw - pw[index+1] - pw[index+7] )^2 ) )  
			peak += ( temp <= 1 )*(1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+8] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+7]) / ( FWHMoffset + 2 * pw[index+8] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+7] ) ) ) ) )^2 ) 
	
			if (pw[index+6] != 0 && abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+7],pw[index+2]*pw[index+8],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				
				peak *=  integrationCorrection*pw[index]*pw[index+6]
			else
				peak *= pw[index]*pw[index+6]
			endif
			yw += peak
			peak =0
		
			//now do the third peak
			//6 > 9
			//7 >10
			//8 > 11
			peak +=(temp >= 0 )* (temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+11] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] - pw[index+10] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+11] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -pw[index+10]) ) ) )^2 + 4 * ( xw - pw[index+1]  -  pw[index+10] )^2 ) )  
			peak +=(temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+11] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+10]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] -  pw[index+10]) / ( FWHMoffset + 2 * pw[index+11] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  -pw[index+10] ) ) ) ) )^2 ) 
	
			if (pw[index+9] != 0  && abs(pw[index+4]) >= 0.01  )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+10],pw[index+2]*pw[index+11],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				
				peak *= integrationCorrection* pw[index]*pw[index+9]
			else
				peak *= pw[index]*pw[index+9]
			endif
			yw += peak
			peak = 0
			//and now the fourth
			// 9>12
			//10>13
			//11>14
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+14] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+13] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+14] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+13]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+13] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+14] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+13]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+13]) / ( FWHMoffset + 2 * pw[index+14] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+13] ) ) ) ) )^2 ) 
		
			if (pw[index+12] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+13],pw[index+2]*pw[index+14],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+12]
			else
				peak *= pw[index]*pw[index+12]
			endif
			
			
			yw += peak
			peak = 0
			
			
			
				//and now the fifth  Ext-Multiplett
			// 12 -> 15
			// 13 -> 16
			// 14 -> 17
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+17] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+16] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+17] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+16]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+16] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+17] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+16]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+16]) / ( FWHMoffset + 2 * pw[index+17] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+16] ) ) ) ) )^2 ) 
		
			if (pw[index+15] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+16],pw[index+2]*pw[index+17],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+15]
			else
				peak *= pw[index]*pw[index+15]
			endif
			
			
			yw += peak
			peak = 0
	
	
	
					//and now the sixth  Ext-Multiplett
			// 15 -> 18
			// 16 -> 19
			// 17 -> 20
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+20] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+19] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+20] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+19]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+19] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+20] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+19]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+19]) / ( FWHMoffset + 2 * pw[index+20] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+19] ) ) ) ) )^2 ) 
		
			if (pw[index+18] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+19],pw[index+2]*pw[index+20],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+18]
			else
				peak *= pw[index]*pw[index+18]
			endif
			
			
			yw += peak
			peak = 0
	
	
	
						//and now the seventh  Ext-Multiplett
			// 18 -> 21
			// 19 -> 22
			// 20 -> 23
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+23] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+22] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+23] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+22]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+22] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+23] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+22]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+22]) / ( FWHMoffset + 2 * pw[index+23] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+22] ) ) ) ) )^2 ) 
		
			if (pw[index+21] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+22],pw[index+2]*pw[index+23],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+21]
			else
				peak *= pw[index]*pw[index+21]
			endif
			
			
			yw += peak
			peak = 0
			
									//and now the eighth  Ext-Multiplett
			// 21 -> 24
			// 22 -> 25
			// 23 -> 26
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+26] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+25] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+26] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+25]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+25] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+26] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+25]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+25]) / ( FWHMoffset + 2 * pw[index+26] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+25] ) ) ) ) )^2 ) 
		
			if (pw[index+24] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+25],pw[index+2]*pw[index+26],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+24]
			else
				peak *= pw[index]*pw[index+24]
			endif
			
			
			yw += peak
			peak = 0
	
										//and now the ninth  Ext-Multiplett
			// 24 -> 27
			// 25 -> 28
			// 26 -> 29
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+29] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+28] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+29] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+28]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+28] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+29] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+28]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+28]) / ( FWHMoffset + 2 * pw[index+29] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+28] ) ) ) ) )^2 ) 
		
			if (pw[index+27] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+28],pw[index+2]*pw[index+29],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+27]
			else
				peak *= pw[index]*pw[index+27]
			endif
			
			
			yw += peak
			peak = 0
			
													//and now the tenth  Ext-Multiplett
			// 27 -> 30
			// 28 -> 31
			// 29 -> 32
			peak += (temp >= 0  )*(temp )* ( 2 * (1) / pi ) * ( ( 2 * pw[index+32] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]   - pw[index+31] ) ) ) ) / ( ( FWHMoffset + 2 * pw[index+32] * pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5] -  pw[index+31]) ) ) )^2 + 4 * ( xw - pw[index+1]  - pw[index+31] )^2 ) )  
			peak += (temp <= 1 )* (1 - temp) * ((1) / ( gPf * ( 2 *  pw[index+32] * pw[index+2]  / ( 1 + exp( -pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+31]) ) ) ) ) ) * exp ( -gAf * ( ( xw - pw[index+1] - pw[index+31]) / ( FWHMoffset + 2 * pw[index+32] *pw[index+2] / ( 1 + exp( - pw[index+4]*( xw - pw[index+1] - pw[index+5]  - pw[index+31] ) ) ) ) )^2 ) 
		
			if (pw[index+30] != 0 &&  abs(pw[index+4]) >= 0.01 )
				areaPeak= XPSTFA#IntegrateSingleVoigtGLS(1,pw[index+1]-pw[index+31],pw[index+2]*pw[index+32],pw[index+3],pw[index+4],pw[index+5])
				
				peak /= areaPeak
				peak *= integrationCorrection*pw[index]*pw[index+30]
			else
				peak *= pw[index]*pw[index+30]
			endif
			
			
			yw += peak
			peak = 0

	endfor
	
	
	pointLength = numpnts(yw)
	//print "Laenge der yw:", pointLength
	totalArea = sum(yw)  //to avoid division by zero
	partialArea = 0		
	if (xw[0] < xw[2] )  //binding energy increases with point index
		for (i=0; i<pointLength; i += 1) 

			partialArea += abs(yw[i]) 
			if (totalArea > 0 )
			ShirleyStep[i] =partialArea/totalArea
			endif
		endfor
	else                     //binding energy decreases with point index
		for (i=0; i<pointLength; i += 1)
			partialArea += abs(yw[pointLength-1-i])
			if (totalArea >0)
				ShirleyStep[pointLength-1-i] =partialArea/totalArea 
			endif
		endfor
	endif
	
	
	//integrate the shirely step again to obtain the HGBackground with the parameter pw[3]
	partialArea = 0
	totalArea = sum(ShirleyStep) 
	if (xw[0] < xw[2] )   //binding energy increases with point index
		for ( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[i])
			if (totalArea > 0)
				hgb[i] = partialArea/totalArea	
			endif
		endfor
	else                     //binding energy decreases with point index
		for( i = 0; i < pointLength; i += 1)
			partialArea += abs(ShirleyStep[pointLength-1-i])
			if (totalArea > 0)
				hgb[pointLength-1-i] = partialArea/totalArea
			endif	
		endfor
	endif
	

	yw +=  pw[3]*hgb
	yw +=  pw[4]*ShirleyStep   //this is necessary, as bgywStart always comes in a range between 0 and 1
	////and now the slope
	yw += pw[0]  + pw[1]*xw + pw[2]*xw^2
	
	//Switching off reported generates a larger error, the same dialog is called over and over again if the fit is not stable
	//reported = 0
 	killwaves /Z ShirleyStep,HGB, individualPeaks
end


