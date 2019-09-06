#pragma rtGlobals=1		// Use modern global access method.
#pragma hide=1
#pragma moduleName = XPSTBL

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


static function LaunchLinePanel()
	String /G root:LP_workingFolder
	SVAR location = root:LP_workingFolder
	DoWindow linePanel     //will write 1 into V_Flag, if the window already exists
	if ( V_Flag )
		DoWindow /F linePanel   //bring it to front
		return -1                          //exit and do nothing else
	endif
	location = GetDataFolder(1)
	//linePanel()
	draw()
end



static function draw()
	
	
	if (screenResolution == 96)
		execute "SetIgorOption PanelResolution = 0"
	endif
	
	
	NewPanel /K=2 /N=linePanel /W=(201,39.5,722,462.5) as "Baseline"
	SetDrawLayer UserBack
	SetDrawEnv fsize= 9
	DrawText 17,22,"Please select a wave"
	SetDrawEnv fsize= 9
	DrawText 16,76.5,"Move the Cursor and press 'Add'"
	SetDrawEnv fsize= 9
	DrawText 16.5,88,"At least 2 points required!"
	GroupBox PopUpGroup,pos={10.00,5.00},size={215.00,52.00}
	PopupMenu WavePop,pos={16.00,28.00},size={199.00,16.50},bodyWidth=199,proc=XPSTBL#initLinePopUp
	PopupMenu WavePop,mode=1,popvalue="_select_",value= #"SortList(WaveList(\"!*list*\",\";\",\"DIMS:1\"), \";\",16)"
	Button CancBut,pos={234.50,5.50},fsize=10, size={91.00,21.50},disable=2,proc=XPSTBL#LeaveLine,title="Undo and Exit"
	Button ExitBut,pos={235.50,30.00},fsize=10,size={89.50,23.00},proc=XPSTBL#exitLineWindow,title="Accept and Exit"
	GroupBox GraphGroup,pos={10.00,59.50},size={311.00,352.50}
	Button AddBut,pos={326.00,61.00},fsize=10,size={50,33.00},proc=XPSTBL#AddCoord,title="Add >>"
	Button AddBut,fColor=(44000,52000,65500)
	Button DelBut,pos={326.50,98.50},fsize=10,size={50,33.00},proc=XPSTBL#DelCoord,title="Delete <<"
	Button DelBut,fColor=(44000,52000,65500)
	ListBox list0,pos={380.50,61.00},fsize=10,size={131.50,351.50},proc=XPSTBL#WatchFunctionForThisListBox
//	ListBox list0,listWave=root:listWave,selWave=root:listWaveSel,mode= 1,selRow= 0
	Display/W=(16,95,306,239)/HOST=# 
	RenameWindow #,guiDisplay
	SetActiveSubwindow ##
	Display/W=(17,247,309,404)/HOST=# 
	RenameWindow #,guiDisplay2
	SetActiveSubwindow ##
	
		
	if (screenResolution == 96)
		execute "SetIgorOption PanelResolution = 1"
	endif
	
	initializeLine()

end


static function initializeLine()
//this function initializes the global variables (yes, I know, but Igor does not...)
//identical to the default values of the gui elements 
//avoid errors or inconsistencies
	SVAR name = root:LP_workingFolder
	SetDataFolder name
	String /G LP_nameWaveRed = StringFromList(0,WaveList("!*Disp*",";",""))
	make /d /n=0 /o XCoords, YCoords
	
	//Prepare the required  waves
	make /t /n=(0,2) /o listWave         //this textwave takes the entries // start with a large number of entries
	wave /t listWave = listWave
	make /d /n=(0,2) /o listWaveSel    // this wave is behind the scences to control the listbox properties, ...c an be pretty advanced
	wave listWaveSel = listWaveSel


	// set colum labels
	SetDimLabel 1,0,$"XCoords",listWave
	SetDimLabel 1,1,$"YCoords",listWave

	// now do some more details on the listbox itself to make it functional 
	ListBox  list0, listWave=listWave, selWave=listWaveSel        //assign the waves to the listbox
	ListBox  list0, mode=1								    //controls the selection mode
//	ListBox  list0,  proc=XPSTBL#WatchFunctionForThisListBox		   // assign the "observer" function to the listbox
	//string /G nameXWaveRed = StringFromList(0,WaveList("!*Disp*",";",""))
	PopupMenu WavePop,mode=1,popvalue="_select_",value= #"SortList(WaveList(\"!*list*\",\";\",\"DIMS:1\"), \";\",16)" //#"WaveList(\"!*Disp*\",\";\",\"\")"		//value= #"WaveList(\"!*Disp*\",\";\",\"\")"
end


static function WatchFunctionForThisListBox(ctrlName,row,col,event): ListBoxControl
	string ctrlName
	variable row
	variable col
	variable event

	wave xWave = XCoords     // make references to these waves, so the values from the listbox can be filled in there later
	wave yWave = YCoords
	wave /t listWave = listWave
	variable i

	if (event == 7)    // 7: means that edit is done
		// update the numerical waves, those waves are the ones which are actually used in the rest of the code
		for ( i = 0; i < numpnts(xWave); i += 1)
			xWave[i] = str2num(listWave[i][0])
			yWave[i] = str2num(listWave[i][1])
			printMe("void")
		endfor
	endif
end


static function initLinePopUp(ctrlName,popNum,popStr): PopupMenuControl
//as soon as a wave is selected, it is displayed and cursors appear
	string ctrlName
	variable popNum
	String popStr
	//local reference to a global variable
	SVAR value = LP_nameWaveRed
	value = popStr                              //write the selection to the global string
	wave xVals = XCoords
	wave yVals = YCoords
	
	redimension /d /n=(0)  xVals
	redimension /d /n=(0) yVals
	
	//Button okBut disable=0
	Button cancBut disable=2
	Button AddBut disable = 0, fColor=(44000,52000,65500)  
	Button DelBut disable = 0, fColor=(44000,52000,65500)  
	wave WorkWave = $value

	duplicate /o /d WorkWave, LP_DispWave
	 
	RemoveFromGraph /Z /W=linePanel#guiDisplay2 /Z $"#0"  
	RemoveFromGraph /Z /W=linePanel#guiDisplay /Z $"#0" $"#1" $"#2" $"#3" $"#4"   //more traces..to be on the safe side

	AppendToGraph /w=linePanel#guiDisplay LP_DispWave
	ModifyGraph /W=linePanel#guiDisplay rgb(LP_DispWave)=(0,0,0) 
	//the name of the panel is hard-coded, usually this is bad style, but here it is acceptable 
	SetAxis/A/R  /w = linePanel#guiDisplay bottom
	ModifyGraph  /w = linePanel#guiDisplay mirror(left)=2
	ModifyGraph  /w = linePanel#guiDisplay mirror(bottom)=2

	Cursor /H=1 /F /P /S=0 /L=1 /w=linePanel#guiDisplay A LP_DispWave, 0.5,0.5
end

//cancel-button, leave without saving
static function LeaveLine(ctrlName):ButtonControl
	string ctrlName
	SVAR globalvalue = LP_nameWaveRed
	string waveTag = globalvalue + "_Bl"
	wave resultWave = $waveTag
	DoWindow /k linePanel
	killwaves /z LP_DispWave, LP_DispWave2, XLP_DispWave, BaseLine, resultWave, XCoords, YCoords
	killstrings /Z root:LP_nameWaveRed
	killstrings /Z root:LP_workingFolder
end


static function exitLineWindow(ctrlName):ButtonControl
	string ctrlName
	 
	DoWindow  /k linePanel
	killwaves /z LP_DispWave, LP_DispWave2, XLP_DispWave, BaseLine, xCoords, yCoords, xVals, yVals, output,listWave, listWaveSel
	killstrings /Z LP_nameWaveRed
	killstrings /Z root:LP_workingFolder
end


static function printMe(ctrlName):ButtonControl
	string ctrlName
	string name = "linePanel#guiDisplay"    //hard-coded to avoid more global variables
	 //get the name of the selected wave
	 SVAR RawWaveName = LP_nameWaveRed
	 Button cancBut disable=0
	 GeneratePolygon(RawWaveName)
end


static function AddCoord(ctrlName):ButtonControl
	string ctrlName
	string name = "linePanel#guiDisplay" 
	variable indexA, posA, heightA
	//make a reference to the coordinate waves - those have to be present in the current data folder
	wave xVals = XCoords
	wave yVals = YCoords
	SVAR RawWaveName = LP_nameWaveRed
	variable length = numpnts(XCoords)
	
	wave /t listWave = listWave
	wave listWaveSel = listWaveSel

	Redimension /N=(length+1,2) listWave
	Redimension /N=(length +1,2) listWaveSel

	listWaveSel[length][] = 2     //note that the index starts from 0  

	
	redimension /d /n=(length + 1)  xVals
	redimension /d /n=(length + 1) yVals
	//now fill in the cursor coordinates into xVals and yVals
	// those values are later on used to generate the polygon background
	indexA = pcsr(A,name)   
	posA = hcsr(A, name)
	heightA= vcsr(A,name)
	
	xVals[length + 1] = posA
	yVals[length + 1] = heightA
	
	listWave[length+1][0]=num2str(posA)
	listWave[length+1][1]=num2str(heightA)
	
	
	if (numpnts(xVals) ==1)
		AppendToGraph /w=linePanel#guiDisplay YCoords vs XCoords
		ModifyGraph /w=linePanel#guiDisplay mode(YCoords)=3, marker(YCoords)=19    //It is necessary to name the window, otherwise: possibly(!) error
	elseif (numpnts(xVals) >= 2)
		GeneratePolygon(RawWaveName)
	endif
end


static function DelCoord(ctrlName):ButtonControl
	string ctrlName
	//make a reference to the coordinate waves
	wave xVals = XCoords
	wave yVals = YCoords
	SVAR RawWaveName = LP_nameWaveRed
	
	variable length = numpnts(XCoords)
	wave /t listWave = listWave
	wave listWaveSel = listWaveSel

	
	if ( length > 0)
		redimension /n=(length - 1)  xVals
		redimension /n=(length - 1) yVals
		Redimension /N=(length - 1,2) listWave
		Redimension /N=(length - 1,2) listWaveSel
	endif
	
	if (numpnts(xVals) >= 2)
		GeneratePolygon(RawWaveName)
	endif
end



//Calculate a polygon background for XPS data
//.................................................................

static function GeneratePolygon(waveTag)
	string waveTag  //this is the name of the raw wave
	wave rawWave = $waveTag
	variable i, j
	string newWaveTag    //name of the final output wave
	
	wave xRawVals = XCoords
	wave yRawVals = YCoords
	duplicate /o xRawVals, xVals
	duplicate /o yRawVals, yVals
	wave xVals = xVals
	wave yVals = yVals
	//now sort the entries accordingly 
	Sort xVals,xVals,yVals   
	 
	variable numXYpoints = numpnts(XCoords)
	variable slope, offset
	
	//make the wave to keep the polygon and then the outputwave
	duplicate /o $waveTag output
	wave output = output
	
	//acquire information on the x-values of the raw wave   //right is always the smallest value
	variable left = max(leftx(rawWave),rightx(rawWave))   
	variable right = min(leftx(rawWave),rightx(rawWave))
	variable xStep = abs(left - right)/numpnts(rawWave)
	//print left, right,xStep
	
	//find out whether if the values in the wave are ascending or descending
	variable currentPos 
	
	variable trend              //1 is descending , 0 is ascending
	if ( leftx(rawWave) > rightx(rawWave))          // as in a usual .itx
		currentPos = left
		trend = 1
	else
		currentPos = right            //in an ascii
		trend = 0
	endif
	
	//now go through the output wave and assign new values
	for ( i = 0; i < numpnts(rawWave); i += 1)
		if (trend == 0)          //the subsequent values are ascending
			currentPos += xStep   
		else
			currentPos -= xStep
		endif
		
		for ( j = 1;  j < numXYPoints; j += 1)   //the first polygon point is used only to create the straight line between 1 and 2
			if (currentPos < xVals[j])
				slope = ( yVals[ j ] - yVals[ j - 1 ] ) / ( xVals[ j ] - xVals[ j - 1 ] )
				offset = yVals[ j ] - slope*xVals[ j ]
				output[i] = offset + slope * currentPos
				break  //leave the j loop on the first success
			endif 
			if (currentPos > xVals[numXYPoints-1])
				slope = ( yVals[numXYPoints-1 ] - yVals[ numXYPoints-2 ] ) / ( xVals[ numXYPoints-1] - xVals[ numXYPoints-2 ] )
				offset = yVals[ numXYPoints-1 ] - slope*xVals[ numXYPoints-1 ]
				output[i] = offset + slope * currentPos
				
			endif
		endfor
	endfor
	
	//now display the whole stuff .............................................
	//.....................................................................................
	
	RemoveFromGraph /Z /w = linePanel#guiDisplay2 $"#0"
	RemoveFromGraph /Z /w =linePanel#guiDisplay output
	
	newWaveTag = waveTag + "_Bl"
	duplicate /o /d rawWave, $newWaveTag
	wave finalOutput = $newWaveTag
	
	RemoveFromGraph /Z /w = linePanel#guiDisplay $"#2"
	
	finalOutput -= output
	AppendToGraph /w =linePanel#guiDisplay output
	AppendToGraph /w =linePanel#guiDisplay2 finalOutput 
	SetAxis/A/R  /w = linePanel#guiDisplay2 bottom
	ModifyGraph /w= linePanel#guiDisplay2 zero(left)=2
	ModifyGraph  /w = linePanel#guiDisplay2 mirror(left)=2
	ModifyGraph  /w = linePanel#guiDisplay2 mirror(bottom)=2
	ModifyGraph  /w = linePanel#guiDisplay2 rgb($newWaveTag)=(0,26112,39168)
	
end
