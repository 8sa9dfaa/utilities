#pragma rtGlobals=1		// Use modern global access method.
#pragma hide=1
#pragma ModuleName = XPSTRP
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


static function LaunchSingleWavePanel()
	String /G root:AV_workingFolder
	SVAR location
	DoWindow singleWavePanel
	if ( V_Flag )
		DoWindow /F singleWavePanel
		return -1
	endif
	location = GetDataFolder(1)
	draw()
end
//


//define the gui and the global variables

static function draw() : Panel
	AV_initialize()
	//GetWindow kwFrameInner, wsize
	//variable startX = (V_left+V_right)/5
	//variable startY= V_top
	
	
	if (screenresolution == 96)
		execute "SetIgorOption PanelResolution = 0"
	endif
	
	NewPanel /K=2 /N=SingleWavePanel /W=(110,39.5,436.5,455) as "Reduce number of points by averaging"
	ModifyPanel cbRGB=(61166,61166,61166), fixedsize=1
	PopupMenu WavePop,fsize=10,pos={18,3},size={193.50,16.50},bodyWidth=103,proc=XPSTRP#initPopUp,title="please select a wave    "
	PopupMenu WavePop,mode=1,popvalue=" ",value= #"WaveList(\"!*Disp*\",\";\",\"\")"
	PopupMenu XWavePop,fsize=10,pos={16,32},size={195.00,16.50},bodyWidth=104,proc=XPSTRP#initPopUpX,title="please select a X wave "
	PopupMenu XWavePop,mode=1,popvalue="_calculated_",value= #"\"_calculated_;\"+WaveList(\"!*Disp*\",\";\",\"\")"
	SetVariable setNumber,fsize=10,pos={78,61},size={131.00,14.00},bodyWidth=49,proc=XPSTRP#initVar,title="#Points to Average: "
	SetVariable setNumber,limits={2,20,1},value= numRedPoints
	Button okBut,fsize=10,pos={224,10},size={88,23},disable=2,proc=XPSTRP#doReduction,title="Reduce Points"
	Button button0,fsize=10,pos={224,41},size={88,23},proc=XPSTRP#exitWindow,title="Close"
	GroupBox GraphGroup,pos={7.00,77.50},size={311.50,332.50}
	
	Display/W=(14,83,313,235)/HOST=# 
	RenameWindow #,guiDisplay
	SetActiveSubwindow ##
	Display/W=(14,244,312,406)/HOST=# 
	RenameWindow #,guiDisplay2
	SetActiveSubwindow ##
	
	if (screenresolution == 96)
		execute "SetIgorOption PanelResolution = 1"
	endif

end

static function AV_initialize()
	SVAR name = root:AV_workingFolder
	SetDataFolder name
	Variable /G numRedPoints = 2
	String /G nameWaveRed = StringFromList(0,WaveList("!*Disp*",";",""))
	string /G nameXWaveRed = "_calculated_"

end



static function initPopUp(ctrlName,popNum,popStr): PopupMenuControl
	string ctrlName
	variable popNum
	String popStr
	//local reference to a global variable
	SVAR value = nameWaveRed
	value = popStr
	refreshWindow()
	Button okBut disable = 0
end

static function initPopUpX(ctrlName,popNum,popStr): PopupMenuControl
	string ctrlName
	variable popNum
	String popStr
	//local reference to a global variable
	SVAR value = nameXWaveRed
	value = popStr
end

static function initVar (ctrlName,varNum,varStr,varName) : SetVariableControl
	string ctrlName
	variable varNum	// value of variable as number
	string varStr		// value of variable as string
	string varName	// name of variable
	//local reference to global variable
	NVAR number = numRedPoints
	number = varNum	
end


static function doReduction(ctrlName):ButtonControl
	string ctrlName
	//local reference to global variable
	NVAR number = numRedPoints
	SVAR RawYWave = nameWaveRed
	SVAR RawXWave = nameXWaveRed
	//now decide if there is an x-axis given or not and call the corresponding function
	strswitch(RawXWave)
	 	case "":
	 	case "_calculated_":
	 		averageSingleWave(RawYWave,number)   
	 	break
	 	default:
			averageXYWave(RawYWave,RawXWave,number) 			 	
	 	break
	 endswitch
	ModifyGraph /w = singleWavePanel#guiDisplay2 mirror=2,standoff=1
	SetAxis /w = singleWavePanel#guiDisplay2 /A/R bottom
	ModifyGraph /w = singleWavePanel#guiDisplay mirror=2,standoff=1	
	SetAxis /w = singleWavePanel#guiDisplay /A/R bottom
end
	

//new and shiny
static function RefreshWindow()
	SVAR RawXWave = nameXWaveRed
	RawXWave = "_calculated_"
	RemoveFromGraph /Z /w = singleWavePanel#guiDisplay2 $"#0", $"#1"
	RemoveFromGraph /Z /w = singleWavePanel#guiDisplay $"#0", $"#1"
	PopupMenu XWavePop,mode=1,popvalue="_calculated_"//,value= #"\"_calculated_;\"+WaveList(\"!*Disp*\",\";\",\"\")"
end

	
static function exitWindow(ctrlName):ButtonControl
	string ctrlName
	DoWindow  /k singleWavePanel
	killwaves /z DispWave, DispWave2, XDispWave
	killvariables /z  numRedPoints
	killstrings /z nameWaveRed, nameXWaveRed, root:AV_workingFolder
	killwaves /z xDuplWave, yDuplWave, yDuplCor
	
end



static function averageXYWave(yWaveTag, xWaveTag, numPointsRed)
	//This function reduces the numbers in a spectrum, consisting of the
	//two given waves, one for the energy and one for the intensity values
	//the output is a scaled wave, containing the intensity.
	// 3 points get averaged to one point. 
	//To start this function, you have to give a intensity and energy wave
	
	string xWaveTag
	string yWaveTag
	variable numPointsRed    //number of points for averaging e.g. 3
	
	
	variable SuitingLength, residual, i , newpoints
	variable oldStart, oldStep
	variable offsetFactor    //important for proper energy position
	string newYwaveTag
	
	newYwaveTag = yWaveTag + "_R"+num2istr(numPointsRed) //give a name to the new wave
	
	WaveStats /Q $yWaveTag  //get information about the input-wave
	
	if (V_npnts <= numPointsRed)
		print "not enough data points in the given wave, setting the number of points to average to 3"
		numPointsRed = 3
	endif
	
	residual = mod(V_npnts,numPointsRed)  //Modulo Division -- here is the residual
	SuitingLength = V_npnts - residual   //truncate to a number of points, dividable by numPoints
	
	newpoints = SuitingLength / numPointsRed  // number of points in the 'reduced' wave
	
	make /w /o /d /n = (newpoints)  $newYwaveTag  //create a new wave with the appropriate length
	//create waves, as kind of local variables
	//the next lines are crucial for the function of the script
	//do not get confused by the $ formalism , in doubt take look 
	//at the help-files
	wave refName = $newYwaveTag
	wave refOrigName = $yWaveTag 
	wave xrefOrigName = $xWaveTag
	
	//find the starting-energy and the size of the energy steps in the input spectrum
	oldStart = xrefOrigName[0]
	oldStep = xrefOrigName[1]- xrefOrigName[0]
	
	//start the calculation
	// look at the explanation at the file end, concerning the next few lines
	for ( i = 0; i< newpoints; i += 1)
			refName[i] =( sum (refOrigName,numPointsRed*i,numPointsRed*i + (numPointsRed-1)) )/numPointsRed		
	endfor
	
	offsetFactor = (numPointsRed -1) / 2
	SetScale /P x, oldStart+offsetFactor*oldStep, numPointsRed*oldStep, refName
	
	//draw the results //rename them properly for display
	duplicate /o /d refOrigName, yDuplWave
	duplicate /o /d xrefOrigName, xDuplWave
	duplicate /o /d refName, yDuplCor
	
	AppendToGraph /w=singleWavePanel#guiDisplay yDuplWave vs XDuplWave       //append the wave
	ModifyGraph/w =singleWavePanel#guiDisplay mode=2,lsize=2.5,rgb=(0,0,65500)
	AppendToGraph /w =singleWavePanel#guiDisplay2 yDuplCor
	ModifyGraph/w =singleWavePanel#guiDisplay2 mode=2,lsize=2.5,rgb=(0,0,0)
	//display /k=1 /n=tempGraph  as "tempGraph"//create a graph which "dies silently"
	//AppendToGraph refOrigName vs xrefOrigName   //append the waves
	//modifyGraph mode($yWaveTag)= 0, rgb = (0,0,0)  //make them look nice
	//AppendToGraph refName 
	//modifygraph mode($newYwaveTag)= 3, marker($newYwaveTag) = 43, rgb($newYwaveTag) = (0,0,39168)	
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


static function averageSingleWave(WaveTag,numPointsRed)
	//This function reduces the number of points in a given wave
	// and creates a new wave with the averaged values of the input wave
	string WaveTag
	variable numPointsRed
	
	string newWaveTag
	variable SuitingLength, residual, i , newpoints
	variable oldStart, oldStep
	variable offsetFactor
	string DWave1Tag = "displayCurve1"
	string DWave2Tag = "displayCurve2"
	
	newWaveTag =  WaveTag  + "_R" + num2istr(numPointsRed)   //give a name to the new wave
	
	WaveStats /Q $WaveTag   //gather information about the 'input-wave'
	
	if (V_npnts <= numPointsRed)
		print "not enough data points in the given wave, setting the number of points to average to 3"
		numPointsRed = 3
	endif
	
	residual = mod(V_npnts,numPointsRed)  //Modulo Division -- here is the residual
	SuitingLength = V_npnts - residual   //truncate to a number of points that is dividable by 3
	newpoints = SuitingLength / numPointsRed  // number of points in the 'reduced' wave
	
	make /w /o /d /n = (newpoints)  /d $newWaveTag
	//create waves, as kind of local variables
	//the next lines are crucial for the function of the script
	//do not get confused by the $ formalism , in doubt take look 
	//at the help-files
	wave refName = $newWaveTag
	wave refOrigName = $WaveTag
	wave DispWave = $DWave1Tag
	wave DispWave2 = $DWave2Tag
	//find the old starting point, i.e. the respective energy value,
	//this is possible, because the wave originates from an igor text file
	//and the leftx() command the assigns to the calculated x-Axis value
	//in the case of a normal x-y file leftx(y) would give the point index of 
	//the first element, i.e. 0.
	oldStart = leftx(refOrigName)
	oldStep = deltax(refOrigName)
	
	
	//start the calculation
	for ( i = 0; i< newpoints; i += 1)
			refName[i] =( sum (refOrigName,pnt2x(refOrigName,numPointsRed *i),pnt2x(refOrigName,numPointsRed*i + (numPointsRed-1) )) ) / numPointsRed		
	endfor
	//  ... huh, what a code mutant! This is hard stuff what does that mean?Look at the explanation at the file end
	//print pnt2x(refOrigName,0)     //uncomment this, to check the output
	
	
	
	offsetFactor = (numPointsRed -1) / 2
	SetScale /P x, oldStart+offsetFactor*oldStep, numPointsRed*oldStep, refName
	
	
	duplicate /o  refOrigName, DispWave
	duplicate /o  refName, DispWave2
	//draw the results
	//display /k=1 /n=tempGraph  as "tempGraph" //create a graph that is killed without any further confirmation
	AppendToGraph /w=singleWavePanel#guiDisplay DispWave        //append the wave
	ModifyGraph/w =singleWavePanel#guiDisplay mode=2,lsize=2.5,rgb=(0,0,65500)
	//modifyGraph /w=singleWavePanel#guiDisplay mode($DWave1Tag)= 0, rgb = (0,0,0)    //make them look nice
	AppendToGraph /w =singleWavePanel#guiDisplay2 DispWave2
	ModifyGraph/w =singleWavePanel#guiDisplay2 mode=2,lsize=2.5,rgb=(0,0,0)
	//Cursor /w=singleWavePanel#guiDisplay A DispWave, leftx(DispWave)
	//Cursor /w = singleWavePanel#guiDisplay B DispWave, rightx(DispWave)
	
	//modifygraph /w=singleWavePanel#guiDisplay  mode($DWave2Tag)= 3, marker($DWave2Tag) = 43, rgb($DWave2Tag) = (0,0,39168)
	
end



//Lets have a look at the diabolic master of confusion, namely the expression:
//
//         refName[i] =( sum (refOrigName,pnt2x(refOrigName,numPointsRed *i),pnt2x(refOrigName,numPointsRed*i + (numPointsRed-1) )) ) / numPointsRed	
//
// what's that monster doing? Lets take it apart.
// The first function is:   pnt2x(wavename,pointIndex)     It has only a meaning if the used wave has an intrinsic scaling, like waves imported
//												  from Igor text files. Remember? If you plot those, you do not have to define a x-axis.
//												  pnt2x gives the x-axis value of the point with the Index   <pointIndex>
//												  e.g.  pnt2x(refOrigName, 0)  gives the x-axis value for the first entry in the wave <refOrigName>
//												  Try to uncomment the respective expression in the code and see the result.
//
//Next we have to care for the < sum > function
//Its basic syntax is:
//						sum ( waveName, startPosition, stopPosition)
//start and stop positions can be found using <pnt2x>, so far so good.  But what does  the product   numPointsRed * i    there?
//The given function should work for each given value of numPointsRed.  
// 
//	numPointsRed = 2             
//      
//	refName[0] = sum( .....)/ 2  = (refOrigName[0] + refOrigName[1] ) / 2             first iteration   i = 0
//	refName[1]  = sum( ....)/2   = (refOrigName[2] + refOrigName[3] ) / 2		second iteration i = 1
//     ....
//	refName[n]  = sum( ....)/2   = (refOrigName[2n] + refOrigName[2n+1] ) / 2                             i = n
//
//	numPointsRed = 3             
//      
//	refName[0] = sum( .....)/ 3  = (refOrigName[0] + refOrigName[1]  + refOrigName[2] ) / 3            first iteration  i = 0
//	refName[1]  = sum( ....)/3   = (refOrigName[3] + refOrigName[4] + refOrigName[5] ) ) / 3		second iteration i = 1.
//     ....
//	refName[n]  = sum( ....)/3   = (refOrigName[3n] + refOrigName[3n+1] + refOrigName[3n+2] ) / 3                        i = n
//
//    .........
//
//	numPointsRed = m             
//      
//	refName[0] = sum( .....)/ m  = (refOrigName[0] + refOrigName[1]  +  ....   +     refOrigName[m-1] ) / m            first iteration i = 0
//	refName[1]  = sum( ....)/m   = (refOrigName[m] + refOrigName[m+1] +  ..... +  refOrigName[2m - 1] ) ) / m	  second iteration   i = 1
//     ....
//	refName[n]  = sum( ....)/m  = (refOrigName[mn] + refOrigName[mn+1]+ .... + refOrigName[mn+(m-1)] ) / m         i = n
//
// If you have a close look, you will find, that the command in the last line is exactly what is written in the code. 
// Compare it with the respective command in the function			averageXYWave
// there, it is more obvious to see, as the used wave has no intrinsic scaling, and no  pnt2x   is necessary.
//

// Concerning the variable:  scalingFactor
//
//Each processed wave is truncated, that it can be divided by   numPointsRed   without a residual, that means  a loss of  max (numPointsRed -1 )
//data points for the following calculation. This is acceptable.
//
//During the averaging process the average intensity refers to certain energy position. The variable    scalingFactor    serves for a correct x-position of
//the averaged data points.
//
// E.g.       numPointsRed = 2
// old         +  ---------------- +
// new                   X
//               |< 0.5 >]                     factor, which gives the offset, in units of  the distance of the old datapoints

// E.g.       numPointsRed = 3
// old         +  ----------- +  ----------- +
// new                 		X	 
//               |<-    1   ->]

// E.g.       numPointsRed = 4
// old         +  ----------- +  ----------- + ----------- +
// new               		 	 X		    
//		    |<-      1.5      ->]

// The distance between neighbouring new datapoints is   numPointsRed * (oldPointDistance),   but where to set the first point?
// From the sketch you can see, that the offsetFactor is connected with   numPointsRed 		by the equation:
//
//                  offsetFactor = (numPointsRed - 1 ) / 2                            or    numPointsRed = (2*offsetFactor + 1 )
