#pragma rtGlobals=1		// Use modern global access method.
#pragma hide=1
#pragma moduleName = XPSTSP
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


static function LaunchShirlPanel()
	String /G root:SP_workingFolder
	SVAR location =root:SP_workingFolder
	DoWindow ShirlPanel     //this writes a 1 into V_Flag, if the panel is already open
	if (V_Flag)    //if it already exists
		DoWindow /F ShirlPanel    //bring  it to front
		return -1   //and leave without anything else
	endif
	location = GetDataFolder(1)
	draw()
	
end

//define the gui and the global variables

static function draw()
//	GetWindow kwFrameInner, wsize   //get the geometry of the Igor main window
//	variable startX, startY, xWidth, yWidth
//	
//	xWidth = 895
//	yWidth = 458
//	startx = (V_left +V_right)/7
//	starty = 10
	
	initializeShirl()
	
	if (screenresolution == 96)
		execute "SetIgorOption PanelResolution = 0"
	endif
	
	NewPanel /K=2 /N=ShirlPanel /W=(212.5,40.5,859.5,460) as "Shirley Background \\ Straight Line"
	SetDrawLayer UserBack
	SetDrawEnv fsize= 9
	DrawText 21.5,29,"Please select a wave"
	GroupBox PopUpGroup,pos={10.00,9.50},size={190.00,89.50}
	PopupMenu WavePop,pos={20.00,29},size={117.00,16.50},bodyWidth=117,proc=XPSTSP#initShirlPopUp
	PopupMenu WavePop,mode=1,popvalue=" ",value= #"WaveList(\"!*Disp*\",\";\",\"\")"
	Button okBut,pos={205.00,10.50},fsize=10, size={103.50,19.50},disable=2,proc=XPSTSP#dumpOut,title="Calculate Shirley"
	Button linearBut,pos={205.00,32.50},size={103.50,19.00},disable=2,proc=XPSTSP#subtractLine,title="Straight Line"
	Button CancBut,pos={205.00,54.50},fsize=10,size={103.50,19.00},disable=2,proc=XPSTSP#LeaveShirl,title="Undo and Exit"
	Button ExitBut,pos={205.00,78.50},fsize=10,size={103.50,19.50},proc=XPSTSP#exitShirlWindow,title="Accept and Exit"
	CheckBox ShirlCheck,pos={22.00,58.50},fsize=10,size={84.50,12.50},proc=XPSTSP#IterateCheck,title="Use iterated Shirley"
	CheckBox ShirlCheck,value= 1
	CheckBox FreeCheck,pos={22.50,77.50},fsize=10,size={88.50,12.50},disable=2,proc=XPSTSP#FreeCheck,title="Bind Cursor to wave"
	CheckBox FreeCheck,value= 1
	GroupBox Frame2,pos={317.50,4.50},size={321.00,405.50}
	GroupBox Frame1,pos={10.00,101.50},size={306.50,309.00}
	Display/W=(323,10,634,403)/HOST=# 
	RenameWindow #,guiDisplay
	SetActiveSubwindow ##
	Display/W=(15,107,310,403)/HOST=# 
	RenameWindow #,guiDisplay2
	SetActiveSubwindow ##

	if (screenResolution == 96)
		execute "SetIgorOption PanelResolution = 1"
	endif
	
end



static function LeaveShirl(ctrlName):ButtonControl
	string ctrlName
	//SVAR value = SP_nameWaveRed
	//string notIteratedWaveTag = value + ".S"
	//string iteratedWaveTag = value + ".iS"
	//string lineWaveTag = value + ".l"
	//wave shirleyWave = $notIteratedWaveTag
	//wave lineWave = $lineWaveTag
	//wave shirleyIteratedWave = $iteratedWaveTag
	
	DoWindow  /k ShirlPanel
	killwaves /z SP_DispWave, SP_DispWave2, XSP_DispWave, shirleyBack, shirleyWave, LineSubtractWave, lineWave, shirleyIteratedWave
	killwaves /z SP_workWave, SP_ShirleyWave
	killstrings /Z SP_nameWaveRed, root:SP_workingFolder
	killvariables /Z V_left, V_right, V_top, V_bottom, SP_FreeCheck
end

static function initializeShirl()
	SVAR name = root:SP_workingFolder
	SetDataFolder name
	Variable /G SP_IterateCheck = 1    //0 or 1, whether the "iterate Shirley"-CheckBox is activated or not
	Variable /G SP_FreeCheck = 1    //0 or 1, whether the "free cursor"-CheckBox is activated or not
	String /G SP_nameWaveRed = StringFromList(0,WaveList("!*Disp*",";",""))
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Function to react to the Check-Box "ShirlCheck"
///

static function IterateCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	NVAR value = SP_IterateCheck
	value = checked
end


static function FreeCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	NVAR value = SP_FreeCheck
	value = checked
	if (checked == 0)
		Cursor /F /P  / w=ShirlPanel#guiDisplay A  $"SP_DispWave" ,0.2, 0.5
		Cursor /F /P  / w=ShirlPanel#guiDisplay B  $"SP_DispWave" ,0.9, 0.5
	elseif (checked == 1 )
		print "wave evaluation left/right  ", leftx($"SP_DispWave"), " / ", pnt2x($"SP_DispWave",numpnts($"SP_DispWave")-1)
		Cursor  /w=ShirlPanel#guiDisplay A  $"SP_DispWave", leftx($"SP_DispWave") 
		Cursor /w = ShirlPanel#guiDisplay B $"SP_DispWave", pnt2x($"SP_DispWave",numpnts($"SP_DispWave")-1) 
	endif
end


static function initShirlPopUp(ctrlName,popNum,popStr): PopupMenuControl
//as soon as a wave is selected, it is displayed and cursors appear
	string ctrlName
	variable popNum
	String popStr
	//local reference to a global variable
	SVAR value = SP_nameWaveRed
	value = popStr                              //write the selection to the global string
	variable highBindPos, lowBindPos
	variable switchVar
	
	Button okBut disable=0
	Button linearBut disable=0
	Button CancBut disable=2
	wave WorkWave = $value
	CheckBox FreeCheck, disable = 0, value = 1
	duplicate /o /d WorkWave, SP_DispWave
	WaveStats /Q WorkWave
	
	RemoveFromGraph /Z /W=ShirlPanel#guiDisplay /Z $"#0" $"#1" $"#2" $"#3" $"#4"   //more traces..to be on the safe side
	RemoveFromGraph /Z /w = ShirlPanel#guiDisplay2 $"#0", $"#1"
	AppendToGraph /W=ShirlPanel#guiDisplay SP_DispWave
	ModifyGraph /W=ShirlPanel#guiDisplay rgb(SP_DispWave)=(0,0,0) 
	ModifyGraph /W=ShirlPanel#guiDisplay minor(bottom) = 1
	//the name of the panel is hard-coded, usually this is bad style, but here it is acceptable 
	highBindPos = leftx($"SP_DispWave")
	lowBindPos = pnt2x($"SP_DispWave",numpnts($"SP_DispWave")-1)
	if ( highBindPos < lowBindPos)
	 	switchVar = highBindPos
	 	highBindPos = lowBindPos
	 	lowBindPos = switchVar
	 endif
	Cursor  /w=ShirlPanel#guiDisplay A  SP_DispWave, highBindPos
	Cursor /w = ShirlPanel#guiDisplay B SP_DispWave, lowBindPos 
	
	//Cursor /F /P  / w=ShirlPanel#guiDisplay A  SP_DispWave,0.2, 0.5
	//Cursor /F /P  / w=ShirlPanel#guiDisplay B  SP_DispWave,0.9, 0.5
	SetAxis /w=ShirlPanel#guiDisplay left 0.9*V_min, 1.15*V_max
	TextBox /w=ShirlPanel#guiDisplay /N=legendText /K        //delete the textbox if it is there
	TextBox /w=ShirlPanel#guiDisplay /N=legendText /F=0 /A = LT "Use  cursors to set the background\rX position is irrelevant for Shirley"
	SetAxis/A/R  /w = ShirlPanel#guiDisplay bottom
	ModifyGraph  /w = ShirlPanel#guiDisplay mirror(left)=2
	ModifyGraph  /w = ShirlPanel#guiDisplay mirror(bottom)=2
	
	//SP_DispWave is deleted when the panel is closed	 
end

static function exitShirlWindow(ctrlName):ButtonControl
	string ctrlName
	 
	DoWindow  /k ShirlPanel
	killwaves /z SP_DispWave, SP_DispWave2, XSP_DispWave, shirleyBack
	killwaves /z SP_ShirleyWave, SP_workWave
	killstrings /Z SP_nameWaveRed, root:SP_workingFolder
	killvariables /Z SP_IterateCheck, SP_FreeCheck
	killvariables /Z V_left, V_right, V_top, V_bottom
end


static function dumpOut(ctrlName):ButtonControl
	string ctrlName
	string name = "ShirlPanel#guiDisplay"    //hard-coded to avoid more global variables
	 //get the name of the selected wave
	 SVAR workWaveName = SP_nameWaveRed
	 variable switchVar
	 
	//read out the cursor position
	 variable posA = hcsr(A, name)
	 variable heightA= vcsr(A,name)
	 print " "
	 print "Position of A (round)", posA,heightA
	 
	 variable posB = hcsr(B,name)
	 variable heightB=vcsr(B,name)
	 print "Position of B (rect)", posB, heightB
	 if ( posA < posB)
		switchVar = heightA
		heightA = heightB 
	 	heightB = switchVar
		switchVar = posA
		posA = posB
	 	posB = switchVar
	 endif
	 Button CancBut disable=0
	 //DoShirley(value,posA,heightA, posB, heightB)	
	IterateShirl(workWaveName,posA,heightA, posB, heightB)
end
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Iterated and not-iterated Shirley background
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static function IterateShirl(waveTag, startx, starty, endx, endy)
	string waveTag
	variable startx, starty
	variable endx, endy
	
	//check whether the wave has the regular XPS order = "from high energy to low energy" 
	//or it is reverse "from low energy to high energy"
	variable highBindPos = leftx($"SP_DispWave")
	variable lowBindPos = pnt2x($"SP_DispWave",numpnts($"SP_DispWave")-1)
	
	variable orderIndicator = 0 // 0 means everything is all right, i.e. from "high to low"
	
	if ( lowBindPos >= highBindPos)
		orderIndicator = 1
	endif
	
	wave rawWave = $waveTag
	duplicate /o rawWave SP_workWave
	duplicate /o rawWave SP_ShirleyWave
	
	variable wholeArea 
	variable tempSum
	
	//integer variables
	NVAR checked = SP_IterateCheck
	variable i,j,k
	variable Iterations = 10          				 //default: use iterated shirley
	variable wavelength = dimSize(rawWave,0)
	
	//check, whether to use the iterated shirley or not
	if (checked == 0)
		Iterations =1
		//print "Number of iterations:", Iterations
	endif
	
	SP_ShirleyWave = endy      //Initialize the first shirley-wave as the offset, before starting the iteration
	for (k = 0; k < Iterations; k += 1)
		SP_workWave = rawWave - SP_ShirleyWave
		//take only positive areas into account, otherwise everything gets numerically uncertain
		wholeArea=0
		for (j = 0; j< wavelength; j+=1)      
			wholeArea += abs(SP_workWave[j])
		endfor
		
		//the following step depends, if the wave is in regular order or reverse		
		if ( orderIndicator == 0)                  //if this is the case, just go through the wave
			for (i = 0; i<wavelength; i+=1)
				tempSum=0
				for (j = i; j < wavelength; j += 1)
					tempSum += abs(SP_workWave[j])
				endfor
				SP_ShirleyWave[i] = tempSum
			endfor
		else 
			for (i = wavelength-1; i > 0; i -= 1)     //the wave is reverse, start from bottom
				tempSum=0
				for (j = i; j > 0; j -= 1)
					tempSum += abs(SP_workWave[j])
				endfor
				SP_ShirleyWave[i] = tempSum
			endfor
			
		endif
		SP_ShirleyWave = (starty-endy)*SP_ShirleyWave / wholeArea
	endfor
	
	SP_workWave = rawWave - SP_ShirleyWave - endy
	
	//duplicate the resulting wave and name the clone, according to the raw data
	if ( checked != 0) 
		duplicate /o SP_workWave $waveTag+"_iS"
	else
		duplicate /o SP_workWave $waveTag+"_S"
	endif 
	
	//add offset to the SP_ShirleyWave, to display it properly together with the raw-data
	SP_ShirleyWave += endy
	WaveStats /Q SP_workWave
	//plot
	RemoveFromGraph /Z /w = ShirlPanel#guiDisplay $"#1"  //If there is something, remove it
	RemoveFromGraph /Z /w = ShirlPanel#guiDisplay2 $"#0", $"#1"  //If there is something, remove it
	AppendToGraph /w =ShirlPanel#guiDisplay2 SP_workWave
	AppendToGraph /w =ShirlPanel#guiDisplay SP_ShirleyWave
	
	SetAxis/A/R  /w = ShirlPanel#guiDisplay2 bottom
	ModifyGraph /w=ShirlPanel#guiDisplay2 zero(left)=2
	ModifyGraph  /w = ShirlPanel#guiDisplay2 mirror(left)=2
	ModifyGraph  /w = ShirlPanel#guiDisplay2 mirror(bottom)=2
	ModifyGraph  /w = ShirlPanel#guiDisplay2 rgb(SP_workWave)=(0,26112,39168)
	ModifyGraph  /w = ShirlPanel#guiDisplay2 minor(bottom)=1
	SetAxis /w=ShirlPanel#guiDisplay2 left -0.1*V_max, 1.15*V_max
end


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// subtract a straight line
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static function subtractLine(ctrlName):ButtonControl
	string ctrlName
	string name = "ShirlPanel#guiDisplay"    //hard-coded to avoid more global variables
	variable slope
	 variable switchVar
	//get the name of the selected wave
	SVAR rawWaveName = SP_nameWaveRed        //get the name of the pre-existing wave
	wave WorkingWave = $rawWaveName                //and make a local reference to it
	 
	string waveTag = rawWaveName + "_l"                //get the name
	duplicate /o WorkingWave $waveTag			//create a (global) wave with this name
	wave ResultWave = $waveTag                            //and make a local reference to it
	
	duplicate /o WorkingWave SP_DispWave2          //create a wave to hold the straight line
	
	//read out the cursor position
	 variable posA = hcsr(A, name)
	 variable heightA= vcsr(A,name)
	 
	 variable posB = hcsr(B,name)
	 variable heightB=vcsr(B,name)
	 
	 if ( posA < posB)
		switchVar = heightA
		heightA = heightB 
	 	heightB = switchVar
	 	switchVar = posA
	 	posA = posB
	 	posB = switchVar
	 endif
	 
	 //calculate the straight line
	slope = (heightA-heightB)/(posA-posB)        //posA>posB
	ResultWave = ResultWave - (slope*(x-posB) + heightB)
	SP_DispWave2 = slope*(x-posB) + heightB

	WaveStats /Q ResultWave
	//and display it 
	RemoveFromGraph /Z /w = ShirlPanel#guiDisplay $"#1"  //If there is something, remove it
	RemoveFromGraph /Z /w = ShirlPanel#guiDisplay2 $"#0", $"#1"  //If there is something, remove it
	AppendToGraph /w =ShirlPanel#guiDisplay2 ResultWave
	AppendToGraph /w=ShirlPanel#guiDisplay SP_DispWave2
	SetAxis/A/R  /w = ShirlPanel#guiDisplay2 bottom
	ModifyGraph /w=ShirlPanel#guiDisplay2 zero(left)=2
	ModifyGraph  /w = ShirlPanel#guiDisplay2 mirror(left)=2
	ModifyGraph  /w = ShirlPanel#guiDisplay2 mirror(bottom)=2
	ModifyGraph  /w = ShirlPanel#guiDisplay2 rgb($waveTag)=(0,26112,39168)

	
	ModifyGraph  /w = ShirlPanel#guiDisplay2 minor(bottom)=1
	SetAxis /w=ShirlPanel#guiDisplay2 left -0.1*V_max, 1.15*V_max
	Button CancBut disable=0 
end
