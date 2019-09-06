#pragma rtGlobals=1		// Use modern global access method.


//////////////////////////////////////////////////////////////////////////////////
//Licence
//////////////////////////////////////////////////////////////////////////////////
//
//	If you use the 'Fit Assistant' to analyze data, please read and cite the following paper:
//	Surface and Interface Analysis, (2014), 46, 505-511
//	This publication contains more details on the fit function used by XPST.
//
//	XPST is a front-end to the IgorPro fitting engine. Although every possible effort was made 
//	to prevent serious bugs and wrong results, the author can not give any warranty for XPST as 
//	large parts actually depend on the underlying IgorPro code. 
//	Author: Dr. Martin Schmid
//
//////////////////////////////////////////////////////////////////////////////////



function NotifyHelp()
	DisplayHelpTopic "XPST"
end




proc XPSTUnhide()
	SetIgorOption IndependentModuleDev=1
end



//this function returns the path to the selected wave

function WhereIs()
	strswitch (CsrWave(A) )           
		case "":            			  	   //A is not on the graph
			strswitch (CsrWave(B))
				case "": 			      // B is not there either
					DoAlert 0, "You have to use the cursor"
					return 1
				default: 			    // B is there
					wave BPointer = CsrWaveRef(B)
					print "Cursor B is on: "
					print GetWavesDataFolder(BPointer,2)
					break
			endswitch
			break
		
		default:      				 // A is on the graph
			strswitch (CsrWave(B))
				case "":   		 //B not
					wave APointer = CsrWaveRef(A)
					print "Cursor A is on: "
					print GetWavesDataFolder(APointer,2)
					break
				default:   			   // A and B are both on the graph
					wave BPointer = CsrWaveRef(B)
					print "Cursor B is on: "
					print GetWavesDataFolder(BPointer,2)
					print "Cursor A is on: "
					wave APointer = CsrWaveRef(A)
					print GetWavesDataFolder(APointer,2)
					break
			endswitch
			break
	endswitch
end


function RemoveUnitString()
	print "This function works on waveform data only and removes the unitstring from the x and y scaling"
	string Aname = CsrWave(A) //up to now, this does not really work with the path to the wave
	wave Awave = CsrWaveRef(A)
	string Bname = CsrWave(B)
	wave Bwave = CsrWaveRef(B) // $Bname
	variable firstPoint
	variable lastPoint
	
	// if A is on a graph,  remove the units of A
	if ( cmpstr(Aname,"") != 0)   //go into the loop, if Aname is not empty
		//use SetScale to remove the unitstring
		firstPoint = pnt2x(Awave,0)
		lastPoint = pnt2x(Awave,numpnts(Awave)-1)
		SetScale /I x firstPoint,lastPoint, "", Awave
		SetScale y 0,0, "", Awave
	endif
	// if B is on a graph, remove the units of B
	if ( cmpstr(Bname,"") != 0)     // go into the section, if Bname is not empty
		firstPoint = pnt2x(Bwave,0)
		lastPoint = pnt2x(Bwave,numpnts(Bwave)-1)
		SetScale /I x firstPoint,lastPoint, "", Bwave
		SetScale y 0,0, "", Bwave
	
	endif
end





// This is the 'handle' function for getting the wave overlap
// it calls waveAlign(), which is the command line function that performs the actual task

function WaveOverlap()

	string LastGraphName = WinList("*", "", "WIN:")

	string Axname = XWaveName(LastGraphName,CsrWave(A))
	string Bxname = XWaveName(LastGraphName,CsrWave(B))
	string Awave = CsrWave(A)
	string Bwave = CsrWave(B)

	wave wRef1 = $Awave
	wave wRef2 = $Bwave

	if ( cmpstr(Axname,"") || cmpstr(Bxname,"") )
		DoAlert 1, "The data are displayed in an X-Y plot. The program requires to merge the current x and y waves to waveform data? Press NO for EXIT."
		//Print "Sorry not implemented yet"
	endif

	if (V_Flag == 1)
		if (cmpstr(Axname,""))
			wave Ax = $Axname		
			SetScale /I x, Ax[0], Ax[numpnts(Ax)-1], wRef1
		endif
		if (cmpstr(Bxname,""))
			wave Bx = $Bxname		
			SetScale /I x, Bx[0], Bx[numpnts(Bx)-1], wRef2
		endif
	endif


	// All that stuff  only prevents user errors - maybe Igor has not the most efficient language
	strswitch (CsrWave(A))
		case "":       //A not on graph
			strswitch (CsrWave(B) )
				case "":  // B missing as well
					DoAlert 0, "Use both cursors to mark the waves"
					return 1
				default:
					DoAlert 0, "You also have to use cursor A"
					return 1 // A is not there but B
			endswitch
			break
		default:       // A is on graph
			strswitch (CsrWave(B) )
				case "":  // B is missing
					DoAlert 0, "You have also to use cursor B"
					return 1
				default:
					break // A and B are there, proceed
			endswitch
	endswitch
		
	if ( cmpstr(Awave,Bwave) == 0 )
		DoAlert 0, "Both cursors on the same wave"
		return 1
	endif

	variable spacingWave1
	variable spacingWave2

	spacingWave1 = abs( (leftx(wRef1) - pnt2x(wRef1, numpnts(wRef1)-1))/numpnts(wRef1) )
	spacingWave2 = abs( (leftx(wRef2) - pnt2x(wRef1, numpnts(wRef1)-1))/numpnts(wRef2) )


	//the second wave should be the one with the smaller point distance, so the interpolation is 
	//more accurate
	string prim
	string second

	if (spacingWave1 >= spacingWave2)
		prim = Awave
		second = Bwave
	else
		prim = Bwave
		second = Awave
	endif

	// since everything is prepared, call the function itself
	WaveOPS(prim, second, "overlap")
end

// Get the values of wave2 at the x-values of wave1
// wave2 should have more datapoints, since those are used to interpolate the values at the
// x values of wave 1 
// the resulting output shows the y characteristic of wave2 at the points of wave1, therefore
// wave1 and the output wave can be directly compared



//Mark a wave with the cursor and then use this function e.g. like
// translate(1.3)
//this will move the function about 1.3 x-units 
function Translate(waveShift)
	variable waveShift
	string targetName
	
	string LastGraphName = WinList("*", "", "WIN:")
	//string name = XWaveRefFromTrace( LastGraphName,CsrWave(A))
	string xname = XWaveName(LastGraphName,CsrWave(A))
	string xname2 = XWaveName(LastGraphName,CsrWave(B))
	strswitch(xname)
		case "":  //proceed normally
		break
		default:   //everything, but not empty
			DoAlert 0, "This function works only with waves with an intrinsic scaling. For waves that require an X wave it is obsolete.\rSimply go to the command line and add the shift to the X wave:\r\r e.g. wave0 += 0.3"
			return 1
	endswitch
	strswitch(xname2)
		case "":  //proceed normally
		break
		default:   //everything, but not empty
			DoAlert 0, "This function works only with waves with an intrinsic scaling. For waves that require an X wave it is obsolete.\rSimply go to the command line and add the shift to the X wave:\r\r e.g. wave0 += 0.3"
			return 1
	endswitch
	
	strswitch (CsrWave(A) )
		case "":                 //obviously A is not on the graph, so B has to do the job
			strswitch (CsrWave(B))
			case "":       // uuups, there is no cursor at all there, inform the user
				DoAlert 0, "You have to place a cursor on the wave you want to shift ..."
				return 1
			endswitch
			targetName = CsrWave(B)+"_t" 
			duplicate /o $(CsrWave(B)), $targetName
			SetScale /I x, leftx($CsrWave(B)) +waveShift , pnt2x($CsrWave(B),numpnts($CsrWave(B))-1) + waveShift , $targetName
			break
		default:       // A is on the graph
			strswitch (CsrWave(B))
			case "":       //B not
				targetName = CsrWave(A)+"_t" 
				duplicate /o $(CsrWave(A)), $targetName
				SetScale /I x, leftx($CsrWave(A)) +waveShift , pnt2x($CsrWave(A),numpnts($CsrWave(A))-1) + waveShift , $targetName
				break
			default:      // A and B are both on the graph, B has to be ignored and removed
				targetName = CsrWave(A)+"_t" 
				duplicate /o $(CsrWave(A)), $targetName
				SetScale /I x, leftx($CsrWave(A)) +waveShift , pnt2x($CsrWave(A),numpnts($CsrWave(A))-1) + waveShift , $targetName
				DoAlert 0, "You placed one cursor to much on the graph, ignoring Cursor B"
				Cursor /K B
				break
			endswitch
			break
	endswitch
	// If there is already the wave displayed, remove it, if not /Z quenches the error message
	RemoveFromGraph /Z $targetName
	AppendToGraph $targetName
	ModifyGraph rgb($targetName) = (0,0,65500)  // Color code it accordingly
end


//// Tougaard BG
function Tougaard()
	string targetName = CsrWave(A)+"_T"
	variable sampleLen,highX, lowX, step, offset, b
	variable c = 1643
	variable i,j
	// All that stuff  only prevents user errors - maybe Igor has not the most efficient language
	strswitch (CsrWave(A))
		case "":       //A not on graph
			strswitch (CsrWave(B) )
				case "":  // B missing as well
					DoAlert 0, "Please set cursor A and B on the curve to mark the range which you want to cut. Use Ctrl+I to activate cursors..."
					return 1
				default:
					DoAlert 0, "You also have to use cursor A"
					return 1 // A is not there but B
			endswitch
		break
		default:       // A is on graph
			strswitch (CsrWave(B) )
				case "":  // B is missing
					DoAlert 0, "You have also to use cursor B"
					return 1
				default:
				break // A and B are there, proceed
			endswitch
		endswitch
	string tempTargetName
	i=1
	do
		tempTargetName = targetName + num2istr(i)
		i+=1
	while(exists(tempTargetName))
	targetName = tempTargetName
	duplicate  /O $(CsrWave(A)), $targetName
	duplicate /O $targetName temp
	wave temp = temp
	wave target = $targetName
	wave original = $(CsrWave(A))
	//now do the actual calculation
	sampleLen = numpnts($(CsrWave(A)))
	print "Calculating Tougaard background, Loss parameter: 1643 eV^2, see:"
	print "S.Tougaard; 1989, 216, 343 - 360"
	print "Please note, that this algorithm does not correct for the transmission function of"
	print "the analyzer and the integrals in Tougaards paper are replaced by discrete sums."
	print "Therefore, one should be careful about relating the parameters of the background to physical quantities"
	if (sampleLen > 1000)
		print "Many points to be considered, calculation may takes a while ..."
	endif
	string xname
	xname = CsrXWave(A)
	if ( stringmatch(CsrXWave(A), "") == 1)
	highX = max( leftx($(CsrWave(A))), pnt2x($CsrWave(A),numpnts($CsrWave(A))-1))
	lowX = min( leftx($(CsrWave(A))), pnt2x($CsrWave(A),numpnts($CsrWave(A))-1)  )
	else
	print "with x-axis"
	highX = leftx($(CsrXwave(A)))
	lowX = pnt2x($CsrWave(A),numpnts($CsrWave(A))-1)
	endif
	if ( leftx($(CsrWave(A) ) )  <= pnt2x($CsrWave(A),numpnts($CsrWave(A))-1) )
		for (i = 0; i < sampleLen; i+= 1)   //reverse the wave contents
			temp[i] = target[sampleLen-i-1]
		endfor
		for (i = 0; i < sampleLen; i+= 1)   //reverse the wave contents
			target[i] = temp[i]
		endfor
	endif
	step = abs(highX - lowX)/sampleLen
	
	//get the average value from the cursor
	
	offset=min( vcsr(A), vcsr(B))
	//print offset
	target -= offset  //target contains the same values as the original wave 
	
	variable Integral = 0
	for ( i = 0; i < sampleLen; i += 1)
		Integral += (i*step)/(c+(i*step)^2)^2 * target[i] 
	
	endfor

	//b = mean(sampleWOoffset, xcsr(B)-3, xcsr(B))
	b =  (max (vcsr(A),vcsr(B)) - offset) /Integral 
	variable IntegralUP = Integral
	//variable IntegralDown =Integral
	for ( i = 0; i < sampleLen; i += 1)
		//IntegralDown=0
		IntegralUP = 0
		for ( j = i; j < sampleLen; j += 1)
			IntegralUP += ( ( j - i )*step)/(c+( ( j - i ) * step)^2)^2 *(original[j] - offset)
		endfor
		//for (j=0; j< i; j+= 1)
		//	IntegralDown += (j*step)/(c+(j*step)^2)^2 * (original[j] - offset)
		//endfor
		//IntegralUP = Integral -IntegralDwon
		target[i] = original[i] - offset - b* IntegralUP
		
	endfor
	//print Integral, IntegralUP + IntegralDown
	if ( stringmatch(CsrXWave(A), "") == 1)
		Display /K=1 $targetName
	else
		Display /K=1 $targetName vs $xname
	endif

	ModifyGraph rgb($targetName) = (0,26112,39168)  // Color code it accordingly
	killwaves /Z temp
	SetAxis /A /R bottom
end










function SetFreeCursors()
	string LastGraphName = WinList("*", "", "WIN:") 
	string name = stringFromList(0,LastGraphName)
	String allNormalTraces=TraceNameList("",";",1)
	string traceName = stringFromList(0,allNormalTraces)
	Cursor /F /P /W=$name A $traceName, 0.2,0.8
	Cursor /F /P /W=$name B $traceName, 0.8,0.8
	//Cursor /F /P  / w=ShirlPanel#guiDisplay A  $"SP_DispWave" ,0.2, 0.5
end









function WaveOPS(wave1, wave2, task)
	string wave1
	string wave2   //the wave with the smallest spacing between the xpoints
	string task   //either overlap, sum, difference, product, quotient
	// Problem the two waves   (xPrim, yPrim)  and (xSecond, ySecond) should be combined (+, -, *, / )
	// due to  xPrim != xSecond   and   #xPrim  !=  # xSecond  a pointwise combination is not possible

	// Solution: Calculate the values of ySecond at the locations of xPrim by interpolation and store
	// those values to a new wave   (xPrim, ySecondInter)

	// then  (xPrim, yPrim)  is combinable with (xPrim, ySecondInter)  since the x values are identical
                                                    
	// the y values shall be calculated in the following way by interpolation with a second wave
	//	1. Find two points in the second wave with xSecond0 < xPrim < xSecond1
	//	2. Get the ordered pairs (xSecond0,ySecond0), (xSecond1, ySecond1)
	//	3. Calculate the linear interpolation of between those two points
	//	4. Use this equation to calculate the ordered pair (xPrim, ySecondInter)
	//	5. Go to the next xPrim

	// until no xSecond1 > xPrim can be found
	// result

	// we start at   (xPrim, yPrim) 
	// and get       (xPrim, ySecondInter)    which is an approximation for  (xSecond, ySecond)

	// the following functions may be useful     
	// 			x2pnt   --> get the index which corresponds closest to the x value        

	// the following code constructions are necessary:
	//	1. reading the cursor, cursors A and B shall mark the two waves at issue, ySecond is automatically
	// 	the wave with the smallest x spacing, so the approximation does not get too crude.                                       
	//	2. An escape mechanism, if xPrim and xSecond are entirely in different regions, so the condition above
	//	can not be fulfilled

	wave prim = $wave1
	wave second = $wave2
	string TargetName
	strswitch (task)
		case "overlap":  
			TargetName = "OL_" + wave1+ "_" + wave2
			break
		case "sum":
			TargetName = "SUM_" + wave1+ "_" + wave2
			break
		case "difference":
			TargetName = "DIF_" + wave1+ "_" + wave2
			break
		case "product":
			TargetName = "PRO_" + wave1+ "_" + wave2
			break
		case "quotient":
			TargetName = "QUO_" + wave1+ "_" + wave2
			break
		default:      
	endswitch

	if ( strlen(TargetName) >= 30)
		doalert 0, "The name(s) of some wave(s) are too long for Igor! Please shorten the names."
		return 1
	endif

	make /d /n=(numpnts(prim)) /o xPrim
	variable xPrimIndex
	variable xPrimSpacing

	xPrimSpacing = abs( (leftx(prim) - pnt2x(prim, numpnts(prim)-1))/numpnts(prim) )


	for ( xPrimIndex = 0; xPrimIndex < numpnts(prim); xPrimIndex += 1)
		xPrim[ xPrimIndex ] = min( leftx(prim), pnt2x(prim, numpnts(prim)-1)) + xPrimIndex * xPrimSpacing
	endfor

	// now make a second wave, which will hold the interpolated y values, its start length is zero, everytime
	// a point is interpolated it will be attached with redimension
	make /d /n=0 /o ySI      //ySecondInter
	make /d /n=0 /o xSI      //xSecondInter

	// make the waves accessible by generating local references
	wave ySIr = ySI
	wave xSIr = xSI     

	// get variables for the offset and slope of the linear interpolation
	variable iUP            // index upper point  x1
	variable iLP             // index lower point  x0
	variable offset
	variable slope

	variable ixP    

	//now loop through the values of xPrim and check
	for ( ixP = 0; ixP < numpnts(prim); ixP += 1)
		// now we are at
		//print xPrim[ ixP ]
		// get the point-index in the second wave, which is closest to this value
		iLP = x2pnt(second,xPrim[ ixP ] )    // returns nothing, if xPrim[ixP] is not in the range of second ... good
		if (iLP <= 0)
			//print "out of range"
			continue
		endif
	
		//print iLP
		iUP = iLP + 1
		if ( iUP > numpnts(second) )
			//print "had to exit"
			continue
		endif
		redimension /n=(numpnts(xSIr) + 1) xSIr
		redimension /n=(numpnts(ySIr) + 1) ySIr
		xSIr [ numpnts(xSIr) ] = xPrim [ixP]
	
		slope = ( second[ iUP ] - second[ iLP ]) / ( pnt2x(second, iUP) - pnt2x(second, iLP) )
		offset = second[ iLP ] - slope * pnt2x(second, iLP)
	
		ySIr [ numpnts(ySIr) ] = offset + slope * xPrim[ ixP ]
	endfor

	//now we have an ordered pair of xSecondInterpolated and ySecondInterpolated where
	// the point spacing is identical to the point spacing in the primary wave, but the y values are
	// based on the y-values of the secondary wave.

	// still to do: make a duplicate of the primary wave with the same number of points as xSecondInterpolated

	duplicate /o /r=(xSIr[0],xSIr[numpnts(xSIr) -1]) prim NewPrime    //this does not say anything about an internal scaling of NewPrime
	wave NewPrimeRef = NewPrime
	SetScale /I x, xSIr[0],xSIr[numpnts(xSIr) -1], NewPrime
	SetScale /I x, xSIr[0],xSIr[numpnts(xSIr) -1], ySIr

	duplicate /o ySIr $TargetName
	wave OL = $TargetName            //OL  = OverLap

	variable iOL                              // iOL  = indexOverLap

	strswitch (task)
		case "overlap":  
			for ( iOL = 0; iOL < numpnts(OL); iOL += 1)
				OL[ iOL ] = min( NewPrimeRef[ iOL ], ySIr [ iOL] )
			endfor
			break
		case "sum":
			for ( iOL = 0; iOL < numpnts(OL); iOL += 1)
				OL[ iOL ] =  NewPrimeRef[ iOL ]+ ySIr [ iOL] 
			endfor
			break
		case "difference":
			for ( iOL = 0; iOL < numpnts(OL); iOL += 1)
				OL[ iOL ] =  NewPrimeRef[ iOL ] - ySIr [ iOL] 
			endfor
			break
		case "product":
			for ( iOL = 0; iOL < numpnts(OL); iOL += 1)
				OL[ iOL ] =  NewPrimeRef[ iOL ] * ySIr [ iOL] 
			endfor
			break
		case "quotient":
			for ( iOL = 0; iOL < numpnts(OL); iOL += 1)
				OL[ iOL ] =  NewPrimeRef[ iOL ]/ ySIr [ iOL] 
			endfor
			break
		default:      
	endswitch

	killwaves /Z xPrim
	killwaves /Z ySI, xSI, NewPrime
end





