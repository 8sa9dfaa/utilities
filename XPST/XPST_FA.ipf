#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=1		// Use modern global access method.
#pragma hide=1
#pragma ModuleName = XPSTFA

//////////////////////////////////////////////////////////////////////////////////
//Licence
//////////////////////////////////////////////////////////////////////////////////
//
//	If you use the 'Fit Assistant' to analyze data, please read and cite the following paper:
//	Surface and Interface Analysis, (2014), 46, 505-511
//	This publication contains more details on the fit static function used by XPST.
//
//	XPST is a front-end to the IgorPro fitting engine. Although every possible effort was made 
//	to prevent serious bugs and wrong results, the author can not give any warranty for XPST as 
//	large parts actually depend on the underlying IgorPro code. 
//	Author: Dr. Martin Schmid
//
//////////////////////////////////////////////////////////////////////////////////

//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// 	Panel for the  CREATION OF A COEFFICIENT WAVE 
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// The coefficient wave W_coef is the wave, where Igor reads out starting values for fits and saves the 
// results of a fit. This wave is REALLY important.
//
//This code implements the following functionality
//
// 1. Select a spectrum (only waveform or x-y data)
// 2. Select a Peak Type
// 3. Set a cursor to the spectrum, each time a "add" button is pressed, its position is appended
//    to a new created coefficient wave,   ALWAYS named W_coef
// 
// This tool offers a way to set the starting values for a peak fit with the functions Gauss Singlet and Voigt
// functions defined in the files "PEFitFunctions.ipf"


static constant epsilonVal = 1e-9
static constant interval = 1e-5                   //that is the epsilon value which is applied by default
static constant Width_Start = 0.8
static constant Width_Min = 0.4
static constant Width_Max = 2

static constant GLratio_Start = 0.3
static constant GLratio_Min = 0.05
static constant GLratio_Max = 0.95

static constant Asym_Start = 1e-3
static constant Asym_Min = 1e-4
static constant Asym_Max = 10

static constant Asym_Shift_Start = 1e-3
static constant Asym_Shift_Min = 1e-5
static constant Asym_Shift_Max = 0.5
static constant Spin_Split_Min = 1e-4
static constant Spin_Split_Max = 20
static constant Spin_Ratio_Min = 1e-4
static constant Spin_Ratio_Max = 1
static constant CursorPrecision = 0.15    //determines as a factor the constraints of the peak position limit = posCursor +/- CursorPrecision x EnergyWindow
static constant randomJump = 0.2     	    // for random fitting mode, determines the random variation of the peak position, has to be smaller than CursorPrecision 
							 					    // otherwise, there would be a conflict with the constraints
//constant noiseThreshold = 0.1
constant gPf = 1.064467019          //GaussPreFactor  1/ ( sqrt( 4 ln(2) / pi ) )
constant gAf = 2.7725887222         //GaussArgumentFactor
constant integrationCorrection = 0.9964//to account for the numerical difference between an integration from +inf to -inf and +/- 90*FWHM

//if you want to change the integration range for the peak area, change the value below
constant IntegrationInterval = 90         //integration width in UNITS of PEAK FWHM






static function LaunchCursorPanel()

	DoWindow CursorPanel   //this will write "1" into V_Flag if the window is open already
	if (V_Flag )
		DoWindow /F CursorPanel  // if it is already open, bring it to front
		return -1
	endif
	 //this should be in the initializing static function, but then it gives problems with the setVariable elements
	   //remember this ... in order leave the project folder later on
	cursorPanelCall()
	SVAR StartingFolder = root:STFitAssVar:ST_StartDirectory
	StartingFolder = GetDataFolder(1)
end







//Window CursorPanel() : Panel
static function cursorPanelCall()
	//string subfolder = root:CP_workingFolder
	//Button showBut,pos={340,83},size={159,31},proc=XPSTFA#displayWavesNewProjectPanel,title="Display Data   >>"
	initCursorPanel()

	/////////////////////////////////////////////////////////////////////////////////////////////////
	
	if (screenresolution == 96)
		execute "SetIgorOption PanelResolution = 0"
	endif
//	
	NewPanel /K=2 /W=(55,41.5,893,469.5) /N=CursorPanel as "Fit Assistant ------  XPST 1.3"
//	RenameWindow CursorPanel0, CursorPanel
	ModifyPanel cbRGB=(65534,65534,65534)
	
	SetDrawLayer UserBack
	SetDrawEnv linefgc= (65535,65535,65535),fillfgc= (13056,13056,0),fillbgc= (0,0,0)
	DrawRect 24,134.9,136,240.4
	SetDrawEnv fsize= 9
	DrawText 696.3,203.6,"Convergence detection"
	SetDrawEnv fsize= 9
	DrawText 696.3,236.7,"coarse"
	SetDrawEnv fsize= 9
	DrawText 774.4,237.3,"fine"
	SetDrawEnv fsize= 9,fstyle= 5,textrgb= (0,26112,39168)
	DrawText 509.25,113.45,"Parameters to link:"
	SetDrawEnv linefgc= (65280,54528,32768),fillfgc= (65280,65280,48896)
	DrawRect 28.5,133.4,141,236.9
	SetDrawEnv fname= "default",fsize= 9
	DrawText 39.5,154.4,"1. Load a spectrum"
	SetDrawEnv fname= "default",fsize= 9
	DrawText 38.5,172.9,"2. Use the crosshair"
	SetDrawEnv fname= "default",fsize= 9
	DrawText 48.5,182.4,"to mark a peak"
	SetDrawEnv fname= "default",fsize= 9
	DrawText 36.5,197.9,"3. Press 'Add Peak'"
	SetDrawEnv fname= "default",fsize= 9
	DrawText 35.5,214.9,"4. Press 'Start Fit' "
	
	
	TabControl OptionsTab,pos={497.00,4.00},size={333.00,419.00},proc=XPSTFA#ManageOptionsTab
	TabControl OptionsTab,fSize=9,fStyle=1,tabLabel(0)="All Options"
	TabControl OptionsTab,tabLabel(1)="Quick Fit Setup",value= 0
	
	ListBox QuickEditList,pos={508,98},size={312.00,315.00},fsize=10,disable=1,proc=XPSTFA#refresh
	//ListBox QuickEditList,colorWave=root:STFitAssVar:myColors
	ListBox QuickEditList,widths={0,0,70,70,40,70,70,1}
	
	TitleBox commentAdd,pos={596.40,72.00},size={49.20,10.20},title="# 0 = no link "
	TitleBox commentAdd,font="Arial",fSize=9,frame=0,fStyle=0,fColor=(0,26112,39168)
	TitleBox commentAdd1,pos={538.20,84.60},size={110.40,10.20},title="Otherwise: Link to peak  #n  "
	TitleBox commentAdd1,font="Arial",fSize=9,frame=0,fStyle=0
	TitleBox commentAdd1,fColor=(0,26112,39168)
	TitleBox commentLink,pos={608.40,34.20},size={31.20,12.00},title="Link to:"
	TitleBox commentLink,fSize=9,frame=0,fStyle=1,fColor=(1,26221,39321)
	TitleBox comment,pos={508,83},size={159.00,12.00},disable=1,title="Legend available in the in 'Full Editor'"
	TitleBox comment,fSize=10,frame=0,fStyle=1
	TitleBox comment1,pos={378.60,405.00},size={103.20,12.00},title="On Display: Initial Values"
	TitleBox comment1,fSize=9,frame=0,fStyle=1,fColor=(65280,0,0)
	TitleBox notify1,pos={174.00,375.00},size={78.00,12.00},title="\t(Parent Data Folder)"
	TitleBox notify1,labelBack=(65000,65000,65000),fSize=9,frame=0
	TitleBox notify1b,pos={174.00,389},size={60.60,12.00},title="\t(Current Project)"
	TitleBox notify1b,labelBack=(65000,65000,65000),fSize=9,frame=0
	TitleBox notify2,pos={174.00,403},size={37.80,12.00},title="\t(Spectrum)"
	TitleBox notify2,labelBack=(65000,65000,65000),fSize=9,frame=0

	Slider ToleranceControl,pos={695,212},size={90.00,9.60},proc=XPSTFA#DisplayTol
	Slider ToleranceControl,limits={-1,-5,0},value= -3,live= 0,vert= 0,ticks= 0
	


	GroupBox PopUpGroup,pos={0.60,6.60},size={156.00,114.00},title="New / Open / Import\\Z00\r"
	GroupBox PopUpGroup,fSize=10,fStyle=1
	GroupBox Frame2,pos={162.60,6.60},size={327.00,414.00},title="Select Peaks and Observe the Fit\\Z00\r"
	GroupBox Frame2,fSize=10,fStyle=1
	GroupBox ExitGroup,pos={0.60,255.00},size={156.00,165.00},title="Save / Export / Quit\\Z00\r"
	GroupBox ExitGroup,fSize=10,fStyle=1
	GroupBox WorkGroup2,pos={500.40,30.60},size={156.00,218.40},fSize=9,fStyle=1
	GroupBox WorkGroup2,fColor=(0,26112,39168)
	GroupBox WorkGroup4,pos={500.40,265.20},size={319.80,144.00},fSize=9,fStyle=1
	CheckBox RecordCheck,pos={696,122},size={86.40,37.80},disable=2,proc=XPSTFA#IterationRecordCheck,title="Record iterations \rin M_Iterates\r(debug a failed fit)"
	CheckBox RecordCheck,fSize=10,value= 0
	CheckBox RobustCheck,pos={696,98},size={76.20,12.60},disable=2,proc=XPSTFA#RobustCheck,title="Robust curve fit"
	CheckBox RobustCheck,fSize=10,value= 0
	//CheckBox SuppressCheck,pos={702.00,102.60},size={81.00,25.20},disable=2,proc=XPSTFA#SuppressCheck,title="Suppress \rcurve-fit window"
	//CheckBox SuppressCheck,fSize=10,value= 0
	CheckBox check0,pos={519.00,124.20},size={30.00,12.60},disable=2,proc=XPSTFA#STAreaLinkCheck,title="Area"
	CheckBox check0,fSize=10,fColor=(0,26112,39168),value= 0
	CheckBox check1,pos={600.00,124.20},size={43.80,12.60},disable=2,proc=XPSTFA#STPositionLinkCheck,title="Position"
	CheckBox check1,fSize=10,fColor=(0,26112,39168),value= 0
	CheckBox check2,pos={519.00,139.20},size={36.00,12.60},disable=2,proc=XPSTFA#STWidthLinkCheck,title="Width"
	CheckBox check2,fSize=10,fColor=(0,26112,39168),value= 1
	CheckBox check4,pos={600.00,139.20},size={43.80,12.60},disable=2,proc=XPSTFA#STGLLinkCheck,title="GL ratio"
	CheckBox check4,fSize=10,fColor=(0,26112,39168),value= 1
	CheckBox check3,pos={519.00,154.80},size={58.80,12.60},disable=2,proc=XPSTFA#STAsymLinkCheck,title="Asymmetry"
	CheckBox check3,fSize=10,fColor=(0,26112,39168),value= 1
	CheckBox check5,pos={519.00,172.20},size={86.40,12.60},disable=2,proc=XPSTFA#STSOSLinkCheck,title="Multiplet-Splitting"
	CheckBox check5,fSize=10,fColor=(0,26112,39168),value= 1
	CheckBox check6,pos={519.00,187.80},size={114.00,12.60},disable=2,proc=XPSTFA#STDoubletRatioLinkCheck,title="Multiplet Intensity Ratios"
	CheckBox check6,fSize=10,fColor=(0,26112,39168),value= 1
	Button LoadNewBtn,pos={27.00,35.40},size={108.60,21.60},proc=XPSTFA#CallSTNewProjectPanel,title="  New Project  "
	Button LoadNewBtn,fSize=10,fStyle=1
	Button OpenProjectBtn,pos={27.00,56.4},size={108.60,21.60},proc=XPSTFA#CallSTProjectPanel,title="Open  "
	Button OpenProjectBtn,fSize=10,fStyle=1
	Button ImportFitBut,pos={27.00,77.4},size={108.60,21.60},proc=XPSTFA#STImportFit,title="Import  "
	Button ImportFitBut,fSize=10,fStyle=1
	
	Button addBut,pos={508.8,45.60},size={87.00,21.6},disable=2,proc=XPSTFA#ReadOutPosition,title="+          Add Peak"
	Button addBut,fSize=10,fStyle=1,fColor=(60928,60928,60928)
	Button DeleteBut,pos={508.80,219.00},size={87.00,21.6},disable=2,proc=XPSTFA#RemoveEntry,title="-  Remove Peak"
	Button DeleteBut,fSize=10,fStyle=1,fColor=(60928,60928,60928)
	
	Button FitBut,pos={508.80,279.60},size={135.00,21.60},disable=2,proc=XPSTFA#launchCurveFit,title="Start Fit"
	Button FitBut,help={"Starts the curve fit"},fSize=9,fStyle=1
	Button FitBut,fColor=(64256,56320,1024)
	Button ReUseBut,pos={508.8,300.60},size={135.00,21.60},disable=2,proc=XPSTFA#ReUseWCoef,title="Result -> New Initial "
	Button ReUseBut,fSize=10,fStyle=1
	Button ConstraintBut,pos={508.80,321.60},size={135.00,21.60},disable=2,proc=XPSTFA#editDisplayWave,title="Peak Editor"
	Button ConstraintBut,fSize=10,fStyle=1,fColor=(0,26112,26112)
	Button ReportViewerBtn,pos={673.20,300.60},size={135.00,21.60},disable=2,proc=XPSTFA#CallPeakViewer,title="Results / Report"
	Button ReportViewerBtn,fSize=10,fStyle=1
	Button FinePlotBtn,pos={673.20,279.00},size={135.00,21.60},disable=2,proc=XPSTFA#makeFinePlot,title="Plot ( + Save)"
	Button FinePlotBtn,fSize=10,fStyle=1
	Button UpDateBut,pos={673.20,352.20},size={135.00,21.60},disable=2,proc=XPSTFA#upDateFitDisplay,title="Show initial"
	Button UpDateBut,fSize=10,fStyle=1
	
	
	Button FitBut2,pos={697.80,27.00},size={120.00,24.00},proc=XPSTFA#launchCurveFit,title="Start Fit"
	Button FitBut2,fSize=10,fStyle=1,fColor=(64256,56320,1024)
	Button PeakEditorBut2,pos={602.00,27.00},size={90.00,24.00},proc=XPSTFA#editDisplayWave,title="Full Editor"
	Button PeakEditorBut2,fSize=10,fStyle=1,fColor=(0,26112,26112)
	Button AddPeakBut2,pos={507.00,27.00},size={90.00,24.00},proc=XPSTFA#ReadOutPosition,title="Add Peak"
	Button AddPeakBut2,fSize=10,fStyle=1,fColor=(65535,65535,65535)
	
	Button RemovePeakBut2,pos={507.00,53.40},size={90.00,24.00},proc=XPSTFA#RemoveEntry,title="Remove Peak"
	Button RemovePeakBut2,fSize=10,fStyle=1,fColor=(65535,65535,65535)
	Button ReUseBut2,pos={697.80,53.4},size={120.00,24.00},proc=XPSTFA#ReUseWCoef,title="Result -> New Initial "
	Button ReUseBut2,fSize=10,fStyle=1,fColor=(65535,65535,65535)
	
	Button CleanBut,pos={26.40,277.4},size={108.60,21.60},disable=2,proc=XPSTFA#saveFit,title="Save"
	Button CleanBut,fSize=10,fStyle=1
	Button SaveAsBut,pos={26.40,298.40},size={108.60,21.60},disable=2,proc=XPSTFA#saveFitAs,title="Save As"
	Button SaveAsBut,fSize=10,fStyle=1
	Button resetBut,pos={26.40,319.4},size={108.60,21.60},disable=2,proc=XPSTFA#STsaveTemplate,title="Save as Template "
	Button resetBut,fSize=10,fStyle=1
	Button ExportFitBut,pos={26.4,340.4},size={108.60,21.60},disable=2,proc=XPSTFA#STExportFit,title="Export Fit Project"
	Button ExportFitBut,fSize=10,fStyle=1
	
	Button restorBut,pos={26.40,361.4},size={108.60,21.60},disable=2,proc=XPSTFA#RestoreSavedFit,title="Recover last Saved"
	Button restorBut,fSize=10,fStyle=1
	
	Button closeBut,pos={26.40,391.80},size={108.60,21.60},proc=XPSTFA#destroyCursorPanel,title="Close "
	Button closeBut,fSize=10,fStyle=1
	Button UpDateButFin,pos={673.20,373.80},size={135.00,21.60},disable=2,proc=XPSTFA#upDateFitDisplayFinalVal,title="Show final"
	Button UpDateButFin,fSize=10,fStyle=1
	SetVariable InputFitMin,pos={548.40,381.00},size={96.00,13.80},proc=XPSTFA#callUpdate,title="x min"
	SetVariable InputFitMin,fSize=9,fStyle=0
	SetVariable InputFitMin,limits={0,20000,0},value= root:STFitAssVar:STFitMin
	SetVariable InputFitMax,pos={509.40,362.40},size={135.00,13.80},proc=XPSTFA#callUpdate,title="Range:    x max"
	SetVariable InputFitMax,fSize=9,fStyle=0
	SetVariable InputFitMax,limits={0,20000,0},value= root:STFitAssVar:STFitMax
	SetVariable InputSetLink,pos={597.00,49.80},size={42.00,13.80},proc=XPSTFA#SetPeakToLink,title=" # "
	SetVariable InputSetLink,fSize=9
	SetVariable InputSetLink,limits={0,3,1},value= root:STFitAssVar:STPeakToLink
	SetVariable InputRemoveLink,pos={597,222},size={42,13.80},proc=XPSTFA#SetPeakToRemove,title=" # "
	SetVariable InputRemoveLink,fSize=9
	SetVariable InputRemoveLink,limits={1,3,1},value= root:STFitAssVar:STPeakToRemove
	SetVariable InputRemoveLink2,pos={601,57},size={42,14.40},proc=XPSTFA#SetPeakToRemove,title=" # "
	SetVariable InputRemoveLink2,fSize=10
	SetVariable InputRemoveLink2,limits={1,3,1},value= root:STFitAssVar:STPeakToRemove
	SetVariable InputMaxFitIterations,pos={672.00,48.60},size={132.60,14.40},title="Max. Iterations"
	SetVariable InputMaxFitIterations,fSize=10,limits={1,100,1}
	GroupBox WorkGroup8,pos={662.40,30.60},size={157.80,218.40}
	Display/W=(174,28,482,73)/HOST=#  

	RenameWindow #,guiCursorDisplayResidual
	SetActiveSubwindow ##


	Display/W=(174,72,482,226)/HOST=#  
	RenameWindow #,guiCursorDisplay
	SetActiveSubwindow ##

	
	Display/W=(174,229,482,367)/HOST=#  
	RenameWindow #,guiCursorDisplayFit
	SetActiveSubwindow ##


	if (screenResolution == 96)
		execute "SetIgorOption PanelResolution = 1"
	endif
	
	
	/////////////////////////////////////////////////////////////////////////////////////
	if (!Exists("KeepCheckIndicate"))
		Variable /G root:STFitAssVar:KeepCheckIndicate = 0
	//	CheckBox KeepCheck,value= 0
	else 
	//	CheckBox LoadCheck value = 1
		NVAR keepIndicate = root:STFitAssVar:KeepCheckIndicate
		keepIndicate = 1
		//CheckBox KeepCheck, value = 1 
	endif

	ManageOptionsTab("startup",0)
	
	DeActivateButtons(1)
	
end
	



static function ManageOptionsTab(name,tab)
	String name
	Variable tab

	CheckBox RecordCheck, win= CursorPanel, disable= (tab !=0) //pos={713,560},size={102,39},proc=XPSTFA#IterationRecordCheck,title="Record iterations \rin M_Iterates\r(debug a failed fit)"

	CheckBox RobustCheck,win= CursorPanel, disable= (tab !=0)//pos={714,532},size={93,14},proc=XPSTFA#RobustCheck,title="Robust curve fit"
	//CheckBox SuppressCheck,win= CursorPanel, disable= (tab !=0)//pos={843,529},size={95,26},proc=XPSTFA#SuppressCheck,title="Suppress \rcurve-fit window"
	CheckBox check0,win= CursorPanel, disable= (tab !=0)
	CheckBox check1, win= CursorPanel, disable= (tab !=0)
	CheckBox check2,win= CursorPanel, disable= (tab !=0)
	CheckBox check4,win= CursorPanel, disable= (tab !=0)
	CheckBox check3,win= CursorPanel, disable= (tab !=0)
	CheckBox check5,win= CursorPanel, disable= (tab !=0)
	CheckBox check6,win= CursorPanel, disable= (tab !=0)
	
	
	
	
	Slider ToleranceControl, win= CursorPanel, disable =(tab != 0) //,pos={721,661},size={91,19},proc=XPSTFA#DisplayTol
	SetVariable InputFitMin,win= CursorPanel, disable= (tab !=0) //pos={849,452},size={91,16},title="x min"
	SetVariable InputFitMax,win= CursorPanel, disable= (tab !=0) //pos={702,452},size={139,16},title="Range:    x max"
	SetVariable InputMaxFitIterations,win= CursorPanel, disable= (tab !=0) //pos={704,480},size={129,16},title="Max. Iterations"
	//GroupBox WorkGroup6, win= CursorPanel, disable = (tab !=0) //pos={700,630},size={153,72},fStyle=1
	GroupBox WorkGroup8, win= CursorPanel, disable = (tab != 0) //pos={699,520},size={251,101},fStyle=1
	
	//Button ConstraintBut1, win=CursorPanel, disable = (tab !=1)
	ListBox QuickEditList, win= CursorPanel, disable= (tab != 1) //pos={6,6},size={880,520},win=PeakEditor, proc=XPSTFA#refresh,listWave=STsetup,userColumnResize=1
	TitleBox comment, win=CursorPanel, disable = (tab != 1)
	Button FitBut2, win=CursorPanel, disable=(tab!=1)
	Button PeakEditorBut2,  win=CursorPanel, disable=(tab!=1)
	Button AddPeakBut2, win=CursorPanel, disable=(tab!=1)	
	Button RemovePeakBut2, win=CursorPanel, disable=(tab!=1)
	Button ReUseBut2, win=CursorPanel, disable=(tab!=1)
	SetVariable InputRemoveLink2, win=CursorPanel, disable=(tab!=1)
	
	
	TitleBox commentLink, win=CursorPanel, disable = (tab !=0)
	
	Button ReportViewerBtn,win= CursorPanel, disable = (tab != 0)

	Button FinePlotBtn,win= CursorPanel, disable = (tab != 0)

	Button FitBut, win= CursorPanel, disable = (tab != 0)

	TitleBox commentAdd, win= CursorPanel, disable = (tab != 0)	
	TitleBox commentAdd1, win=CursorPanel, disable = (tab !=0)
	
	Button addBut,win= CursorPanel, disable = (tab != 0)

	Button DeleteBut,win= CursorPanel, disable = (tab != 0)

	Button UpDateBut,win= CursorPanel, disable = (tab != 0)
	Button ConstraintBut,win= CursorPanel, disable = (tab != 0)
	Button UpDateButFin,win= CursorPanel, disable = (tab != 0)
	Button ReUseBut,win= CursorPanel, disable = (tab != 0)
	//Button restorBut,win= CursorPanel, disable = (tab != 0)
	
	Slider ToleranceControl,win= CursorPanel, disable = (tab != 0)

	SetVariable InputFitMin,win= CursorPanel, disable = (tab != 0)
	SetVariable InputFitMax,win= CursorPanel, disable = (tab != 0)
	SetVariable InputSetLink,win= CursorPanel, disable = (tab != 0)
	SetVariable InputRemoveLink,win= CursorPanel, disable = (tab != 0)                 
	SetVariable InputMaxFitIterations,win= CursorPanel, disable = (tab != 0)
	GroupBox WorkGroup4,win= CursorPanel, disable = (tab != 0)
	GroupBox WorkGroup2,win= CursorPanel, disable = (tab != 0)
	
	
	
	
	if (tab == 1)
		//TitleBox comment1,win=CursorPanel, title="On Display: Initial Values"
		
		fancyUp("fromTab")
		updateFitDisplay("fromTab")
		updateResidualDisplay("void")
	endif
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//         initialize variables
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static function initCursorPanel()
	//SVAR name = root:CP_workingFolder
	//SetDataFolder name
	
	NewDataFolder /o root:STFitAssVar
	
	Variable /G root:STFitAssVar:CleanCheckIndicate = 0
	Variable /G root:STFitAssVar:CP_IndepCheck = 0  //this variable will go later on, use the ones below instead
	Variable /G root:STFitAssVar:AreaLink=0
	Variable /G root:STFitAssVar:PositionLink=0
	Variable /G root:STFitAssVar:WidthLink=1
	Variable /G root:STFitAssVar:GLLink =1
	Variable /G root:STFitAssVar:AsymLink=1
	Variable /G root:STFitAssVar:SOSLink=1
	Variable /G root:STFitAssVar:DoubletRatioLink=1
	Variable /G root:STFitAssVar:ST_NumPeaks = 0
	Variable /G root:STFitAssVar:saved = 0
	Variable /G root:STFitAssVAr:savedLast = 0
	Variable /G root:STFitAssVar:projectStarted = 0
	Variable /G root:STFitAssVar:useTemplate = 0
	Variable /G root:STFitAssVar:STFitMin= 0
	Variable /G root:STFitAssVar:STFitMax= 0
	Variable /G root:STFitAssVar:STPeakToLink= 0
	Variable /G root:STFitAssVar:STPeakToRemove = 0
	Variable /G root:STFitAssVar:IterationsStart = 50  
	Variable /G root:STFitAssVar:AreaLinkFactorLow = 0.4
	Variable /G root:STFitAssVar:AreaLinkFactorHigh = 0.6
	Variable /G root:STFitAssVar:PositionLinkOffsetMax = 1.5
	Variable /G root:STFitAssVar:PositionLinkOffsetMin = 1.5
	Variable /G root:STFitAssVar:V_FitTol = 0.001
	Variable /G root:STFitAssVar:savedNumPeaks //for saving and recovery
	Variable /G root:STFitAssVar:keepInitConfiguration = 1     //modified 15.03.2016
	Variable /G root:STFitAssVar:EpsilonFactor = 1
	Variable /G root:STFitAssVar:WrongReported = 0
	Variable /G root:STFitAssVar:OldValueInSetup = 0
	//Variable /G root:STFitAssVar:KineticAxis = 0 //ist neu, das muss ab jetzt abgefragt werden
	
	
	string /G root:STFitAssVar:PR_nameWorkWave
	string /G root:STFitAssVar:PR_PeakType = "Singlet"
	string /G root:STFitAssVar:PR_Background = "SK"
	string /G root:STFitAssVar:PR_PeakTypeTemp  ="Singlet"
	string /G root:STFitAssVar:PR_XRawDataCursorPanel 
	string /G root:STFitAssVar:PR_FitRawData 
	string /G root:STFitAssVar:PR_CoefWave = "W_coef"
	string /G root:STFitAssVar:PR_FitWave
	string /G root:STFitAssVar:CP_workingFolder 
	string /G root:STFitAssVar:ST_StartDirectory 
	string /G root:STFitAssVar:ST_oldStartDirectory
	string /G root:STFitAssVar:ProjectName
	string /G root:STFitAssVar:TemplateName = ""
	string /G  root:STFitAssVar:nextProjectToOpen=""
	make /d /n=(6,3) /o myColors
	myColors[0][q] = 0
	myColors[1][0] = 65535
	myColors[1][1] = 0
	myColors[1][2] = 0
	myColors[2][0] = 55000
	myColors[2][1] = 60000
	myColors[2][2] = 64000
	myColors[3][0] = 51000
	myColors[3][1] = 56000
	myColors[3][2] = 60000
	myColors[4][0] = 65000
	myColors[4][1] = 55000
	myColors[4][2] = 45000
	myColors[5][0] = 65000
	myColors[5][1] = 65000
	myColors[5][2] = 65000
	
	duplicate myColors root:STFitAssVar:myColors
	killwaves /z myColors
	
	
end

static function SetPeakToLink (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR peakToLink = root:STFitAssVar:STPeakToLink
	
	SetVariable InputSetLink, win=CursorPanel, limits={0,numPeaks,1}
End


static function SetPeakToRemove (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR peakToLink = root:STFitAssVar:STPeakToRemove
	
	SetVariable InputRemoveLink, win=CursorPanel, limits={0,numPeaks,1}
	SetVariable InputRemoveLink2, win=CursorPanel, limits={0,numPeaks,1}
End


static function callUpdate (ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	if (Exists("W_Coef"))
	updateFitDisplay("void")
	updateResidualDisplay("void")
	endif
End

static function DisplayTol(name, value, event) : SliderControl
	String name	// name of this slider control
	Variable value	// value of slider
	Variable event	// bit field: bit 0: value set; 1: mouse down, 
	
	NVAR tolerance = root:STFitAssVar:V_FitTol				
	tolerance =1*10^(value)
end


static function SetEpsilonFactor(name, value, event) : SliderControl
	String name	// name of this slider control
	Variable value	// value of slider
	Variable event	// bit field: bit 0: value set; 1: mouse down, 
	
	NVAR factor = root:STFitAssVar:EpsilonFactor				
	factor =1*10^(value+5)
end


static function saveFitAs(ctrlName):ButtonControl
	string ctrlName
	checkLocation()
	SVAR parentDir = root:STFitAssVar:ST_StartDirectory
	SVAR projectName = root:STFitAssVar:projectName
	NVAR saved = root:STFitAssVar:saved             //check if it is saved at all (at any point)
	NVAR savedLast = root:STFitAssVar:savedLast   //check if the very last action was saved too
	
	NVAR fitMin = root:STFitAssVar:STFitMin
	NVAR fitMax = root:STFitAssVar:STFitMax
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks

	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	NVAR ProjectSaved = root:STFitAssVar:savedLast
	
	SVAR projectPath = root:STFitAssVar:CP_workingFolder
	
	NVAR tolerance = V_FitTol
	NVAR iterations = V_FitMaxiters
	NVAR fitOptions = V_FitOptions
	SVAR nameWorkWave = root:STFitAssVar:PR_nameWorkWave
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR background = root:STFitAssVar:PR_Background
	SVAR peakTypeTemp = root:STFitAssVar:PR_PeakTypeTemp
	SVAR XRawWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR FitRawData = root:STFitAssVar:PR_FitRawData
	SVAR CoefWave = root:STFitAssVar:PR_CoefWave
	SVAR fitWave = root:STFitAssVar:PR_FitWave
	
	wave /t setup = STsetup
	if (DimSize(setup,0) == 0)
		DoAlert 0, "You can not just save an empty project, please add some peaks and/or do a fit."
		return -1
	endif 
	string CurrentName = GetDataFolder(0)
	string CurrentPath = GetDataFolder(1)
	projectName=CurrentName
	string newName
	Prompt newName, "Enter a new project name "		// Set prompt for x param
	DoPrompt "Save project as", newName
	if (V_Flag)
		return -1								// User canceled
	endif
	
	variable legal = !GrepString(newName,"[^[:alnum:]_+-]") 
	variable letter = GrepString(newName,"[[:alpha:]]") 
	variable number =  GrepString(newName,"[[:digit:]]")
	variable nameOkay = legal && ( (letter && number) || (letter && !number))
	variable invalid = ! nameOkay // !nameOkay //look for not alpha-numeric characters
	
	if (invalid)
		DoAlert 0, "Process aborted because of an invalid name.\rThe project name may only contain '+', ' _', '-', letters, and digits.\r \rPlease provide a new project name."
		return -1
	endif
	
	SetDataFolder parentDir
	if (DataFolderExists(newName))
		DoAlert 0, "Process aborted because of an invalid name.\rThis name already exists, pick another one."
		SetDataFolder CurrentPath
		return -1
	endif
	//switch the names
	DuplicateDataFolder $CurrentPath, oldTemp
	RenameDataFolder $CurrentPath, $newName
	string substitute = ReplaceString("'", projectName, "")
	RenameDataFolder oldTemp, $substitute

	
	SetDataFolder CurrentPath//projectName   //this is actually the original name, now carried by the duplicate
	if (saved == 1)
		
		////RestoreSavedFit("CalledBy:saveFitAs")
		DuplicateDataFolder :FitTemp, Setup
		//NewDataFolder /o :Setup
		//duplicate /o :FitTemp:STsetup :Setup:STsetup 
		//duplicate /o :FitTemp:selSTsetup :Setup:selSTsetup
		//duplicate /o :FitTemp:Numerics :Setup:Numerics 
		//duplicate /o :FitTemp:selNumerics :Setup:selNumerics
		//DuplicateDataFolder :FitTemp:Peaks, :Peaks
		killwaves /z STsetup, selSTsetup, Numerics, selNumerics
		killwaves /z W_Coef, Min_Limit, Max_Limit, epsilon, hold, W_Sigma, T_Constraints, InitializeCoef
		killvariables /z V_numNaNs, V_numINFs, V_npnts, V_nterms, V_nheld, V_startRow, V_endRow, V_startCol, V_endCol
		killvariables /z V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_FitTol, V_FitMaxIters, V_FitOptions
		killdataFolder :FitTemp
		//now make a hard-copy of all relevant variables, use this, if the project is re-opened to initialize everything properly
		
		make /t /n=(100,2) /o FitControls    //more points than needed right now - maybe useful in the future
		FitControls[p][q] = "0"  
		FitControls[0][0] = MyNum2str(fitMin)
		FitControls[1][0] = MyNum2str(fitMax)
		FitControls[2][0] = MyNum2str(tolerance)
		FitControls[3][0] = MyNum2str(iterations)
		FitControls[4][0]= MyNum2str(fitOptions)
		FitControls[5][0] = ProjectName
		FitControls[6][0] = nameWorkWave
		FitControls[7][0] = XRawWave
		FitControls[8][0] = peakType
		FitControls[9][0] = peakTypeTemp
		FitControls[10][0] = background
		FitControls[11][0] = MyNum2str(numPeaks)
		duplicate /o FitControls :Setup:FitControls
		killwaves /z FitControls
		SetDataFolder parentDir
	else
		SetDataFolder parentDir
		killdataFolder :$projectName
		//leave the subfolder and delete it ... nothing has been saved anyway
	endif

	
	SetDataFolder newName //now we are still in the old datafolder /// however with a new name
	projectName = newName
	ProjectPath = GetDataFolder(1)
	saveFit("fromTheSaveAsButton")
	
	string displayString = "" 
	sprintf displaystring,"%s\t(Parent Data Folder)", parentDir
	TitleBox notify1, win=CursorPanel, title=displayString
	
	sprintf displaystring,"%s\t(Current Project) ",ProjectName
	TitleBox notify1b, win=CursorPanel, title=displayString
	
	
	sprintf displaystring,"%s\t(Spectrum) ", nameWorkWave
	TitleBox notify2, win=CursorPanel, title=displayString
	// 1. duplicate the project Folder with a new name
	// 2. set the current working directory there
	// the "old" project is either dismissed, if it was not saved previously
	//                        or will be set to the last save-point
	// all auxiliary waves etc. have to be purged from the old directory
	
End



end

// read the peak type
static function ReadType_CursorPanel(ctrlName,popNum,popStr): PopupMenuControl
	string ctrlName
	variable popNum
	String popStr
	//if ( CheckLocation() )
	//	PopupMenu TypePop , mode = 1, popvalue= " "
	//	return 1
	//endif
	SVAR value = root:STFitAssVar:PR_PeakTypeTemp

	strswitch(popStr)
		case "Singlet":
			value = "Singlet"
		break
		case "Doublet":
			value = "Doublet"
		break		
		case "Multiplet":
			value = "Multiplet"
		break
		case "ExtMultiplet":
			value = "ExtMultiplet"
		break
	default:
		value = popStr
	endswitch

      combinePeakBackground()
	ReDoPeaks()                              
end

static function ReDoPeaks()
	print "This static function conserves the background after a change of the peaks"
	//if there is already a valid fit setup present, inform the user that a change in peak type will destroy his peaks, the background will stay as it is
end

static function ReDoBackground()
       print "This static function conserves the peaks after a change of the background"
       //if there is already a valid fit setup, conserve the peak information
end

static function combinePeakBackground()
//this is basically a matrix that associates a certain peak static function with a combination of peak and background
SVAR peak = root:STFitAssVar:PR_PeakTypeTemp
SVAR background = root:STFitAssVar:PR_Background
SVAR PeakFunc = root:STFitAssVar:PR_PeakType

	strswitch(background)     //later on, there could be more backgrounds
		case "SK":
			strswitch(peak)
				case "Singlet":
					PeakFunc = "SingletSK"
				break
				case "Doublet":
					PeakFunc = "DoubletSK"
				break				
				case "Multiplet":
					PeakFunc = "MultiSK"
				break
				case "ExtMultiplet":
					PeakFunc = "ExtMultiSK"
				break				
				default:
					PeakFunc = ""
					Print "Sorry, not implemented yet"
					return 1
			endswitch	
		break		
		default:
			PeakFunc = ""
			print "This combination is not implemented yet"
			return 1
	endswitch



end


// read the x-axis of the raw data
static function initXWavePopUp(ctrlName,popNum,popStr): PopupMenuControl
	string ctrlName
	variable popNum
	String popStr
	//if ( CheckLocation() )
	//	PopupMenu WavePop2 , mode = 1, popvalue= "_calculated_ "
	//	return 1
	//endif
	SVAR value = root:STFitAssVar:PR_XRawDataCursorPanel
	value = popStr                          
end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Check box for multiple runs

static function IterationRecordCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	if (!Exists("V_FitOptions"))
		Variable /G V_FitOptions = 0
	endif
	NVAR value = V_FitOptions
	
	if (checked ==1)
		value = 8
		CheckBox RobustCheck value = 0
	//	CheckBox SuppressCheck value =0
	else
		value = 0
	endif	
end

static function STAreaLinkCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:AreaLink
	NVAR peakToLink = root:STFitAssVar:STPeakToLink
	
	if (checked ==1)
		value = 1
		//call the procedure to input the variables
		if (peakToLink != 0)
			//Execute "GetAreaFactors()"
			DrawGetAreaFactors()
		else
			DoAlert 0, "If you link to peak '0', the resulting peak will be independent!\r\rSelect peak #1 or #2 etc. to actually do a link"
			CheckBox check0,value= 0
			value = 0
		endif
	else
		value = 0
	endif	
end

static function STPositionLinkCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:PositionLink
	NVAR peakToLink = root:STFitAssVar:STPeakToLink
	
	if (checked ==1)
		value = 1
		if (peakToLink != 0)
			//Execute "GetOffsetInterval()"
			DrawGetOffsetInterval()
		else
			DoAlert 0, "If you link to peak '0', the resulting peak will be independent!\r Select peak #1 or #2  or .... etc. to actually do a link"
			CheckBox check1,value= 0
			value = 0
		endif
		
		
	else
		value = 0
	endif	
end

static function STWidthLinkCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:WidthLink
	
	if (checked ==1)
		value = 1
	else
		value = 0
	endif	
end

static function STGLLinkCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:GLLink
	
	if (checked ==1)
		value = 1
	else
		value = 0
	endif	
end

static function STAsymLinkCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:AsymLink
	
	if (checked ==1)
		value = 1
	else
		value = 0
	endif	
end



static function STSOSLinkCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:SOSLink
	
	if (checked ==1)
		value = 1
	else
		value = 0
	endif	
end




static function STDoubletRatioLinkCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:DoubletRatioLink
	
	if (checked ==1)
		value = 1
	else
		value = 0
	endif	
end




static function STsetKeepInitCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:keepInitConfiguration
	
	if (checked ==1)
		value = 0   //this assignment is a bit screwed
		
	else
		value = 1 
		
	endif	

end



static function RobustCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	if (!Exists("V_FitOptions"))
		Variable /G V_FitOptions = 0
	endif
	NVAR value = V_FitOptions
	if (checked ==1)
		value = 1
		CheckBox RecordCheck value = 0
	//	CheckBox SuppressCheck value = 0
	else
		value = 0
		
	endif	
end




static function SuppressCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	if (!Exists("V_FitOptions"))
		Variable /G V_FitOptions = 0
	endif
	NVAR value = V_FitOptions
	if (checked ==1)
		value = 4
		CheckBox RecordCheck value = 0
		CheckBox RobustCheck value = 0
	else
		value = 0
		
	endif	
end



static function KeepCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:KeepCheckIndicate
	value = checked
end




static function CleanCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = root:STFitAssVar:CleanCheckIndicate
	value = checked
end



static function IndepCheck(ctrlName, checked):CheckBoxControl
	string ctrlName
	variable checked
	CheckLocation()
	NVAR value = CP_IndepCheck
	value = checked
end



static function SetIterations(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName	// name of variable
	NVAR value = V_FitOptions
	value = varNum
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Button functions
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static function MakeFinePlot(ctrlName):ButtonControl
	string ctrlName
	SVAR rawY = root:STFitAssVar:PR_nameWorkWave
	SVAR rawX = root:STFitAssVar:PR_XrawDataCursorPanel
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR projectName =root:STFitAssVar:ProjectName
	
	if (exists("root:STFitAssVar:KineticAxis"))
		NVAR kinetic = root:STFitAssVar:KineticAxis
	endif
	
	wave /t setup = STsetup
	variable numPeaks = 0
	variable i,j
	variable numWaves
	string WavesInFolder, item
	//Do the following things only, if a fit wave is there
	string wavesWithFit = WaveList("fit_*",";","")
	variable FitThere = ItemsInList(wavesWithFit)
	if ( FitThere == 0)
		DoAlert 0, "There seems to be no fit wave. Did you already do a fit? Press 'Start Fit' and retry then."
		return -1
	endif
	
	
	saveFit("void")
	updateFitDisplayFinalVal("fromMakeFinePlot")
	variable numSubFolders
	string dynamicName
	string parent = GetDataFolder(1)
	
	if ( DataFolderExists("PermanentPlot") )
		NewDataFolder /o /s OldPermanentPlots   //that makes a new one or attaches to the old one, if it is already there .... /s makes this the current datafolder
		numSubFolders = CountObjects("",4)
		
		//dynamicName = "PlotSet"+ MyNum2str(numSubFolders)
		dynamicName = "PlotSet"+ num2str(numSubFolders)
		SetDataFolder parent
		RenameDataFolder :PermanentPlot, $dynamicName
		MoveDataFolder :$dynamicName, :OldPermanentPlots		
	endif
	//NewDataFolder /o PermanentPlot
	
	SetDataFolder :Peaks
	WavesInFolder = WaveList("*",";","")  
	numWaves = itemsInList(WavesInFolder)

	SetDataFolder parent
	
	DuplicateDataFolder :Peaks, PermanentPlot
	//for (i = 0; i < numWaves; i += 1)
	//	item = StringFromList(i,WavesInFolder)	
	//	duplicate /o :Peaks:$item :PermanentPlot:$item
	//endfor

	string fitName = "fit_" + rawY
	duplicate /o $rawY :PermanentPlot:$rawY
	duplicate /o $fitName :PermanentPlot:$fitName
	
	string ResName = "Res_" + rawY
	if (WaveExists($ResName))
		duplicate /o $ResName :PermanentPlot:$ResName
	endif
	strswitch(rawX)
		case "":
		break
		case "_calculated_":
		break
		default:
			duplicate /o $rawX :PermanentPlot:$rawX
			numPeaks -= 1
		break
	endswitch
	
	variable PlotGroupCounter =1
	
	String objName
	variable DFindex = 0
		do
			objName = GetIndexedObjName(":", 4, DFindex)
			if (strlen(objName) == 0)
				break
			endif
			
			if( GrepString(objName,"Plot_") )
				PlotGroupCounter += 1
			endif
			DFindex += 1
		while(1)
	dynamicName = "Plot_"+num2str(PlotGroupCounter)
	
	
	SetDataFolder :PermanentPlot
	//now do all the plotting
	WavesInFolder = WaveList("*",";","")  
	variable show = ItemsInList(WavesInFolder)
	strswitch(peakType)
			case "DoubletSK":
				numPeaks += (ItemsInList(WavesInFolder)-4)/3
			break
			case "MultiSK":
				numPeaks += (ItemsInList(WavesInFolder)-4)/5
			break
			case "ExtMultiSK":
				numPeaks += (ItemsInList(WavesInFolder)-4)/11
			break
			default:
				numPeaks += ItemsInList(WavesInFolder) - 4  //raw,bg and fit
			break
	endswitch
	
	strswitch(rawX)
		case "":
			Display /K=1 $rawY
		break
		case "_calculated_":
			Display /K=1 $rawY
		break
		default:
			Display $rawY vs $rawX			
		break
	endswitch
	
	ModifyGraph mode=3,marker=19,msize=1.5
	ModifyGraph rgb=(47872,47872,47872)
	//ModifyGraph
	string TagName, PeakTag
	string TempString
	variable TagPosition
	variable index
	variable NumCoef    ////////////////////////// number of coefficients  33= extMultiplet
	variable numSubPeaks //////////////////// number of subpeaks   10 = extMultiplet
	for ( i = 0; i < numPeaks; i +=1)
		
		strswitch(peakType)
			case "DoubletSK":
			NumCoef = 9 
			numSubPeaks= 2
				WavesInFolder = WaveList("m"+num2str(i+1)+"p*",";","")
				
				for (j = 0; j < numSubPeaks; j += 1 )
					item = StringFromList(j,WavesInFolder)
					index = NumCoef*i+5
					if ( (j == 0 && str2num(setup[index][2]) != 0) || (str2num(setup[index+6+3*(j-1)][2]) != 0 && j != 0) )  //append only those waves which actually contain something
						AppendToGraph $item
						ModifyGraph rgb($item)=(21760,21760,21760), lsize($item)=1, lstyle($item)=2
					endif
				endfor
				WavesInFolder = WaveList("m"+num2str(i+1)+"_*",";","")   //this is necessary for tagging (later on)
			break
			case "MultiSK":
			NumCoef = 15 
			numSubPeaks=4
				WavesInFolder = WaveList("m"+num2str(i+1)+"p*",";","")
				
				for (j = 0; j < numSubPeaks; j += 1 )
					item = StringFromList(j,WavesInFolder)
					index = NumCoef*i+5
					if ( (j == 0 && str2num(setup[index][2]) != 0) || (str2num(setup[index+6+3*(j-1)][2]) != 0 && j != 0) )  //append only those waves which actually contain something
						AppendToGraph $item
						ModifyGraph rgb($item)=(21760,21760,21760), lsize($item)=1, lstyle($item)=2
					endif
				endfor
				WavesInFolder = WaveList("m"+num2str(i+1)+"_*",";","")   //this is necessary for tagging (later on)
			break
			case "ExtMultiSK":
			NumCoef = 33 
			numSubPeaks=10
				WavesInFolder = WaveList("m"+num2str(i+1)+"p*",";","")
				
				for (j = 0; j < numSubPeaks; j += 1 )
					item = StringFromList(j,WavesInFolder)
					index = NumCoef*i+5
					if ( (j == 0 && str2num(setup[index][2]) != 0) || (str2num(setup[index+6+3*(j-1)][2]) != 0 && j != 0) )  //append only those waves which actually contain something
						AppendToGraph $item
						ModifyGraph rgb($item)=(21760,21760,21760), lsize($item)=1, lstyle($item)=2
					endif
				endfor
				WavesInFolder = WaveList("m"+num2str(i+1)+"_*",";","")   //this is necessary for tagging (later on)
			break
			default:
				WavesInFolder = WaveList("p"+num2str(i+1)+"_*",";","")
			break
		endswitch
		item = StringFromList(0,WavesInFolder)
		AppendToGraph $item
		ModifyGraph rgb($item)=(26112,26112,26112), lsize($item)=1
			
		duplicate /o $item ItemTemp
		wave itemTemp = ItemTemp
		TempString = "bg_" + rawY
		wave bgWave = $TempString
		itemTemp -= bgWave  //this is the corrected wave without background
		//this is necessary, because a steep background might screw up the tag positions
			
		WaveStats /Q itemTemp                       // get the location of the maximum
		TagName = "tag"+num2istr(i)           //each tag has to have a name
		PeakTag = num2istr(i+1)                 // The tag displays the peak index
		TagPosition = V_maxloc                 // and is located at the maximum
		Tag  /C /N= $TagName  /F=0 /L=1  /Y =2.0  $item, TagPosition ,PeakTag    // Now put the tag there
	endfor
	killwaves /z ItemTemp
	WavesInFolder = WaveList("fit_*",";","")  
	item = StringFromList(0,WavesInFolder)
	AppendToGraph $item
	ModifyGraph rgb($item)=(0,0,0) 
	

	if (exists("root:STFitAssVar:KineticAxis") && kinetic ==1 )
	      //don't do anything
	else
		SetAxis /A /R bottom	
	endif 
	
	
	WavesInFolder = WaveList("bg_*",";","")
	item = StringFromList(0,WavesInFolder)
	AppendToGraph $item
	ModifyGraph rgb($item)=(0,0,0),lstyle($item)=2
	ModifyGraph mirror=2,minor(bottom)=1
	ModifyGraph margin(top)=40, margin(right)=40
	ModifyGraph width=252,height={Aspect,0.66}
	Label left "\\f01 intensity"
	Label bottom "\\f01  binding energy (eV)"
	string GraphTag = "\\f01Spectrum / project name / file name:\r\\f00" + rawY + " / " + ProjectName + ":"+ dynamicName +" / " + IgorInfo(1)+".pxp"
	TextBox/C/N=text0 /A=MC /F=0 GraphTag
	TextBox/C/N=text0/A=LT/X=-10/Y=-20
	
	
//	string ProjectNameTag = "\\f01 Project: " + ProjectName
//	TextBox/C/N=text1/F=0/A=MC ProjectNameTag
//	TextBox/C/N=text1/A=LT/X=5/Y=5
	
	SetDataFolder parent
	

	RenameDataFolder :PermanentPlot, $dynamicName


end



static function saveFit(ctrlName):ButtonControl
string ctrlName
//this static function sets the global variable saved to 1
//    -  moves the fit setup to FitTemp  (from there it can be restored)
checkLocation()

NVAR saved = root:STFitAssVar:saved
NVAR savedLast = root:STFitAssVar:savedLast
NVAR savedNumPeaks = root:STFitAssVar:savedNumPeaks
SVAR rawY = root:STFitAssVar:PR_nameWorkWave
NVAR numPeaks = root:STFitAssVar:ST_NumPeaks

wave /t setup = STsetup
if (DimSize(setup,0) == 0)
	DoAlert 0, "You can not just save an empty project, please add some peaks and/or do a fit."
	return -1
endif 



saved = 1 //okay, now the rest of the program knows
savedLast = 1
makeFitControls()
duplicate /o $"STsetup" :FitTemp:$"STsetup"
duplicate /o $"selSTsetup" :FitTemp:$"selSTsetup"
duplicate /o $"Numerics" :FitTemp:$"Numerics"
duplicate /o $"selNumerics" :FitTemp:$"selNumerics"
duplicate /o $"FitControls" :FitTemp:$"FitControls"
duplicate /o $rawY :FitTemp:$rawY

//variable /G :FitTemp:SavedNumPeaks
savedNumPeaks = numPeaks //remember the number of peaks
end


static function RestoreSavedFit(ctrlName):ButtonControl
	string ctrlName
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR peakToExtract = root:STFitAssVar:STPeakToRemove
	NVAR peakToLink = root:STFitAssVar:STPeakToLink
	NVAR savedNumPeaks =  root:STFitAssVar:SavedNumPeaks
	NVAR savedLast = root:STFitAssVar:savedLast
	NVAR saved = root:STFitAssVar:saved
	SVAR rawY = root:STFitAssVar:PR_nameWorkWave
	if (saved ==0)
		DoAlert 0, "You have not saved the fit so far ... nothing to recover"
		return 1
	endif

	string traces, traceIndex
	variable i, traceCount
	//clean up
	traces = TraceNameList("CursorPanel#guiCursorDisplayResidual",";",1)
	traceCount = ItemsInList(traces,";")
//	print traces
	//SetAxis/A Res_Left
	
	for (i = traceCount; i > -1 ; i -= 1)
		traceIndex = "#"+num2str(i)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayResidual /Z $traceIndex
	endfor
	// take care of the fit wave
	traces = TraceNameList("CursorPanel#guiCursorDisplay",";",1)
	traceCount = ItemsInList(traces,";")
//	print traces
	//SetAxis/A Res_Left
	string fitName = "fit_"+rawY
	
	RemoveFromGraph /W=CursorPanel#guiCursorDisplay /Z $fitName
	
	// 
	string ResName = "Res_" + rawY
	if (exists(ResName))
		killwaves  $fitName, $ResName
	endif

	savedLast = 1 //this change has not been saved yet
	duplicate /o :FitTemp:$"STsetup" $"STsetup" 
	duplicate /o :FitTemp:$"selSTsetup" $"selSTsetup"
	duplicate /o :FitTemp:$"Numerics" $"Numerics"
	duplicate /o :FitTemp:$"selNumerics" $"selNumerics"
	
	string currentFolder = GetDataFolder(1)
	setDataFolder :FitTemp
	if (Exists(rawY))
		setDataFolder currentFolder
		duplicate /o :FitTemp:$rawY $rawY
	else
		setDataFolder currentFolder
	endif
	

	
	numPeaks = getPeakNumber()// savedNumPeaks
	string ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	variable numberCurves = ItemsInList(ListOfCurves)
	
	KillDataFolder /z :Peaks  //if it exists from a previous run, kill it
	//now recreate it, so everything is updated             
	NewDataFolder /O :Peaks
	//variable i
	//update the graph, remove everything	
	for (i =1; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	
	
	setup2waves()
	updateFitDisplayFinalVal("void")
	
	peakToExtract = numPeaks
	peakToLink = 0
	SetVariable InputSetLink, limits={0,numPeaks,1}, value = peakToLink
	SetVariable InputRemoveLink,limits={1,numPeaks,1}, value = peakToExtract
	SetVariable InputRemoveLink2,limits={1,numPeaks,1}, value = peakToExtract
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Re-usage of W_coef

static function ReUseWCoef(ctrlName):ButtonControl
	string ctrlName
	wave /t source = STsetup
	NVAR savedLast = root:STFitAssVar:savedLast
	savedLast = 0 //this change has not been saved yet
	variable length = DimSize(source,0)
	variable i

	strswitch(ctrlName)
	case "ReUseBut":
		updateFitDisplayFinalVal("void")
		break
	case "ReUseBut2":
		updateFitDisplayFinalVal("void")
		break
	default:
	endswitch
	///////////////////////////////////////////////////////////////////////////////////////////////////
	// the initial values in the setup are overwritten by the final values
	for ( i = 0; i < length; i += 1 )
		if (numtype(str2num(source[i][2])) == 0)
			source[i][3] = source[i][2]
		endif
	endfor
	
	///////////////////////////////////////////////////////////////////////////////////////
	//overwrite initializeCoef with W_Coef
	duplicate /o W_Coef InitializeCoef

end


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Clean up button
static function PlotAndSort(ctrlName):ButtonControl
	string ctrlName
	CheckLocation()
	//disable this button after it has been used once
	//CheckBox KeepCheck disable = 0
	//Button CleanBut disable = 2
	//Button closeBut, title="Close"
	//Titlebox notify, title="Results saved; use Igor's Data Browser to view\rthose waves"
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	//NVAR saved = root:STFitAssVar:saved                                         //the code should remember, if the last action was to save, so the respective waves do not get erased
	//saved = 1                                                         // by the static function selectiveDel()
	string fitWave = "fit_"+RawYWave
	string ResWave = "Res_"+RawYWave
	
	string oldFitWave = fitWave + "old"
	string oldResWave = ResWave + "old"
	
	NVAR clean = root:STFitAssVar:CleanCheckIndicate
	variable newFolder = 1
	
	string wavesWithFit = WaveList("fit_*",";","")
	variable FitThere = ItemsInList(wavesWithFit)
	if ( FitThere == 0)
		DoAlert 0, "There seems to be no fit wave. Did you already do a fit? Press 'Start Fit' and retry then."
		return -1
	endif
	
	
	
	RemoveFromGraph /W=CursorPanel#guiCursorDisplay /Z $"#1"
	PlotPeaks(coefWave,RawYWave,fitWave,peakType,RawXWave,newFolder)
	
	if (Exists(oldFitWave) )
		killwaves $oldFitWave 
	endif
	//once, this static function was called, it deletes the old fit wave
	
end


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Close Button:  kill global variables after usage

static function destroyCursorPanel(ctrlName) : ButtonControl
	string ctrlName
	string LastObjectName = WinList("*", "", "WIN:64")  //get the name of the target windows
	String cmd
	
	NVAR fitMin = root:STFitAssVar:STFitMin
	NVAR fitMax = root:STFitAssVar:STFitMax
	
	NVAR saved = root:STFitAssVar:saved
	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	
	NVAR SavedLast = root:STFitAssVar:savedLast
	
	NVAR tolerance = V_FitTol
	NVAR iterations = V_FitMaxiters
	NVAR fitOptions = V_FitOptions
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR savedNumPeaks = root:STFitAssVar:savedNumPeaks
	
	SVAR projectName = root:STFitAssVar:projectName
	SVAR StartingDirectory = root:STFitAssVar:ST_StartDirectory

	SVAR projectPath = root:STFitAssVar:CP_workingFolder
	SVAR nameWorkWave = root:STFitAssVar:PR_nameWorkWave
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR background = root:STFitAssVar:PR_Background
	SVAR peakTypeTemp = root:STFitAssVar:PR_PeakTypeTemp
	SVAR XRawWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR FitRawData = root:STFitAssVar:PR_FitRawData
	SVAR CoefWave = root:STFitAssVar:PR_CoefWave
	SVAR fitWave = root:STFitAssVar:PR_FitWave
	
	string pathToSaved = projectName + "FitTemp:"
	string pathSTsetup = pathToSaved + "STsetup"
	string pathSelSTsetup = pathToSaved + "selSTsetup"
	
	variable restart = 0
	
	strswitch(ctrlName)
	case "restart":
		restart = 1
		break
	endswitch
		
	wave /t STsetup = STsetup
	variable WorkedInProject 
	
	if (WaveExists(STsetup))
		WorkedInProject= DimSize(STsetup,0)	//use the length of the wave as marker if something was done
	else
		WorkedInProject = 0
	endif
		
//	if (WorkedInProject != 0 && SavedLast == 0 && saved == 0 && restart == 0) //(ProjectStarted == 1 && SavedLast == 0 && saved == 0 && restart == 0)
//		DoAlert 1, "There are unsaved changes in the current project. Do you really want to close?"
//		if (V_Flag ==2) //user pressed no
//			return -1
//		endif
//	elseif (WorkedInProject != 0 && SavedLast==0 && saved==1 && restart == 0)
//		DoAlert 1, "You did not save the most recent changes in this project - however a previous version was saved. Do you want to close and keep the previous version?"
//		if (V_Flag ==2)
//			return -1
//		endif
//	endif
	//this if structure is only active, if there are any changes immediately before pressing the close button and if there is no restart (by the program)
	
	if (WorkedInProject != 0 && SavedLast == 0 && saved == 0 && restart == 0) 
		DoAlert 2, "There are unsaved changes. Save now?"
		if (V_Flag ==3) //user pressed cancel
			return -1
		elseif (V_Flag ==2) //user pressed no
			//simply go on
		elseif (V_Flag == 1) //user pressed yes
			saveFit("beforeQuitting")
		endif
	elseif (WorkedInProject != 0 && SavedLast==0 && saved==1 && restart == 0)
		DoAlert 2, "There are unsaved changes. Save now?"
		if (V_Flag ==3) //user pressed cancel
			return -1
		elseif (V_Flag ==2) //user pressed no
			//simply go on
		elseif (V_Flag == 1) //user pressed yes
			saveFit("beforeQutitting")
		endif
	endif

//	if (V_Flag ==3) //user pressed cancel
//			SetDataFolder workingFolder
//			//return without doing anything
//			return -1
//		elseif (V_Flag == 2)  //no
//			destroyCursorPanel("restart") //now,we are using the string as a switch for a restart
//			LaunchCursorPanel()	
//		elseif (V_Flag == 1)
//			//restart the panel
//			SetDataFolder workingFolder
//			saveFit("beforeRestarting")
//			destroyCursorPanel("restart") //now,we are using the string as a switch for a restart
//			LaunchCursorPanel()	
//		endif


	DoWindow /K PeakEditor   //in case it is still open
	DoWindow /K PeakViewer
	DoWindow  /k CursorPanel
	DoWindow /K STOpenProjectPanel
	DoWindow /K STNewProjectPanel
		
	if (saved == 0)  // no one saved the project
		SetDataFolder StartingDirectory
		strswitch (projectName)   //well, if there is an "" as project name, igor deletes everything
			case "" :
				break
			default:
				if (DataFolderExists(projectName))
				killdatafolder $projectName
				endif
			break
		endswitch
	else
		
		numPeaks = savedNumPeaks
		makeFitControls()
		
		if (DataFolderExists("FitTemp"))
			DuplicateDataFolder :FitTemp, Setup
		endif

		killwaves /z STsetup, selSTsetup, Numerics, selNumerics
		killwaves /z W_Coef, Min_Limit, Max_Limit, epsilon, hold, W_Sigma, T_Constraints, InitializeCoef
		killvariables /z V_numNaNs, V_numINFs, V_npnts, V_nterms, V_nheld, V_startRow, V_endRow, V_startCol, V_endCol
		killvariables /z V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_FitTol, V_FitMaxIters, V_FitOptions
		if (DataFolderExists("Setup"))
			duplicate /o FitControls :Setup:FitControls
		endif
		killwaves /z FitControls
		if (DataFolderExists("FitTemp"))
			killdataFolder :FitTemp
		endif
		SetDataFolder StartingDirectory	
	endif
	killdatafolder /z root:STFitAssVar
end

static function makeFitControls()

	NVAR fitMin = root:STFitAssVar:STFitMin
	NVAR fitMax = root:STFitAssVar:STFitMax
	
	NVAR saved = root:STFitAssVar:saved
	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	
	NVAR SavedLast = root:STFitAssVar:savedLast
	
	NVAR tolerance = V_FitTol
	NVAR iterations = V_FitMaxiters
	NVAR fitOptions = V_FitOptions
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	
	SVAR projectName = root:STFitAssVar:projectName
	SVAR StartingDirectory = root:STFitAssVar:ST_StartDirectory

	SVAR projectPath = root:STFitAssVar:CP_workingFolder
	SVAR nameWorkWave = root:STFitAssVar:PR_nameWorkWave
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR background = root:STFitAssVar:PR_Background
	SVAR peakTypeTemp = root:STFitAssVar:PR_PeakTypeTemp
	SVAR XRawWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR FitRawData = root:STFitAssVar:PR_FitRawData
	SVAR CoefWave = root:STFitAssVar:PR_CoefWave
	SVAR fitWave = root:STFitAssVar:PR_FitWave

	
	make /t /n=(100,2) /o FitControls    //more points than needed right now - maybe useful in the future
	wave /t FitControls = FitControls
	FitControls[p][q] = "0"  
	FitControls[0][0] = MyNum2str(FitMin)
	FitControls[1][0] = MyNum2str(FitMax)
	FitControls[2][0] = MyNum2str(tolerance)
	FitControls[3][0] = MyNum2str(iterations)
	FitControls[4][0]= MyNum2str(fitOptions)
	FitControls[5][0] = projectName
	FitControls[6][0] = nameWorkWave
	FitControls[7][0] = XRawWave
	FitControls[8][0] = peakType
	FitControls[9][0] = peakTypeTemp
	FitControls[10][0] = background
	FitControls[11][0] = MyNum2str(getPeakNumber())
end




static function STsaveTemplate(ctrlName) : ButtonControl
	string ctrlName
	
	wave /t STsetup = STsetup
	if (DimSize(STsetup,0) == 0)
		DoAlert 0, "You can not save an empty project as template, please add some peaks and/or do a fit."
		return -1
	endif 
	
	makeFitControls()
	variable index = 0
	string templateName = ""
	Prompt templateName, "Provide a name for the template "
	DoPrompt "Save as template",templateName
	if (V_Flag)
		return -1								// User canceled
	endif
	
	string parent = GetDataFolder(1)
	SetDataFolder root:
	
	if (!DataFolderExists("Fit_templates"))
		NewDataFolder /O Fit_templates
		//provide a name for the template
	endif
	SetDataFolder Fit_templates
	NewDataFolder /O templateName
	SetDataFolder parent
	////wave /t setup = STsetup
	
	if (DataFolderExists("Setup"))
	SetDataFolder :Setup
	Duplicate /T /o STsetup, root:Fit_templates:templateName:STsetup
	Duplicate /T /o selSTsetup root:Fit_templates:templateName:selSTsetup
	Duplicate /T /o Numerics root:Fit_templates:templateName:Numerics
	Duplicate /T /o selNumerics root:Fit_templates:templateName:selNumerics
	Duplicate /T /o FitControls root:Fit_templates:templateName:FitControls
	SetDataFolder parent
	
	else
	Duplicate /T /o STsetup, root:Fit_templates:templateName:STsetup
	Duplicate /T /o selSTsetup root:Fit_templates:templateName:selSTsetup
	Duplicate /T /o Numerics root:Fit_templates:templateName:Numerics
	Duplicate /T /o selNumerics root:Fit_templates:templateName:selNumerics
	Duplicate /T /o FitControls root:Fit_templates:templateName:FitControls
	endif
	
	SetDataFolder root:
	SetDataFolder :Fit_templates
	string tempName = templateName
	if (dataFolderExists(templateName))
	do
		index += 1
		tempName = templateName +"_" + num2str(index)
	while (dataFolderExists(tempName))
	templateName = tempName
	endif
	RenameDataFolder templateName, $templateName
	SetDataFolder parent
end





//////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////
//    Display the constraints wave and the respective legend
static function editDisplayWave(ctrlName):ButtonControl
	string ctrlName
	CheckLocation()
	DoWindow PeakEditor//ConstraintTable
	if ( V_Flag )
		DoWindow /F PeakEditor
		return -1
	endif
	CallPeakEditor()
	DoWindow /T PeakEditor, "Constraints and initial values"
end

//////////////////////////////////////////
/////////
//	Show the various waves   //commented 13.4.2018
//static function ConstraintTable()
//	initializeConstraintTable()  //the window command goes back to the root directory by default, so one has to force it to go back to the correct data folder
//	Button UpDateBut disable =0
//	if ( !exists("Min_Limit") )
//		CreateBoundaryWaves()    // to be backwards compatible
//	endif
//	if (exists("epsilon"))
//		edit /k=1 /W=(10,50,710,390)  CoefLegend,W_Coef,InitializeCoef,hold, Min_Limit, Max_Limit, epsilon
//		modifytable title(epsilon)="Iteration Step", rgb(epsilon)=(30000,0,0) , alignment(epsilon) =1
//	else
//		edit /k=1 /W=(10,50,710,390)  CoefLegend,W_Coef,InitializeCoef,hold, Min_Limit, Max_Limit
//	endif
//	modifytable alignment(InitializeCoef) =1, title(InitializeCoef)="Initial Values", width(hold) =35, alignment(hold)=1
//	modifytable width(CoefLegend) =150, size(CoefLegend)=10, style(CoefLegend)=1, style(hold)=1, alignment(CoefLegend)=0
//	modifytable alignment(W_Coef)=2, rgb(W_Coef)=(0,23000,12000), alignment(Min_Limit)=0, alignment(Max_Limit)=0, width(Min_Limit)=100, width(Max_Limit)=100
//	modifytable rgb(CoefLegend)=(0,23000,65535), alignment(W_coef)=1,title(CoefLegend) ="Parameters", title(Min_Limit)="Lower Limit",title(Max_Limit) = "Upper Limit" 
//	modifytable title(W_coef)="Results", style(W_Coef)=1
//end




/////////////////////////////////////////////////////////////////////
/////////
//	Set the correct location in the data browser
static function initializeConstraintTable()
	SVAR name = root:STFitAssVar:CP_workingFolder
	SetDataFolder name
end





///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////
//	Read  T_Constraints and make Min_Limit and Max_Limit --> backward compatibility static function
static function CreateBoundaryWaves()
	wave /t T_Constraints = T_Constraints    //make a local reference to T_Constraints
	variable length = numpnts(T_Constraints)
	variable i = 0
	length *= 0.5              						//Min_Limit and Max_Limit do only have half the length of T_Constraints
	make /t /o /n=(length) Min_Limit
	make /t /o /n=(length) Max_Limit
	for ( i=0 ;  i < length ;  i += 1 )
		Min_Limit[i] = T_Constraints[2*i]
		Max_Limit[i] = T_Constraints[2*i+1]
	endfor
end






/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// static function behind the "Delete Peak" button  
//
// removes the very last graph from the small display and cuts off the last peak parameters form
// all relevant waves


static function RemoveEntry(ctrlName):ButtonControl
	string ctrlName
	NVAR peakToRemove = root:STFitAssVar:STPeakToRemove
	SVAR peakType = root:STFitAssVar:PR_PeakType
	if (peakToRemove == 0)
	return -1
	endif
	
	strswitch(peakType)
	case "SingletSK":
		RemoveSinglet()
		break
	case "DoubletSK":
		RemoveDoublet()
		break
	case "MultiSK":
		RemoveMultiplet()
		break
	case "ExtMultiSK":
		RemoveExtMultiplet()
		break
	default:
		DoAlert 0, "Peak type not recognized in RemoveEntry()"
		break
	endswitch
	updateFitDisplay("FromRemoveEntry")
	updateResidualDisplay("void")
	//update the SetVariable
//	SetVariable InputRemove, value= root:STFitAssVar:STPeakToRemove
	SetVariable InputRemoveLink,limits={0,peakToRemove,1}	
	SetVariable InputRemoveLink2,limits={0,peakToRemove,1}		
end






static function RemoveSinglet()
	CheckLocation()
	//these are needed to be able to call SinglePeakDisplay, in case of the background functions
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR toLink = root:STFitAssVar:STPeakToLink
	NVAR peakToExtract = root:STFitAssVar:STPeakToRemove
	NVAR savedLast = root:STFitAssVar:savedLast
	savedLast = 0 //this change has not been saved yet
	UpdateFitDisplay("fromAddPeak")
	updateResidualDisplay("void")
	//updateCoefs()
	setup2waves()
	numPeaks -= 1
	numPeaks=max(0,numPeaks)
	toLink = min(toLink,numPeaks)
	//peakToExtract = max(0,numPeaks)
	/////////////////////////////////////////////////////////////


	wave /t source = STsetup
	//NVAR peakToExtract = PeakToDelete
	wave sw = selSTsetup

	wave /t  numerics = Numerics
	wave selNumerics = selNumerics

	variable i,j,k
	variable length = DimSize(source,0)
	variable NumLength = DimSize(numerics,0)

	//this needs to be rewritten for doublet functions as well
	//numPeaks = (length-5)/6

	//this is the simple version of delete which only removes the last entry
	//if (length>=6)
	//Redimension /n=(length-6,-1) source
	//Redimension /n=(length-6,-1) sw
	//endif

	if (length == 5) ///only the background is left
		return 1 /// do nothing, the background may stay there forever
	endif

	string ListOfCurves
	variable numberCurves
	variable startCutIndex, endCutIndex
	variable numCoefs = 6

	//FancyUP("foe")

	//now do a sophisticated form of delete which removes a certain peak from within the waves
	//for example peak 2
	//peakToExtract = 2 //this needs to be soft-coded later on

	//duplicate the sections that need to go
	//to do so: calculate the indices that have to be removed
	//this needs to be extended for doublet functions as well

	startCutIndex = 5 + (peakToExtract-1)*numCoefs
	endCutIndex = startCutIndex + 6

	variable startCutIndexNumerics = (peakToExtract-1)*4
	variable endCutIndexNumerics = startCutIndexNumerics + 4

	//now, check if there are any constraints linked to this peak, if yes, refuse to do the deleting and notify the user
	// that means the ax, px, wx, etc of this peak e.g. a2, w2, etc show up anywhere else in the constraints wave, if so, abort
	variable abortDel = 0

	string planeName = "backColors"
	variable plane = FindDimLabel(sw,2,planeName)

	Variable nplanes = max(1,Dimsize(sw,2))
	if (plane <0)
		Redimension /N=(-1,-1,nplanes+1) sw
		plane = nplanes
		SetDimLabel 2,nplanes,$planeName sw
	endif

	variable Errors = 0
	string tempString
	string CoefficientList = "a;p;w;g;s;t"
	string matchString 
	string badSpotList = ""

	for (j = 0; j<itemsInList(CoefficientList); j += 1)
		matchString = "*" + StringFromList(j,CoefficientList) + MyNum2str(peakToExtract) + "*"
		for (i=0; i < startCutIndex; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
		endfor
		for (i=endCutIndex; i < length; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
		endfor
	endfor

	variable badSpots = ItemsInList(badSpotList)
	variable badSpot

	if (Errors != 0)
		tempString = "Other peaks are linked to the one you want to remove. \r\rDelete all references to the peak you want to remove from 'Lower Limit' and 'Upper Limit'."
		Doalert 0, tempString
		tempString = "editDisplayWave(\"foe\")"
		Execute tempString
		// and now do the highlighting
		for ( i = 0; i < badSpots; i += 1 )
			badSpot = str2num(StringFromList(i,badSpotList))
			sw[badSpot][5][plane] =1		
			sw[badSpot][6][plane] =1		
		endfor
	
		//end highlighting
	
		numpeaks += 1
		return -1
	endif

	//everything seems to be fine, now continue
	duplicate /o /r=(0,startCutIndex-1) source $"lowerSectionSetup" 
	wave /t lowerSetup = $"lowerSectionSetup"
	duplicate /o /r=(0,startCutIndex-1) sw $"lowerSectionSw" 
	wave  lowerSW = $"lowerSectionSw"

	duplicate /o /r=(endCutIndex,length-1) source $"upperSectionSetup" 
	wave /t upperSetup = $"upperSectionSetup"
	duplicate /o /r =(endCutIndex, length -1) sw $"upperSectionSw" 
	wave upperSW = $"upperSectionSw"


	duplicate /o /r=(0,startCutIndexNumerics-1) numerics $"lowerSectionNumerics" 
	wave /t lowerNumerics = $"lowerSectionNumerics"
	duplicate /o /r=(0,startCutIndexNumerics-1) selNumerics $"lowerSectionSelNumerics" 
	wave  lowerSelNumerics = $"lowerSectionSelNumerics"

	duplicate /o /r=(endCutIndexNumerics,NumLength-1) numerics $"upperSectionNumerics" 
	wave /t upperNumerics = $"upperSectionNumerics"
	duplicate /o /r =(endCutIndexNumerics, NumLength -1) selNumerics $"upperSectionSelNumerics" 
	wave upperSelNumerics = $"upperSectionSelNumerics"


	//remove also the entries for the numerics wave

	//remove the space for one peak
	Redimension /n=(length-6,-1) source
	Redimension /n=(length-6,-1) sw

	Redimension /n=(NumLength-4,-1) numerics    //four lines per peak if the peak type is singlet
	Redimension /n=(NumLength-4,-1) selNumerics

	//and now, copy the stuff back, start with the lowerSection
	for (i = 0; i < startCutIndex; i += 1)
		for ( j =2; j < 8; j +=1) // do not overwrite the legend waves, this would be redundant
			if (j  != 4)
				source[i][j]=lowerSetup[i][j]
			endif
			sw[i][j]=lowerSW[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndex; i < length-6; i += 1)
		for ( j =2; j < 8; j +=1)
			if (j  != 4)
				source[i][j]=upperSetup[i-startCutIndex][j]
			endif
			sw[i][j]=upperSW[i-startCutIndex][j]
		endfor
	endfor

	//now repeat everything for the Numerics wave
	for (i = 0; i < startCutIndexNumerics; i += 1)
		for ( j =2; j < 15; j +=1) // do not overwrite the legend waves, this would be redundant
			numerics[i][j]=lowerNumerics[i][j]
			selNumerics[i][j]=lowerSelNumerics[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndex; i < length-4; i += 1)
		for ( j =2; j < 15; j +=1)
			numerics[i][j]=upperNumerics[i-startCutIndex][j]
			selNumerics[i][j]=upperSelNumerics[i-startCutIndex][j]
		endfor
	endfor

	killwaves /z upperSetup, upperSW, lowerSetup, lowerSW, lowerSelNumerics, upperSelNumerics, lowerNumerics, upperNumerics

	//now make sure that all the parameter names, such as a2, a3, etc are updated
	//if the second peak was removed:   old > new 
	//								a1 > a1
	//								a2 > removed
	//								a3 > a2 //k = 0
	//								a4 > a3  //k = 1
	string lowerIndexIn, higherIndexOut

	for ( k = 0; k< numpeaks; k += 1)
		for ( j = 0; j < itemsInList(CoefficientList); j += 1 )
			lowerIndexIn = StringFromList(j,CoefficientList) + MyNum2str(peakToExtract+k )  
			higherIndexOut = StringFromList(j,CoefficientList) +MyNum2str(peakToExtract + k +1)
			//print lowerIndexIn, higherIndexOut
			for ( i = 0; i < length-6; i += 1 )
				tempString = source[i][5]
				source[i][5]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
				tempString = source[i][6]
				source[i][6]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
			endfor
		endfor
	endfor
	
	///////////////////////////////////////////////////////////
	setup2waves()	
	ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	//this needs to be adapted to the background functions
	RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-1)
	//if (BackgroundType != 0 )
	for (i =2; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	//and now redisplay, if there are any peaks left
	SinglePeakDisplay(peakType,RawYWave,RawXWave, "InitializeCoef")//coefWave)
	FancyUp("foe")
	peakToExtract = max(0,numPeaks)
	SetVariable InputSetLink, limits={0,numPeaks,1}
	SetVariable InputRemoveLink,limits={0,peakToExtract,1}
	SetVariable InputRemoveLink2,limits={0,peakToExtract,1}
end






///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
static function PeakDisplay(ctrlName):ButtonControl
	string ctrlName
	CheckLocation()	
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	//extensions: this static function has to be modified as well	
	SinglePeakDisplay(peakType,RawYWave,RawXWave,coefWave)
	
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//   Display the single peaks
// to do so, analyze the coefficient wave and the peak type







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Display-Button 
// display the wave to be fitted

static function displayWavesCursorPanel(ctrlName): ButtonControl
	string ctrlName
	string HostWindowName = "CursorPanel"
	CheckLocation()
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	wave rawX = $RawXWave
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	wave rawY = $RawYWave
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR templateName = root:STFitAssVar:templateName
	
	NVAR useTemplate = root:STFitAssVar:useTemplate
	NVAR keepIndicate = root:STFitAssVar:KeepCheckIndicate
	NVAR FitMin = root:STFitAssVar:STFitMin
	NVAR FitMax = root:STFitAssVar:STFitMax	

	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR background = root:STFitAssVar:PR_Background
	SVAR peakTypeTemp = root:STFitAssVar:PR_PeakTypeTemp
	
	NVAR peakToExtract = root:STFitAssVar:STPeakToRemove
	
	
	if ( strlen(RawYWave) >= 26)		  //26 characters would be okay, but there are names generated form this string, and those get possibly too long
		doalert 0, "The name of the fit-wave is too long! Please shorten the names."
		return 1
	endif
	combinePeakBackground()  //call the static function that gets the peak type from chosen profile and background
	
	strswitch(RawYWave)
		case "":
			doalert 0, "No data wave given!"
			return -1
			break
		default:
			break
	endswitch
	
	//figure out if there is an xwave to get the default values for the fit min and max
	strSwitch(RawXWave)
		case "":
			FitMin = min( pnt2x(rawY,0),  pnt2x( rawY,numpnts(rawY)-1 ) )
			FitMax = max( pnt2x(rawY,0),  pnt2x( rawY,numpnts(rawY)-1 ) )
			break
		case "_calculated_":
			FitMin = min( pnt2x(rawY,0),  pnt2x( rawY,numpnts(rawY)-1 ) )
			FitMax = max( pnt2x(rawY,0),  pnt2x( rawY,numpnts(rawY)-1 ) )
			break
		default:
			FitMin=WaveMin(rawX)
			FitMax=WaveMax(rawX)
			break
	endswitch

	strswitch(peakType)
		case "":
			doalert 0, "No peak type given, or selected combination of peak and background not implemented yet!"
			return -1
			break
		default:
			break
	endswitch

	if (useTemplate == 0)
	make /t /n=(0,8) /o STsetup
	make /n=(0,8) /o selSTsetup
	make /t /n=(0,15) /o Numerics
	make /n=(0,15) /o selNumerics
	
	makeFitControls()
	
	else
	//duplicate the wave from the template folder to this location
	// this is not working:     Duplicate /o root:Fit_templates:$templateName:STsetup STsetup        and it is annoying
	
	DuplicateDataFolder root:Fit_templates:$templateName, Setup
	string parentFolder = GetDataFolder(1)
	SetDataFolder Setup 
		duplicate /o STsetup, $(parentFolder + "STsetup")
		duplicate /o selSTsetup, $(parentFolder + "selSTsetup")
		duplicate /o Numerics, $(parentFolder + "Numerics")
		duplicate /o selNumerics, $(parentFolder + "selNumerics")
		duplicate /o FitControls, $(parentFolder + "FitControls")
	SetDataFolder parentFolder
	//duplicate /o :Setup:STsetup :STsetup 
	//duplicate /o :Setup:selSTsetup :selSTsetup 
	//duplicate /o :Setup:Numerics :Numerics 
	//duplicate /o :Setup:selNumerics :selNumerics 
	//duplicate /o :Setup:FitControls :FitControls 
	wave /t FitControls = FitControls
	KillDataFolder Setup

	
	/////	reverse this
	FitMin = str2num(FitControls[0][0])
	FitMax = str2num(FitControls[1][0]) 
	peakType = FitControls[8][0] 
	peakTypeTemp = FitControls[9][0] 
	background = FitControls[10][0]
	numPeaks = str2num(FitControls[11][0])
	peakToExtract = numPeaks
	setup2waves()
	updateFitDisplayFinalVal("fromTemplateLoad")
	//now reset everything
	useTemplate = 0 
	templateName = ""
	
	endif
	
	//Titlebox notify win=$HostWindowName, title="Use the mouse to select a peak ..."
	Button addBut win=$HostWindowName, disable = 0//, fColor=(44000,52000,65500), disable=0        //(32768,54528,65280)
	Button DeleteBut win=$HostWindowName, disable = 0 //, fColor=(44000,52000,65500), disable=0           //(32768,54528,65280)
	Button FitBut win=$HostWindowName //, fColor=(44000,52000,65500)    
	Button ConstraintBut win=$HostWindowName//, fColor=(44000,52000,65500)   

end





///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	Add Button
// read the cursor position and write into the coefficient wave, which is used for fitting later on
static function ReadOutPosition(ctrlName): ButtonControl
	string ctrlName
	CheckLocation()
	//hard-coded to the root directory, maybe change later
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	//SVAR coefWave = root:STFitAssVar:PR_CoefWave
	NVAR keepIndicate = root:STFitAssVar:KeepCheckIndicate
	NVAR indepCheck = root:STFitAssVar:CP_IndepCheck
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR savedLast = root:STFitAssVar:savedLast
	NVAR keepInitConfiguration = root:STFitAssVar:keepInitConfiguration
	savedLast = 0 //this change has not been saved yet
	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	
	NVAR toLink = root:STFitAssVar:STPeakToLink
	NVAR toRemove = root:STFitAssVar:STPeakToRemove
	NVAR areaLink = root:STFitAssVar:AreaLink
	NVAR positionLink = root:STFitAssVar:PositionLink
	NVAR WidthLink = root:STFitAssVar:WidthLink
	NVAR GLLink = root:STFitAssVar:GLLink
	NVAR AsymLink =root:STFitAssVar:AsymLink
	keepInitConfiguration = 0 //now, forever, if there is something left, where it is actually "1", this is a residual from an older version, disregard
	//add a peak and, if there is an old fit result, add it to this fit results
	//if ( keepInitConfiguration == 1 && Exists("W_Coef"))
	//	//duplicate /o InitializeCoefBackup InitializeCoef

	//	//this one was working
	//	ReUseWCoef("fromAddPeak")
	//endif

	string initCoef = "InitializeCoef"
	string finalCoef = "W_Coef"
	numPeaks += 1
	numPeaks =max(0,numPeaks)
	toLink = min(toLink,numPeaks)
	toRemove = max(0,numPeaks)
	
	//out:18.3.16
	//Button DeleteBut disable = 0
	//Button ConstraintBut disable =0
	//Button UpDateBut disable = 0
	SetVariable InputSetLink,limits={0,numPeaks,1}
	SetVariable InputRemoveLink,limits={1,numPeaks,1}
	SetVariable InputRemoveLink2,limits={1,numPeaks,1}

	RemoveFromGraph /W=CursorPanel#guiCursorDisplay /Z $"#1"
	//updateCoefs()
	
	//16.3 if (keepInitConfiguration == 0 && Exists("W_Coef"))
	//	wave initBackup = $"initializeCoefBackup"
	//	duplicate /o initBackup InitializeCoef
	//	waves2setup()
	//endif
	//also remove this
	
	setup2waves()
	
	//now use this, to append the cursor position, this is necessary since the following static function works only on W_coef
	//this static function has to be edited as well
	
	ReadOutPositionFunc(peakType,RawYWave, RawXWave,initCoef,indepCheck)
	
	//SinglePeakDisplay(peakType,RawYWave,RawXWave,coefWave)
	//duplicate /o $"W_coef" $initCoef
	areaLink = 0
	positionLink = 0
	WidthLink =1
	GLLink = 1
	AsymLink = 1
	CheckBox check0,value= 0
	CheckBox check1,value= 0
	CheckBox check2,value= 1
	CheckBox check3,value= 1
	CheckBox check4,value= 1
	ProjectStarted = 1
	updateFitDisplay("fromAddPeak")
	updateResidualDisplay("void")
end






static function CheckLocation()
	SVAR location = root:STFitAssVar:CP_workingFolder
	variable match
	string actualLocation = GetDataFolder(1)
	match=stringmatch(location,actualLocation)    //returns 1 if they match
	if (match != 1)
		doalert 0,"Do not change the data folder while a session is running. Going back to session folder ...\rYou can navigate to a different parent folder when you\r    - open a fit project or\r    - make a new fit project."
		SetDataFolder location
		return 1
	endif
	return 0
end







// auxiliary static function to normalize the constraints wave
static function /S NormAndDeNormConstraints(line,factor,NormSwitch)
	string line
	variable factor
	
	variable NormSwitch           //0: normalize  //1: de-normalize
	string answer = ""  //also used as temporary string for cleaning of whitespaces
	
	string filterResult
	string ListWithSeparators = ">;<;+;- ;"
	variable i,j 
	string Separator = "", positionList = ""
	string S_lowIndex, S_highIndex
	variable lowIndex, highIndex
	string partString
	variable partNumber
	variable LenPositionList
	
	if ( factor == 0)
		print "error in NormAndDeNormConstraints, division by zero"
		return "error"
	endif
	
	//clean string from whitespaces answer is used as a volatile container
	line = UpperStr(line)    //deal only with capital characters
	variable sampleLen = strlen(line)
	for ( i = 0; i < sampleLen ; i += 1 )
		if (stringmatch(line[i]," ") == 0)
			answer += line[i]
		endif
	endfor
	line = answer
	answer = ""
	// .... done
	
	//get the location of the separators and the last location in the string
	for ( i = 0; i < 4; i += 1 )
		Separator = StringFromList(i,ListWithSeparators)
		for ( j = 0 ; j < sampleLen;  j += 1 )
			if (stringmatch(line[j],Separator) == 1 && stringmatch(line[j-1],"e") == 0)
				positionList += num2str(j)+";"
			endif
		endfor
	endfor
	//attach start and end-index, and sort it
	positionList += num2str(sampleLen)
	positionList = "0;" + positionList
	positionList = SortList(positionList,";",2)
	// .... done

	LenPositionList = ItemsInList(positionList)
	for ( i = 1; i < LenPositionList; i += 1 )	
		S_lowIndex = StringFromList(i-1, positionList)
		S_highIndex = StringFromList(i, positionList)
		lowIndex = str2num(S_lowIndex)
		highIndex = str2num(S_highIndex)
		if (lowIndex != 0)
			partString = line[lowIndex+1,highIndex-1]
		else
			partString = line[lowIndex, highIndex-1]
		endif
		if ( MyGrepString(partString,"K") == 0)
			partNumber = str2num(partString)
			if (NormSwitch == 0)
				partNumber /= factor
			else 
				partNumber *= factor
			endif
			if (partNumber != Nan)    //this can happen sometimes
				partString = num2str(partNumber)
				answer +=  " " + line[lowIndex] + " " + partString + " "
			endif
		else
			if ( i == 1)  
				answer +=  line[lowIndex, highIndex-1] + " "    //make correct indents
			else
				answer +=  " " + line[lowIndex] + " " + line[lowIndex+1, highIndex-1] + " "
			endif
		
		endif
	endfor	
	return answer
end






///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	Add Button
// read the cursor position and write into the coefficient wave, which is used for fitting later on
static function ReadOutPositionFunc(peakType,RawYWave, RawXWave,coefWave,indepCheck)
	
	string RawXWave 
	string peakType
	string RawYWave
	string coefWave
	variable indepCheck                //decide whether to link the new peak to peak 1 or not
	
	//Button FitBut disable=0           //now the user can press the fit button
	//Button showBut disable=2       //once the graph is displayed, there is no way back
	 
	string name = "CursorPanel#guiCursorDisplay"    //hard-coded to avoid more global variables
	
	
	//Variables for the cursor position
	variable width, relPos, relHeight, indexA, posA, heightA
	variable PeakArea
	variable WCoef_length,i, nPeaks, numPara
	variable left, right
	variable EstimatedPeakArea
	// the creation of the local reference is necessary to
	// copy the values of W_coef in the form
	// of newWave = oldWave
	// with this method, no new wave ( a global object ) is created
	wave locRefW_coef = W_Coef
	wave /t Min_Limit = Min_Limit   //just create a local reference, do not get confused by the identical names
	wave /t Max_Limit = Max_Limit 
	wave /t locRefConstraints = T_Constraints
	wave /t locRefLegend = LegendWave
	wave /t CoefLegendRef = CoefLegend
	wave holdRef = hold                      //The global wave is named "hold"
	wave epsilon = epsilon
	wave raw = $RawYWave
	
	//check if all necessary informations are given, if not, refuse to make further actions
	strswitch(RawYWave)
		case "":
			doalert 0, "No data wave given!"
			return -1
			break
		default:
			break
	endswitch

	strswitch(peakType)
		case "":
			doalert 0, "No peak type given!"
			return -1
			break
		default:
			break
	endswitch
	
	//get the cursor position
	 indexA = pcsr(A,name)   
	 posA = hcsr(A, name)
	 
	 heightA= vcsr(A,name)
	 
	 
	//decide, if the spectrum is in waveform or x-y format 
	//and do the scaling of the cursor positions accordingly
	
	variable initialSlope, initialOffset
	
	variable x1, x0
	variable y1, y0
	
	strswitch(RawXWave)
	 	case "":
	 		 left = max(leftx($RawYWave),pnt2x($RawYWave,numpnts($RawYWave)-1))
	 		 right = min(leftx($RawYWave),pnt2x($RawYWave,numpnts($RawYWave)-1))
	 		 width = leftx($RawYWave)-pnt2x($RawYWave,numpnts($RawYWave)-1)
	 		
	 		 x0 = right
	 		 x1 = left
	 		 y0 = raw[x2pnt(raw,right)]
			 y1 = raw[x2pnt(raw,left)]
	  
	 	break
	 	case "_calculated_":
	 		 left = max(leftx($RawYWave),pnt2x($RawYWave,numpnts($RawYWave)-1))
	 		 right = min(leftx($RawYWave),pnt2x($RawYWave,numpnts($RawYWave)-1))
	 		 width = leftx($RawYWave)-pnt2x($RawYWave,numpnts($RawYWave)-1) 
	 		 
	 		 x0 = right
	 		 x1 = left
	 		 
	 		 y0 = raw[x2pnt(raw,right)]
			 y1 = raw[x2pnt(raw,left)]
	 	break
	 	default:
	 		waveStats /Q $RawXWave
	 		wave rawX = $RawXWave
	 		left = V_max
	 		right = V_min
	 		width = left - right
	 		
	 		x0 = rawX[0]
	 		x1 = rawX[numpnts(rawX)-1]
	 		
	 		y0 = raw[0]
			y1 = raw[numpnts(rawX)-1]
	 	break
	 endswitch
	 
	WCoef_length =DimSize(W_coef,0)    
	variable ConstraintLength =DimSize(locRefConstraints,0)

	initialSlope = (y1-y0)/(x1-x0)
	// y = mx + t
	initialOffset = y1 -  initialSlope*x1

	strswitch(peakType)
	///////////////////////////////////////////////////////////////////////////////////////////////// 
	//			values like 'interval', 'Width_Start' and so on are pre-defined in the file Constants.ipf
	// 			they are no ordinary variables and should not be changed during execution
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// Gauss Singlet
		
		case "SingletSK":
			AddVoigtSKPeak(coefWave,RawYWave,indepCheck,heightA,posA,initialSlope, initialOffset, left,right,Wcoef_length)
		break
		case "DoubletSK":
			AddVoigtSKDoublet(coefWave,RawYWave,indepCheck,heightA,posA,initialSlope, initialOffset, left,right,Wcoef_length)
		break
		case "MultiSK":
			AddVoigtSKMultiplet(coefWave,RawYWave,indepCheck,heightA,posA, initialSlope, initialOffset,left,right,Wcoef_length)
		break
		case "ExtMultiSK":
			AddVoigtSKExtMultiplet(coefWave,RawYWave,indepCheck,heightA,posA,initialSlope, initialOffset,left,right,Wcoef_length)
		break
		default:
			DoAlert 0, "Peak type not recognized, something is wrong"
		break
	endswitch
	SinglePeakDisplay(peakType,RawYWave,RawXWave,coefWave)
end

// the following static function is called, after the Add-peak button was pressed and the waves have been updated
// it displays the individual peaks in the graphical user interface

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// single peak display 





static function SinglePeakDisplay(peakType,RawYWave, RawXWave,coefWave)

	//SVAR peakType = root:S_PeakType
	//SVAR RawYWave = root:S_nameWorkWave
	//SVAR coefWave = root:S_CoefWave
	//SVAR RawXWave = root:S_XRawDataCursorPanel
	
	string peakType
	string RawYWave
	string RawXWave
	string coefWave
	string TagName    // the Tag in the result window
	string PeakTag     // text in this tag
	string PkName, parentDataFolder //, cleanUpString=""		
	string BGName //background
	string PeakSumName
	variable idx
	
	wave coefs = $coefWave
	variable coefLength = numpnts(coefs)
	
	if (coefLength == 0)
		return 1
	else
		for ( idx = 0; idx < coefLength; idx += 1)
			if (numtype(coefs[idx]) != 0)
				return 1
			endif
		endfor
	endif
	
 	strswitch(peakType)
		case "SingletSK":     
			PlotPseudoVoigtSKDisplay(peakType,RawYWave, RawXWave,coefWave)
		break
		case "DoubletSK":
			PlotDoubletSKDisplay(peakType,RawYWave, RawXWave,coefWave)
		break
		case "MultiSK":
			PlotMultipletSKDisplay(peakType,RawYWave, RawXWave,coefWave)
		break
		case "ExtMultiSK":
			PlotExtMultipletSKDisplay(peakType,RawYWave, RawXWave,coefWave)
		break
		default:
			DoAlert 0, "Peak type not recognized, something is wrong"
			print "Peak type was not recognized, something is wrong."
			break
	endswitch
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// display the waves in the GUI








////////////////////////////////
////  Export and Import

static function STExportFit(ctrlName):ButtonControl
	string ctrlName
	//get the full fit setup, this includes the setup waves, the fit_control wave and the spectrum (+xWave if necessary)
	checkLocation()
	SVAR projectName = root:STFitAssVar:projectName	
	SVAR rawY = root:STFitAssVar:PR_nameWorkWave
	wave spectrum = $rawY
	SVAR rawX = root:STFitAssVar:PR_XRawDataCursorPanel
	
	string outputName = "Fit_" + projectname +".itx"
	wave /t setup = STsetup
	wave selSetup = selSTsetup
	wave /t num = Numerics
	wave selNum = selNumerics
	wave /t fitC = FitControls
	string fitResult = WaveList("fit_*",";","")
	variable fitThere = itemsInList(fitResult)
	if (fitThere != 0)
		wave fitWave = $StringFromList(0,fitResult)
	endif
	
	if (DimSize(setup,0) == 0)
		DoAlert 0, "You can not export an empty project, please add some peaks."
		return -1
	endif 
	
	
	makeFitControls()
	
	strswitch(rawX)
		case "":
			if (fitThere != 0)
				save /I /T setup,selSetup,num,selNum,fitC,fitWave,spectrum, as outputName
			else
				save /I /T setup,selSetup,num,selNum,fitC,spectrum as outputName
			endif
		break
		case "_calculated_":
			if (fitThere != 0)
				save /I /T setup,selSetup,num,selNum,fitC,fitWave,spectrum as outputName
			else
				save /I /T setup,selSetup,num,selNum,fitC,spectrum as outputName
			endif
		break
		default:
			wave xSpectrum = $rawX
			if (fitThere != 0)
				save /I /T setup,selSetup,num,selNum,fitC,fitWave,spectrum,xSpectrum as outputName
			else
				save /I /T setup,selSetup,num,selNum,fitC,spectrum,xSpectrum as outputName
			endif
		break
	endswitch
	
end

static function STImportFit(ctrlName):ButtonControl
	string CtrlName
	//go to the main dataFolder
	SVAR parent = root:STFitAssVar:ST_StartDirectory
	SVAR oldWorkingDirectory = root:STFitAssVar:CP_workingFolder
	SVAR toOpen = root:STFitAssVar:nextProjectToOpen
	
	NVAR saved = root:STFitAssVar:saved
	NVAR savedLast = root:STFitAssVar:savedLast
	NVAR projectStarted = root:STFitAssVar:projectStarted
	
	DoWindow /K PeakEditor
	DoWindow /K PeakViewer
	DoWindow /K GetAreaFactors
	DoWindow /K GetOffsetIntervall
	
	variable index = 1
	string oldPlace = oldWorkingDirectory
	
	//if (projectStarted == 1 && saved ==0)
	//	DoAlert 1, "You did not save the current fitting project. Proceed anyway?"
	//	if (V_Flag == 2)
	//		return 1
	//	endif
	//elseif (saved == 1 && savedLast == 0)
	//	DoAlert 1, "You did not save the most recent changes to the current fitting project. Proceed and keep the previous saved version?"
	//	if (V_Flag == 2)
	//		return 1
	//	endif
	//endif
	
	//if  (projectStarted == 1 && saved ==0)   
	if ( projectStarted ==1 &&  saved == 0) 
		DoAlert 2, "There are unsaved changes in the current project. Save now?"
		if (V_Flag ==3) //user pressed cancel
			return -1
		elseif (V_Flag == 2) 
			destroyCursorPanel("restart") //user pressed no
			LaunchCursorPanel() 
		elseif (V_Flag == 1)  //user pressed yes
			saveFit("beforeNewProject")
			destroyCursorPanel("restart") //now,we are using the string as a switch for a restart
			LaunchCursorPanel()
		endif  
	elseif ( projectStarted ==1 &&  saved == 1 && savedLast == 0)
		
		DoAlert 2, "There are unsaved changes in the current project. Save now?"
		if (V_Flag ==3) //user pressed cancel
			return -1
		elseif (V_Flag == 2)   //no
			restoreSavedFit("fromOpenProject")
		elseif (V_Flag == 1)  //user pressed yes
			saveFit("beforeNewProject")
		
		endif  
	endif
	
	
	SetDataFolder parent
	NewDataFolder /O /S imported
	LoadWave /T 
	if (V_Flag == 0)
		SetDataFolder parent
		KillDataFolder /z imported
		SetDataFolder oldWorkingDirectory
		return 1
	endif
	SetDataFolder parent
	S_FileName = ReplaceString("Fit_",S_Filename,"")
	S_FileName = ReplaceString(".itx",S_Filename,"")
	
	string temp = S_FileName
	string output = ""
	if (DataFolderExists(S_FileName))
		do 	
			temp = S_FileName + num2str(index)
			index += 1
		while (DataFolderExists(temp))
		
		sprintf output, "This project name already existed.\rThe name of the imported project was changed to:    %s ", temp
		DoAlert 0, output
	endif
	S_FileName = temp
	
	RenameDataFolder :imported, $S_FileName
	SetDataFolder $S_FileName
	ClearGraphs() //empty the graphs so that the main window is ready for a change
	toOpen = S_FileName
	NewDataFolder /o Peaks
	NewDataFolder /o Setup
	duplicate /o STsetup :Setup:STsetup
	duplicate /o selSTsetup :Setup:selSTsetup
	duplicate /o Numerics :Setup:Numerics
	duplicate /o selNumerics :Setup:selNumerics
	wave /t FitControls = FitControls
	FitControls[5][0] = S_FileName
	duplicate /o FitControls :Setup:FitControls
	
	
	killwaves /z FitControls, Numerics, selNumerics,STsetup, selSTsetup
	
	//now go back to the folder where you started from and simply call OpenFitProject
//	SetDataFolder oldWorkingDirectory
	SetDataFolder parent
	OpenFitProject("FormImport")
	SetDataFolder parent
	if (saved == 0)
		killDataFolder /z oldPlace
	endif
	SetDataFolder toOpen
end




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////
//////////////////////////////
///////////////////////////////                                                                                   MORE PANELS
//////////////////////////////
//////////////////////////////
//////////////////////////////
//////////////////////////////
//////////////////////////////
//////////////////////////////
//////////////////////////////
//////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



static function CallSTProjectPanel(ctrlName):ButtonControl
	string ctrlName
	NVAR saved = root:STFitAssVar:saved
	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	NVAR savedLast = root:STFitAssVar:savedLast
	
	SVAR parentFolder = root:STFitAssVAr:ST_StartDirectory
	SVAR oldParentFolder = root:STFitAssVar:ST_oldStartDirectory
	SVAR workingFolder = root:STFitAssVar:CP_workingFolder
	
	DoWindow /K PeakEditor
	DoWindow /K PeakViewer
	DoWindow /K GetAreaFactors
	DoWindow /K GetOffsetIntervall
	
	wave /t STsetup = STsetup
	variable WorkedInProject = DimSize(STsetup,0)
	
	SetDataFolder parentFolder
	DoWindow STOpenProjectPanel   //this will write "1" into V_Flag if the window is open already
	if (V_Flag )
		DoWindow /F STOpenProjectPanel  // if it is already open, bring it to front
		return -1
	endif
	
	
	if (ProjectStarted == 1 &&  saved == 0)
		//DoAlert 1, "There are unsaved changes in the current project. Do you really want to proceed?"
		DoAlert 2, "There are unsaved changes in the current project. Save now?"
		
		//if (V_Flag ==2) //user pressed no
		if (V_Flag ==3) //user pressed cancel
			SetDataFolder workingFolder
			//return without doing anything
			return -1
		elseif (V_Flag == 2)  //no

			destroyCursorPanel("restart") //now,we are using the string as a switch for a restart
			LaunchCursorPanel()	
		elseif (V_Flag == 1)
			//restart the panel
			SetDataFolder workingFolder
			saveFit("beforeRestarting")
			SetDataFolder parentFolder

		endif
	elseif (ProjectStarted ==1 && SavedLast==0 && saved==1)
		//DoAlert 2, "You did not save the most recent changes in this project - however a previous version was saved. Do you want to proceed and keep only the previous version?"
		DoAlert 2, "There are unsaved changes in the current project. Save now?"
		
		if (V_Flag ==3)  //user pressed cancel
			SetDataFolder workingFolder
			return -1
		elseif (V_Flag == 2)  //no
			SetDataFolder workingFolder
			restoreSavedFit("fromOpenProject")
			SetDataFolder parentFolder

		elseif (V_Flag == 1)
			SetDataFolder workingFolder
			saveFit("beforeRestarting")
			SetDataFolder parentFolder
				
		endif
	endif
	
	WakeSTOpenProjectPanel()
	DeActivateButtons(0)
	Button OpenProjectBtn,  win=CursorPanel, disable=0
end

static function KillSTOpenProjectPanel(ctrlName):ButtonControl
	string ctrlName
	SVAR originalLocation = root:STFitAssVar:OpenDialogOriginalLocation //root:STFitAssVar:CP_WorkingFolder
	SVAR originalProject = root:STFitAssVar:OpenDialogOriginalProject
	NVAR projectStarted = root:STFitAssVar:projectStarted
	SVAR startingDirectory = root:STFitAssVar:ST_StartDirectory
	SVAR toOpen = root:STFitAssVar:nextProjectToOpen
	SVAR projectName = root:STFitAssVar:projectName						//14.4.2018
	SVAR oldParentFolder = root:STFitAssVar:ST_oldStartDirectory
	

	string parent = GetDataFolder(1)

	
	strswitch(ctrlName)
		case "afterOpening":
			//the user chose a project and wants to work with it now
			projectStarted = 1
			
		break
		//another modification
		case "CancelBtn":
			startingDirectory = oldParentFolder
			if (projectStarted ==1 )
				OpenFitProject("reset")
				SetDataFolder originalLocation
			else
				ClearGraphs()
				SetDataFolder :$toOpen
				CleanUpAfterPreview()
				SetDataFolder startingDirectory
				
			endif
		break
		//and again
		default:
			if (projectStarted ==1 )
				OpenFitProject("reset")
				SetDataFolder originalLocation
			else
				ClearGraphs()
				SetDataFolder :$toOpen
				CleanUpAfterPreview()
				SetDataFolder startingDirectory
			endif
			
		break
	endswitch
	//killstrings /z root:STFitAssVar:nextProjectToOpen,root:STFitAssVar:OpenDialogOriginalLocation,root:STFitAssVar:OpenDialogOriginalProject 
	if (projectStarted == 0)
		ActivateButtons(1)
	else
		ActivateButtons(0)
	endif
	
	string temp=startingDirectory
	KillStrings /Z root:STFitAssVar:ST_StartDirectory	    //to avoid a really, really weird Igor bug
//	print startingDirectory
	KillWindow /Z STOpenProjectPanel
//	print startingDirectory
	String /G root:STFitAssVar:ST_StartDirectory = temp
end

static function CleanUpAfterPreview()
	SVAR originalProject = root:STFitAssVar:OpenDialogOriginalProject
	SVAR startingDirectory = root:STFitAssVar:ST_StartDirectory
	SVAR toOpen = root:STFitAssVar:nextProjectToOpen
	SVAR projectName = root:STFitAssVar:projectName						//14.4.2018
	SVAR nameWorkWave = root:STFitAssVar:PR_NameWorkWave 
	
	if (DataFolderExists("FitTemp"))
		DuplicateDataFolder :FitTemp, Setup	
		//NewDataFolder /o :Setup
		//duplicate /o :FitTemp:STsetup :Setup:STsetup 
		//duplicate /o :FitTemp:selSTsetup :Setup:selSTsetup
		//duplicate /o :FitTemp:Numerics :Setup:Numerics 
		//duplicate /o :FitTemp:selNumerics :Setup:selNumerics
		//duplicate /o :FitTemp:FitControls :Setup:FitControls
	endif
	
	/////					Adapted 14.4.2018
	toOpen = ""     			
	originalProject = ""    
	projectName = ""	 		
	nameWorkWave = ""
		
	string displayString = "" 
	sprintf displaystring,"%s\t(Parent Data Folder)", startingDirectory
	TitleBox notify1, win=CursorPanel, title=displayString
	
	sprintf displaystring,"%s\t(Current Project) ",ProjectName
	TitleBox notify1b, win=CursorPanel, title=displayString
	
	
	sprintf displaystring,"%s\t(Spectrum) ", nameWorkWave
	TitleBox notify2, win=CursorPanel, title=displayString
	///////////end 14.4.18	
		
	//DuplicateDataFolder :FitTemp:Peaks, :Peaks
	killwaves /z STsetup, selSTsetup, Numerics, selNumerics, FitControls
	killwaves /z W_Coef, Min_Limit, Max_Limit, epsilon, hold, W_Sigma, T_Constraints, InitializeCoef
	killvariables /z V_numNaNs, V_numINFs, V_npnts, V_nterms, V_nheld, V_startRow, V_endRow, V_startCol, V_endCol
	killvariables /z V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_FitTol, V_FitMaxIters, V_FitOptions
	killdatafolder /z :FitTemp
end
//
//Window STOpenProjectPanelWorking() : Panel
//
////static function drawOpenPanel()
//	
//	NewPanel /K=2  /W=(829,77,1158,454)  as "open/preview fit projects"
//	ModifyPanel cbRGB=(65534,65534,65534)
//	SetDrawLayer UserBack
//	SetDrawEnv fsize= 14,fstyle= 1,fillfgc= (65280,65280,48896),linefgc=(65280,54528,32768)
//	DrawRect 12,201,316,360
//	SetDrawEnv fstyle= 1,fsize= 13
//	DrawText 17,37,"Open / Browse Projects"
//	
//	DrawText 28,224,"Only fit projects in the current parent folder"
//	DrawText 28,239,"will be displayed"
//	SetDrawEnv fstyle= 1
//	DrawText 26,276,"To change the parent folder:"
//	SetDrawEnv fstyle= 1
//	DrawText 28,299,"Call the data browser and"
//	SetDrawEnv fstyle= 1
//	DrawText 28,315,"use the red arrow."
//
//	DrawText 26,283,"--------------------------------------------------------"
//	
//	Button CancelBtn,pos={26,133},size={105,33},fsize=10, appearance={os9,Win}, proc=XPSTFA#KillSTOpenProjectPanel,title="Cancel"
//	Button OpenBtn,pos={202,133},size={105,33},fsize=10, appearance={os9,Win},proc=XPSTFA#OpenFitProject,title="Open"
//	
//	PopupMenu ProjectPop,pos={31,103},size={278,21},bodyWidth=173,proc=XPSTFA#SelectFitProject,title="Available Projects:   "
//	PopupMenu ProjectPop,mode=2,popvalue="select a project",fsize=10,value= #"getValidDataFolders()"
//	GroupBox group0,pos={14,63},size={301,111}
//	Button CallBrowserBtn,pos={26,69},size={283,27},fsize=10,appearance={os9,Win},proc=XPSTFA#CallDataBrowser,title="Call browser to set parent folder"
//
//	initOpenProjectPanel()
//
//endmacro

static function WakeSTOpenProjectPanel() 

	////////////////////////////////////////////////////////////////////////////
	
	
	
		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 0"
		endif
		
	NewPanel /K=2 /W=(564,88,807,489) /N=STOpenProjectPanel as "open/preview fit projects"
	ModifyPanel cbRGB=(65534,65534,65534)
	SetDrawLayer UserBack
	SetDrawEnv fsize= 11,fstyle= 1
	DrawText 20,21,"Open / Browse Projects"
	SetDrawEnv linefgc= (65280,54528,32768),fillfgc= (65280,65280,48896)
	DrawRect 7,254,226,388
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 19,280,"Only fit projects in the current parent folder"
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 20,295,"will be displayed"
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 21,332,"To change the parent folder:"
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 23,355,"Call the data browser and"
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 23,371,"use the red arrow to point at the folder."
	SetDrawEnv fsize= 9
	DrawText 21,339,"--------------------------------------------------------"
	ListBox ProjectList,pos={23.00,79.00},size={184.00,129.00},fsize=10,proc=XPSTFA#watchOpenProjectListBox
	ListBox ProjectList,selRow= -1
	Button CancelBtn,pos={22.00,218.00},size={92.00,31.00},proc=XPSTFA#KillSTOpenProjectPanel,title="Cancel"
	Button CancelBtn,fSize=9,fStyle=1,appearance={os9,Win}
	Button OpenBtn,pos={116.00,218.00},size={92.00,31.00},proc=XPSTFA#OpenFitProject,title="Open"
	Button OpenBtn,fSize=9,fStyle=1,appearance={os9,Win}
	Button CallBrowserBtn,pos={20.00,29.00},size={186.00,19.00},proc=XPSTFA#CallDataBrowser,title="Call Browser to Change Data Folder"
	Button CallBrowserBtn,fSize=9,fStyle=1,appearance={os9,Win}
	Button CallBrowserBtn1,pos={20.00,50.00},size={186.00,19.00},proc=XPSTFA#PopulateListOpenProjectPanel,title="Update List for Current Data Folder"
	Button CallBrowserBtn1,fSize=9,fStyle=1,appearance={os9,Win}
	TitleBox comment1,pos={260.00,79.00},size={50.00,20.00},frame=0
	TitleBox comment1,fColor=(0,26112,0)
	
	
		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 1"
		endif
	
	////////
	initOpenProjectPanel()
End



static function initOpenProjectPanel()
	
	SVAR oldParentFolder = root:STFitAssVar:ST_oldStartDirectory
	SVAR parentFolder = root:STFitAssVar:ST_StartDirectory
	oldParentFolder = parentFolder 
	
	SVAR workingFolder = root:STFitAssVar:CP_workingFolder
	SVAR projectName = root:STFitAssVar:projectName
	string /G root:STFitAssVar:nextProjectToOpen = ""
	SetDataFolder parentFolder
	string /G root:STFitAssVar:OpenDialogOriginalLocation = workingFolder
	string /G root:STFitAssVar:OpenDialogOriginalProject = projectName
	TabControl OptionsTab, win=CursorPanel, value=0
	ManageOptionsTab("fromOpen",0)
	PopulateListOpenProjectPanel("fromInitOpenProjectPanel")
	ListBox ProjectList,listWave=root:STFitAssVar:XPSTProjectList, selWave=root:STFitAssVar:SelXPSTProjectList
end

static function PopulateListOpenProjectPanel(ctrlName):ButtonControl
	string ctrlName
	wave myColors = root:STFitAssVar:myColors
	string ProjectList = getValidDataFolders()
	variable numberProjects = itemsInList(ProjectList)
	
	make /t /n=(numberProjects) /o root:STFitAssVar:XPSTProjectList
	
	make /n=(numberProjects) /o root:STFitAssVar:SelXPSTProjectList
	
	wave /t WaveProjectList = root:STFitAssVar:XPSTProjectList
	wave SelectionWaveProjectList = root:STFitAssVar:SelXPSTProjectList

	
	variable i,j,k
	for (i=0; i < numberProjects; i += 1)
		WaveProjectList[i] = stringFromList(i,ProjectList,";")
		
		SelectionWaveProjectList[i]=(0x04)
		
		
	endfor
end





static function watchOpenProjectListBox(LBStruct)//(ctrlName,row,col,event): ListBoxControl
	Struct WMListBoxAction &LBStruct
//	string ctrlName
//	variable row
//	variable col
//	variable event
	
	SVAR nextProjectToOpen = root:STFitAssVar:nextProjectToOpen
	SVAR StartingDirectory = root:STFitAssVar:ST_StartDirectory
	StartingDirectory = GetDataFolder(1)
	//this static function updates the selection of the project which should be opened
	PopulateListOpenProjectPanel("fromListBox")
		
	
	wave /t WaveProjectList = root:STFitAssVar:XPSTProjectList
	string projectName =WaveProjectList[LBStruct.row]
	
	if (LBStruct.eventCode == 4 && DataFolderExists(projectName))
		//somewhere here OpenFitProject("preview")
		nextProjectToOpen = WaveProjectList[LBStruct.row]
		OpenFitProject("preview")
	endif


end

static function OpenFitProject(ctrlName):ButtonControl
	string ctrlName
	
	
	NVAR fitMin = root:STFitAssVar:STFitMin
	NVAR fitMax = root:STFitAssVar:STFitMax
	NVAR peakToExtract = root:STFitAssVar:STPeakToRemove
	NVAR peakToLink = root:STFitAssVar:STPeakToLink
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	
	NVAR saved = root:STFitAssVar:saved
	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	
	NVAR SavedLast = root:STFitAssVar:savedLast
	NVAR savedNumPeaks = root:STFitAssVar:savedNumPeaks	
	if (exists("root:STFitAssVar:KineticAxis"))
		NVAR kinetic = root:STFitAssVar:KineticAxis
	endif
	SVAR projectName = root:STFitAssVar:projectName
	SVAR originalProject = root:STFitAssVar:OpenDialogOriginalProject
	SVAR StartingDirectory = root:STFitAssVar:ST_StartDirectory
	SVAR projectPath = root:STFitAssVar:CP_workingFolder
	
	SVAR nameWorkWave = root:STFitAssVar:PR_nameWorkWave
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR background = root:STFitAssVar:PR_Background
	SVAR peakTypeTemp = root:STFitAssVar:PR_PeakTypeTemp
	SVAR XRawWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR FitRawData = root:STFitAssVar:PR_FitRawData
	SVAR CoefWave = root:STFitAssVar:PR_CoefWave
	SVAR fitWave = root:STFitAssVar:PR_FitWave
	wave workWave = $nameWorkWave
		
	SVAR toOpen = root:STFitAssVar:nextProjectToOpen
	
	strswitch(ctrlName)
		case "reset":
			toOpen = originalProject
		break
		default:
		break
	endswitch
	
	strswitch (toOpen)
		case "":
			DoAlert 0, "Please select a project."
			return 1
			break
		default:
		break
	endswitch
	
	//saved = 1 //it has been saved at least once, otherwise it could not be re-opened
	SetDataFolder $projectPath
	if (Exists("STsetup") && DataFolderExists("FitTemp") ) //(ProjectStarted == 1)     //this happens only, if there is already a project open
		variable isOkay = 0
		NVAR tolerance = V_FitTol
		NVAR iterations = V_FitMaxiters
		NVAR fitOptions = V_FitOptions
		//before leaving to the new folder, clean up in the old one
		make /t /n=(100,2) /o FitControls    //more points than needed right now - maybe useful in the future
		wave /t FitControls = FitControls
		FitControls[p][q] = "0"  
		FitControls[0][0] = MyNum2str(fitMin)
		FitControls[1][0] = MyNum2str(fitMax)
		FitControls[2][0] = MyNum2str(tolerance)
		FitControls[3][0] = num2str(iterations)
		FitControls[4][0]= MyNum2str(fitOptions)
		FitControls[5][0] = projectName
		FitControls[6][0] = nameWorkWave
		FitControls[7][0] = XRawWave
		FitControls[8][0] = peakType
		FitControls[9][0] = peakTypeTemp
		FitControls[10][0] = background
		FitControls[11][0] = num2istr(getPeakNumber())
		//this works, if a fit was done and later on a new project is opened, if a new project is opened from scratch this is not necessary
		
		if (DataFolderExists("FitTemp"))
			//NewDataFolder /o :Setup
			SetDataFolder FitTemp
			if (Exists("STsetup"))
				isOkay = 1
			endif
			SetDataFolder $projectPath
			if (isOkay ==1)
				DuplicateDataFolder :FitTemp, Setup
				//duplicate /o :FitTemp:STsetup :Setup:STsetup 
				//duplicate /o :FitTemp:selSTsetup :Setup:selSTsetup
				//duplicate /o :FitTemp:Numerics :Setup:Numerics 
				//duplicate /o :FitTemp:selNumerics :Setup:selNumerics
			endif
		endif
		if (DataFolderExists("Setup"))
			SavedNumPeaks = numPeaks
		endif
		//DuplicateDataFolder :FitTemp:Peaks, :Peaks
		killwaves /z STsetup, selSTsetup, Numerics, selNumerics
		killwaves /z W_Coef, Min_Limit, Max_Limit, epsilon, hold, W_Sigma, T_Constraints, InitializeCoef
		killvariables /z V_numNaNs, V_numINFs, V_npnts, V_nterms, V_nheld, V_startRow, V_endRow, V_startCol, V_endCol
		killvariables /z V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_FitTol, V_FitMaxIters, V_FitOptions
		
		//now make a hard-copy of all relevant variables, use this, if the project is re-opened to initialize everything properly
	
		if (DataFolderExists("Setup"))
			duplicate /o FitControls :Setup:FitControls
		endif
	
		killwaves /z FitControls
		if (DataFolderExists("FitTemp"))
			killdataFolder :FitTemp
		endif
	endif
	
	SetDataFolder $StartingDirectory
	//saved = 1 //the one which was already opened was saved at least once
	//projectStarted = 1
	//now step into "toOpen"
	SetDataFolder :$toOpen
	
	variable /G V_FitMaxIters
	variable /G V_FitOptions 
	variable /G V_FitTol
	NVAR toleranceLocal = V_FitTol
	NVAR tolerance = root:STFitAssVar:V_FitTol
	toleranceLocal = tolerance
	NVAR iterations = V_FitMaxIters
	NVAR fitOptions = V_FitOptions

	
	ProjectPath = GetDataFolder(1)
	//now populate the global variables with meaningful values
	
	if (DataFolderExists("Setup"))
		SetDataFolder :Setup
		duplicate /o STsetup, $(ProjectPath+"STsetup")
		//duplicate /o :Setup:STsetup :STsetup
		
		duplicate /o selSTsetup, $(ProjectPath+"selSTsetup")
		duplicate /o Numerics, $(ProjectPath+"Numerics")
		duplicate /o selNumerics, $(ProjectPath+"selNumerics")
		duplicate /o FitControls, $(ProjectPath+"FitControls")
		//duplicate /o :Setup:selSTsetup :selSTsetup
		//duplicate /o :Setup:Numerics :Numerics
		//duplicate /o :Setup:selNumerics :selNumerics
		//duplicate /o :Setup:FitControls :FitControls
		SetDataFolder $ProjectPath
		wave /t FitControls = FitControls
		wave /t setup = STsetup
		RenameDataFolder :Setup, FitTemp
		SavedNumPeaks = numPeaks
	endif
//	if( DataFolderExists("FitTemp") && !DataFolderExists("Setup"))
//		Variable /G :FitTemp:SavedNumPeaks = numPeaks
//	endif
	

	fitMin = str2num(FitControls[0][0])
	fitMax = str2num(FitControls[1][0])
	tolerance = str2num(FitControls[2][0])
	iterations = str2num(FitControls[3][0])
	fitOptions = str2num(FitControls[4][0])
	projectName = FitControls[5][0]
	nameWorkWave = FitControls[6][0]
	XRawWave = FitControls[7][0]
	peakType = FitControls[8][0]
	peakTypeTemp = FitControls[9][0]
	background = FitControls[10][0]
	numPeaks = str2num(FitControls[11][0])
	peakToExtract = numPeaks
	savedNumPeaks = numPeaks
	
	
	
	
	if (DataFolderExists("Setup"))
		RenameDataFolder :Setup, FitTemp
//		Variable /G :FitTemp:SavedNumPeaks = numPeaks
	endif
	
	if (Exists("STsetup"))
		setup2waves()
		//new modification
		ListBox QuickEditList, win=CursorPanel, listWave=STsetup
		ListBox QuickEditList,win = CursorPanel, selWave=selSTsetup,colorWave=root:STFitAssVar:myColors
		TabControl OptionsTab, win=CursorPanel, value=0
		//ManageOptionsTab("fromOpen",0)                                           //20.03.16
	endif
	
	SetVariable InputMaxFitIterations, win=$"CursorPanel", limits={1,100,1},value=iterations
	SetVariable InputRemoveLink,win=$"CursorPanel", limits={1,numPeaks,1}, value=peakToExtract
	SetVariable InputRemoveLink2,win=$"CursorPanel", limits={1,numPeaks,1}, value=peakToExtract
	peakToLink=0
	SetVariable InputSetLink, win=$"CursorPanel", limits={0,numPeaks,1},value= peakToLink
	if (fitOptions ==1)
		CheckBox RobustCheck, win=$"CursorPanel", value= 1
	else
		CheckBox RobustCheck, win=$"CursorPanel", value= 0
	endif
	
	//NewDataFolder /o FitTemp
	
	WaveStats /Q $nameWorkWave
	//print StartingDirectory   //check1
	clearGraphs()	
	//now do the display
	string fit_waveName = "fit_"+nameWorkWave
	strswitch(XRawWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph /w=CursorPanel#guiCursorDisplayFit $nameWorkWave 
			ModifyGraph  /w = CursorPanel#guiCursorDisplayFit rgb($"#0")=(39168,39168,39168) 
			AppendToGraph /w=CursorPanel#guiCursorDisplay $nameWorkWave  
			if (exists(fit_waveName))
				AppendToGraph /w=CursorPanel#guiCursorDisplay $fit_waveName
			endif                   
			break
		case "_calculated_":
			if (exists(fit_waveName))
				AppendToGraph /w=CursorPanel#guiCursorDisplay $fit_waveName
			endif
			AppendToGraph /w=CursorPanel#guiCursorDisplayFit $nameWorkWave
			ModifyGraph  /w = CursorPanel#guiCursorDisplayFit rgb($"#0")=(39168,39168,39168)  
			AppendToGraph /w=CursorPanel#guiCursorDisplay $nameWorkWave 
			if (exists(fit_waveName))
				AppendToGraph /w=CursorPanel#guiCursorDisplay $fit_waveName
			endif
			break
		default:                                                 // if not empty
		       wave xraw = $XRawWave

			AppendToGraph /w=CursorPanel#guiCursorDisplayFit $nameWorkWave vs $XRawWave
			ModifyGraph  /w = CursorPanel#guiCursorDisplayFit rgb($"#0")=(39168,39168,39168) 
			AppendToGraph /w=CursorPanel#guiCursorDisplay  $nameWorkWave vs $XRawWave
			if (exists(fit_waveName))
				AppendToGraph /w=CursorPanel#guiCursorDisplay $fit_waveName
			endif
			break
	endswitch
	
	if (exists("root:STFitAssVar:KineticAxis") && kinetic ==1 )
	      //don't do anything
	else
		SetAxis /A /R /w = CursorPanel#guiCursorDisplay bottom
		SetAxis /A /R /w = CursorPanel#guiCursorDisplayFit bottom	
	endif 
	
	SetAxis /w = CursorPanel#guiCursorDisplay left *, 1.02*V_max
	//SetAxis /w = CursorPanel#guiCursorDisplayFit left 0.9*V_min, 1.04*V_max
	
	//append not the local reference of the wave,since it does not exist globally. Use the $WaveNameString notation instead
	Cursor /H=1 /F /P /S=0 /L=1 /W=CursorPanel#guiCursorDisplay A $nameWorkWave, 0.55, 0.2
	ModifyGraph /w= CursorPanel#guiCursorDisplay zero(left)=2 
	ModifyGraph  /w = CursorPanel#guiCursorDisplay mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplay mirror(bottom)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplay rgb($"#0")=(0,26112,39168) 
	ModifyGraph  /w = CursorPanel#guiCursorDisplay mode($"#0")=7, hbfill($"#0")=5
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2, nticks(left)=0
	ModifyGraph /w = CursorPanel#guiCursorDisplayFit axRGB(left)=(34816,34816,34816),tlblRGB(left)=(34816,34816,34816), alblRGB(left)=(34816,34816,34816)
	ModifyGraph /w = CursorPanel#guiCursorDisplayFit axRGB(bottom)=(34816,34816,34816),tlblRGB(bottom)=(34816,34816,34816), alblRGB(bottom)=(34816,34816,34816) 
	
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplay Bottom " "
	ModifyGraph  /w = CursorPanel#guiCursorDisplay minor(bottom)=1,sep(bottom)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplay minor(bottom)=1,sep(bottom)=2
	//TextBox /C /w = CursorPanel#guiCursorDisplay /N=text0/F=0/A=LT "Drag the crosshairs to a peak\rPress 'Add Peak'\rPress 'Start Fit'"
	
	strswitch(ctrlName)
		case "FromImport":
			
		break
		default:
			saved = 1
		break
	endswitch
	//print StartingDirectory //check2
	if (Exists("STsetup"))
		strswitch(setup[0][2])
		case "":
			updateFitDisplay("void")  //only the starting values are there
			updateResidualDisplay("void")
			break
		default:
			updateFitDisplayFinalVal("void")
			updateResidualDisplay("void")
			break
		endswitch
	endif
	
	//print StartingDirectory, "before"
	
	strswitch(ctrlName)
		case "preview":
			SetDataFolder $StartingDirectory
		break
		default:
			KillSTOpenProjectPanel("afterOpening")
			break
	endswitch
	
	//print StartingDirectory, "after"
	
	string displayString = "" 
	//sprintf displaystring, "Parent Data Folder: %s \rCurrent Project: %s ", StartingDirectory, projectName
	
	sprintf displaystring,"%s\t(Parent Data Folder)", startingDirectory
	TitleBox notify1, win=CursorPanel, title=displayString
	
	sprintf displaystring,"%s\t(Current Project) ",ProjectName
	TitleBox notify1b, win=CursorPanel, title=displayString
	
	
	sprintf displaystring,"%s\t(Spectrum) ", nameWorkWave
	TitleBox notify2, win=CursorPanel, title=displayString
	savedLast = 1
end

static function getPeakNumber()
	SVAR peakType = root:STFitAssVar:PR_PeakType  //later on the number of coefficients changes with the peak static function,
	wave /t setup = STsetup
	variable length = DimSize(setup,0)
	variable numCoef 
	variable numPeaks
	
	strswitch(peakType)
		case "DoubletSK":
			numCoef = 9   //  
		break
		case "MultiSK":
			numCoef = 15   //  
		break
		case "ExtMultiSK":
			numCoef = 33   //  	
		break
		default:
			numCoef = 6
		break
		endswitch
	numPeaks = max(0, (length-5)/numCoef)
	return numPeaks
	

end



static function ClearGraphs()
	variable i
	//SetActiveSubWindow CursorPanel#guiCursorDisplay
	string traces = TraceNameList("CursorPanel#guiCursorDisplay", ";", 1)
	variable items = itemsInList(traces,";")

	for ( i =0; i< items; i += 1)   
		RemoveFromGraph /W=CursorPanel#guiCursorDisplay /Z $"#0"  //always remove the bottom curve
	endfor
		
	traces = TraceNameList("CursorPanel#guiCursorDisplayFit", ";", 1)
	items = itemsInList(traces,";")
	for ( i = 0; i < items; i += 1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#0"
	endfor
	
	
	string traceIndex
	variable traceCount
	//clean up
	traces = TraceNameList("CursorPanel#guiCursorDisplayResidual",";",1)
	traceCount = ItemsInList(traces,";")
//	print traces
	//SetAxis/A Res_Left
	
	for (i = traceCount; i > -1 ; i -= 1)
		traceIndex = "#"+num2str(i)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayResidual /Z $traceIndex
	endfor
	
end

static function SelectFitProject(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	SVAR nextProjectToOpen = root:STFitAssVar:nextProjectToOpen
	SVAR StartingDirectory = root:STFitAssVar:ST_StartDirectory
	StartingDirectory = GetDataFolder(1)
	//this static function updates the selection of the project which should be opened
	nextProjectToOpen = popStr
	OpenFitProject("preview")
end




static function /s getValidDataFolders()
	string datafolders = ""
	variable i
	Variable numDataFolders = CountObjects(":",4)
	string parent = GetDataFolder(1)
	for(i=0; i<numDataFolders; i+=1)
		String nextPath = GetIndexedObjName(":",4,i)
		//now check if this datafolder contains a subfolder "Setup" and a wave STsetup, if so it is a valid fit project
		SetDataFolder nextPath
		if (DataFolderExists("Setup"))
			SetDataFolder :$"Setup"
			if (exists("STsetup"))
				datafolders += nextPath + ";"
			endif
		else 
			if (exists("STsetup"))
				datafolders += nextPath + ";"
			endif
		endif
		SetDataFolder parent
	endfor
	datafolders = Sortlist(datafolders,";",4)
	return datafolders
end

static function CallSTNewProjectPanel(ctrlName):ButtonControl
	string ctrlName
	wave /t STsetup = STsetup
	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	NVAR ProjectSaved = root:STFitAssVar:savedLast
	variable WorkedInProject = DimSize(STsetup,0)
	
	if  (ProjectStarted == 1 && ProjectSaved == 0)    //projectSaved is actually saved last
		//DoAlert 1, "There are unsaved changes in the current project. Proceed anyway?"
		DoAlert 2, "There are unsaved changes in the current project. Save now?"
		if (V_Flag ==3) //user pressed no
			
			return -1
		elseif (V_Flag == 2)
			destroyCursorPanel("restart") //now,we are using the string as a switch for a restart
			LaunchCursorPanel()
		elseif (V_Flag == 1)  //user pressed yes
			//restart the entire thing
			saveFit("beforeNewProject")
			destroyCursorPanel("restart") //now,we are using the string as a switch for a restart
			LaunchCursorPanel()
		endif  

		
	elseif  (ProjectStarted == 1 && ProjectSaved == 1)
	
		destroyCursorPanel("void")
		LaunchCursorPanel()
	endif

	DoWindow STNewProjectPanel   //this will write "1" into V_Flag if the window is open already
	if (V_Flag )
		DoWindow /F STNewProjectPanel  // if it is already open, bring it to front
		return -1
	endif

//	execute "STNewProjectPanel()"
	drawSTNewProjectPanel() 
	initSTNewProjectPanel()
	
	
	DeActivateButtons(0)  // 0 means all of them
	Button LoadNewBtn,  win=CursorPanel, disable= 0	
	    //make it right for the datafolder
end




static function drawSTNewProjectPanel() 
	
		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 0"
		endif
	
	
	NewPanel /K=2 /N=STNewProjectPanel /W=(414.5,42.5,840.5,383.5) as "Start a new project"
	ModifyPanel cbRGB=(65534,65534,65534)
	SetDrawLayer UserBack
	SetDrawEnv fsize= 10,fstyle= 1
	DrawText 231.5,83.5,"For your information:"
	SetDrawEnv fsize= 10,fstyle= 1
	DrawText 231.5,94.5,"Finished fit projects in this folder"
	SetDrawEnv fsize= 10
	DrawText 85,117.8,"(binding energy only)"
	PopupMenu WavePop,pos={32.00,55.00},size={174.50,16.50},bodyWidth=125,proc=XPSTFA#initCursorPopUp,title="Spectrum    "
	PopupMenu WavePop,fSize=10
	PopupMenu WavePop,mode=1,popvalue="please select a wave",value= #"SortList(WaveList(\"!*Disp*\",\";\",\"DIMS:1\"), \";\",16)"
	PopupMenu WavePop2,pos={41,83.00},size={165.00,16.50},bodyWidth=125,proc=XPSTFA#initXWavePopUp,title="Energy     "
	PopupMenu WavePop2,fSize=10
	PopupMenu WavePop2,mode=1,popvalue="_calculated_ ",value= #"\"_calculated_;\"+ WaveList(\"*\", \";\", \"\")"
	PopupMenu TemplatePop,pos={50.00,243.50},size={149.00,16.50},bodyWidth=102,proc=XPSTFA#SetTemplate,title="Template    "
	PopupMenu TemplatePop,fSize=10,mode=1,popvalue="None",value= #"XPSTFA#STtemplateList()"
	PopupMenu TypePop,pos={31.00,164.00},size={175.00,4},bodyWidth=127,proc=XPSTFA#ReadType_CursorPanel,title="Peak Type   "
	PopupMenu TypePop,fSize=10
	PopupMenu TypePop,mode=1,popvalue="Singlet",value= #"\"Singlet;Doublet;Multiplet;ExtMultiplet\"\t"
	
	Button showbut,pos={112.50,304.50},size={100.00,22.00},proc=XPSTFA#StartNewProject,title="Do it"
	Button showbut,fSize=10,fStyle=1,appearance={os9,Win}
	Button CancelBtn,pos={10.00,304.00},size={100.00,22.00},proc=XPSTFA#KillSTNewProjectPanel,title="Cancel"
	Button CancelBtn,fSize=10,fStyle=1,appearance={os9,Win}
	
	SetVariable setvar0,pos={18,28},size={187.50,14.00},title="Project Name    "
	SetVariable setvar0,fSize=10,value= root:STFitAssVar:ProjectName
	GroupBox group1,pos={10.00,142.00},size={204.00,154.00},title="Choose a Model"
	GroupBox group1,fSize=10,fStyle=1
	GroupBox group2,pos={14.00,222.50},size={192.50,54.00},title="or select a template"
	GroupBox group2,fSize=10,fStyle=1
	GroupBox group3,pos={9.00,9.00},size={205.00,128.50},title="Data",fSize=10
	GroupBox group3,fStyle=1
	
	Button showbut1,pos={88,194},size={117.00,22.00},proc=XPSTFA#CallPeakTypeHelp,title="Explain the Peak Types"
	Button showbut1,fSize=10,fStyle=1,appearance={os9,Win}
	Button CancelBtn1,pos={287.00,20.00},size={121.00,22.00},proc=XPSTFA#CallDataBrowser,title="Call Data Browser"
	Button CancelBtn1,fSize=10,fStyle=1,appearance={os9,Win}
	
	ListBox availableProjectsList,pos={230.00,99.00},size={177.00,224.50},frame=0, fsize=10
	
	Button updateBut,pos={287.00,43.00},size={121.00,22.00},proc=XPSTFA#PopulateListOpenProjectPanel,title="Update list"
	Button updateBut,fSize=10,fStyle=1,appearance={os9,Win}
	
	
		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 1"
		endif
		
end



static function initSTNewProjectPanel()
	SVAR StartingFolder = root:STFitAssVar:ST_StartDirectory
	
	SetDataFolder StartingFolder
	PopulateListOpenProjectPanel("fromNewProject")
	ListBox availableProjectsList,win=STNewProjectPanel, listwave=root:STFitAssVar:XPSTProjectList, mode=0
end

static function CallPeakTypeHelp(ctrlName):ButtonControl
	string ctrlName
	DisplayHelpTopic "Singlet and Multiplet peaks"
end


static function KillSTNewProjectPanel(ctrlName):ButtonControl
	string ctrlName
	SVAR workingFolder = root:STFitAssVar:CP_workingFolder
	NVAR projectStarted = root:STFitAssVar:projectStarted
	SetDataFolder workingFolder
	DoWindow /K STNewProjectPanel
	if (projectStarted == 0)
		ActivateButtons(1)
		RemoveFromGraph /w=CursorPanel#guiCursorDisplay /Z $"#0"
	else
		ActivateButtons(0)
		
	endif
	
end

static function STKineticAxisCheck(ctrlName,checked): CheckBoxControl                          // this static function is not required any more, it was inserted to deal with spectra vs. kinetic energy
	string ctrlName
	variable checked
//	CheckLocation()
	NVAR value = root:STFitAssVar:KineticAxis
	
	
	if (checked ==1)
		value = 1
		
	else
		value = 0
		
	endif	
end


static function CallDataBrowser(ctrlName):ButtonControl
	string ctrlName
	
	DFREF saveDF = GetDataFolderDFR()		// Save current data folder before
	CreateBrowser /M
	
	ModifyBrowser /M showModalBrowser, showVars=0, showWaves=0, showStrs=0, showInfo=0, showPlot=0
 	
	if (V_Flag == 0)
		SetDataFolder saveDF		// Restore current data folder	if user cancelled
	endif
	
	PopulateListOpenProjectPanel("fromNewProject")
end



static function StartNewProject(ctrlName):ButtonControl
	string ctrlName

	SVAR currentFolder = root:STFitAssVar:CP_workingFolder 
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR RawYWave =root:STFitAssVar:PR_nameWorkWave
	SVAR StartingFolder = root:STFitAssVar:ST_StartDirectory
	SVAR ProjectName = root:STFitAssVar:ProjectName
	SVAR templateName = root:STFitAssVar:templateName
	
	NVAR useTemplate = root:STFitAssVar:useTemplate
	
	NVAR ProjectStarted = root:STFitAssVar:projectStarted
	if (exists("root:STFitAssVar:KineticAxis") )
	      NVAR kinetic = root:STFitAssVar:KineticAxis
	endif
	
	variable invalid = 0
	wave yraw = $RawYWave

	strswitch(RawYWave)
		case "":
			DoAlert 0, "Please provide a Spectrum"
		return -1
		break
	endswitch
	
	if (!WaveExists(yraw))
		DoAlert 0, "This wave does not exist in this data folder.\rPlease check if you are still in the right parent folder!"
		return -1
	endif
	
	strswitch(ProjectName)
		case "":
			DoAlert 0, "Please provide a project name"
			return -1
			break
	endswitch
	
	//the same construction is in saveFitAs .... maybe this can be outsourced into a separate static function
	variable legal = !GrepString(Projectname,"[^[:alnum:]_+-]") 
	variable letter = GrepString(Projectname,"[[:alpha:]]") 
	variable number =  GrepString(Projectname,"[[:digit:]]")
	variable nameOkay = legal && ( (letter && number) || (letter && !number))
	invalid = ! nameOkay // !nameOkay //look for not alpha-numeric characters
	//this would allow + and - too   [^[:alnum:]+-]

	if (invalid)
		DoAlert 0, "The project name may only contain '+', ' _', '-', letters, and digits.\r \rPlease provide a new project name."
		return -1
	endif
	
	if (DataFolderExists(ProjectName))
		DoAlert 0, "This project name already exists! \rPlease choose a different name."
		return -1
	endif
	
	if (strlen(ProjectName)>27)
		DoAlert 0, "The project name can only be 27 characters long, please provide a new one."
		return -1
	endif
	//make a test, if everything is okay with the global variables
	strswitch(RawYWave)
	case "":
		doalert 0, "No data wave given!"
		Button addBut disable=2 
		return -1
		break
	default:
		break
	endswitch

	if (strlen(RawYWave) > 25)
		string newName
		Prompt newName, "The original wave will be duplicated into the project folder as:"		// Set prompt for x param
		DoPrompt "Wave name is too long (more than 25 characters)", newName
		if (V_Flag)
			return -1								// User canceled
		endif
		if (strlen(newName) == 0 )
			DoAlert 0, "This was too short ..."
			return -1
		endif
		RawYWave = newName
		//DoAlert 0,"The wave name is too long, please rename the wave (Menu: Data).\rThe new name must not exceed 22 characters."
		//return -1
	endif
	
	StartingFolder = GetDataFolder(1)  //remember this ... in order leave the project folder later on
	
	string shiftNameY = ":'" + ProjectName + "':" + "'" + RawYWave + "'"
	
	NewDataFolder $ProjectName
	strswitch(RawXWave)
		case "":
		break
		case "_calculated_":
		break
		default:
			wave xraw = $RawXWave
			string shiftNameX = ":" + ProjectName + ":" + "'" + RawXWave + "'"
			duplicate /o xraw $shiftNameX
		break
	endswitch

	duplicate /o yraw $shiftNameY
	SetDataFolder ProjectName
	
	currentFolder = getDataFolder(1)   //remember where we are ...
	
	variable /G V_FitTol    //those have to remain in the current working directory
	variable /G V_FitMaxIters = 50
	Variable /G V_FitOptions = 0
	NVAR iterations= V_FitMaxIters
	NewDataFolder FitTemp
	NewDataFolder Peaks
	string HostWindowName = "CursorPanel"
	SetVariable  InputMaxFitIterations, win=$HostWindowName, limits={1,100,1},value=iterations
	
	
	
	//strswitch(peakType)
	//case "":
	//	doalert 0, "No peak type given!"
	//	Button addBut disable=2   
	//	return -1
	//default:
	//	break
	//endswitch

	wave WorkWave = $RawYWave 
	Wavestats /Q WorkWave	
	//Remove old traces from the graph, four of them to be on the safe side
	RemoveFromGraph /W=CursorPanel#guiCursorDisplay /Z $"#0" $"#1" $"#2" $"#3" $"#4"
	//this is quite a lot of coding to accomplish such a simple task
	string path = "CursorPanel#guiCursorDisplayFit"
	string traces = TraceNameList(path,";",1)
	variable itemsOnGraph = itemsInList(traces)
	string tempString
	do
		sprintf tempString, "#%d", itemsOnGraph
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $tempString
		itemsOnGraph -= 1
	while ( itemsOnGraph >= 0)
	/// done
	
	
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph /w=CursorPanel#guiCursorDisplayFit WorkWave 
			ModifyGraph  /w = CursorPanel#guiCursorDisplayFit rgb($"#0")=(39168,39168,39168) 
			AppendToGraph /w=CursorPanel#guiCursorDisplay WorkWave                     
			break
		case "_calculated_":
			AppendToGraph /w=CursorPanel#guiCursorDisplayFit WorkWave
			ModifyGraph  /w = CursorPanel#guiCursorDisplayFit rgb($"#0")=(39168,39168,39168)  
			AppendToGraph /w=CursorPanel#guiCursorDisplay WorkWave 
			break
		default:                                                 // if not empty
		       wave xraw = $RawXWave
			AppendToGraph /w=CursorPanel#guiCursorDisplayFit WorkWave vs xraw
			ModifyGraph  /w = CursorPanel#guiCursorDisplayFit rgb($"#0")=(39168,39168,39168) 
			AppendToGraph /w=CursorPanel#guiCursorDisplay WorkWave vs xraw
			break
	endswitch
	
	if (exists("root:STFitAssVar:KineticAxis") && kinetic ==1 )
	      //don't do anything
	else
		SetAxis /A /R /w = CursorPanel#guiCursorDisplay bottom
		SetAxis /A /R /w = CursorPanel#guiCursorDisplayFit bottom
	endif
	SetAxis /w = CursorPanel#guiCursorDisplay left *, 1.02*V_max
	//SetAxis /w = CursorPanel#guiCursorDisplayFit left 0.9*V_min, 1.04*V_max
	
	//append not the local reference of the wave,since it does not exist globally. Use the $WaveNameString notation instead
	Cursor /H=1 /F /P /S=0 /L=1 /W=CursorPanel#guiCursorDisplay A $RawYWave, 0.55, 0.2
	ModifyGraph /w= CursorPanel#guiCursorDisplay zero(left)=2 
	ModifyGraph  /w = CursorPanel#guiCursorDisplay mirror(left)=2, minor(left)=1
	ModifyGraph  /w = CursorPanel#guiCursorDisplay mirror(bottom)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplay rgb($"#0")=(0,26112,39168) 
	ModifyGraph  /w = CursorPanel#guiCursorDisplay mode($"#0")=7, hbfill($"#0")=5
	
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2, minor(left)=1
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2//, nticks(left)=0
	ModifyGraph /w = CursorPanel#guiCursorDisplayFit axRGB(left)=(34816,34816,34816),tlblRGB(left)=(34816,34816,34816), alblRGB(left)=(34816,34816,34816)
	ModifyGraph /w = CursorPanel#guiCursorDisplayFit axRGB(bottom)=(34816,34816,34816),tlblRGB(bottom)=(34816,34816,34816), alblRGB(bottom)=(34816,34816,34816) 
	
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplay Bottom " "
	ModifyGraph  /w = CursorPanel#guiCursorDisplay minor(bottom)=1,sep(bottom)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplay minor(bottom)=1,sep(bottom)=2
	//TextBox /C /w = CursorPanel#guiCursorDisplay /N=text0/F=0/A=LT "Drag the crosshairs to a peak\rPress 'Add Peak'\rPress 'Start Fit'"
	
	ProjectStarted = 1
	displayWavesCursorPanel("void")
	KillSTNewProjectPanel("foe")
	wave /t FitControls = FitControls
	FitControls[5][0] = ProjectName
	FitControls[6][0] = RawYWave
	FitControls[7][0] = RawXWave
	
	ListBox QuickEditList, win=CursorPanel, listWave=STsetup
	ListBox QuickEditList,win = CursorPanel, selWave=selSTsetup,colorWave=root:STFitAssVar:myColors
	TabControl OptionsTab, win=CursorPanel, value=0
	
	string displayString = "" 
	//sprintf displaystring, "Parent Data Folder: %s \rCurrent Project: %s ", StartingFolder, ProjectName
	//sprintf displaystring, "Parent Data Folder:\t%s \rCurrent Project:\t\t\t%s ", StartingFolder, ProjectName
	//TitleBox notify1, win=CursorPanel, title=displayString
	
	sprintf displaystring,"%s\t(Parent Data Folder)", startingFolder
	TitleBox notify1, win=CursorPanel, title=displayString
	
	sprintf displaystring,"%s\t(Current Project) ",ProjectName
	TitleBox notify1b, win=CursorPanel, title=displayString
	
	
	sprintf displaystring,"%s\t(Spectrum) ", RawYWave
	TitleBox notify2, win=CursorPanel, title=displayString
end

static function /S STtemplateList()

	string templateList = "None;"
	variable i
	string parent = GetDataFolder(1)
	
	if (DataFolderExists("root:Fit_templates"))
		SetDataFolder root:Fit_templates
		Variable numDataFolders = CountObjects(":",4)
		string nextPath
		for(i=0; i<numDataFolders; i+=1)
			nextPath = GetIndexedObjName(":",4,i)
			templateList += nextPath + ";"
		endfor
		SetDataFolder parent
		return templateList
	else
		return "None;"
	endif


end

static function SetTemplate(ctrlName,popNum,popStr) : PopupMenuControl
	string ctrlName
	variable popNum
	string popStr
	NVAR useTemplate = root:STFitAssVar:useTemplate
	SVAR templateName = root:STFitAssVar:templateName
	strswitch(popStr)
	case "None":
		PopupMenu TypePop disable=0
		useTemplate = 0
		templateName = ""
		break
	default:
		PopupMenu TypePop disable=2
		useTemplate = 1
		templateName = popStr
		break
	endswitch
	
end

static function displayWavesNewProjectPanel(ctrlName):ButtonControl
	string ctrlName
	string HostWindowName = "CursorPanel"
	//Button addBut win=$HostWindowName, fColor=(44000,52000,65500), disable=0        //(32768,54528,65280)
	//Button DeleteBut win=$HostWindowName, fColor=(44000,52000,65500), disable=0           //(32768,54528,65280)
	//Button FitBut win=$HostWindowName, fColor=(44000,52000,65500)    
	//Button ConstraintBut win=$HostWindowName, fColor=(44000,52000,65500)    
	//displayWavesCursorPanel("foe")
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Read the values in the pop-up menus
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//read the name of the raw-data wave
static function initCursorPopUp(ctrlName, popNum, popStr) : PopupMenuControl
	string ctrlName //not used here
	variable popNum //not used here
	string popStr
	//if ( CheckLocation() )
	//	PopupMenu WavePop , mode = 1, popvalue= " "
	//	return 1
	//endif
	SVAR value = root:STFitAssVar:PR_nameWorkWave    
	value = popStr 
	RemoveFromGraph /w=CursorPanel#guiCursorDisplay /Z $"#0"
	
	AppendToGraph /w=CursorPanel#guiCursorDisplay $popStr //$nameWorkWave  
	SetAxis /w=CursorPanel#guiCursorDisplay /A /R bottom	
end

//read the background type
static function ReadBackground_CursorPanel(ctrlName,popNum,popStr): PopupMenuControl
	string ctrlName
	variable popNum
	String popStr
	//if ( CheckLocation() )
	//	PopupMenu TypePop , mode = 1, popvalue= " "
	//	return 1
	//endif
	SVAR value = root:STFitAssVar:PR_Background
	//print value
	strswitch(popStr)
		case "Shirley Kombi":
			value = "SK"
		break		
	default:
		value = popStr
	endswitch              
	combinePeakBackground()
	ReDoBackground()
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// ListBoxPanels

static function CallPeakEditor() 
	initializeConstraintTable()
	

		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 0"
		endif
	
	NewPanel /K=1 /N=PeakEditor /W=(45,83,927,473) as "Editor"
	ModifyPanel cbRGB=(65534,65534,65534)
	
	ListBox list0,pos={6,6},size={870,320},win=PeakEditor, proc=XPSTFA#refresh,listWave=STsetup,userColumnResize=1
	ListBox list0,selWave=selSTsetup,colorWave=root:STFitAssVar:myColors
	ListBox list0,widths={200,30,100,100,40,100,100,60},userColumnResize= 1, fsize=10
	
	Button CheckButton,pos={126.00,362.00},size={120.00,22.00},proc=XPSTFA#checkSetup,title="Check 'Hold-Logic'"
	Button CheckButton,fSize=9,appearance={os9,Win}
	Button HelpCalBut,pos={4.00,339.00},size={120.00,22.00},proc=XPSTFA#callHelp,title="How to get a stable fit"
	Button HelpCalBut,fSize=9,appearance={os9,Win}
	Button PeakParaHelp,pos={126.00,339.00},size={120.00,22.00},proc=XPSTFA#callHelpPeakParameters,title="Explain those parameters"
	Button PeakParaHelp,fSize=9,appearance={os9,Win}
	Button CallHelpDoNots,pos={4.00,362.00},size={120.00,22.00},proc=XPSTFA#callHelpDoNots,title="What to avoid ..."
	Button CallHelpDoNots,fSize=9,appearance={os9,Win}


		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 1"
		endif
 	
End

static function ApplyChanges(ctrlName):ButtonControl
	string ctrlName
	//updateCoefs()
	setup2waves()
	updateFitDisplay("void")
	updateResidualDisplay("void")
end

static function callHelpDoNots(ctrlName):ButtonControl
string ctrlName
DisplayHelpTopic "Things to avoid during a XPST fit"

end


static function Refresh(ctrlName,row,col,event): ListBoxControl
	string ctrlName
	variable row
	variable col
	variable event
	NVAR oldVal = root:STFitAssVar:OldValueInSetup
	NVAR savedLast = root:STFitAssVAr:savedLast 
	wave /t setup = STsetup
	wave sw = selSTsetup
	
	wave myColors = root:STFitAssVar:myColors
	SVAR peakType = root:STFitAssVar:PR_PeakType
	variable length, numpeaks, index, i,j,k
	string planeName = "foreColors"
	variable plane = FindDimLabel(sw,2,planeName)
	
	
	//planeName = "foreColors"   //used to be backColors
	//	plane = FindDimLabel(sw,2,planeName)
	//	nplanes = max(1,Dimsize(sw,2))
	//	if (plane <0)
	//		Redimension /N=(-1,-1,nplanes+1) sw
	//		plane = nplanes
	//		SetDimLabel 2,nplanes,$planeName sw
	//	endif

	//	for ( i = 0; i < length; i += 1)
	//		if (sw[i][4] == 48)
	//			sw[i][5][0] = 0
	//			sw[i][6][0] = 0
	//			sw[i][5][plane] = 4
	//			sw[i][6][plane] = 4
	//		else
	//			sw[i][5][0] = (0x02)
	//			sw[i][6][0] = (0x02)
	//			sw[i][5][plane] = 0
	//			sw[i][6][plane] = 0
	//		endif
	//	endfor
	if (event == 2)
		fancyUp("foe")
	endif

	//the following code should recognize if there have been any changes in the cell
	if (event == 6 && col == 3 )

		oldVal = str2num(setup[row][col])
	endif
	
	if (event ==7 && col == 3 )
		if (str2num(setup[row][col]) != oldVal)  //do this only, if there was a change in the cell value
			updateFitDisplay("void")
			updateResidualDisplay("void")
			savedLast = 0
		endif
	endif
	// hide subpeaks if ratio is zero
		if( event == 7  && col == 3 && StringMatch(setup[row][0],"*Ratio*")   &&  StringMatch(setup[row][0],"!*Gauss*") && str2num(setup[row][3]) == 0 && sw[row][4] == 48)
			
	 			// colour to special
				sw[row][0][plane] = 2
				sw[row][1][plane] = 2
				sw[row][2][plane] = 2

				sw[row+1][0][plane] = 2
				sw[row+1][1][plane] = 2
				sw[row+1][2][plane] = 2

				sw[row+2][0][plane] = 2
				sw[row+2][1][plane] = 2
				sw[row+2][2][plane] = 2
				
				//sw[row][3][plane] = 4
				sw[row+1][3][plane] = 2
				sw[row+2][3][plane] = 2
			
				//  disable edit
				sw[row+1][3][0] = 0
				sw[row+2][3][0] = 0
	
			
		elseif ( event == 7  && col == 3 && StringMatch(setup[row][0],"*Ratio*")   &&  StringMatch(setup[row][0],"!*Gauss*") && (str2num(setup[row][3]) != 0 || sw[row][4] != 48))
				// colour to normal
				sw[row][0][plane] = 0
				sw[row][1][plane] = 0
				sw[row][2][plane] = 0

				sw[row+1][0][plane] = 0
				sw[row+1][1][plane] = 0
				sw[row+1][2][plane] = 0

				sw[row+2][0][plane] = 0
				sw[row+2][1][plane] = 0
				sw[row+2][2][plane] = 0
	

				sw[row][3][plane] = 0
				sw[row+1][3][plane] = 0
				sw[row+2][3][plane] = 0
				
				// enable edit
				sw[row+1][3][0] = (0x02)
				sw[row+2][3][0] = (0x02)
		endif	
		if (event ==2 && col ==4  && StringMatch(setup[row][0],"*Ratio*")   &&  StringMatch(setup[row][0],"!*Gauss*") )   //clicked into hold
			if (sw[row][4] == 32)   //if it is not on hold
				sw[row][0][plane] = 0
				sw[row][1][plane] = 0
				sw[row][2][plane] = 0

				sw[row+1][0][plane] = 0
				sw[row+1][1][plane] = 0
				sw[row+1][2][plane] = 0

				sw[row+2][0][plane] = 0
				sw[row+2][1][plane] = 0
				sw[row+2][2][plane] = 0
	

				sw[row][3][plane] = 0
				sw[row+1][3][plane] = 0
				sw[row+2][3][plane] = 0
				
				// enable edit
				sw[row+1][3][0] = (0x02)
				sw[row+2][3][0] = (0x02)
			elseif ( str2num(setup[row][3])==0)   //that means it is on hold and 0
				sw[row][0][plane] = 2
				sw[row][1][plane] = 2
				sw[row][2][plane] = 2

				sw[row+1][0][plane] = 2
				sw[row+1][1][plane] = 2
				sw[row+1][2][plane] = 2

				sw[row+2][0][plane] = 2
				sw[row+2][1][plane] = 2
				sw[row+2][2][plane] = 2

				
				//sw[row][3][plane] = 4
				sw[row+1][3][plane] = 2
				sw[row+2][3][plane] = 2
			
				//  disable edit
				sw[row+1][3][0] = 0
				sw[row+2][3][0] = 0
			
			endif
		endif
		
		// to prevent broadening zero
 		if (event == 7  && col == 3 && StringMatch(setup[row][0],"*Broadening*") && str2num(setup[row][3]) == 0 )
			DoAlert 0, "A broadenig of zero is physically wrong and will kill the fit!"
			setup[row][3] = MyNum2str(oldVal)  //set broadening back to 1
		endif
end

//static function updateCoefs()
//	//wave /t source= setup
//	wave /t source = STsetup
//	variable length    //0 for rows, 1 for columns
//	wave W_coef = W_Coef      //could also be initalizeCoef
//	wave init = InitializeCoef
//	variable i
	
//	if (WaveExists(source))
//		length = dimsize(source,0)
//		for (i =0; i < length; i += 1)
//			init[i] = str2num(source[i][3])
//			W_Coef[i] = str2num(source[i][3])
//		endfor
//		setup2waves()
//	else
//		length = 0
//	endif
//end



static function FancyUp(ctrlName):ButtonControl
	string ctrlName
	wave /t source = STsetup
	wave sw = selSTsetup
	wave myColors = root:STFitAssVar:myColors
	SVAR peakType = root:STFitAssVar:PR_PeakType

	
	SetDimLabel 1,0,$"Legend",source
	SetDimLabel 1,1,$"",source
	SetDimLabel 1,2,$"Fit Results",source
	SetDimLabel 1,3,$"Initial Guess", source
	SetDimLabel 1,4,$"hold", source
	SetDimLabel 1,5,$"Lower Limit", source
	SetDimLabel 1,6,$"Upper Limit", source
	SetDimLabel 1,7,$"epsilon", source

	string planeName = "backColors"
	variable plane = FindDimLabel(sw,2,planeName)
	
	
	variable numCoef          ////////////////////////      number of coefficients  extMultiplet = 33
	variable numSubPeaks      ///////////////////////// number of Subpeaks extMultiplet = 10
	
	
	Variable nplanes = max(1,Dimsize(sw,2))
	if (plane <0)
		Redimension /N=(-1,-1,nplanes+1) sw
		plane = nplanes
		SetDimLabel 2,nplanes,$planeName sw
	endif


	//now do the color coding
	//these are the basic colors
	sw[][][plane] = 4   //4th row in the color wave
	sw[][3][plane] =3
	sw[][5][plane] =3
	sw[][6][plane] =3
	sw[][7][plane] =3
	
	variable length, numpeaks, index, i,j,k,l
	strswitch(peakType)
	case "SingletSK":
		//now re-colorcode every other peak meaning peak 2, 4, 6, 8, ....
		//first extract the number of peaks
		numCoef=6
	 	length = DimSize(source,0)
	 	numpeaks = (length-5)/ 6 
	 	numSubPeaks = 1

		make /d /n=4 /o tempWaveAsArray
		wave tempWave = tempWaveAsArray
		tempWave={3,5,6,7}

		for (i=0; i<numpeaks; i += 1)
			index = 6*i + 5
			if (mod(i,2) != 0)
				continue
			endif
			sw[index][][plane] = 0
			sw[index+1][][plane] = 0
			sw[index+2][][plane] = 0
			sw[index+3][][plane] = 0
			sw[index+4][][plane] = 0
			sw[index+5][][plane] = 0

			for (j= 0; j<4;j+=1)
				k = tempWave[j]

				sw[index][k][plane] = 2
				sw[index+1][k][plane] = 2
				sw[index+2][k][plane] = 2
				sw[index+3][k][plane] = 2
				sw[index+4][k][plane] = 2
				sw[index+5][k][plane] = 2
			endfor
		endfor


		planeName = "foreColors"   //used to be backColors
		plane = FindDimLabel(sw,2,planeName)
		nplanes = max(1,Dimsize(sw,2))
		if (plane <0)
			Redimension /N=(-1,-1,nplanes+1) sw
			plane = nplanes
			SetDimLabel 2,nplanes,$planeName sw
		endif

		for ( i = 0; i < length; i += 1)
			if (sw[i][4] == 48)
				sw[i][5][0] = 0
				sw[i][6][0] = 0
				sw[i][5][plane] = 4
				sw[i][6][plane] = 4
			else
				sw[i][5][0] = (0x02)
				sw[i][6][0] = (0x02)
				sw[i][5][plane] = 0
				sw[i][6][plane] = 0
			endif
		endfor
	break
	
	case "DoubletSK":                                                //begin section for multiplet
		numCoef=9
		length = DimSize(source,0)
		numpeaks = (length-5)/numCoef 
		numSubPeaks = 2

		make /d /n=4 /o tempWaveAsArray
		wave tempWave = tempWaveAsArray
		//stopped for now ....
		tempWave={3,5,6,7}

		for (i=0; i<numpeaks; i += 1)
			index = numCoef*i + 5
			if (mod(i,2) != 0)
				continue
			endif
			for (l=0; l<numCoef; l += 1)
				sw[index+l][][plane] = 0
			endfor
			for (j= 0; j<4;j+=1)    //4 before
				k = tempWave[j]
				for (l=0; l<numCoef; l += 1)
					sw[index+l][k][plane] = 2
				endfor
			endfor
		endfor


		planeName = "foreColors"   //used to be backColors
		plane = FindDimLabel(sw,2,planeName)
		nplanes = max(1,Dimsize(sw,2))
		if (plane <0)
			Redimension /N=(-1,-1,nplanes+1) sw
			plane = nplanes
			SetDimLabel 2,nplanes,$planeName sw
		endif
		//go through the setup and find items on hold, the constraints need to be passivated in this case
		for ( i = 0; i < length; i += 1)
			if (sw[i][4] == 48)
				sw[i][5][0] = 0
				sw[i][6][0] = 0
				sw[i][5][plane] = 4
				sw[i][6][plane] = 4
			else
				sw[i][5][0] = (0x02)
				sw[i][6][0] = (0x02)
				sw[i][5][plane] = 0
				sw[i][6][plane] = 0
			endif
		endfor
		
		//and now, hiding and unhiding unused multiplets
		for ( i =0; i < length; i += 1)
		
			if( StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") && str2num(source[i][3]) == 0 && sw[i][4] == 48)
			
	 			// colour to special
				sw[i][0][plane] = 2
				sw[i][1][plane] = 2
				sw[i][2][plane] = 2

				sw[i+1][0][plane] = 2
				sw[i+1][1][plane] = 2
				sw[i+1][2][plane] = 2

				sw[i+2][0][plane] = 2
				sw[i+2][1][plane] = 2
				sw[i+2][2][plane] = 2

				
				//sw[i][3][plane] = 4
				sw[i+1][3][plane] = 2
				sw[i+2][3][plane] = 2
			
				//  disable edit
				sw[i+1][3][0] = 0
				sw[i+2][3][0] = 0
	
			
		elseif (  StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") && (str2num(source[i][3]) != 0 || sw[i][4] != 48))
				// colour to normal
				sw[i][0][plane] = 0
				sw[i][1][plane] = 0
				sw[i][2][plane] = 0

				sw[i+1][0][plane] = 0
				sw[i+1][1][plane] = 0
				sw[i+1][2][plane] = 0

				sw[i+2][0][plane] = 0
				sw[i+2][1][plane] = 0
				sw[i+2][2][plane] = 0
	

				sw[i][3][plane] = 0
				sw[i+1][3][plane] = 0
				sw[i+2][3][plane] = 0
				
				// enable edit
				sw[i+1][3][0] = (0x02)
				sw[i+2][3][0] = (0x02)
		endif	
		if ( StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") )   //clicked into hold
			if (sw[i][4] == 32)   //if it is not on hold
				sw[i][0][plane] = 0
				sw[i][1][plane] = 0
				sw[i][2][plane] = 0

				sw[i+1][0][plane] = 0
				sw[i+1][1][plane] = 0
				sw[i+1][2][plane] = 0

				sw[i+2][0][plane] = 0
				sw[i+2][1][plane] = 0
				sw[i+2][2][plane] = 0
	

				sw[i][3][plane] = 0
				sw[i+1][3][plane] = 0
				sw[i+2][3][plane] = 0
				
				// enable edit
				sw[i+1][3][0] = (0x02)
				sw[i+2][3][0] = (0x02)
			elseif ( str2num(source[i][3])==0)   //that means it is on hold and 0
				sw[i][0][plane] = 2
				sw[i][1][plane] = 2
				sw[i][2][plane] = 2

				sw[i+1][0][plane] = 2
				sw[i+1][1][plane] = 2
				sw[i+1][2][plane] = 2

				sw[i+2][0][plane] = 2
				sw[i+2][1][plane] = 2
				sw[i+2][2][plane] = 2

				
				//sw[i][3][plane] = 4
				sw[i+1][3][plane] = 2
				sw[i+2][3][plane] = 2
			
				//  disable edit
				sw[i+1][3][0] = 0
				sw[i+2][3][0] = 0
			
			endif
		endif
	endfor
		
		
	break  
	
	
	
	
	case "MultiSK":                                                //begin section for multiplet
		numCoef=15
		length = DimSize(source,0)
		numpeaks = (length-5)/numCoef 
		numSubPeaks = 4 

		make /d /n=4 /o tempWaveAsArray
		wave tempWave = tempWaveAsArray
		//stopped for now ....
		tempWave={3,5,6,7}

		for (i=0; i<numpeaks; i += 1)
			index = numCoef*i + 5
			if (mod(i,2) != 0)
				continue
			endif
			for (l=0; l<numCoef; l += 1)
				sw[index+l][][plane] = 0
			endfor
			for (j= 0; j<4;j+=1)    //4 before
				k = tempWave[j]
				for (l=0; l<numCoef; l += 1)
					sw[index+l][k][plane] = 2
				endfor
			endfor
		endfor


		planeName = "foreColors"   //used to be backColors
		plane = FindDimLabel(sw,2,planeName)
		nplanes = max(1,Dimsize(sw,2))
		if (plane <0)
			Redimension /N=(-1,-1,nplanes+1) sw
			plane = nplanes
			SetDimLabel 2,nplanes,$planeName sw
		endif
		//go through the setup and find items on hold, the constraints need to be passivated in this case
		for ( i = 0; i < length; i += 1)
			if (sw[i][4] == 48)
				sw[i][5][0] = 0
				sw[i][6][0] = 0
				sw[i][5][plane] = 4
				sw[i][6][plane] = 4
			else
				sw[i][5][0] = (0x02)
				sw[i][6][0] = (0x02)
				sw[i][5][plane] = 0
				sw[i][6][plane] = 0
			endif
		endfor
		
		//and now, hiding and unhiding unused multiplets
		for ( i =0; i < length; i += 1)
		
			if( StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") && str2num(source[i][3]) == 0 && sw[i][4] == 48)
			
	 			// colour to special
				sw[i][0][plane] = 2
				sw[i][1][plane] = 2
				sw[i][2][plane] = 2

				sw[i+1][0][plane] = 2
				sw[i+1][1][plane] = 2
				sw[i+1][2][plane] = 2

				sw[i+2][0][plane] = 2
				sw[i+2][1][plane] = 2
				sw[i+2][2][plane] = 2

				
				//sw[i][3][plane] = 4
				sw[i+1][3][plane] = 2
				sw[i+2][3][plane] = 2
			
				//  disable edit
				sw[i+1][3][0] = 0
				sw[i+2][3][0] = 0
	
			
		elseif (  StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") && (str2num(source[i][3]) != 0 || sw[i][4] != 48))
				// colour to normal
				sw[i][0][plane] = 0
				sw[i][1][plane] = 0
				sw[i][2][plane] = 0

				sw[i+1][0][plane] = 0
				sw[i+1][1][plane] = 0
				sw[i+1][2][plane] = 0

				sw[i+2][0][plane] = 0
				sw[i+2][1][plane] = 0
				sw[i+2][2][plane] = 0

				sw[i][3][plane] = 0
				sw[i+1][3][plane] = 0
				sw[i+2][3][plane] = 0
				
				// enable edit
				sw[i+1][3][0] = (0x02)
				sw[i+2][3][0] = (0x02)
		endif	
		if ( StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") )   //clicked into hold
			if (sw[i][4] == 32)   //if it is not on hold
				sw[i][0][plane] = 0
				sw[i][1][plane] = 0
				sw[i][2][plane] = 0

				sw[i+1][0][plane] = 0
				sw[i+1][1][plane] = 0
				sw[i+1][2][plane] = 0

				sw[i+2][0][plane] = 0
				sw[i+2][1][plane] = 0
				sw[i+2][2][plane] = 0
	

				sw[i][3][plane] = 0
				sw[i+1][3][plane] = 0
				sw[i+2][3][plane] = 0
				
				// enable edit
				sw[i+1][3][0] = (0x02)
				sw[i+2][3][0] = (0x02)
			elseif ( str2num(source[i][3])==0)   //that means it is on hold and 0
				sw[i][0][plane] = 2
				sw[i][1][plane] = 2
				sw[i][2][plane] = 2

				sw[i+1][0][plane] = 2
				sw[i+1][1][plane] = 2
				sw[i+1][2][plane] = 2

				sw[i+2][0][plane] = 2
				sw[i+2][1][plane] = 2
				sw[i+2][2][plane] = 2

				
				//sw[i][3][plane] = 4
				sw[i+1][3][plane] = 2
				sw[i+2][3][plane] = 2
			
				//  disable edit
				sw[i+1][3][0] = 0
				sw[i+2][3][0] = 0
			
			endif
		endif
	endfor
		
		
	break  
	
	case "ExtMultiSK":                                                //begin section for multiplet
		numCoef=33
		length = DimSize(source,0)
		numpeaks = (length-5)/numCoef 
		numSubPeaks = 10 

		make /d /n=4 /o tempWaveAsArray
		wave tempWave = tempWaveAsArray
		//stopped for now ....
		tempWave={3,5,6,7}

		for (i=0; i<numpeaks; i += 1)
			index = numCoef*i + 5
			if (mod(i,2) != 0)
				continue
			endif
			for (l=0; l<numCoef; l += 1)
				sw[index+l][][plane] = 0
			endfor
			for (j= 0; j<4;j+=1)    //4 before
				k = tempWave[j]
				for (l=0; l<numCoef; l += 1)
					sw[index+l][k][plane] = 2
				endfor
			endfor
		endfor


		planeName = "foreColors"   //used to be backColors
		plane = FindDimLabel(sw,2,planeName)
		nplanes = max(1,Dimsize(sw,2))
		if (plane <0)
			Redimension /N=(-1,-1,nplanes+1) sw
			plane = nplanes
			SetDimLabel 2,nplanes,$planeName sw
		endif
		//go through the setup and find items on hold, the constraints need to be passivated in this case
		for ( i = 0; i < length; i += 1)
			if (sw[i][4] == 48)
				sw[i][5][0] = 0
				sw[i][6][0] = 0
				sw[i][5][plane] = 4
				sw[i][6][plane] = 4
			else
				sw[i][5][0] = (0x02)
				sw[i][6][0] = (0x02)
				sw[i][5][plane] = 0
				sw[i][6][plane] = 0
			endif
		endfor
		
		//and now, hiding and unhiding unused multiplets
		for ( i =0; i < length; i += 1)
		
			if( StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") && str2num(source[i][3]) == 0 && sw[i][4] == 48)
			
	 			// colour to special
				sw[i][0][plane] = 2
				sw[i][1][plane] = 2
				sw[i][2][plane] = 2

				sw[i+1][0][plane] = 2
				sw[i+1][1][plane] = 2
				sw[i+1][2][plane] = 2

				sw[i+2][0][plane] = 2
				sw[i+2][1][plane] = 2
				sw[i+2][2][plane] = 2

				
				//sw[i][3][plane] = 4
				sw[i+1][3][plane] = 2
				sw[i+2][3][plane] = 2
			
				//  disable edit
				sw[i+1][3][0] = 0
				sw[i+2][3][0] = 0
	
			
		elseif (  StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") && (str2num(source[i][3]) != 0 || sw[i][4] != 48))
				// colour to normal
				sw[i][0][plane] = 0
				sw[i][1][plane] = 0
				sw[i][2][plane] = 0

				sw[i+1][0][plane] = 0
				sw[i+1][1][plane] = 0
				sw[i+1][2][plane] = 0

				sw[i+2][0][plane] = 0
				sw[i+2][1][plane] = 0
				sw[i+2][2][plane] = 0
	

				sw[i][3][plane] = 0
				sw[i+1][3][plane] = 0
				sw[i+2][3][plane] = 0
				
				// enable edit
				sw[i+1][3][0] = (0x02)
				sw[i+2][3][0] = (0x02)
		endif	
		if ( StringMatch(source[i][0],"*Ratio*")   &&  StringMatch(source[i][0],"!*Gauss*") )   //clicked into hold
			if (sw[i][4] == 32)   //if it is not on hold
				sw[i][0][plane] = 0
				sw[i][1][plane] = 0
				sw[i][2][plane] = 0

				sw[i+1][0][plane] = 0
				sw[i+1][1][plane] = 0
				sw[i+1][2][plane] = 0

				sw[i+2][0][plane] = 0
				sw[i+2][1][plane] = 0
				sw[i+2][2][plane] = 0
	

				sw[i][3][plane] = 0
				sw[i+1][3][plane] = 0
				sw[i+2][3][plane] = 0
				
				// enable edit
				sw[i+1][3][0] = (0x02)
				sw[i+2][3][0] = (0x02)
			elseif ( str2num(source[i][3])==0)   //that means it is on hold and 0
				sw[i][0][plane] = 2
				sw[i][1][plane] = 2
				sw[i][2][plane] = 2

				sw[i+1][0][plane] = 2
				sw[i+1][1][plane] = 2
				sw[i+1][2][plane] = 2

				sw[i+2][0][plane] = 2
				sw[i+2][1][plane] = 2
				sw[i+2][2][plane] = 2

				
				//sw[i][3][plane] = 4
				sw[i+1][3][plane] = 2
				sw[i+2][3][plane] = 2
			
				//  disable edit
				sw[i+1][3][0] = 0
				sw[i+2][3][0] = 0
			
			endif
		endif
	endfor
		
		
	break                                                            //end of section for multiplet
	default:
		DoAlert 0, "Peak type not recognized in static function FancyUp() "
		break
	endswitch
	
	killwaves /z tempWaveAsArray
	//Listbox list0, colorWave=myColors

end




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////Peak Viewer and depending functions
static function CallPeakViewer(ctrlName):ButtonControl
	string ctrlName
	DoWindow PeakViewer//ConstraintTable
	if ( V_Flag )
		DoWindow /F PeakViewer
		return -1
	endif
	PeakViewerFunc()
	//DoWindow /T PeakViewer, "Numerical Results"
end


static function PeakViewerFunc() 
	initializeConstraintTable()
	//PauseUpdate; Silent 1		// building window...
	

		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 0"
		endif
	
	NewPanel /K=1 /N=PeakViewer /W=(25,79,900,404) as "Numerical Results"
	ModifyPanel cbRGB=(65534,65534,65534)
	ListBox NumericList,pos={1.00,2.00},size={870.00,276.00}, listWave=Numerics, fsize=9
	ListBox NumericList,selWave=selNumerics, usercolumnresize = 1
	ListBox NumericList,colorWave=root:STFitAssVar:myColors
	//ListBox NumericList,widths={4,4,4,6,4,6,4,6,4,6,2,6,4,0,0,0}
	ListBox NumericList,widths={3,3,3,4,2,4,2,5,2,7,3,8,3,0,0,0}
	Button PlotBtn,pos={4.00,292.00},size={120.00,22.00},proc=XPSTFA#makeReport,title="Export Report"
	Button PlotBtn,fSize=9,appearance={os9,Win}
	Button PeakParaHelp,pos={125.00,292.00},size={120.00,22.00},proc=XPSTFA#callHelpPeakParameters,title="Explain those parameters"
	Button PeakParaHelp,fSize=9,appearance={os9,Win}

		if (screenResolution == 96)
			execute "SetIgorOption PanelResolution = 1"
		endif
	
	
	fancyUpViewer()
end


static function callHelpPeakParameters(ctrlName):ButtonControl
	string ctrlName
	DisplayHelpTopic "Peak parameters in XPST"

end


static function makeReport(ctrlName):ButtonControl
string ctrlName
//saveFit("foe")
PlotAndSort("void")
end


static function fancyUpViewer()
	string ctrlName
	//wave /t source = Numerics
	wave /t source = STsetup
	wave sw = selNumerics
	wave myColors = root:STFitAssVar:myColors
	SVAR peakType = root:STFitAssVar:PR_PeakType
	//SetDimLabel 1,0,$"Legend",source
	//SetDimLabel 1,1,$"",source
	//SetDimLabel 1,2,$"Fit Results",source
	//ListBox list0, widths={120,30,100,100,40,100,100,60}
	//SetDimLabel 1,3,$"Initial Guess", source
	//SetDimLabel 1,4,$"hold", source
	//SetDimLabel 1,5,$"Lower Limit", source
	//SetDimLabel 1,6,$"Upper Limit", source
	//SetDimLabel 1,7,$"epsilon", source

	string planeName = "backColors"
	variable plane = FindDimLabel(sw,2,planeName)

	Variable nplanes = max(1,Dimsize(sw,2))
	if (plane <0)
		Redimension /N=(-1,-1,nplanes+1) sw
		plane = nplanes
		SetDimLabel 2,nplanes,$planeName sw
	endif


	//now do the color coding
	//these are the basic colors
	sw[][][] = (0x02)
	sw[][][plane] =4  //4th row in the color wave
	//sw[][3][plane] =3
	//sw[][5][plane] =3
	//sw[][6][plane] =3
	//sw[][7][plane] =3


	//now re-colorcode every other peak meaning peak 2, 4, 6, 8, ....
	//first extract the number of peaks
	variable length = DimSize(source,0)
	
	variable numpeaks
	
	variable numCoef         ////////////////////////      number of Coefficients  extMultiplet = 33, Multiplet = 15, Doublet = 9
	variable numSubPeaks     ///////////////////////// number of Subpeaks extMultiplet = 10, Multiplet = 4, Doublet = 2
	
	variable index, i,j,k
	
	strswitch(peakType)
	
	case "DoubletSK":
		numCoef  = 9    
		numSubPeaks = 2 
		numpeaks= (length-5)/ (numCoef)    // 
		for (i=0; i<numpeaks; i += 1)
			index = (4*numSubPeaks)*i             // 
		
			if (mod(i,2) != 0)
				continue
			endif
			for ( j = 0; j < (numSubPeaks*4); j += 1)             // 
				sw[index + j][][plane] =5
			       

			endfor
		endfor
	break
	
	case "MultiSK":
		numCoef  = 15     
		numSubPeaks = 4 
		numpeaks= (length-5)/ (numCoef)    //  
		for (i=0; i<numpeaks; i += 1)
			index = (4*numSubPeaks)*i             //
		
			if (mod(i,2) != 0)
				continue
			endif
			for ( j = 0; j < (numSubPeaks*4); j += 1)             // 
				sw[index + j][][plane] =5
			       

			endfor
		endfor
	break
	
	case "ExtMultiSK":
		numCoef  = 33     
		numSubPeaks = 10  
		numpeaks= (length-5)/ (numCoef)    //  
		for (i=0; i<numpeaks; i += 1)
			index = (4*numSubPeaks)*i             //  
		
			if (mod(i,2) != 0)
				continue
			endif
			for ( j = 0; j < (numSubPeaks*4); j += 1)             // 
				sw[index + j][][plane] =5
			       

			endfor
		endfor
	break
	
	default:
		numCoef  = 6     
		numSubPeaks = 1 
		numpeaks= (length-5)/ 6            //for the regular singlet static function
		for (i=0; i<numpeaks; i += 1)
			index = 4*i                         // 4 rows for each peak in the 'Numerical Results' viewer 
		
			if (mod(i,2) != 0)
				continue
			endif
			
			sw[index][][plane] = 5
			sw[index+1][][plane] = 5
			sw[index+2][][plane] = 5
			sw[index+3][][plane] = 5
		endfor
	break
	endswitch
	


end



static function waves2Setup()
	//that one is actually only concerned with W_Coef
	Wave /t source = STsetup
	wave fitResults = W_Coef
	wave init = InitializeCoef
	variable length = DimSize(source,0)	
	variable i
	for ( i = 0; i < length; i += 1 )
		source[i][2] = MyNum2str(fitResults[i])
		source[i][3] = MyNum2str(init[i])
		if ( i== 2)
			source[i][2] = MyNum2strEH(fitResults[i])
			source[i][3] = MyNum2strEH(init[i])
		endif
		
	endfor
end


static function setup2Waves()

variable i,j
//print length
//variable Summe = 0
string tempStr
variable item

wave /t source= STsetup
wave sw = selSTsetup

variable length = dimsize(source,0)   //0 for rows, 1 for columns

make /d /n=(length) /o hold, W_Coef, InitializeCoef, epsilon
make /t /n=(length) /o Min_Limit, Max_Limit
make /t /n=(2*length) /o T_Constraints

wave hold = hold
wave W_coef = W_Coef
wave init = InitializeCoef
wave eps = epsilon

wave /t allConstraints = T_Constraints
wave /t minLim = Min_Limit
wave /t maxLim = Max_Limit

hold = sw[p][4]

for (i =0; i < length; i += 1)
	if (hold[i] ==32)
		hold[i] = 0
	else
		hold[i] = 1
	endif
endfor

// take the textwaves
minLim = source[p][5]
maxLim=source[p][6]

string kList = ""
string paraList = ""

//generate a list with the k's and with the parameters used in the setup
for ( i = 0; i < length; i += 1 )
	kList +=   "K" + num2str(i) + ";"
	paraList +=  source[i][1] + ";"
endfor
//print kList, paraList

//now exchange all a1,a2, etc with the corresponding K0,K1, etc. make sure to add K0< .... and K0> .... in the output waves

for ( j = 0; j < ItemsInList(kList); j += 1 )
	for ( i = 0; i < length; i += 1 )
		minLim[i] =  ReplaceString(StringFromList(j,paraList) ,minLim[i],StringFromList(j,kList))   //remember, if no substitution is done, ReplaceString just returns the original string
		maxLim[i] =  ReplaceString(StringFromList(j,paraList) ,maxLim[i],StringFromList(j,kList))
	endfor
endfor

for ( j = 0; j < ItemsInList(kList); j += 1 )
		minLim[j] = StringFromList(j,kList) + " > " + minLim[j] + " - 0.0001"
		maxLim[j] = StringFromList(j,kList) + " < " + maxLim[j] +  " + 0.0001"		
endfor
//and now do the numerical waves
for (i =0; i < length; i += 1)
	init[i] = str2num(source[i][3])
	W_Coef[i] = str2num(source[i][2])

	eps[i] = str2num(source[i][7])
endfor

for (i=0; i < numpnts(minLim); i+=1)
	allConstraints[2*i] = minLim[i]
	allConstraints[2*i+1] = maxLim[i]
endfor


end


//Window GetAreaFactors() : Panel
static function DrawGetAreaFactors()
	PauseUpdate; Silent 1		// building window...
	//NewPanel /K=2 /W=(150,77,397,256)

	//Button ConfirmBtn,win=GetAreaFactors,pos={120,137},proc=XPSTFA#CloseGetAreaFactors,size={112,32},title="Use it and Close"
//	SetVariable setUpperFactor,pos={6,99},size={227,16},title="Factor for upper limit:  B ", limits={0.001,100,0}, value = root:STFitAssVar:AreaLinkFactorHigh
//	SetVariable setUpperFactor1,pos={8,69},size={227,16},title="Factor for lower limit:  A ", limits={0.001,100,0}, value = root:STFitAssVar:AreaLinkFactorLow
//	SetDrawLayer UserBack
//	DrawText 21,27,"(peak area)  >  A  x  (area parent peak)"
//	DrawText 20,47,"(peak area)  <  B  x  (area parent peak)"

	NewPanel /K=2 /N=GetAreaFactors /W=(150,77,399,350)
	ModifyPanel cbRGB=(65534,65534,65534)
	SetDrawLayer UserBack
	SetDrawEnv linefgc= (65280,49152,16384),fillfgc= (65280,65280,48896)

	DrawRect 9,179,240,261
	DrawText 21,27,"(peak area)  >  A  x  (area parent peak)"
	DrawText 20,47,"(peak area)  <  B  x  (area parent peak)"

	DrawText 20,214,"For multiplet peaks: This factor"
	DrawText 20,229,"acts on the first subpeaks only!"
	Button ConfirmBtn,pos={122,131},size={112,32},appearance={os9,win},proc=XPSTFA#CloseGetAreaFactors,title="Use it and Close"
	SetVariable setUpperFactor,pos={6,99},size={227,16},title="Factor for upper limit:  B "
	SetVariable setUpperFactor,limits={0.001,100,0},value= root:STFitAssVar:AreaLinkFactorHigh
	SetVariable setUpperFactor1,pos={8,69},size={227,16},title="Factor for lower limit:  A "
	SetVariable setUpperFactor1,limits={0.001,100,0},value= root:STFitAssVar:AreaLinkFactorLow


	DeActivateButtons(0)
end


static function CloseGetAreaFactors(ctrlName):ButtonControl
	string ctrlName
	NVAR areaFactorMin = root:STFitAssVar:AreaLinkFactorLow
	NVAR areaFactorMax = root:STFitAssVar:AreaLinkFactorHigh
	variable temp
	
	//make sure that high and low limits are sound
	temp = areaFactorMin
	areaFactorMin = min(areaFactorMin,areaFactorMax)
	areaFactorMax = max(temp, areaFactorMax)
	
	//now close
	DoWindow /K GetAreaFactors
	ActivateButtons(0)
end

//Window GetOffsetInterval() : Panel
static function drawGetOffsetInterval()
	NewPanel /K=2 /N=GetOffsetInterval /W=(150,77,411,255)
	ModifyPanel cbRGB=(65534,65534,65534)
	Button ConfirmBtn, win=GetOffsetInterval,pos={120,132},size={112,32},proc=XPSTFA#CloseGetOffsetInterval, appearance={os9,win},title="Use it and Close"
	SetVariable setUpperOffset,pos={6,99},size={227,16},title="Upper Limit for Offset:  B ", limits={-100,100,0}, value = root:STFitAssVar:PositionLinkOffsetMax
	SetVariable setLowerOffset,pos={8,69},size={227,16},title="Lower Limit for Offset:  A", limits={-100,100,0}, value = root:STFitAssVar:PositionLinkOffsetMin
	SetDrawLayer UserBack
	DrawText 6,26,"(peak position)  >  (position parent peak) + A"
	DrawText 6,44,"(peak position)  <  (position parent peak) + B"
	DeActivateButtons(0)
	
end


static function CloseGetOffsetInterval(ctrlName):ButtonControl
	string ctrlName
	NVAR offSetMin = root:STFitAssVar:PositionLinkOffsetMin
	NVAR offSetMax = root:STFitAssVar:PositionLinkOffsetMax
	variable temp
	
	//make sure that high and low limits are sound
	temp = offsetMin
	offsetMin = min(offsetMin,offsetMax)
	offsetMax = max(temp, offsetMax)
	
	DoWindow /K GetOffsetInterval
	ActivateButtons(0)
end

static function callHelp(ctrlName):ButtonControl
string ctrlName
DisplayHelpTopic "Generating a stable fit setup"

end

static function checkSetup(ctrlName): ButtonControl
string ctrlName
//this has to be called upon checking or unchecking and editing in [5] and [6]

wave /t source= STsetup
variable i,j,k
variable length = dimsize(source,0)   //0 for rows, 1 for columns
string tempStr
variable item

wave sw = selSTsetup
string matchString

string planeName = "backColors"   //used to be backColors
variable plane = FindDimLabel(sw,2,planeName)
variable nplanes = max(1,Dimsize(sw,2))
variable Errors = 0
string tempString
variable refuseHold

if (plane <0)
	Redimension /N=(-1,-1,nplanes+1) sw
	plane = nplanes
	SetDimLabel 2,nplanes,$planeName sw
endif



for ( i = 0; i < length; i += 1)
	if (sw[i][4] == 48)   //this parameter is set to be constant does it show up anywhere else?
		matchString = "*" + source[i][1] +"*"


		for (j=0; j < length; j += 1)
			tempString =source[j][5]
			refuseHold = StringMatch(tempString,matchString)
			if (refuseHold != 0 && sw[j][4] == 32)
				Errors += 1
				sw[j][5][plane] =1
			endif
			tempString =source[j][6]
			refuseHold = StringMatch(tempString,matchString)
			if (refuseHold != 0 && sw[j][4] == 32)
				Errors += 1
				sw[j][6][plane] =1	
			endif
		endfor
	endif	
endfor

		if (Errors != 0)
			tempString = "\rNo parameter which is on hold is allowed to show up as active in 'Lower Limit' or 'Upper Limit'. Remove it from the limits or freeze the depending parameter too."
			Doalert 0, tempString
			
		else
			tempString = "\rThe logic between hold and constraints seems to be fine. \r\rMake sure all your initial conditions are consistent with the constraints.\rNote: Use constraints only 'backwards':\r\r a4 =>2*a2   is   GOOD    ..... a2 =>0.5*a4  is  BAD."
			//DoAlert 0, tempString 
			FancyUp("foe")
		endif
end


static function ActivateButtons(set)
	variable set    // 0, 1, 2. ... do define which buttons are to be switched on
	
	if ( set == 0)
	Button LoadNewBtn,  win=CursorPanel, disable= 0			 //title="  New Fit Project  >>"
	Button ImportFitBut,  win=CursorPanel, disable= 0			//title="Import Fit Project    >>"
	Button OpenProjectBtn,  win=CursorPanel, disable= 0		//title="Open Fit Project"
	Button ReportViewerBtn, win=CursorPanel, disable= 0		//title="View Numeric Results"
	Button FinePlotBtn, win=CursorPanel, disable=0 	 			//title="Permanent Plot (saves last)"
	Button addBut, win=CursorPanel, disable=0 					//title=" Add Peak   >>"
	Button DeleteBut, win=CursorPanel, disable=0				//title=" Delete Peak  <<"
	Button CleanBut, win=CursorPanel, disable=0				 //title="Save"
	Button SaveAsBut, win=CursorPanel, disable=0				 //title="Save As"
	Button closeBut, win=CursorPanel, disable=0					//title="Close"
	Button ExportFitBut, win=CursorPanel, disable=0				//title="Export Fit Project"
	Button resetBut, win=CursorPanel, disable=0  				//title="Save as Template "
	Button UpDateBut, win=CursorPanel, disable=0				//title="Show Initial Values"
	Button ConstraintBut, win=CursorPanel, disable=0			//title="Peak Editor"
	Button UpDateButFin, win=CursorPanel, disable=0			//title="Show Final Values"
	Button FitBut, win=CursorPanel, disable=0					//title="Start Fit"
	Button ReUseBut, win=CursorPanel, disable=0				//title="Result ---> Initial"
	Button restorBut, win=CursorPanel, disable=0				//title="Recover last Saved"
	CheckBox RecordCheck,win=CursorPanel, disable = 0 
	CheckBox RobustCheck,win=CursorPanel, disable = 0 
	//CheckBox SuppressCheck,win=CursorPanel, disable = 0 
	CheckBox check0, win=CursorPanel, disable = 0				//,title="Area"
	CheckBox check1, win=CursorPanel, disable = 0
	CheckBox check2, win=CursorPanel, disable = 0
	CheckBox check3, win=CursorPanel, disable =0
	CheckBox check4, win=CursorPanel, disable =0
	CheckBox check5, win=CursorPanel, disable = 0
	CheckBox check6, win=CursorPanel, disable = 0
	//CheckBox InitCheck, win=CursorPanel, disable =0
	TabControl OptionsTab, win = CursorPanel, disable = 0
	
	
	
	
	elseif (set == 1)
	Button LoadNewBtn,  win=CursorPanel, disable= 0			 //title="  New Fit Project  >>"
	Button ImportFitBut,  win=CursorPanel, disable= 0			//title="Import Fit Project    >>"
	Button OpenProjectBtn,  win=CursorPanel, disable= 0	
	Button closeBut, win=CursorPanel, disable=0					//title="Close"
	endif
	
end


static function DeActivateButtons(set)
	variable set   // 0, 1, 2. ... do define which buttons are to be switched off
	
	if ( set == 0)   //all of them
	Button LoadNewBtn,  win=CursorPanel, disable= 2			 //title="  New Fit Project  >>"
	Button ImportFitBut,  win=CursorPanel, disable=2			//title="Import Fit Project    >>"
	Button OpenProjectBtn,  win=CursorPanel, disable=2		//title="Open Fit Project"
	Button ReportViewerBtn, win=CursorPanel, disable= 2		//title="View Numeric Results"
	Button FinePlotBtn, win=CursorPanel, disable=2 	 			//title="Permanent Plot (saves last)"
	Button addBut, win=CursorPanel, disable=2 					//title=" Add Peak   >>"
	Button DeleteBut, win=CursorPanel, disable=2				//title=" Delete Peak  <<"
	Button CleanBut, win=CursorPanel, disable=2				 //title="Save"
	Button SaveAsBut, win=CursorPanel, disable=2				 //title="Save As"
	Button closeBut, win=CursorPanel, disable=2					//title="Close"
	Button ExportFitBut, win=CursorPanel, disable=2				//title="Export Fit Project"
	Button resetBut, win=CursorPanel, disable=2  				//title="Save as Template "
	Button UpDateBut, win=CursorPanel, disable=2				//title="Show Initial Values"
	Button ConstraintBut, win=CursorPanel, disable=2			//title="Peak Editor"
	Button UpDateButFin, win=CursorPanel, disable=2			//title="Show Final Values"
	Button FitBut, win=CursorPanel, disable=2					//title="Start Fit"
	Button ReUseBut, win=CursorPanel, disable=2				//title="Result ---> Initial"
	Button restorBut, win=CursorPanel, disable=2				//title="Recover last Saved"
					
	CheckBox RecordCheck,win=CursorPanel, disable = 2 
	CheckBox RobustCheck,win=CursorPanel, disable = 2 
	//CheckBox SuppressCheck,win=CursorPanel, disable = 2 
	CheckBox check0, win=CursorPanel, disable = 2				//,title="Area"
	CheckBox check1, win=CursorPanel, disable = 2 
	CheckBox check2, win=CursorPanel, disable = 2 
	CheckBox check3, win=CursorPanel, disable = 2 
	CheckBox check4, win=CursorPanel, disable = 2 
	CheckBox check5, win=CursorPanel, disable = 2 
	CheckBox check6, win=CursorPanel, disable = 2 
	//CheckBox InitCheck, win=CursorPanel, disable = 2 
	
	TabControl OptionsTab, win = CursorPanel, disable = 2
	
	elseif (set == 1)
	Button ReportViewerBtn, win=CursorPanel, disable= 2		//title="View Numeric Results"
	Button FinePlotBtn, win=CursorPanel, disable=2	 			//title="Permanent Plot (saves last)"
	Button addBut, win=CursorPanel, disable=2 					//title=" Add Peak   >>"
	Button DeleteBut, win=CursorPanel, disable=2				//title=" Delete Peak  <<"
	Button CleanBut, win=CursorPanel, disable=2				 //title="Save"
	Button SaveAsBut, win=CursorPanel, disable=2				 //title="Save As"
	Button closeBut, win=CursorPanel, disable=0					//title="Close"
	Button ExportFitBut, win=CursorPanel, disable=2			//title="Export Fit Project"
	Button resetBut, win=CursorPanel, disable=2 				//title="Save as Template "
	Button UpDateBut, win=CursorPanel, disable=2				//title="Show Initial Values"
	Button ConstraintBut, win=CursorPanel, disable=2			//title="Peak Editor"
	Button UpDateButFin, win=CursorPanel, disable=2			//title="Show Final Values"
	Button FitBut, win=CursorPanel, disable=2					//title="Start Fit"
	Button ReUseBut, win=CursorPanel, disable=2				//title="Result ---> Initial"
	Button restorBut, win=CursorPanel, disable=2			
		
	CheckBox RecordCheck,win=CursorPanel, disable = 2 
	CheckBox RobustCheck,win=CursorPanel, disable = 2 
//	CheckBox SuppressCheck,win=CursorPanel, disable = 2 
	CheckBox check0, win=CursorPanel, disable = 2				//,title="Area"
	CheckBox check1, win=CursorPanel, disable = 2 
	CheckBox check2, win=CursorPanel, disable = 2 
	CheckBox check3, win=CursorPanel, disable = 2 
	CheckBox check4, win=CursorPanel, disable = 2 
	CheckBox check5, win=CursorPanel, disable = 2 
	CheckBox check6, win=CursorPanel, disable = 2 
	//CheckBox InitCheck, win=CursorPanel, disable = 2 
	
	TabControl OptionsTab, win = CursorPanel, disable = 2
	
	endif
end



static function launchCurveFit(ctrlName): ButtonControl
	string ctrlName
	CheckLocation()
	setup2waves()
	
	
	//////////////////////////////////////////////////////////////////
	//	Make references to global objects
	NVAR toleranceLocal = V_FitTol
	NVAR toleranceGlobal = root:STFitAssVar:V_FitTol
	toleranceLocal = toleranceGlobal
	NVAR savedLast = root:STFitAssVar:savedLast
	savedLast = 0 //this change has not been saved yet

	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	NVAR FitMin = root:STFitAssVar:STFitMin
	NVAR FitMax = root:STFitAssVar:STFitMax
	NVAR epsilonFactor = root:STFitAssVar:EpsilonFactor
	NVAR reported = root:STFitAssVar:WrongReported 
	reported = 0
	variable FitMinIndex

	variable FitMaxIndex
	Wave RawY = $RawYWave
	
	Wave  holdRef = hold
	Wave /t T_Constraints = T_Constraints
	Wave /t Min_Limit = Min_Limit
	Wave /t Max_Limit = Max_Limit
	if ( numpnts(hold) == 0 )
		DoAlert 0, "You have to add peaks before you can do a fit."
		return -1
	endif
	
	
	
	//////////////////////////////////////////////////////////
	//	Make auxiliary global objects
	duplicate /o T_Constraints $"EffectiveConstraints"
	Wave /t ConstRef = $"EffectiveConstraints"
	Variable /G V_FitError = 0
	Variable /G V_chisq
	
	////////////////////////////////
	//	Local objects
	variable timerRefNum
	variable microSeconds
	variable index,constraintIndex,k, i
	variable nPeaks
	variable numPntsOutput = 600
	variable normFac = area(RawY)
	variable numCoef = 6 // Voigt as default
	
	string HoldString = ""
	string DestWave = "fit_" + RawYWave                 //keeps the name of the fit-result wave like "fit_Au4f_sample", wave is automatically generated by FitFunc command
	string ResidWave = "Res_" + RawYWave
	string functionType
	string CheckFitString 			//this string is proceeded via the command "execute" to set up the fit, but don't do anything numerical -> check for 'syntax' errors
	string FitString				//this string is proceeded via the command "execute" to perform the fitting
	//the following variables are needed to implement the temporarily normalization of the intensity constraints
	string FirstPartMin				//hold the text part of a constraints statement
	string FirstPartMax
	string LastPartMin				//hold the numerical part of a constraints statement  
	string LastPartMax
	string NormalizedLowLimit		//hold the constraint statement after normalization
	string NormalizedHighLimit
	variable NumLowLimit
	variable NumHighLimit
	variable operatorPos			//hold the position of > or < in a string
	
	variable BackgroundType = 0     //0: no background, 1: Line-Shirley, 2 ....
	
	///////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: Is the wave name too long?
	if ( strlen(RawYWave) >= 26)		  //26 characters would be okay, but there are names generated form this string, and those get possibly too long
		doalert 0, "The name of the fit-wave is too long! Please shorten the names."
		return 1
	endif
	
	print "\r---------------------------------------------------------------          XPST macro package\rStart curve fit.\r"
	
	/////////////////////////////////////////////////////////////////////
	//	Update the graphical user interface
	// Button CleanBut, win= CursorPanel, disable =0
	// Button ReUseBut, win= CursorPanel,  disable = 0
	//CheckBox CleanCheck disable = 0
	SetActiveSubwindow CursorPanel#GuiCursorDisplay
	upDateFitDisplay("void")    //refresh the display, since this static function is usually a button control, give an artificial Buttonname i.e. "void"
	updateResidualDisplay("void")
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Overwrite the old W_coef, so the entire thing starts from the initial conditions
	wave InitializeCoef = InitializeCoef
	killwaves /z W_coef
	duplicate /o InitializeCoef W_coef    //InitializeCoef contains the coefficients which were set, by pressing the add button
	
	
	///////////////////////////////////////////////////////////////////////////////////////////////////
	//	Get the number of peaks and define the static function type
	strswitch(peakType)
	case "SingletSK":
		numCoef = 6
		nPeaks = (numpnts(W_coef )- 5)/numCoef
		functionType = "FitMultiVoigtSK"
		BackgroundType = 2
		break
	case "DoubletSK":
		numCoef = 9   //
		nPeaks = (numpnts(W_coef )- 5)/numCoef
		functionType = "FitDoubletVoigtSK"
		BackgroundType = 2
		break
	case "MultiSK":
		numCoef = 15   //
		nPeaks = (numpnts(W_coef )- 5)/numCoef
		functionType = "FitMultipletVoigtSK"
		BackgroundType = 2
		break
	case "ExtMultiSK":
		numCoef = 33   //
		nPeaks = (numpnts(W_coef )- 5)/numCoef
		functionType = "FitExtMultipletVoigtSK"
		BackgroundType = 2
		break
	default:
		DoAlert 0, "Error in the static function launchCurveFit() in the strswitch(peakType) construction."
		return 1
	endswitch
	
	//////////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: No peaks given? if yes, exit
	if (nPeaks == 0)
		FitAbort()
		DoAlert 0, "There are no peaks .... "        
		return 1
	endif
	
	//////////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: Are the values for the upper and lower limits ok?
	FitMin = min(FitMin,FitMax)
	FitMax = max(FitMin,FitMax)   //take care if the user mixed up the upper and lower limits
	
	strswitch(RawXWave)
		case "":
			
			break
		case "_calculated_":
			
			break
		default:
			wave rawX = $RawXWave
			if (FitMin < min(rawX[0],rawX[numpnts(rawX)-1]))
				FitMin = min(rawX[0],rawX[numpnts(rawX)-1])
			endif
			if (FitMax > max(rawX[0],rawX[numpnts(rawX)-1]))
				FitMax = max(rawX[0],rawX[numpnts(rawX)-1])
			endif
			
			break
	endswitch
	
	
	

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: Faulty logical constraints with + and - in the area coefficient ... this would possibly conflict with the normalization later on
	//for ( i = 0; i < npeaks; i += 1)
		//figure out, whether the constraints to the area coefficient are numerical or logical, if it is logical then continue with the next area coefficient
	//	if ( ( countStringItems(Min_Limit[numCoef * i],"k") > 1 && countStringItems(Min_Limit[numCoef * i],"+") != 0 ) || ( countStringItems(Min_Limit[numCoef * i],"k") > 1 && countStringItems(Max_Limit[numCoef * i],"+") != 0 ) )         //countStringItems( ) is implemented in MiscFUNC.ipf
	//		DoAlert 0, "You constrained one or more of the area coefficients by using + or -.\rThis is not valid, use multiplication or division instead!"
	//		FitAbort()
	//		return 1
	//	endif
	//	if ( ( countStringItems(Min_Limit[numCoef * i],"k") > 1 && countStringItems(Min_Limit[numCoef * i],"-") != 0 ) || ( countStringItems(Min_Limit[numCoef * i],"k") > 1 && countStringItems(Max_Limit[numCoef * i],"-") != 0 ) )         //countStringItems( ) is implemented in MiscFUNC.ipf
	//		DoAlert 0, "You constrained one or more of the area coefficients by using + or -.\rThis is not valid, use multiplication or division instead!"
	//		FitAbort()
	//		return 1
	//	endif
	//endfor
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: Is the lower and upper limit of the area compatible with the normalization
	//		the number of k's tells, if the constraint is a logical one, like k6 > 0.5*k0 or a numerical one k6> 10
	//		if it is a numerical one, then split it into the part "k6 >" and the number
	//		normalize the number and rejoin it to "k6 > normalized number "
	//
	//     first check if there are any brackets
	for ( i = 0; i < npeaks; i += 1)
		if (MyGrepString(Min_Limit[numCoef*i],"[;(;);{;};]") == 1 || MyGrepString(Max_Limit[numCoef*i],"[;(;);{;};]" ) == 1 )
			DoAlert 0, "Do not use ( ) or [ ] in the constraints wave"
			FitAbort()
			return 1
		endif
	endfor
	//if not, go on ....
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	NUMERICAL IMPROVEMENT: Normalize the raw data and the intensity initial values for the fit
	//    do the normalization also for the constraints
	
	for ( i = 0; i < nPeaks; i += 1)
		if (BackgroundType == 0)
			W_coef[numCoef*i] /= normFac
			
			Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,0)
			Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,0)
			
		elseif (BackgroundType == 1)
			if (i==0)   //the first peak also has the background attached  // the following lines could be condensed in a for - loop
					// but they are kept like that for clarity
				W_coef[numCoef*i] /= normFac
				W_coef[numCoef*i+1] /= normFac
				W_coef[numCoef*i+2] /= normFac
				W_coef[numCoef*i+3] /= normFac
				Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,0)
				Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,0)
				Min_Limit[numCoef*i+1] = NormAndDeNormConstraints(Min_Limit[numCoef*i+1],normFac,0)
				Max_Limit[numCoef*i+1] = NormAndDeNormConstraints(Max_Limit[numCoef*i+1],normFac,0)
				Min_Limit[numCoef*i+2] = NormAndDeNormConstraints(Min_Limit[numCoef*i+2],normFac,0)
				Max_Limit[numCoef*i+2] = NormAndDeNormConstraints(Max_Limit[numCoef*i+2],normFac,0)
				Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,0) //this is the first peak amplitude
				Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,0) 
			else 
				W_coef[numCoef*i+3] /= normFac
				Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,0)
				Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,0)
			endif
		elseif (BackgroundType == 2)
			if (i==0)   //the first peak also has the background attached  // the following lines could be condensed in a for - loop
					// but they are kept like that for clarity
				W_coef[numCoef*i] /= normFac //offset
				W_coef[numCoef*i+1] /= normFac //slope
				W_coef[numCoef*i+2] /= normFac //parabola
				W_coef[numCoef*i+3] /= normFac //pseudo-tougaard
				W_coef[numCoef*i+4] /= normFac //shirley
				W_coef[numCoef*i+5] /= normFac //amplitude
				Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,0)
				Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,0)
				Min_Limit[numCoef*i+1] = NormAndDeNormConstraints(Min_Limit[numCoef*i+1],normFac,0)
				Max_Limit[numCoef*i+1] = NormAndDeNormConstraints(Max_Limit[numCoef*i+1],normFac,0)
				Min_Limit[numCoef*i+2] = NormAndDeNormConstraints(Min_Limit[numCoef*i+2],normFac,0)
				Max_Limit[numCoef*i+2] = NormAndDeNormConstraints(Max_Limit[numCoef*i+2],normFac,0)
				Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,0)
				Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,0)
				Min_Limit[numCoef*i+4] = NormAndDeNormConstraints(Min_Limit[numCoef*i+4],normFac,0)
				Max_Limit[numCoef*i+4] = NormAndDeNormConstraints(Max_Limit[numCoef*i+4],normFac,0) 
				Min_Limit[numCoef*i+5] = NormAndDeNormConstraints(Min_Limit[numCoef*i+5],normFac,0)
				Max_Limit[numCoef*i+5] = NormAndDeNormConstraints(Max_Limit[numCoef*i+5],normFac,0) 
			else 
				W_coef[numCoef*i+5] /= normFac
				Min_Limit[numCoef*i+5] = NormAndDeNormConstraints(Min_Limit[numCoef*i+5],normFac,0)
				Max_Limit[numCoef*i+5] = NormAndDeNormConstraints(Max_Limit[numCoef*i+5],normFac,0)
			endif
		
		
		endif 
	endfor
	RawY /= normFac
	
	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Generate the contents of the constraints wave  T_Constraints
	for (i=0; i <  numpnts(Min_Limit); i+=1)
		T_Constraints[2*i] = Min_Limit[i]
		print Min_Limit[i]
		print Max_Limit[i]
		T_Constraints[2*i+1] = Max_Limit[i]
	endfor

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Create a HoldString and create an effective constraints wave (parameters that are set to be constant are omitted in that wave)
	constraintIndex = -2
	k = 0
	for (index = 0; index < numpnts(holdRef); index += 1)
		HoldString +=num2istr(holdRef[index])
		constraintIndex += 2       								 //index der effectiveConstraints
		k = 2*index                           							 //Index von T_constraints
		if ( holdRef[index] == 0 )
			ConstRef[constraintIndex] = T_Constraints[k]
			ConstRef[constraintIndex+1] = T_Constraints[k+1]
		elseif (holdRef[index] != 1 && holdRef[index] != 0)
			DoAlert 0, "Something is wrong with the 'hold' wave! Only 0 and 1 are valid entries."
			FitAbort()
			return 1
		else
			constraintIndex -= 2
		endif
	endfor
	redimension /n=(constraintIndex+2) ConstRef				//ConstRef is a link to the auxiliary wave "EffectiveConstraints" which is used during fitting
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: Was a reasonable background subtracted?
	WaveStats /Q RawY //needed later on, so do not uncomment
	//if ( RawY[0] > noiseThreshold*V_max && RawY[numpnts(RawY)-1] > noiseThreshold*V_max)
	//	DoAlert 0, "The spectrum seems to have a significant offset. This will very likely cause an error! Subtract a better background."
	//endif
	

	
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: Make an epsilon wave in case there is none
	if (! exists("epsilon") )
		duplicate /o W_coef epsilon
		wave epsilon = epsilon
		epsilon = 1e-9
	endif
	
	epsilon *=epsilonFactor
	
	if (exists(ResidWave) )
		wave Residual = $ResidWave
		Residual *= 0
	
	endif

	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	CHECK POINT: Set up the fit, but do nothing numerical, done by flag "/O". This will catch non-numerical errors
	strswitch(RawXWave)
		case "":
			sprintf CheckFitString, "FuncFit  /O /Q /NTHR=0 /H=\"%s\"  /Q  %s W_coef  '%s' /D /C=EffectiveConstraints  /E=epsilon", HoldString, functionType, RawYWave
			break
		case "_calculated_":
			sprintf CheckFitString, "FuncFit  /O /Q  /NTHR=0 /H=\"%s\"  /Q  %s W_coef  '%s' /D /C=EffectiveConstraints  /E=epsilon", HoldString, functionType, RawYWave
			break
		default:
			sprintf CheckFitString, "FuncFit /O /Q /NTHR=0 /H=\"%s\" /Q %s W_coef  '%s' /X='%s' /D /C=EffectiveConstraints  /E=epsilon", HoldString, functionType, RawYWave, RawXWave
			break
	endswitch
	Execute CheckFitString
	if (V_FitError ==1)
		DoAlert 0, "Non-numerical error: There is something wrong in the fit setup.\rCheck constraints and hold wave!\rA parameter that is set to be constant in the hold wave MUST NOT appear anywhere else in the constraints wave!"
		
		///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//////        THERE IS A PROBLEM   >    DENORMALIZE   EVERYTHING   BEFORE   CONTINUING
		//////
		
		RawY *= normFac             	 //the raw wave is de -normalized
		
		for ( i = 0; i < nPeaks; i += 1)
			if (BackgroundType == 0)
				W_coef[numCoef*i] *= normFac
				Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,1)
				Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,1)
			elseif (BackgroundType == 1)
				if (i==0) //first peak + background
					W_coef[numCoef*i] *= normFac
					W_coef[numCoef*i+1] *= normFac
					W_coef[numCoef*i+2] *= normFac
					W_coef[numCoef*i+3] *= normFac
				
					Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,1)
					Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,1)
					Min_Limit[numCoef*i+1] = NormAndDeNormConstraints(Min_Limit[numCoef*i+1],normFac,1)
					Max_Limit[numCoef*i+1] = NormAndDeNormConstraints(Max_Limit[numCoef*i+1],normFac,1)
					Min_Limit[numCoef*i+2] = NormAndDeNormConstraints(Min_Limit[numCoef*i+2],normFac,1)
					Max_Limit[numCoef*i+2] = NormAndDeNormConstraints(Max_Limit[numCoef*i+2],normFac,1)
					Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,1) 
					Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,1) 

				else
					W_coef[numCoef*i+3] *= normFac
					Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,1)
					Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,1)
				endif
				elseif (BackgroundType == 2)
				if (i==0) //first peak + background
					W_coef[numCoef*i] *= normFac
					W_coef[numCoef*i+1] *= normFac
					W_coef[numCoef*i+2] *= normFac
					W_coef[numCoef*i+3] *= normFac
					W_coef[numCoef*i+4] *= normFac
					W_coef[numCoef*i+5] *= normFac
					
					Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,1)
					Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,1)
					Min_Limit[numCoef*i+1] = NormAndDeNormConstraints(Min_Limit[numCoef*i+1],normFac,1)
					Max_Limit[numCoef*i+1] = NormAndDeNormConstraints(Max_Limit[numCoef*i+1],normFac,1)
					Min_Limit[numCoef*i+2] = NormAndDeNormConstraints(Min_Limit[numCoef*i+2],normFac,1)
					Max_Limit[numCoef*i+2] = NormAndDeNormConstraints(Max_Limit[numCoef*i+2],normFac,1)
					Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,1) 
					Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,1) 
					Min_Limit[numCoef*i+4] = NormAndDeNormConstraints(Min_Limit[numCoef*i+4],normFac,1) //this is the first peak amplitude
					Max_Limit[numCoef*i+4] = NormAndDeNormConstraints(Max_Limit[numCoef*i+4],normFac,1) 
					Min_Limit[numCoef*i+5] = NormAndDeNormConstraints(Min_Limit[numCoef*i+5],normFac,1) //this is the first peak amplitude
					Max_Limit[numCoef*i+5] = NormAndDeNormConstraints(Max_Limit[numCoef*i+5],normFac,1) 

				else
					W_coef[numCoef*i+5] *= normFac
					Min_Limit[numCoef*i+5] = NormAndDeNormConstraints(Min_Limit[numCoef*i+5],normFac,1)
					Max_Limit[numCoef*i+5] = NormAndDeNormConstraints(Max_Limit[numCoef*i+5],normFac,1)
				endif
			endif 	
		endfor
		
		//	Generate the de-normalized contents of the constraints wave  T_Constraints
		for (i=0; i < numpnts(Min_Limit); i+=1)
			T_Constraints[2*i] = Min_Limit[i]
			T_Constraints[2*i+1] = Max_Limit[i]
		endfor
		
		FitAbort()
		return 1   					//leave, if something was wrong
	endif


	timerRefNum = startMSTimer

	///////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////			NOW   DO   THE   REAL   FIT	
	////////

	strswitch(RawXWave)
		case "":
			sprintf FitString, "FuncFit /L=%d /H=\"%s\"  %s W_coef  '%s'(%f,%f) /D /C=EffectiveConstraints  /E=epsilon /A=0 /R ",numPntsOutput, HoldString, functionType, RawYWave, FitMin, FitMax
			//print FitString
			break
		case "_calculated_":
			sprintf FitString, "FuncFit  /L=%d /H=\"%s\"  %s W_coef  '%s'(%f,%f)  /D /C=EffectiveConstraints  /E=epsilon /A=0 /A=0 /R", numPntsOutput,HoldString, functionType, RawYWave, FitMin, FitMax
			//print FitString
			break
		default:
			//find the indices of the min and max
			
				FitMinIndex= max( 0,  ceil(  (     (  FitMin-WaveMin(rawX)  ) / ( WaveMax(rawX) -WaveMin(rawX)  )  )      *numpnts(rawX) )  )
				FitMaxIndex= min(numpnts(rawX)-1, numpnts(rawX) -1 - floor( (    (  WaveMax(rawX) -FitMax )  / ( WaveMax(rawX) -WaveMin(rawX)  ) )      *numpnts(rawX) )  )
			
			// Check if wave is descending. If yes, take care of the intervals
		
			if (abs(rawX[2]) < abs(rawX[0]))
				FitMinIndex= max( 0, numpnts(rawX) -1 - ceil(  (     (  FitMin-WaveMin(rawX)  ) / ( WaveMax(rawX) -WaveMin(rawX)  )  )      *numpnts(rawX) )  )
				FitMaxIndex= min(numpnts(rawX)-1,  floor( (    (  WaveMax(rawX) -FitMax )  / ( WaveMax(rawX) -WaveMin(rawX)  ) )      *numpnts(rawX) )  )
				
			endif
		
			
			sprintf FitString, "FuncFit /Q /L=%d /H=\"%s\"  %s W_coef  '%s'[%d,%d] /X='%s'[%d,%d]  /D /C=EffectiveConstraints  /E=epsilon /A=0 /R",numPntsOutput, HoldString, functionType, RawYWave,  FitMinIndex, FitMaxIndex, RawXWave, FitMinIndex, FitMaxIndex
	
			
			break
	endswitch

	
	Execute FitString
		
	microSeconds = stopMSTimer(timerRefNum)
	Print microSeconds/1e6, "seconds for the fit to finish"

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////						DENORMALIZE    AFTER    EVERYTHING    IS   DONE
	///////////
	
	RawY *= normFac							//the raw wave is de -normalized
	
	//	If residual exists, upscale it too
	if (exists(ResidWave) )
		wave Residual = $ResidWave
		Residual *= normFac
	//	SetAxis/A /W=CursorPanel#guiCursorDisplay Res_Left
	endif
	
	Wave OutputWave = $DestWave				//the fit_wave was generated by Igor, simply make a reference to it
	OutputWave *= normFac   						//de-normalize the fit_wave
	
	for ( i = 0; i < nPeaks; i += 1)
		if (BackgroundType == 0)
			W_coef[numCoef*i] *= normFac
			Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,1)
			Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,1)
		elseif (BackgroundType == 1)
			if (i==0)   //specific for line-shirley background
				W_coef[numCoef*i] *= normFac
				W_coef[numCoef*i+1] *= normFac
				W_coef[numCoef*i+2] *= normFac
				W_coef[numCoef*i+3] *= normFac			
				Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,1)
				Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,1)
				Min_Limit[numCoef*i+1] = NormAndDeNormConstraints(Min_Limit[numCoef*i+1],normFac,1)
				Max_Limit[numCoef*i+1] = NormAndDeNormConstraints(Max_Limit[numCoef*i+1],normFac,1)
				Min_Limit[numCoef*i+2] = NormAndDeNormConstraints(Min_Limit[numCoef*i+2],normFac,1)
				Max_Limit[numCoef*i+2] = NormAndDeNormConstraints(Max_Limit[numCoef*i+2],normFac,1)

				Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,1) //this is the first peak amplitude
				Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,1) 
			else
				W_coef[numCoef*i+3] *= normFac
				Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,1)
				Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,1)
			endif
		elseif (BackgroundType == 2)
			if (i==0)   //specific for line-shirley background
				W_coef[numCoef*i] *= normFac
				W_coef[numCoef*i+1] *= normFac
				W_coef[numCoef*i+2] *= normFac
				W_coef[numCoef*i+3] *= normFac
				W_coef[numCoef*i+4] *= normFac
				W_coef[numCoef*i+5] *= normFac
				
				Min_Limit[numCoef*i] = NormAndDeNormConstraints(Min_Limit[numCoef*i],normFac,1)
				Max_Limit[numCoef*i] = NormAndDeNormConstraints(Max_Limit[numCoef*i],normFac,1)
				Min_Limit[numCoef*i+1] = NormAndDeNormConstraints(Min_Limit[numCoef*i+1],normFac,1)
				Max_Limit[numCoef*i+1] = NormAndDeNormConstraints(Max_Limit[numCoef*i+1],normFac,1)
				Min_Limit[numCoef*i+2] = NormAndDeNormConstraints(Min_Limit[numCoef*i+2],normFac,1)
				Max_Limit[numCoef*i+2] = NormAndDeNormConstraints(Max_Limit[numCoef*i+2],normFac,1)
				Min_Limit[numCoef*i+3] = NormAndDeNormConstraints(Min_Limit[numCoef*i+3],normFac,1) 
				Max_Limit[numCoef*i+3] = NormAndDeNormConstraints(Max_Limit[numCoef*i+3],normFac,1)
				Min_Limit[numCoef*i+4] = NormAndDeNormConstraints(Min_Limit[numCoef*i+4],normFac,1) //this is the first peak amplitude
				Max_Limit[numCoef*i+4] = NormAndDeNormConstraints(Max_Limit[numCoef*i+4],normFac,1) 
				Min_Limit[numCoef*i+5] = NormAndDeNormConstraints(Min_Limit[numCoef*i+5],normFac,1) //this is the first peak amplitude
				Max_Limit[numCoef*i+5] = NormAndDeNormConstraints(Max_Limit[numCoef*i+5],normFac,1) 
			else
				W_coef[numCoef*i+5] *= normFac
				Min_Limit[numCoef*i+5] = NormAndDeNormConstraints(Min_Limit[numCoef*i+5],normFac,1)
				Max_Limit[numCoef*i+5] = NormAndDeNormConstraints(Max_Limit[numCoef*i+5],normFac,1)
				
			endif
		endif 	
	endfor
		
	
	
	//	Generate the de-normalized contents of the constraints wave  T_Constraints
	for (i=0; i < numpnts(Min_Limit); i+=1)
		T_Constraints[2*i] = Min_Limit[i]
		T_Constraints[2*i+1] = Max_Limit[i]
	endfor
	
	
	////////////////////////////////////////////////////////
	//	Notify the user about errors
	if (V_FitError != 0)
		if (V_FitError ==1)
			printf "Fit failed ..... Reason: Singular Matrix\r"
			printf "If the fit reported on missing dependencies on some parameters: Open the peak editor (button: 'Edit') and increase the corresponding 'Iteration Step' values."
		elseif (V_FitError == 2)
			printf "Fit failed ..... Reason: Out of Memory\r"
		elseif (V_FitError ==3)
			print "\rFit failed .... The fit static function returned NaN of Inf.CHECK constraints and hold waves, or retry in robust mode.\r"
			//DoAlert 0, "The fit static function returned NaN or Inf. CHECK constraints and hold waves, or retry in robust mode."
		endif
	else
		print "\rDone ...  "
	endif
	
	if (V_chisq/V_npnts > 0.001 || V_FitError == 3)
		DoAlert 0, "There was something not quite right with the fit."
	//	print "\rUnusual high Chi-square value or crash of the fit\r--------------------------------------------------------------"
	//	print "\rThis can have one of the following numerical reasons:\r"
	//	print "         - noisy data\r"
	//	print "         - bad background subtraction\r"
	//	print "         - to few or far too many peaks -> no unique solution possible\r"
	//	print "\rConflicts due to bad constraints:\r"
	//	print "         - you mixed up the values of upper and lower limits, at least for one coefficient. E.g. K1 < 5  and K1 > 10\r"
	//	print "         - typo somewhere in the waves for upper and lower limit\r"
	//	print "         - you forward-referenced a peak:\t K0 = 0.5 * K6     THIS IS UNSTABLE\r"
	//	print "            INSTEAD:   K6 = 2 * K0\r"
	//	print "         - initial values outside the constraints regions\r"
	//	print "\rSee the Technical remarks above (scroll upwards in this window) for more information."
	
	endif
	
	/////////////////////////////
	//	Delete remains
	killwaves /z EffectiveConstraints, bgyw
	killvariables  V_FitError, V_chisq
	// now, do the aftermath
	//Display the fit results
	SinglePeakDisplay(peakType, RawYWave, RawXWave, coefWave)
	//copy the fit results into the setup wave
	waves2setup()
	
	
	
	// now extract the peaks from the FitTemp folder
	if (V_chisq/V_npnts < 0.001 && V_FitError == 0)
		PullOutPeaksFromFitTemp( )
		AnalyzeWCoefAfterFit()
	endif
	
	epsilon /= epsilonFactor
	print "\r---------------------------------------------------------------\r"
	updateFitDisplayFinalVal("fromFit")
	updateResidualDisplay(RawYWave)
end


static function PullOutPeaksFromFitTemp()
	//later on, this static function also serves to split doublet/multiplet peaks into single peaks
	string wavesInFitTemp
	variable i
	string parentFolder = GetDataFolder(1)
//	print parentFolder

	string item = ""
	SetDataFolder :FitTemp:
	wavesInFitTemp = WaveList("*",";","DIMS:1") //only get the one-dimensional ones
	SetDataFolder $parentFolder //go back after you made the list

	//first, make a duplicate of those waves to the main folder
	for ( i = 0; i < ItemsInList(wavesInFitTemp); i += 1 )
		item = StringFromList(i,wavesInFitTemp)
		duplicate /o :FitTemp:$item $item
	endfor
end


static function AnalyzeWCoefAfterFit()
//this static function needs to know the peak-type later on .... for now it is only PVSK (Pseudo-Voigt Shirley Kombi)
	SVAR peakType = root:STFitAssVar:PR_PeakType
	
	strswitch(peakType)
	case "SingletSK":
		EvaluateSingletSK()
		break
	case "DoubletSK":
		EvaluateDoubletSK()
		break
	case "MultiSK":
		EvaluateMultipletSK()
		break
	case "ExtMultiSK":
		EvaluateExtMultipletSK()
		break
	default:
		DoAlert 0, "Peak type not recognized in AnalyzeWCoefAfterFit()"
		break
	endswitch

end

//////////////////////////////////////////////////////////////////////////////////////
////////
//	delete auxiliary global objects if the static function has to quit
static function FitAbort()
	upDateFitDisplay("void")
	updateResidualDisplay("void")
	killwaves /z EffectiveConstraints
	killvariables  V_FitError
end

////////////////////////////////////
///////////////////////////////////
// Refresh the fit display
static function upDateFitDisplay(ctrlName):ButtonControl 
	string ctrlName
	
	CheckLocation()
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	
	NVAR keepInitConfiguration = root:STFitAssVar:keepInitConfiguration
	string InitializeCoefName = "InitializeCoef"
	string finalCoefName = "W_Coef"
	wave InitializeCoef = InitializeCoef
	
	//RemoveFromGraph /W=CursorPanel#guiCursorDisplay /Z $"#1"
	//updateCoefs()
	setup2waves()
	
	SinglePeakDisplay(peakType,RawYWave,RawXWave,InitializeCoefName)
	
	TitleBox comment1,win=CursorPanel, title="On Display: Initial Values"
	TitleBox comment1,frame=0,fColor=(65280,0,0)
end




static function updateResidualDisplay(YWaveName)
	string YWaveName
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	
	string ResName = "Res_" + YWaveName
	string traces, traceIndex
	variable i, traceCount

	//clean up
	traces = TraceNameList("CursorPanel#guiCursorDisplayResidual",";",1)
	traceCount = ItemsInList(traces,";")
	
	for (i = traceCount; i > -1 ; i -= 1)
		traceIndex = "#"+num2str(i)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayResidual /Z $traceIndex
		ModifyGraph  /W=CursorPanel#guiCursorDisplayResidual margin(bottom)=7
	endfor
	
	
	//make a list of all waves in the current data folder, if there is one which has Res_ in it, plot that one
	string DynamicWaveNameList
	DynamicWaveNameList = WaveList("Res_*", ";", "DIMS:1" )
	ResName = StringFromList(0, DynamicWaveNameList)
	
	if (exists(ResName))

		strswitch(RawXWave)
		case "":
			AppendToGraph /W=CursorPanel#guiCursorDisplayResidual $ResName
			break
		case "_calculated_":
			AppendToGraph /W=CursorPanel#guiCursorDisplayResidual $ResName
			break
		default:
			wave rawX = $RawXWave
			AppendToGraph /W=CursorPanel#guiCursorDisplayResidual $ResName vs rawX
			
			break
		endswitch
		
		ModifyGraph  /W=CursorPanel#guiCursorDisplayResidual zero(left)=1,nticks(bottom)=0, nticks(left)=5,axRGB(bottom)=(65535,65535,65535)
		ModifyGraph  /W=CursorPanel#guiCursorDisplayResidual mode=1,rgb=(47872,47872,47872), highTrip(left)=1
		
		SetAxis /W=CursorPanel#guiCursorDisplayResidual /A/R bottom
		//Display /W=CursorPanel#guiCursorDisplayResidual ResName 
	endif

end


static function upDateFitDisplayFinalVal(ctrlName):ButtonControl 
	string ctrlName
	CheckLocation()
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel

	variable i
	variable traceCount
	string traces
	string traceIndex
//	updateCoefs()

	setup2waves()
	traces = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	traceCount = ItemsInList(traces,";")
//	print traces
	//SetAxis/A Res_Left
	
	for (i = traceCount; i > 0; i -= 1)
		traceIndex = "#"+num2str(i)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $traceIndex
	endfor
	SinglePeakDisplay(peakType,RawYWave,RawXWave,"W_Coef")
	TitleBox comment1,win=CursorPanel, title="On Display: Final Values"
	TitleBox comment1,frame=0,fColor=(0,26112,0)
end



static function PlotPeaks( coefWave,dataWave,fitWave,peakType,RawXWave,newFolder)

string coefWave
string dataWave
string fitWave
string peakType
string RawXWave
variable newFolder               //if this value is different from 1, no folder for the results will be created

strswitch(peakType)
	case "SingletSK":   //for now, we work only here
		DrawAndEvaluatePseudoVoigtSK(dataWave,fitWave,peakType,RawXWave,newFolder)
	break
	case "DoubletSK":
		DrawAndEvaluateDoubletSK(dataWave,fitWave,peakType,RawXWave,newFolder)
	break	
	case "MultiSK":
		DrawAndEvaluateMultipletSK(dataWave,fitWave,peakType,RawXWave,newFolder)
	break	
	case "ExtMultiSK":
		DrawAndEvaluateExtMultipletSK(dataWave,fitWave,peakType,RawXWave,newFolder)
	break	
	default:
		DoAlert 0, "Peak type not recognized, something is wrong"
	break
endswitch

end 

//static function to name graphs and other windows in an easy-to-read way
//This static function is also accessible from the commandline
static function TagWindow(newTag)
	string newTag
	string TempTag
	string commandString
	NVAR V_Flag = V_Flag
	
	//now search the name-string for illegal characters and if there are any, replace them by '_'

	newTag = stringClean(newTag)
	variable i=1   //index variable for the data folder	
	commandString = ""
	sprintf commandString, "DoWindow '%s'", newTag
	Execute  commandString
	commandString =""
	  //V_flag will be set to 0, if this is not the case
	

	if (V_Flag || Exists(newTag))          //is there already a window or some other object with this name?
	//if yes:
	 //Append an index number to the current foldername and check if a folder with this name
	 //is already present. If so, increase the index number by one, append it to the basic foldername
	 //and check again. Repeat this procedure until a "free" name is found
		do
			TempTag =  newTag +"_" + num2istr(i)
			i+=1
			sprintf commandString, "DoWindow '%s'", TempTag
			Execute /Q  commandString
			commandString = ""
		while(V_Flag)
		
		if ( strlen(TempTag) >= 30)	
			printf "static function 'TagWindow' error: name too long!"
			return -1
		else
			sprintf commandString, "DoWindow /C '%s'", TempTag
			Execute /Q   commandString
			commandString =""
			sprintf commandString, "DoWindow /T %s, \"%s\"", TempTag, TempTag
			Execute /Q  commandString
			//RenameDataFolder subfolder, $tempFoldername                   //now rename the peak-folder accordingly
		endif
	
	else
		sprintf commandString, "DoWindow /C '%s'", newTag
		Execute /Q  commandString
		commandString =""
		sprintf commandString, "DoWindow /T %s, \"%s\"", newTag, newTag
		Execute /Q commandString
		killstrings /z commandString
	endif
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//check a string for illegal characters, and replace them by regular ones
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static function /s stringClean(startString)
	string startString
	
	if ( strsearch(startString,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		startString = ReplaceString(".", startString,"_")
	endif
	if ( strsearch(startString,":",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		startString = ReplaceString(":", startString,"_")
	endif
	if ( strsearch(startString," ",0) != -1 )  
		startString = ReplaceString(" ", startString,"")
	endif
	if ( strsearch(startString,",",0) != -1 )  
		startString = ReplaceString(",", startString,"_")
	endif
	if ( strsearch(startString,";",0) != -1 )  
		startString = ReplaceString(";", startString,"_")
	endif
	if ( strsearch(startString,"-",0) != -1 )  
		startString = ReplaceString("-", startString,"_")
	endif
	if ( strsearch(startString,"#",0) != -1 )  
		startString = ReplaceString("#", startString,"_")
	endif
	//if ( strsearch(startString,"'",0) != -1 )  
//		startString = ReplaceString("'", startString,"_")
//	endif
	if ( strsearch(startString,"*",0) != -1 )  
		startString = ReplaceString("*", startString,"_")
	endif
	if ( strsearch(startString,"~",0) != -1 )  
		startString = ReplaceString("~", startString,"_")
	endif
//	if ( strsearch(startString,".",0) != -1 )  
//		startString = ReplaceString(".", startString,"_")
//	endif
	if ( strsearch(startString,"'",0) != -1 )  
		startString = ReplaceString("'", startString,"")
	endif
	if ( strsearch(startString,"+",0) != -1 )  
		startString = ReplaceString("+", startString,"_")
	endif
	if ( strsearch(startString,",",0) != -1 )  
		startString = ReplaceString(",", startString ,"_")
	endif
	if ( strsearch(startString,"/",0) != -1 )  
		startString = ReplaceString("/", startString ,"_")
	endif
	if ( strsearch(startString,"ä",0) != -1 )  
		startString = ReplaceString("ä", startString,"ae")
	endif
	if ( strsearch(startString,"Ä",0) != -1 )  
		startString = ReplaceString("Ä", startString,"Ae")
	endif
	if ( strsearch(startString,"ö",0) != -1 )  
		startString = ReplaceString("ö", startString,"oe")
	endif
	if ( strsearch(startString,"Ö",0) != -1 )  
		startString = ReplaceString("Ö", startString,"Oe")
	endif
	if ( strsearch(startString,"ü",0) != -1 )  
		startString = ReplaceString("ü", startString,"ue")
	endif
	if ( strsearch(startString,"Ü",0) != -1 )  
		startString = ReplaceString("Ü", startString,"Ue")
	endif
	if ( strsearch(startString,"ß",0) != -1 )  
		startString = ReplaceString("ß", startString,"ss")
	endif
	
	return startString
end


///////PseudoVoigt General
///////////
///////////
///////////
//////////
///////////


static function AddVoigtPeak(coefWave,indepCheck,heightA,posA,left,right,Wcoef_length)

string coefWave
variable indepCheck                //decide whether to link the new peak to peak 1 or not
variable heightA
variable posA	
variable left
variable right
variable Wcoef_length

wave locRefW_coef = W_Coef
wave /t Min_Limit = Min_Limit   //just create a local reference, do not get confused by the identical names
wave /t Max_Limit = Max_Limit 
wave /t locRefConstraints = T_Constraints
wave /t locRefLegend = LegendWave
wave /t CoefLegendRef = CoefLegend
wave holdRef = hold                      //The global wave is named "hold"
wave epsilon = epsilon
	
variable nPeaks,i,numPara,EstimatedPeakArea
variable epsilonVal=1e-5
			numPara = 6
			nPeaks =WCoef_length/numPara
			redimension /n=(WCoef_length+numPara)  locRefW_coef
			redimension /n=(WCoef_length+numPara) Min_Limit
			redimension /n=(WCoef_length+numPara) Max_Limit
			redimension /n=(WCoef_length+numPara) CoefLegendRef        // This approach is much easier, than the other, using Temporary waves
			redimension /n=(WCoef_length+numPara) holdRef
			redimension /n=(WCoef_length+numPara) epsilon
			redimension /n=(2*(WCoef_length+numPara)) locRefConstraints
			
			if (WCoef_length == 0 )                                //the first peak gets these values
				EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)	
				locRefW_coef[0] = EstimatedPeakArea  		//now append the current cursor settings
				locRefW_coef[1]  = posA
				locRefW_coef[2] = Width_Start
				locRefW_coef[3] = GLratio_Start
				locRefW_coef[4] = Asym_Start
				locRefW_coef[5] = Asym_Shift_Start
			else                                                              // all further peaks are related to those values
				 //now append the current cursor settings
				locRefW_coef[WCoef_length+1]  = posA
				if ( indepCheck == 1 )
					// This is a trick to calculate a good estimator for the peak area form the cursor height
					//     so that the resulting peak has its maximum also roughly at the cursor height
					//  First assume that the fit coefficient would be 1
					// Calculate the maximum peak height with this coefficient at the peak position
					// Compare this with the desired peak height which is given by the cursor
					// Multiply the initial fit coefficient of 1 with number how many times the y value of the cursor is higher
					EstimatedPeakArea = EstimatePeakArea ( heightA , locRefW_coef[2] , locRefW_coef[3] , locRefW_coef[4] , locRefW_coef[5] )						
					locRefW_coef[WCoef_length] = EstimatedPeakArea  
					locRefW_coef[WCoef_length+2] = locRefW_Coef[2]                 //by default, everything is linked to peak 1	
					locRefW_coef[WCoef_length+3] = locRefW_Coef[3]
					locRefW_coef[WCoef_length+4] = locRefW_Coef[4]
					locRefW_coef[WCoef_length+5] = locRefW_Coef[5]
				else
					EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)						
					locRefW_coef[WCoef_length] = EstimatedPeakArea
					locRefW_coef[WCoef_length+2] = Width_Start             
					locRefW_coef[WCoef_length+3] = GLratio_Start
					locRefW_coef[WCoef_length+4] = Asym_Start
					locRefW_coef[WCoef_length+5] = Asym_Shift_Start
				endif
			endif
			
			if (WCoef_length == 0)
				Min_Limit[0] = "K0 >  " + num2str(min(1e-5,0.2 * EstimatedPeakArea ))  // the first one has to be finite not zero
				Max_Limit[0] ="K0 <  " + num2str(max(10,10 * EstimatedPeakArea ))
				Min_Limit[1] = "K1 >  " + num2str(right)
				Max_Limit[1] ="K1 <  " + num2str(left )
				Min_Limit[2] = "K2 >  " + num2str(Width_Min)
				Max_Limit[2] ="K2 <  " + num2str(Width_Max )
				Min_Limit[3] = "K3 >  " + num2str(GLratio_Min)
				Max_Limit[3] = "K3 <  " + num2str(GLratio_Max)
				Min_Limit[4] = "K4 >  " + num2str(Asym_Min)
				Max_Limit[4] = "K4 <  " + num2str(Asym_Max)
				Min_Limit[5] = "K5 >  " + num2str(Asym_Shift_Min)
				Max_Limit[5] = "K5 <  " + num2str(Asym_Shift_Max)
			else 
				Min_Limit[WCoef_length] = "K"  + num2istr(WCoef_length) + " >  "+ num2str(min(1e-5,0.2 * EstimatedPeakArea ) ) 
				Max_Limit[WCoef_length] ="K"  + num2istr(WCoef_length) + " <  " + num2str(max(10,10 * EstimatedPeakArea ) )
				Min_Limit[WCoef_length+1] =  "K" + num2istr(WCoef_length+1) + " >  "+ num2str(right)
				Max_Limit[WCoef_length+1] ="K" + num2istr(WCoef_length+1) + " <  " +num2str(left)
				
				if ( indepCheck == 1 )
					Min_Limit[WCoef_length+2] = "K" + num2istr(WCoef_length+2) + " >  K2 - " + num2str(interval)
					Max_Limit[WCoef_length+2] ="K" + num2istr(WCoef_length+2) + " <  K2 + " + num2str(interval)
					Min_Limit[WCoef_length+3] = "K" + num2istr(WCoef_length+3) + " >  K3 - " + num2str(interval)
					Max_Limit[WCoef_length+3] ="K" + num2istr(WCoef_length+3) + " <  K3 +" + num2str(interval)
					Min_Limit[WCoef_length+4] = "K" + num2istr(WCoef_length+4) + " >  K4 - " + num2str(interval)
					Max_Limit[WCoef_length+4] ="K" + num2istr(WCoef_length+4) + " <  K4 + " + num2str(interval)
					Min_Limit[WCoef_length+5] = "K" + num2istr(WCoef_length+5) + " >  K5 - " + num2str(interval)
					Max_Limit[WCoef_length+5] ="K" + num2istr(WCoef_length+5) + " <  K5 + " + num2str(interval)
				else
					Min_Limit[WCoef_length+2] = "K" + num2istr(WCoef_length+2) + " >  " + num2str(Width_Min)
					Max_Limit[WCoef_length+2] = "K" + num2istr(WCoef_length+2) + " <  " + num2str(Width_Max)
					Min_Limit[WCoef_length+3] = "K" + num2istr(WCoef_length+3) + " >  " + num2str(GLratio_Min)
					Max_Limit[WCoef_length+3] = "K" + num2istr(WCoef_length+3) + " <  " + num2str(GLratio_Max)
					Min_Limit[WCoef_length+4] = "K" + num2istr(WCoef_length+4) + " >  " + num2str(Asym_Min)
					Max_Limit[WCoef_length+4] = "K" + num2istr(WCoef_length+4) + " <  " + num2str(Asym_Max)
					Min_Limit[WCoef_length+5] = "K" + num2istr(WCoef_length+5) + " >  " + num2str(Asym_Shift_Min)
					Max_Limit[WCoef_length+5] = "K" + num2istr(WCoef_length+5) + " <  " + num2str(Asym_Shift_Max)	
				endif			
			endif
			
			for (i=0; i <  numpnts(Min_Limit); i+=1)
				locRefConstraints[2*i] = Min_Limit[i]
				locRefConstraints[2*i+1] = Max_Limit[i]
			endfor

			epsilon[Wcoef_length] = epsilonVal
			epsilon[Wcoef_length+1] =epsilonVal
			epsilon[Wcoef_length+2] = epsilonVal
			epsilon[Wcoef_length+3] =epsilonVal
			epsilon[Wcoef_length+4] = epsilonVal
			epsilon[Wcoef_length+5] = epsilonVal
			
			holdRef[Wcoef_length] = 0
			holdRef[Wcoef_length+1] = 0
			holdRef[Wcoef_length+2] = 0
			holdRef[Wcoef_length+3] = 0
			holdRef[Wcoef_length+4] = 1
			holdRef[Wcoef_length+5] = 1

			CoefLegendRef[WCoef_length] = " K" + num2istr(WCoef_length) + " : Area ------------- Peak: #"  + num2istr(nPeaks+1)
			CoefLegendRef[WCoef_length+1] = " K" + num2istr(WCoef_length+1) + " : Position"
			CoefLegendRef[WCoef_length+2] = " K" + num2istr(WCoef_length+2) + " : Width"
			CoefLegendRef[WCoef_length+3] = " K" + num2istr(WCoef_length+3) + " : GL ratio"
			CoefLegendRef[WCoef_length+4] = " K" + num2istr(WCoef_length+4) + " : Asymmetry"
			CoefLegendRef[WCoef_length+5] = " K" + num2istr(WCoef_length+5) + " : Asym. Shift"
end

// 2.////////////////////////////// Display the peak in the fit window correctly

static function PlotPseudoVoigtDisplay(peakType,RawYWave, RawXWave,coefWave)

	//SVAR peakType = root:S_PeakType
	//SVAR RawYWave = root:S_nameWorkWave
	//SVAR coefWave = root:S_CoefWave
	//SVAR RawXWave = root:S_XRawDataCursorPanel
	
	string peakType
	string RawYWave
	string RawXWave
	string coefWave
	string TagName    // the Tag in the result window
	string PeakTag     // text in this tag
	string PkName, parentDataFolder //, cleanUpString=""		
	string BGName //background
	string PeakSumName
	NVAR FitMin = STFitMin
	NVAR FitMax = STFitMax
	
	wave cwave = $coefWave
	wave raw = $RawYWave
//	wave xraw = $RawXWave
	variable LenCoefWave = DimSize(cwave,0)
	
	//create some waves, to display the peak
	variable nPeaks = 0
	variable numCoef
	variable i,index
	variable xmin, xmax, step
	variable TagPosition   //the position of the tag in the result window
	variable totalPeakSumArea, partialPeakSumArea
	
	duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate   
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			                     
			break
		case "_calculated_":
			 
			break
		default:                                                 // if not empty, x-axis wave necessary
			//read in the start x-value and the step size from the x-axis wave
			wave xraw = $RawXWave
			xmax = max(xraw[0],xraw[numpnts(xraw)-1] )
			xmin = min(xraw[0],xraw[numpnts(xraw)-1] )
			step = (xmax - xmin ) / DimSize(xraw,0)
			// now change the scaling of the y-wave duplicate, so it gets equivalent to a data-wave imported from an igor-text file
			duplicate /o raw tempWaveForCutting  
			SetScale /I x, xmin, xmax, tempWaveForCutting  //OKAY, NOW THE SCALING IS ON THE ENTIRE RANGE
			duplicate /o /R=(FitMin,FitMax) tempWaveForCutting WorkingDuplicate  
			killwaves /z tempWaveForCutting
			break
	endswitch
	
	parentDataFolder = GetDataFolder(1)
	
	
	//now make tabular rasa in the case of background functions
	string ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	variable numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	
	// If a wave is given which needs an external x-axis (from an ASCII-file) create a duplicate which receives a proper x-scaling later on
	// the original wave will not be changed
	              
	NewDataFolder /O /S FitTemp

	
 			numCoef = 6   //Voigt
			nPeaks = LenCoefWave/numCoef
			for (i =0; i<nPeaks;i+=1)
				index = numCoef*i
				PkName = "peak_" + num2istr(i+1)   //make a propper name
			 	//create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
				duplicate /o WorkingDuplicate $PkName			
				wave tempDisplay = $PkName        //This needs some explanation, see commentary at the end of the file                                        
			 
				 //overwrite the original values in the wave with the values of a single peak
				tempDisplay = CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
			
				RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
				AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempDisplay                           //now plot it
				// and add a tag
				WaveStats /Q tempDisplay
				tagName = PkName+num2istr(i)
				PeakTag = num2istr(i+1)
				TagPosition = V_maxloc
				
				Tag /w= CursorPanel#guiCursorDisplayFit /C /N= $tagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag
				ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($PkName)=(0,0,0)       // and color-code it	
			endfor
			
		
	WaveStats /Q WorkingDuplicate
//	SetAxis /w = CursorPanel#guiCursorDisplayFit left -0.1*V_max, 1.1*V_max
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	SetAxis/A/R /w = CursorPanel#guiCursorDisplayFit bottom
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	SetDataFolder parentDataFolder 
	killwaves /Z WorkingDuplicate
end







// 3 //////////////////////    draw and evaluate the fit results from Voigt peaks ////////////////////////////////////////////////////////////////////////////////////////////////////////

static function DrawAndEvaluatePseudoVoigt(dataWave,fitWave,peakType,RawXWave,newFolder)

string dataWave
string fitWave
string peakType
string RawXWave
variable newFolder               //if this value is different from 1, no folder for the results will be created

wave cwave = W_coef
wave origWave = $dataWave
wave fitted = $fitWave
wave epsilon = epsilon
wave hold = hold
wave InitializeCoef = InitializeCoef
wave Min_Limit = Min_Limit
wave Max_Limit = Max_Limit
wave T_Constraints = T_Constraints
wave  CoefLegend = CoefLegend

if ( strlen(fitWave) >= 30)	
	doalert 0, "The name of the fit-wave is too long! Please shorten the names."
	return -1
endif


//define further local variables
variable LenCoefWave = DimSize(cwave,0)	
variable nPeaks
variable index
variable i =0                               //general counting variable
variable numCoef                       //variable to keep the number of coefficients of the selected peak type
							  // numCoef = 3   for Gauss Singlet     and numCoef =5 for VoigtGLS
variable pointLength, totalArea, partialArea
variable peakMax 
variable TagPosition
variable AnalyticalArea
variable EffectiveFWHM
variable GeneralAsymmetry        //  = 1 - (fwhm_right)/(fwhm_left)

string PkName                          //string to keep the name of a single peak wave
string foldername                       //string to keep the name of the datafolder, which is created later on for the single peak waves
string tempFoldername               //help-string to avoid naming conflicts
string parentDataFolder
string TagName
string PeakTag
string LastGraphName
string NotebookName = "Report"     //this is the initial notebook name, it is changed afterwards
string tempNotebookName
string tempString                          // for a formated output to the notebook
string BGName
//The following switch construct is necessary in order to plot waveform data (usually from igor-text files , *.itx) as well as
//raw spectra which need an extra x-axis (such data come usually from an x-y ASCII file)

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		display /K=1 origWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
		break
	case "_calculated_":
		display /K=1 origWave
		break
	default:
		wave xraw = $RawXWave                                                 // if not empty
		display /K=1 origWave vs xraw        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
endswitch
ModifyGraph mode($dataWave)=3,msize($dataWave)=1.3, marker($dataWave)=8
ModifyGraph mrkThick($dataWave)=0.7
ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
    
LastGraphName = WinList("*", "", "WIN:")    //get the name of the graph

//check if this Notebook already exists
V_Flag = 0
DoWindow $NotebookName   
// if yes, construct a new name
if (V_Flag)
	i = 1
	do 
		tempNoteBookName = NotebookName + num2istr(i)
		DoWindow $tempNotebookName
		i += 1
	while (V_Flag)
	NotebookName = tempNotebookName 
endif
//if not, just proceed

NewNotebook /F=1 /K=1 /N=$NotebookName      //make a new notebook to hold the fit report
Notebook $NoteBookName ,fsize=8
//Notebook $NoteBookName ,text="\r\r \t\t --- if necessary, insert plot by copy and paste ----    "
Notebook $NoteBookName ,text="\r\r\rPeak Shape:    "+ peakType

//prepare a new datafolder for the fitting results, in particular the single peaks
parentDataFolder = GetDataFolder(1)    //get the name of the current data folder

if (newFolder == 1)
	NewDataFolder /O /S subfolder
	//now, this folder is the actual data folder, all writing is done here and not in root
endif

duplicate /o fitted tempFitWave
wave locRefTempFit = tempFitWave
locRefTempFit = 0

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		 sprintf  tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  area(origWave)           
		break
	case "_calculated_":
		sprintf tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  area(origWave)
		break
	default:                                                 // if not empty
		sprintf tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  areaXY(xraw,origWave)
		break
endswitch
Notebook $NoteBookName ,text=tempString

//take the fit-result and analyze the maximum, get the maximum signal, so a significance threshold can be calculated
//WaveStats /Q fitted
//peakMax = V_max

//now decompose the fit into single peaks --- if a further fit static function is added, a further "case" has to be attached

		numCoef = 6
		nPeaks = LenCoefWave/numCoef                                             //get the number of  peaks from the output wave of the fit
		
		if ( mod(LenCoefWave,numCoef) != 0 )
			DoAlert 0, "Missmatch, probably wrong peak type selected or wrong coefficient file, retry "
			SetDataFolder parentDataFolder 
			KillDataFolder /Z subfolder
			print " ******* Peak type mismatch - check your fit and peak type ******"
			return 1
		endif 
		
		Notebook $NoteBookName ,text="\rNumber of peaks:    " + num2istr(nPeaks)
		//Notebook $NoteBookName ,text="\rPeak No \t  Area\t\t\tPosition \t  FWHM \t  G-L ratio (0:Gauss)  Asymmetryfactor \t Asym. Shift\r " 
		
		for (i =0; i<nPeaks;i+=1)
			index = numCoef*i
			//make a proper name for the single peak wave
			PkName = "p" + num2istr(i+1)+"_" + dataWave
			 //create a wave with this name and the correct scaling 
			 //and number of datapoints -> copy the fit wave and give the copy the name PkName    
			duplicate /o fitted $PkName	                                                  									  
			wave W = $PkName     //This needs explanation, see comments at the end of the file                                                 
 			//overwrite the original values in the wave with the values of a single peak   
			//The static function CalcSingleVoigtGLS is defined in the file FitAssistFunc.ipf 
			W = CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
			locRefTempFit += W
			AppendToGraph $PkName                                                        //now plot it
			
			//append the peak-tags to the graph, let the arrow point to a maximum
			WaveStats /Q W                             // get the location of the maximum
			TagName = "tag"+num2istr(i)           //each tag has to have a name
			PeakTag = num2istr(i+1)                 // The tag displays the peak index
			TagPosition = V_maxloc                 // and is located at the maximum
			Tag  /C /N= $TagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag    // Now put the tag there
			
			ModifyGraph rgb($PkName)=(30464,30464,30464)              // color code the peak
				
			AnalyticalArea =  IntegrateSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
			
			EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
			GeneralAsymmetry = CalcGeneralAsymmetry(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])   
			
			sprintf  tempString, "\r\r %1g	Area                                   |  Position |  FWHM   | GL-ratio  |   Asym.   | Asym. S. |\r",(i+1)
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------" 
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "\r       %16.4g   'Fit-coefficient'  |  %8.2f  |  %8.2f  |  %8.2f  |  %8.2f  |  %8.2f    |\r" ,  cwave[index], cwave[index+1] ,cwave[index+2] ,cwave[index+3] , cwave[index+4],cwave[index+5]
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "   %20.3g   'Fit wave area' \t Effective maximum position %8.2f \r",  area(W), V_maxloc  // "-> In case of asymmetry, this value does not represent an area any more"
			Notebook $NoteBookName ,text=tempString
			sprintf tempString, "   %20.3g   'Analytical area' \t Effective Asymmetry = 1 - (fwhm_right)/(fwhm_left) %8.2f \r" ,	AnalyticalArea, GeneralAsymmetry
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "   \t\t\t \t Effective FWHM: %8.2f \r"	EffectiveFWHM	
			Notebook $NoteBookName ,text=tempString
		endfor
		
		sprintf tempString, "\r'Singlet area':     Identical to the Fit coefficient - not significant for asymmetric peaks!"
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString,"\r'Fit wave area':    Peak area within the measured energy range"
		Notebook $NoteBookName ,text=tempString																			    
		sprintf tempString,"\r'Analytical area': Obtained by numerically integrating the peak from 0 to (position + 1000eV)\r                        Significant also for asymmetric peaks - approximates the peak area from -INF to + INF\r"
		Notebook $NoteBookName ,text=tempString
		sprintf tempString,"\r\rPlease note that for asymmetric peaks the fit coefficients do not describe the physically relevant quantities any more. \rPlease refer to the respective 'effective' or 'analytical' values.\r"      
		Notebook $NoteBookName ,text=tempString
		

killwaves /z  fitted     //this applies to the original fit-wave of Igor, since it is a reference to the wave root:Igor-FitWave, the original wave is possibly wrong
duplicate /o locRefTempFit, $fitWave               //but we are still in the subfolder, 
killwaves /z locRefTempFit
wave fitted = $fitWave

//go back to the parent data folder
if (newFolder ==1)
	SetDataFolder parentDataFolder 

	//create a copy of the coefficient wave in the subfolder, so the waves 
	//and the complete fitting results are within that folder
	duplicate /o :$dataWave, :subfolder:$dataWave
	//if (WaveExists($RawXWave))
	if (Exists(RawXWave))
		duplicate /o :$RawXWave, :subfolder:$RawXWave
	endif

	//duplicate  :$fitWave, :subfolder:$fitWave
	killwaves /z :$fitWave            //probably fails, if the fit wave is displayed in the main panel as well
	AppendToGraph :subfolder:$fitWave                                 //draw the complete fit
	ModifyGraph rgb($fitWave) = (0,0,0)       //color-code it
	//Remove the original wave, which is located in the parent directory and replace it by the copy in the subfolder
	RemoveFromGraph $"#0" 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph :subfolder:$dataWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
			break
		case "_calculated_":
			AppendToGraph  :subfolder:$dataWave
			break
		default:                                                 // if not empty
			AppendToGraph :subfolder:$dataWave vs :subfolder:$RawXWave        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
	endswitch

	
	duplicate :T_Constraints, :subfolder:T_Constraints
	duplicate :Min_Limit, :subfolder:Min_Limit
	duplicate :Max_Limit, :subfolder:Max_Limit
	//if (WaveExists(LegendWave))
	//	duplicate :LegendWave, :subfolder:LegendWave
	//endif

	if (WaveExists(InitializeCoef))
		duplicate InitializeCoef, :subfolder:InitializeCoef
	endif
 	if (exists("epsilon"))
 		duplicate epsilon :subfolder:epsilon
 	endif
 	duplicate hold, :subfolder:hold
 	duplicate CoefLegend, :subfolder:CoefLegend
	duplicate cwave, :subfolder:W_Coef                //now create that copy, leave the original 
														//coefficient wave where it is, maybe the 
														//user wants to try another fit

//Now rename the subfolder accordingly
//If there are any datafolders with peak-waves from previous runs are present, do
//not overwrite them, but create a foldername with a running index
// if a folder named "test" was present, name the new folder "test1", the next one "test2" and so on

	foldername = "V"+num2istr(nPeaks)+ "_" + dataWave
	
	//foldername ="Fit_"+ dataWave
	i=1   //index variable for the data folder	
	tempFoldername = foldername            //used also for the notebook
	if (DataFolderExists(foldername))    //is there already a folder with this name
	//if yes:
	 //Append an index number to the current foldername and check if a folder with this name
	 //is already present. If so, increase the index number by one, append it to the basic foldername
	 //and check again. Repeat this procedure until a "free" name is found
		do
			tempFoldername = foldername + num2istr(i)
			i+=1
		while(DataFolderExists(tempFoldername))
		
		if ( strlen(tempFoldername) >= 30)	
			doalert 0, "The output folder name is too long! Please shorten the names. The output folder of the current run is named 'subfolder'."
		else
			RenameDataFolder subfolder, $tempFoldername                   //now rename the peak-folder accordingly
			Notebook  $NoteBookName, text="\r------------------------------------------------------------------------------"
			//remove illegal characters from the string
			tempFoldername = stringClean(tempFoldername)
			DoWindow /C $tempFoldername
			DoWindow /F $LastGraphName
			DoWindow /C $tempFoldername + "_graph"
			//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"   //valid in Igor 6.x
		endif
		//TextBox/N=text0/A=LT tempFoldername        //prints into the graph
	else 
		//if no:
		RenameDataFolder subfolder, $foldername 
		//TagWindow(foldername)
		Notebook  $NoteBookName, text="\r------------------------------------------------------------------------------"
		//if ( strsearch(foldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		//	foldername = ReplaceString(".", foldername,"_")
		//endif
		foldername = stringClean(foldername)
		tempFoldername = stringClean(tempFoldername)
		DoWindow /C $foldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
		//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"
		//TextBox/N=text0/A=LT foldername               //prints into the graph
	endif
	//everything up to now was done in a subfolder
else          //varialbe newFolder different from 1  create no new folder
	AppendToGraph $fitWave
	ModifyGraph rgb($fitWave) = (0,0,0)
	SetAxis/A/R bottom
	//find a name for the graph and the notebook, that reflects the location of the corresponding data
	String location = GetDataFolder (0)
	strswitch(location)
		case "root":
			tempFoldername = "fit" + dataWave
			break
		default:
			tempFoldername = location
			break
	endswitch

	Notebook  $NoteBookName, text="\r------------------------------------------------------------------------------"
	
	//if ( strsearch(tempFoldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
	//	tempFoldername = ReplaceString(".", tempFoldername,"_")
	//endif
	tempFoldername = stringClean(tempFoldername)
	V_Flag = 0
	DoWindow $tempFoldername    //check if it is there, if yes V_Flag is set to 1
	if (V_Flag)
		do
			V_Flag = 0   // it should be possible to use the cancel button
			Prompt tempFoldername, "There is already a report on this folder, please enter a new for the new report."
			DoPrompt /Help="Please use only letters, numbers and an underscore!" "Please enter a new name", tempFoldername
			if (V_Flag)  //user pressed cancel
				DoWindow /K Report //kill the notebook
				DoWindow /K $LastGraphName
				
				killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
				killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr
				return -1
			endif
			tempFoldername = stringClean(tempFoldername)
			DoWindow $tempFoldername    //check again and
		while (V_Flag)                                 //repeat until
		DoWindow /C $tempFoldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
		//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"
	else
		DoWindow /C $tempFoldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
		//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph" 
	endif
	//TextBox/N=text0/A=LT "fit"+dataWave
endif
 
//make the graph look good
ModifyGraph mode($dataWave)=3 ,msize($dataWave)=1.3 // ,marker($dataWave)=8, opaque($dataWave)=1
ModifyGraph opaque=1,marker($dataWave)=19
ModifyGraph rgb($dataWave)=(60928,60928,60928)
ModifyGraph useMrkStrokeRGB($dataWave)=1
ModifyGraph mrkStrokeRGB($dataWave)=(0,0,0)
//ModifyGraph mrkThick($dataWave)=0.7
//ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
ModifyGraph mirror=2,minor(bottom)=1
Label left "\\f01 intensity (counts)"
Label bottom "\\f01  binding energy (eV)"	
ModifyGraph width=255.118,height=157.465, standoff = 0, gfSize=11

//The following command works easily, but then the resulting graph is not displayed properly in the notebook
//SetAxis/A/R bottom
//instead do it like this:
variable left,right

strswitch(RawXWave)
	 	case "":
	 		 left = max(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 	break
	 	case "_calculated_":
	 		 left = max(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 	break
	 	default:
	 		waveStats /Q $RawXWave
	 		left = V_max
	 		right = V_min
	 	break
 endswitch
 SetAxis bottom left,right
//okay this is not perfectly elegant ... but

WaveStats /Q $dataWave
SetAxis left V_min-0.05*(V_max-V_min), 1.02*V_max
LastGraphName = WinList("*", "", "WIN:")



Notebook  $tempFoldername, selection = {startOfFile,startOfFile}
tempString = "Fitting results for: " + tempFoldername + "\r"
Notebook  $tempFoldername, text=tempString
Notebook  $tempFoldername, selection = {startOfPrevParagraph,endOfPrevParagraph}, fsize = 12, fstyle = 0

Notebook  $tempFoldername, selection = {startOfNextParagraph,startOfNextParagraph}
Notebook  $tempFoldername, picture={$LastGraphName, 0, 1} , text="\r" 




//Notebook  $tempFoldername, text="\r \r"  

//now clean up
killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr

end 


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Doublet //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet
 //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet  //Doublet

static function AddVoigtDoublet(coefWave,indepCheck,heightA,posA,left,right,Wcoef_length)

string coefWave
variable indepCheck                //decide whether to link the new peak to peak 1 or not
variable heightA
variable posA	
variable left
variable right
variable Wcoef_length

wave locRefW_coef = W_Coef
wave /t Min_Limit = Min_Limit   //just create a local reference, do not get confused by the identical names
wave /t Max_Limit = Max_Limit 
wave /t locRefConstraints = T_Constraints
wave /t locRefLegend = LegendWave
wave /t CoefLegendRef = CoefLegend
wave holdRef = hold                      //The global wave is named "hold"
wave epsilon = epsilon
	
variable nPeaks,i,numPara,EstimatedPeakArea
variable epsilonVal=1e-5
numPara = 8	
			nPeaks =WCoef_length/numPara
			redimension /n=(WCoef_length+numPara)  locRefW_coef
			redimension /n=(WCoef_length+numPara) Min_Limit
			redimension /n=(WCoef_length+numPara) Max_Limit
			redimension /n=(WCoef_length+numPara) CoefLegendRef        // This approach is much easier, than the other, using Temporary waves
			redimension /n=(WCoef_length+numPara) holdRef
			redimension /n=(WCoef_length+numPara) epsilon
			redimension /n=(2*(WCoef_length+numPara)) locRefConstraints
			
			if (WCoef_length == 0 )                                //the first peak gets these values
				EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)	
				locRefW_coef[0] = EstimatedPeakArea 		//now append the current cursor settings
				locRefW_coef[1]  = posA
				locRefW_coef[2] = Width_Start	   //standard guess
				locRefW_coef[3] = GLratio_Start
				locRefW_coef[4] =  Asym_Start
				locRefW_coef[5] = Asym_Shift_Start
				locRefW_coef[6] = 2
				locRefW_coef[7] = 0.5
			else                                                              // all further peaks are related to those values
				locRefW_coef[WCoef_length+1]  = posA
				if ( indepCheck == 1 )
					EstimatedPeakArea = EstimatePeakArea ( heightA , locRefW_coef[2] , locRefW_coef[3] , locRefW_coef[4] , locRefW_coef[5] )						
					locRefW_coef[WCoef_length] = EstimatedPeakArea  
					locRefW_coef[WCoef_length+2] = locRefW_Coef[2]                 //by default, everything is linked to peak 1	
					locRefW_coef[WCoef_length+3] = locRefW_Coef[3]
					locRefW_coef[WCoef_length+4] = locRefW_Coef[4]
					locRefW_coef[WCoef_length+5] = locRefW_Coef[5]
					locRefW_coef[WCoef_length+6] = locRefW_Coef[6]
					locRefW_coef[WCoef_length+7] = locRefW_Coef[7]
				else
					EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)						
					locRefW_coef[WCoef_length] = EstimatedPeakArea
					locRefW_coef[WCoef_length+2] = Width_Start         
					locRefW_coef[WCoef_length+3] = GLratio_Start
					locRefW_coef[WCoef_length+4] = Asym_Start
					locRefW_coef[WCoef_length+5] = Asym_Shift_Start
					locRefW_coef[WCoef_length+6] = 2
					locRefW_coef[WCoef_length+7] =0.5
				endif
			endif
			
			if (WCoef_length == 0)
				Min_Limit[0] = "K0 >  " + num2str(min(1e-5,0.2 * EstimatedPeakArea ))  //the first one should not become zero, its the reference peak
				Max_Limit[0] ="K0 <  " + num2str(max(10,10*heightA ) )
				Min_Limit[1] = "K1 >  " + num2str(right)
				Max_Limit[1] ="K1 <  " + num2str(left )
				Min_Limit[2] = "K2 >  " + num2str(Width_Min)
				Max_Limit[2] ="K2 <  " + num2str(Width_Max )
				Min_Limit[3] = "K3 >  " + num2str(GLratio_Min)
				Max_Limit[3] = "K3 <  " + num2str(GLratio_Max)
				Min_Limit[4] = "K4 >  " + num2str(Asym_Min)
				Max_Limit[4] = "K4 <  " + num2str(Asym_Max)
				Min_Limit[5] = "K5 >  " + num2str(Asym_Shift_Min)
				Max_Limit[5] = "K5 <  " + num2str(Asym_Shift_Max)
				Min_Limit[6] = "K6 >  " + num2str(Spin_Split_Min)
				Max_Limit[6] = "K6 <  " + num2str(Spin_Split_Max)
				Min_Limit[7] = "K7 >  " + num2str(Spin_Ratio_Min)
				Max_Limit[7] = "K7 <  " + num2str(Spin_Ratio_Max)

			else 
				Min_Limit[WCoef_length] = "K"  + num2istr(WCoef_length) + " >  "+ num2str(min(1e-5,0.2 * EstimatedPeakArea )) 
				Max_Limit[WCoef_length] ="K"  + num2istr(WCoef_length) + " <  " + num2str(max(10,10*heightA) )
				Min_Limit[WCoef_length+1] =  "K" + num2istr(WCoef_length+1) + " >  "+ num2str(right)
				Max_Limit[WCoef_length+1] ="K" + num2istr(WCoef_length+1) + " <  " +num2str(left)
				
				if ( indepCheck == 1 )
					Min_Limit[WCoef_length+2] = "K" + num2istr(WCoef_length+2) + " >  K2 - "+ num2str(interval)
					Max_Limit[WCoef_length+2] ="K" + num2istr(WCoef_length+2) + " <  K2 + "+ num2str(interval)
					Min_Limit[WCoef_length+3] = "K" + num2istr(WCoef_length+3) + " >  K3 - "+ num2str(interval)
					Max_Limit[WCoef_length+3] ="K" + num2istr(WCoef_length+3) + " <  K3 + "+ num2str(interval)
					Min_Limit[WCoef_length+4] = "K" + num2istr(WCoef_length+4) + " >  K4 - "+ num2str(interval)
					Max_Limit[WCoef_length+4] ="K" + num2istr(WCoef_length+4) + " <  K4 + "+ num2str(interval)
					Min_Limit[WCoef_length+5] = "K" + num2istr(WCoef_length+5) + " >  K5 - "+ num2str(interval)
					Max_Limit[WCoef_length+5] ="K" + num2istr(WCoef_length+5) + " <  K5 + "+ num2str(interval)
					Min_Limit[WCoef_length+6] = "K" + num2istr(WCoef_length+6) + " >  K6 - "+ num2str(interval)
					Max_Limit[WCoef_length+6] ="K" + num2istr(WCoef_length+6) + " <  K6 + "+ num2str(interval)
					Min_Limit[WCoef_length+7] = "K" + num2istr(WCoef_length+7) + " >  K7 - "+ num2str(interval)
					Max_Limit[WCoef_length+7] ="K" + num2istr(WCoef_length+7) + " <  K7 + "+ num2str(interval)
				else
					Min_Limit[WCoef_length+2] = "K" + num2istr(WCoef_length+2) + " >  " + num2str(Width_Min)
					Max_Limit[WCoef_length+2] = "K" + num2istr(WCoef_length+2) + " <  " + num2str(Width_Max)
					Min_Limit[WCoef_length+3] = "K" + num2istr(WCoef_length+3) + " >  " + num2str(GLratio_Min)
					Max_Limit[WCoef_length+3] = "K" + num2istr(WCoef_length+3) + " <  " + num2str(GLratio_Max)
					Min_Limit[WCoef_length+4] = "K" + num2istr(WCoef_length+4) + " >  " + num2str(Asym_Min)
					Max_Limit[WCoef_length+4] = "K" + num2istr(WCoef_length+4) + " <  " + num2str(Asym_Max)
					Min_Limit[WCoef_length+5] = "K" + num2istr(WCoef_length+5) + " >  " + num2str(Asym_Shift_Min)
					Max_Limit[WCoef_length+5] = "K" + num2istr(WCoef_length+5) + " <  " + num2str(Asym_Shift_Max)	
					Min_Limit[WCoef_length+6] = "K" + num2istr(WCoef_length+6) + " >  " + num2str(Spin_Split_Min)
					Max_Limit[WCoef_length+6] = "K" + num2istr(WCoef_length+6) + " <  " + num2str(Spin_Split_Max)
					Min_Limit[WCoef_length+7] = "K" + num2istr(WCoef_length+7) + " >  " + num2str(Spin_Ratio_Min)
					Max_Limit[WCoef_length+7] = "K" + num2istr(WCoef_length+7) + " <  " + num2str(Spin_Ratio_Max)
				endif			
			endif
			
			for (i=0; i <  numpnts(Min_Limit); i+=1)
				locRefConstraints[2*i] = Min_Limit[i]
				locRefConstraints[2*i+1] = Max_Limit[i]
			endfor

			epsilon[Wcoef_length] = epsilonVal
			epsilon[Wcoef_length+1] = epsilonVal
			epsilon[Wcoef_length+2] =epsilonVal
			epsilon[Wcoef_length+3] = epsilonVal
			epsilon[Wcoef_length+4] =epsilonVal
			epsilon[Wcoef_length+5] =epsilonVal
			epsilon[Wcoef_length+6] =epsilonVal
			epsilon[Wcoef_length+7] = epsilonVal
			
			holdRef[Wcoef_length] = 0
			holdRef[Wcoef_length+1] = 0
			holdRef[Wcoef_length+2] = 0
			holdRef[Wcoef_length+3] = 0
			holdRef[Wcoef_length+4] = 1
			holdRef[Wcoef_length+5] = 1
			holdRef[Wcoef_length+6] = 1
			holdRef[Wcoef_length+7] = 1
			
			CoefLegendRef[WCoef_length] = " K" + num2istr(WCoef_length) + " : Area -------- Peak: #"  + num2istr(nPeaks+1)
			CoefLegendRef[WCoef_length+1] = " K" + num2istr(WCoef_length+1) + " : Position"
			CoefLegendRef[WCoef_length+2] = " K" + num2istr(WCoef_length+2) + " : Width"
			CoefLegendRef[WCoef_length+3] = " K" + num2istr(WCoef_length+3) + " : GL ratio"
			CoefLegendRef[WCoef_length+4] = " K" + num2istr(WCoef_length+4) + " : Asymmetry"
			CoefLegendRef[WCoef_length+5] = " K" + num2istr(WCoef_length+5) + " : Asym. Shift"
			CoefLegendRef[WCoef_length+6] = " K" + num2istr(WCoef_length+6) + " : Spin Orbit Split"
			CoefLegendRef[WCoef_length+7] = " K" + num2istr(WCoef_length+7) + " : Spin Orbit ratio"
					
end

///2    // //////////////////////////////// Display
// fill in the case for doublet
static function PlotPVDoubletDisplay(peakType,RawYWave, RawXWave,coefWave)

	//SVAR peakType = root:S_PeakType
	//SVAR RawYWave = root:S_nameWorkWave
	//SVAR coefWave = root:S_CoefWave
	//SVAR RawXWave = root:S_XRawDataCursorPanel
	
	string peakType
	string RawYWave
	string RawXWave
	string coefWave
	string TagName    // the Tag in the result window
	string PeakTag     // text in this tag
	string PkName, parentDataFolder //, cleanUpString=""		
	string BGName //background
	string PeakSumName
	NVAR FitMin = STFitMin
	NVAR FitMax =STFitMax
	
	wave cwave = $coefWave
	wave raw = $RawYWave
//	wave xraw = $RawXWave
	variable LenCoefWave = DimSize(cwave,0)
	
	//create some waves, to display the peak
	variable nPeaks = 0
	variable numCoef
	variable i,index
	variable xmin, xmax, step
	variable TagPosition   //the position of the tag in the result window
	variable totalPeakSumArea, partialPeakSumArea
	
	
	duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate   
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			                     
			break
		case "_calculated_":
			 
			break
		default:                                                 // if not empty, x-axis wave necessary
			//read in the start x-value and the step size from the x-axis wave
			wave xraw = $RawXWave
			wave xraw = $RawXWave
			xmax = max(xraw[0],xraw[numpnts(xraw)-1] )
			xmin = min(xraw[0],xraw[numpnts(xraw)-1] )
			step = (xmax - xmin ) / DimSize(xraw,0)
			// now change the scaling of the y-wave duplicate, so it gets equivalent to a data-wave imported from an igor-text file
			SetScale /I x, xmin, xmax, WorkingDuplicate
			
			break
	endswitch
	
	parentDataFolder = GetDataFolder(1)
	
	
	//now make tabular rasa in the case of background functions
	string ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	variable numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	
	// If a wave is given which needs an external x-axis (from an ASCII-file) create a duplicate which receives a proper x-scaling later on
	// the original wave will not be changed
	              
	NewDataFolder /O /S FitTemp

	numCoef = 8   //Voigt Doublet
			nPeaks = LenCoefWave/numCoef
			for (i =0; i<nPeaks;i+=1)
				index = numCoef*i
				PkName = "peak_" + num2istr(i+1)   //make a propper name
			 	//create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
				duplicate /o WorkingDuplicate $PkName			
				wave tempDisplay = $PkName        //This needs some explanation, see commentary at the end of the file                                        
			 
				 //overwrite the original values in the wave with the values of a single peak
				tempDisplay = CalcVoigtDoublet(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5], cwave[index+6],cwave[index+7], x)
			
				RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
				AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempDisplay                           //now plot it
				
				WaveStats /Q tempDisplay
				tagName = PkName+num2istr(i)
				PeakTag = num2istr(i+1)
				TagPosition = V_maxloc
				
				Tag /w= CursorPanel#guiCursorDisplayFit /C /N= $tagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag
				ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($PkName)=(0,0,0)       // and color-code it	
			endfor		

 					
	WaveStats /Q WorkingDuplicate
//	SetAxis /w = CursorPanel#guiCursorDisplayFit left -0.1*V_max, 1.1*V_max
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	SetAxis/A/R /w = CursorPanel#guiCursorDisplayFit bottom
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	SetDataFolder parentDataFolder 
	killwaves /Z WorkingDuplicate
end


  

static function DrawAndEvaluatePVDoublet(dataWave,fitWave,peakType,RawXWave,newFolder)

string dataWave
string fitWave
string peakType
string RawXWave
variable newFolder               //if this value is different from 1, no folder for the results will be created

wave cwave = W_coef
wave origWave = $dataWave
wave fitted = $fitWave
wave epsilon = epsilon
wave hold = hold
wave InitializeCoef = InitializeCoef
wave Min_Limit = Min_Limit
wave Max_Limit = Max_Limit
wave T_Constraints = T_Constraints
wave  CoefLegend = CoefLegend

if ( strlen(fitWave) >= 30)	
	doalert 0, "The name of the fit-wave is too long! Please shorten the names."
	return -1
endif


//define further local variables
variable LenCoefWave = DimSize(cwave,0)	
variable nPeaks
variable index
variable i =0                               //general counting variable
variable numCoef                       //variable to keep the number of coefficients of the selected peak type
							  // numCoef = 3   for Gauss Singlet     and numCoef =5 for VoigtGLS
variable pointLength, totalArea, partialArea
variable peakMax 
variable TagPosition
variable AnalyticalArea
variable EffectiveFWHM
variable GeneralAsymmetry        //  = 1 - (fwhm_right)/(fwhm_left)

string PkName                          //string to keep the name of a single peak wave
string foldername                       //string to keep the name of the datafolder, which is created later on for the single peak waves
string tempFoldername               //help-string to avoid naming conflicts
string parentDataFolder
string TagName
string PeakTag
string LastGraphName
string NotebookName = "Report"     //this is the initial notebook name, it is changed afterwards
string tempNotebookName
string tempString                          // for a formated output to the notebook
string BGName
//The following switch construct is necessary in order to plot waveform data (usually from igor-text files , *.itx) as well as
//raw spectra which need an extra x-axis (such data come usually from an x-y ASCII file)

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		display /K=1 origWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
		break
	case "_calculated_":
		display /K=1 origWave
		break
	default:
		wave xraw = $RawXWave                                                 // if not empty
		display /K=1 origWave vs xraw        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
endswitch
ModifyGraph mode($dataWave)=3,msize($dataWave)=1.3, marker($dataWave)=8
ModifyGraph mrkThick($dataWave)=0.7
ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
    
LastGraphName = WinList("*", "", "WIN:")    //get the name of the graph

//check if this Notebook already exists
V_Flag = 0
DoWindow $NotebookName   
// if yes, construct a new name
if (V_Flag)
	i = 1
	do 
		tempNoteBookName = NotebookName + num2istr(i)
		DoWindow $tempNotebookName
		i += 1
	while (V_Flag)
	NotebookName = tempNotebookName 
endif
//if not, just proceed

NewNotebook /F=1 /K=1 /N=$NotebookName      //make a new notebook to hold the fit report
Notebook $NoteBookName ,fsize=8
//Notebook $NoteBookName ,text="\r\r \t\t --- if necessary, insert plot by copy and paste ----    "
Notebook $NoteBookName ,text="\r\r\rPeak Shape:    "+ peakType

//prepare a new datafolder for the fitting results, in particular the single peaks
parentDataFolder = GetDataFolder(1)    //get the name of the current data folder

if (newFolder == 1)
	NewDataFolder /O /S subfolder
	//now, this folder is the actual data folder, all writing is done here and not in root
endif

duplicate /o fitted tempFitWave
wave locRefTempFit = tempFitWave
locRefTempFit = 0

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		 sprintf  tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  area(origWave)           
		break
	case "_calculated_":
		sprintf tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  area(origWave)
		break
	default:                                                 // if not empty
		sprintf tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  areaXY(xraw,origWave)
		break
endswitch
Notebook $NoteBookName ,text=tempString

//take the fit-result and analyze the maximum, get the maximum signal, so a significance threshold can be calculated
//WaveStats /Q fitted
//peakMax = V_max

//now decompose the fit into single peaks --- if a further fit static function is added, a further "case" has to be attached
		numCoef = 8
		nPeaks = LenCoefWave/numCoef                                             //get the number of  peaks from the output wave of the fit
		
		if ( mod(LenCoefWave,numCoef) != 0 )
			DoAlert 0, "Missmatch, probably wrong peak type selected or wrong coefficient file, retry "
			SetDataFolder parentDataFolder 
			KillDataFolder /Z subfolder
			print " ******* Peak type mismatch - check your fit and peak type ******"
			return 1
		endif 
		
		Notebook $NoteBookName ,text="\rNumber of peaks:    " + num2istr(nPeaks)
		//Notebook $NoteBookName ,text="\r\rPeak No  ||  Area  |  Position  |  FWHM  |  G-L ratio  |  Asymmetry  |  Asym. shift  |  Doublet ratio  |  Doublet splitting \r " 
		
		for (i =0; i<nPeaks;i+=1)
			
			index = numCoef*i

			//make a proper name for the single peak wave
			PkName = "p" + num2istr(i+1)+"_" + dataWave
			 //create a wave with this name and the correct scaling 
			 //and number of datapoints -> copy the fit wave and give the copy the name PkName    
			duplicate /o fitted $PkName                                                  
												  
			wave W = $PkName                                                 
		
 			//overwrite the original values in the wave with the values of a single peak   
			//The static function CalcSingleVoigtGLS is defined in the file FitAssistFunc.ipf 
			W = CalcVoigtDoublet(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5], cwave[index+6],cwave[index+7],x)
			locRefTempFit += W
			AppendToGraph $PkName                                                        //now plot it
			//append the peak-tags to the graph, let the arrow point to a maximum
			WaveStats /Q W				 // get the location of the maximum
			TagName = "tag"+num2istr(i)     //each tag has to have a name
			PeakTag = num2istr(i+1)           // The tag displays the peak index
			TagPosition = V_maxloc           // and is located at the maximum
			Tag  /C /N= $TagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag  //Now put the tag there
			
			ModifyGraph rgb($PkName)=(30464,30464,30464)              // and color-code the graph
			
			//The FWHM is for both peaks in the doublet the same, so the Singlet static function is re-usable
			EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
			GeneralAsymmetry = CalcGeneralAsymmetry(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5]) 
			
			AnalyticalArea =  IntegrateVoigtDoublet(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5], cwave[index+6], cwave[index+7])

			//WaveStats /Q $PkName
			//peakMax = V_max     //in this way, each peak has a numerically different threshold
			sprintf  tempString, "\r\r %1g	Area                                   |  Position |  FWHM   | GL-ratio  |   Asym.   | Asym. S. | Db. split  |  Db. ratio |\r",(i+1)
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------" 
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "\r       %16.4g   'Fit-coefficient'  |  %8.2f  |  %8.2f  |  %8.2f  |  %8.2f  |  %8.2f    |  %8.2f  |  %8.2f  |\r" ,  cwave[index], cwave[index+1] ,cwave[index+2] ,cwave[index+3] , cwave[index+4],cwave[index+5], cwave[index+6], cwave[index+7]
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "   %20.4g   'Fit wave area' \t Effective maximum position %8.2f \r",  area(W), V_maxloc // "-> In case of asymmetry, this value does not represent an area any more"
			Notebook $NoteBookName ,text=tempString
			sprintf tempString, "   %20.4g   'Analytical area' \t Effective Asymmetry = 1 - (fwhm_right)/(fwhm_left) %8.2f \r" ,	AnalyticalArea, GeneralAsymmetry
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "   %20.4g  'Doublet area' \t Effective FWHM %8.2f\r", cwave[index]*(1+cwave[index+7]),EffectiveFWHM     // "-> In case of asymmetry, this value does not represent an area any more"
			Notebook $NoteBookName ,text=tempString
			//sprintf tempString, "   %20.4g   'Analytical area'\r\r" ,AnalyticalArea
			 //Notebook $NoteBookName ,text=tempString
						
		endfor
		
		sprintf tempString, "\rThe 'area' fit-coefficient corresponds only to the area of one component of the doublet. The complete doublet area can be calculated according to: Doublet Area  = Area Fit-Coefficient ( 1 + Doublet Ratio)\r"
		Notebook $NoteBookName ,text=tempString
		sprintf tempString, "\r'Doublet area':    Calculated from the fit coefficients - not significant for asymmetric peaks!"
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString,"\r'Fit wave area':    Peak area within the measured energy range"
		Notebook $NoteBookName ,text=tempString																			    
		sprintf tempString,"\r'Analytical area': Obtained by numerically integrating the peak from 0 to (position + 1000eV)\r                        Significant also for asymmetric peaks - approximates the peak area from -INF to + INF\r"
		Notebook $NoteBookName ,text=tempString
		sprintf tempString,"\r\rPlease note that for asymmetric peaks the fit coefficients do not describe the physically relevant quantities any more. \rPlease refer to the respective 'effective' or 'analytical' values.\r"      
		Notebook $NoteBookName ,text=tempString
	

killwaves /z  fitted     //this applies to the original fit-wave of Igor, since it is a reference to the wave root:Igor-FitWave, the original wave is possibly wrong
duplicate /o locRefTempFit, $fitWave               //but we are still in the subfolder, 
killwaves /z locRefTempFit
wave fitted = $fitWave

//go back to the parent data folder
if (newFolder ==1)
	SetDataFolder parentDataFolder 

	//create a copy of the coefficient wave in the subfolder, so the waves 
	//and the complete fitting results are within that folder
	duplicate /o :$dataWave, :subfolder:$dataWave
	//if (WaveExists($RawXWave))
	if (Exists(RawXWave))
		duplicate /o :$RawXWave, :subfolder:$RawXWave
	endif

	//duplicate  :$fitWave, :subfolder:$fitWave
	killwaves /z :$fitWave            //probably fails, if the fit wave is displayed in the main panel as well
	AppendToGraph :subfolder:$fitWave                                 //draw the complete fit
	ModifyGraph rgb($fitWave) = (0,0,0)       //color-code it
	//Remove the original wave, which is located in the parent directory and replace it by the copy in the subfolder
	RemoveFromGraph $"#0" 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph :subfolder:$dataWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
			break
		case "_calculated_":
			AppendToGraph  :subfolder:$dataWave
			break
		default:                                                 // if not empty
			AppendToGraph :subfolder:$dataWave vs :subfolder:$RawXWave        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
	endswitch

	
	duplicate :T_Constraints, :subfolder:T_Constraints
	duplicate :Min_Limit, :subfolder:Min_Limit
	duplicate :Max_Limit, :subfolder:Max_Limit
	//if (WaveExists(LegendWave))
	//	duplicate :LegendWave, :subfolder:LegendWave
	//endif

	if (WaveExists(InitializeCoef))
		duplicate InitializeCoef, :subfolder:InitializeCoef
	endif
 	if (exists("epsilon"))
 		duplicate epsilon :subfolder:epsilon
 	endif
 	duplicate hold, :subfolder:hold
 	duplicate CoefLegend, :subfolder:CoefLegend
	duplicate cwave, :subfolder:W_Coef                 //now create that copy, leave the original 
														//coefficient wave where it is, maybe the 
														//user wants to try another fit

//Now rename the subfolder accordingly
//If there are any datafolders with peak-waves from previous runs are present, do
//not overwrite them, but create a foldername with a running index
// if a folder named "test" was present, name the new folder "test1", the next one "test2" and so on

	foldername = "VD"+num2istr(nPeaks)+ "_" + dataWave
	
	//foldername ="Fit_"+ dataWave
	i=1   //index variable for the data folder	
	tempFoldername = foldername            //used also for the notebook
	if (DataFolderExists(foldername))    //is there already a folder with this name
	//if yes:
	 //Append an index number to the current foldername and check if a folder with this name
	 //is already present. If so, increase the index number by one, append it to the basic foldername
	 //and check again. Repeat this procedure until a "free" name is found
		do
			tempFoldername = foldername + num2istr(i)
			i+=1
		while(DataFolderExists(tempFoldername))
		
		if ( strlen(tempFoldername) >= 30)	
			doalert 0, "The output folder name is too long! Please shorten the names. The output folder of the current run is named 'subfolder'."
		else
			RenameDataFolder subfolder, $tempFoldername                   //now rename the peak-folder accordingly
			Notebook  $NoteBookName, text="\r------------------------------------------------------------------------------"
			//remove illegal characters from the string
			tempFoldername = stringClean(tempFoldername)
			DoWindow /C $tempFoldername
			DoWindow /F $LastGraphName
			DoWindow /C $tempFoldername + "_graph"
			//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"   //valid in Igor 6.x
		endif
		//TextBox/N=text0/A=LT tempFoldername        //prints into the graph
	else 
		//if no:
		RenameDataFolder subfolder, $foldername 
		//TagWindow(foldername)
		Notebook  $NoteBookName, text="\r------------------------------------------------------------------------------"
		//if ( strsearch(foldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		//	foldername = ReplaceString(".", foldername,"_")
		//endif
		foldername = stringClean(foldername)
		tempFoldername = stringClean(tempFoldername)
		DoWindow /C $foldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
		//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"
		//TextBox/N=text0/A=LT foldername               //prints into the graph
	endif
	//everything up to now was done in a subfolder
else          //varialbe newFolder different from 1  create no new folder
	AppendToGraph $fitWave
	ModifyGraph rgb($fitWave) = (0,0,0)
	SetAxis/A/R bottom
	//find a name for the graph and the notebook, that reflects the location of the corresponding data
	String location = GetDataFolder (0)
	strswitch(location)
		case "root":
			tempFoldername = "fit" + dataWave
			break
		default:
			tempFoldername = location
			break
	endswitch

	Notebook  $NoteBookName, text="\r------------------------------------------------------------------------------"
	
	//if ( strsearch(tempFoldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
	//	tempFoldername = ReplaceString(".", tempFoldername,"_")
	//endif
	tempFoldername = stringClean(tempFoldername)
	V_Flag = 0
	DoWindow $tempFoldername    //check if it is there, if yes V_Flag is set to 1
	if (V_Flag)
		do
			V_Flag = 0   // it should be possible to use the cancel button
			Prompt tempFoldername, "There is already a report on this folder, please enter a new for the new report."
			DoPrompt /Help="Please use only letters, numbers and an underscore!" "Please enter a new name", tempFoldername
			if (V_Flag)  //user pressed cancel
				DoWindow /K Report //kill the notebook
				DoWindow /K $LastGraphName
				
				killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
				killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr
				return -1
			endif
			tempFoldername = stringClean(tempFoldername)
			DoWindow $tempFoldername    //check again and
		while (V_Flag)                                 //repeat until
		DoWindow /C $tempFoldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
		//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"
	else
		DoWindow /C $tempFoldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
		//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph" 
	endif
	//TextBox/N=text0/A=LT "fit"+dataWave
endif
 
//make the graph look good
ModifyGraph mode($dataWave)=3 ,msize($dataWave)=1.3 // ,marker($dataWave)=8, opaque($dataWave)=1
ModifyGraph opaque=1,marker($dataWave)=19
ModifyGraph rgb($dataWave)=(60928,60928,60928)
ModifyGraph useMrkStrokeRGB($dataWave)=1
ModifyGraph mrkStrokeRGB($dataWave)=(0,0,0)
//ModifyGraph mrkThick($dataWave)=0.7
//ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
ModifyGraph mirror=2,minor(bottom)=1
Label left "\\f01 intensity (counts)"
Label bottom "\\f01  binding energy (eV)"	
ModifyGraph width=255.118,height=157.465, standoff = 0, gfSize=11

//The following command works easily, but then the resulting graph is not displayed properly in the notebook
//SetAxis/A/R bottom
//instead do it like this:
variable left,right

strswitch(RawXWave)
	 	case "":
	 		 left = max(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 	break
	 	case "_calculated_":
	 		 left = max(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave,numpnts($dataWave)-1))
	 	break
	 	default:
	 		waveStats /Q $RawXWave
	 		left = V_max
	 		right = V_min
	 	break
 endswitch
 SetAxis bottom left,right
//okay this is not perfectly elegant ... but

WaveStats /Q $dataWave
SetAxis left V_min-0.05*(V_max-V_min), 1.02*V_max
LastGraphName = WinList("*", "", "WIN:")



Notebook  $tempFoldername, selection = {startOfFile,startOfFile}
tempString = "Fitting results for: " + tempFoldername + "\r"
Notebook  $tempFoldername, text=tempString
Notebook  $tempFoldername, selection = {startOfPrevParagraph,endOfPrevParagraph}, fsize = 12, fstyle = 0

Notebook  $tempFoldername, selection = {startOfNextParagraph,startOfNextParagraph}
Notebook  $tempFoldername, picture={$LastGraphName, 0, 1} , text="\r" 




//Notebook  $tempFoldername, text="\r \r"  

//now clean up
killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr

end 


//auxiliary functions, used by all of the memebers of the Pseudo-Voigt family
/////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////
				//Aux: Peak Analysis Functions
/////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////

//this expects a wave to be duplicated ... strange ... to be changed
static function CalcVoigtWaveManual(w0,w1,w2,w3,w4,w5,w6,w7,originalWave)
	//this order is identical to the order of the parameters in the fit static function
	variable w0 //area
	variable w1 //position
	variable w2 //width
	variable w3 //GLRatio
	variable w4 //asymmetry
	variable w5 //asymmetry shift
	variable w6 //spin-orbit splitting
   	variable w7 //spin-orbit ratio
	//those values are obtained from the doublet fit
	wave originalWave
	
	string firstName = "outwave"
	string secondName = "outwave2"
	
	duplicate /o originalWave $firstName
	duplicate /o originalWave $secondName
	
	wave outWave = $firstName                                                  									  
	wave outWave2 = $secondName
	//CalcSingleVoigtGLS( area,position , width , GLratio , asymmetry , asymmetry shift )
	outWave = CalcSingleVoigtGLS( w0 / (1+w7) ,w1,w2,w3,w4,w5,x)
	outWave2 = CalcSingleVoigtGLS( w0*w7 / (1+w7) , w1 + w6 ,w2,w3,w4,w5,x)
	
end



function IntegrateSingleVoigtGLS(w0, w1, w2, w3, w4,w5)
	variable w0
	variable w1
	variable w2
	variable w3
	variable w4
	variable w5
	
	variable  result = 0
	
	//now create a set of global variables
	killvariables /z root:tempW0,root:tempW1,root:tempW2,root:tempW3,root:tempW4, root:tempW5
	variable /G root:tempW0 = w0
	variable /G root:tempW1 = w1
	variable /G root:tempW2 = w2
	variable /G root:tempW3 = w3
	variable /G root:tempW4 = w4
	variable /G root:tempW5 = w5
	string resultString
	
	result = integrate1D(VoigtGLSFunction,w1-IntegrationInterval*w2, w1+IntegrationInterval*w2,1)    //2:Gauss//Romberg integration is much faster //integration stopped at zero for stability
	resultString= num2str(result)
	
	
	if (numType(result)!=0)   //something went wrong during integration
		print "Igors integrate1D static function had a problem! If the output makes no sense ( NaN displayed) you have possibly to modify the file IntegrationFunc.ipf."
		result = integrate1D(VoigtGLSFunction,max(0,w1-IntegrationInterval*w2), w1+IntegrationInterval*w2,1) 
		//result = integrate1D(VoigtGLSFunction,0, w1+2000,1)         //try this, if the integration does continuously give NaN, also try to vary the integration method, see the help on integrate1D()
		
	endif
	//clean up afterwards
	killvariables /Z root:tempW0, root:tempW1, root:tempW2, root:tempW3, root:tempW4, root:tempW5
	return result
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// Calculate the effective FWHM and general asymmetry

static function CalcFWHMSingleVoigtGLS(Varea,pos,fwhm,glR,asym,asymShift)
	variable Varea
	variable pos
	variable fwhm
	variable glR
	variable asym
	variable asymShift
	
	variable i=0
	variable step = 1e-3
	//When global variables are used, the static function for the integration can be re-used
	killvariables /z root:tempW0,root:tempW1,root:tempW2,root:tempW3,root:tempW4, root:tempW5
	variable /G root:tempW0 = Varea
	variable /G root:tempW1 = pos
	variable /G root:tempW2 = fwhm
	variable /G root:tempW3 = glR
	variable /G root:tempW4 = asym
	variable /G root:tempW5 = asymShift
	
	// Get suitable variables for determining the maximum height and position
	variable PreviousStepFunctionValue 
	variable CurrentStepFunctionValue 
	variable CurrentPos
	variable maxPos
	variable maxHeight
	
	//Get the real maximum and its location, do not use WaveStats /Q; it is applied to a discrete approximation of the static function, not the real thing --> truncation errors
	i = 1
	do 
		CurrentStepFunctionValue = VoigtGLSFunction(pos - 0.5*fwhm + i*step)
		PreviousStepFunctionValue = VoigtGLSFunction(pos - 0.5*fwhm + (i-1)*step)
		CurrentPos = (pos - 0.5*fwhm + i*step)
		i+= 1
	while (CurrentStepFunctionValue > PreviousStepFunctionValue)
	maxPos = CurrentPos
	maxHeight = PreviousStepFunctionValue     // in the last step, CurrentStepFunctionValue was already smaller then PreviousStepFunctionValue
	i = 0	
	
	
	variable upperPos = maxPos  //initialize at the "center"
	variable lowerPos = maxPos  //initialize at the "center"
	do
		upperPos = maxPos + i*step
		i+=1
	while (VoigtGLSFunction(upperPos) > 0.5*maxHeight)
	//now make a loop to determine where the Intensity is halfway down	
	do
		lowerPos = maxPos - i*step
		i+=1
	while (VoigtGLSFunction(lowerPos) > 0.5*maxHeight)
	
	
	
	//clean up afterwards
	killvariables /Z root:tempW0, root:tempW1, root:tempW2, root:tempW3, root:tempW4, root:tempW5
	return abs(upperPos - lowerPos)
end


// General asymmetry =  1 - (fwhm_right)/(fwhm_left)
static function CalcGeneralAsymmetry(Varea,pos,fwhm,glR,asym,asymShift)
	variable Varea
	variable pos
	variable fwhm
	variable glR
	variable asym
	variable asymShift
	
	variable i=0
	variable step = 1e-4
	//When global variables are used, the static function for the integration can be re-used
	killvariables /z root:tempW0,root:tempW1,root:tempW2,root:tempW3,root:tempW4, root:tempW5
	variable /G root:tempW0 = Varea
	variable /G root:tempW1 = pos
	variable /G root:tempW2 = fwhm
	variable /G root:tempW3 = glR
	variable /G root:tempW4 = asym
	variable /G root:tempW5 = asymShift
	

	// Get suitable variables for determining the maximum height and position
	variable PreviousStepFunctionValue 
	variable CurrentStepFunctionValue 
	variable CurrentPos
	variable maxPos
	variable maxHeight
	
	//Get the real maximum and its location, do not use WaveStats /Q; it is applied to a discrete approximation of the static function, not the real thing --> truncation errors
	i = 1
	do 
		CurrentStepFunctionValue = VoigtGLSFunction(pos - 0.5*fwhm + i*step)
		PreviousStepFunctionValue = VoigtGLSFunction(pos - 0.5*fwhm + (i-1)*step)
		CurrentPos = (pos - 0.5*fwhm + i*step)
		i+= 1
	while (CurrentStepFunctionValue > PreviousStepFunctionValue)
	maxPos = CurrentPos
	maxHeight = PreviousStepFunctionValue     // in the last step, CurrentStepFunctionValue was already smaller then PreviousStepFunctionValue
	i = 0	
	
	variable upperPos = maxPos  //initialize at the "center"
	variable lowerPos = maxPos  //initialize at the "center"
	
	do
		upperPos = maxPos + i*step
		i+=1
	while (VoigtGLSFunction(upperPos) > 0.5*maxHeight)
	//now make a loop to determine where the Intensity is halfway down
	i = 0	
	do
		lowerPos = maxPos - i*step
		i+=1
	while (VoigtGLSFunction(lowerPos) >0.5*maxHeight)
	
	
	
	//clean up afterwards
	killvariables /Z root:tempW0, root:tempW1, root:tempW2, root:tempW3, root:tempW4, root:tempW5
	variable Gasym =  (abs(lowerPos - maxPos)/abs(upperPos - maxPos))
	return 1 - Gasym
end


function VoigtGLSFunction(x)    //can't be static because of integrate1D
	variable x
	NVAR w0 = root:tempW0
	NVAR w1 = root:tempW1
	NVAR w2 = root:tempW2
	NVAR w3 = root:tempW3
	NVAR w4 = root:tempW4
	NVAR w5 = root:tempW5
	variable result
	result = 0
	variable loc
	variable width
	
	//loc = x - w1
	//width = 2*w2/ ( 1+ exp( -w4 * (loc - w5 )))
	result  =  ( w3 *  w0 * 2 / pi ) *  ( 2*w2/ ( 1+ exp(- w4 *(x - w1-w5))) ) / ( ( 2*w2/ ( 1+ exp( - w4* (x - w1-w5))) )^2 + 4 * ( x - w1 )^2 )   
	result += ( 1 - w3 ) * ( w0 / ( gPf * ( 2*w2/ ( 1+ exp( - w4 * (x - w1-w5))) ) ) ) * exp ( -gAf  * ( ( x - w1 ) / ( 2*w2/ ( 1+ exp( - w4 * (x - w1-w5))) ) )^2 ) 
	
	if (w4 >= 0.01)
		result *= integrationCorrection
	endif
	//result  =  ( w3 *  0.636619772 ) *  ( width) / ( ( width )^2 + 4 * (loc )^2 )   
	//result += ( 1 - w3 ) * (1 / ( gPf * (  width ) ) ) * exp ( - gAf  * ( ( loc ) / ( width ) )^2 ) 
	//result *= w0
	
	return result
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// The following two functions enable a numerical integration of the voigt-static function over an arbitrary range

static function IntegrateVoigtDoublet(w0, w1, w2, w3, w4,w5,w6,w7)
	variable w0  //area
	variable w1  //position
	variable w2  //width
	variable w3  //GL ratio
	variable w4  //asymmetry
	variable w5  //asymmetry shift
	variable w6 //spin splitting
	variable w7 //spin ratio
	variable  result
	//now create a set of global variables
	killvariables /z root:tempW0,root:tempW1,root:tempW2,root:tempW3,root:tempW4, root:tempW5, root:tempW6, root:tempW7  //just in case ...make tabula rasa
	variable /G root:tempW0 = w0
	variable /G root:tempW1 = w1
	variable /G root:tempW2 = w2
	variable /G root:tempW3 = w3
	variable /G root:tempW4 = w4
	variable /G root:tempW5 = w5
	variable /G root:tempW6 = w6
	variable /G root:tempW7 = w7
		
	result = integrate1D(VoigtDoubletFunction,0, w1+w6+1000,1)    //Romberg integration is much faster

	//clean up afterwards
	killvariables /Z root:tempW0, root:tempW1, root:tempW2, root:tempW3, root:tempW4, root:tempW5, root:tempW6, root:tempW7
	return result
end

function VoigtDoubletFunction(x)
	variable x
	NVAR w0 = root:tempW0   //width
	NVAR w1 = root:tempW1   //position
	NVAR w2 = root:tempW2   //width
	NVAR w3 = root:tempW3   //GL ratio
	NVAR w4 = root:tempW4   //asymmetry
	NVAR w5 = root:tempW5   //asymmetry shift
	NVAR w6 = root:tempW6   //spin splitting
	NVAR w7 = root:tempW7   //spin ratio
	
	variable result
	result = 0
	//first peak
	result  =  ( w3 *  w0 * 2 / pi ) *  ( 2*w2/ ( 1+ exp(- w4 *(x - w1-w5))) ) / ( ( 2*w2/ ( 1+ exp( - w4* (x - w1-w5))) )^2 + 4 * ( x - w1 )^2 )   
	result += ( 1 - w3 ) * ( w0 / ( gPf * ( 2*w2/ ( 1+ exp( - w4 * (x - w1-w5))) ) ) ) * exp ( -gAf  * ( ( x - w1 ) / ( 2*w2/ ( 1+ exp( - w4 * (x - w1-w5))) ) )^2 ) 
	//second peak
	result +=  ( w3 * w7 * w0 * 2 / pi ) *  ( 2*w2/ ( 1+ exp( - w4 * (x - w6 - w1- w5))) ) / ( (2*w2/ ( 1+ exp( - w4 * (x - w6 - w1 - w5))) )^2 + 4 * ( x -  w6 - w1 )^2 )   
	result += ( 1 - w3 ) * ( w0 * w7 / ( gPf * (  2*w2/ ( 1+ exp( - w4 * (x - w6 - w1 -w5 ))) ) ) ) * exp ( -gAf  * ( ( x - w6 - w1 ) / ( 2*w2/ ( 1+ exp( - w4 * (x - w6 - w1-w5))) ) )^2 ) 
	return result
end




// the following two functions enable a numerical integration of the voigt-static function over an arbitrary range
static function IntegrateSingleVoigtGLS2(w0, w1, w2, w3, w4,peakMax)
	variable w0
	variable w1
	variable w2
	variable w3
	variable w4
	variable peakMax
	variable start, stop
	variable  result
	variable threshold
	variable tempValue
	//now create a set of global variables
	killvariables /z root:tempW0,root:tempW1,root:tempW2,root:tempW3,root:tempW4
	variable /G root:tempW0 = w0
	variable /G root:tempW1 = w1
	variable /G root:tempW2 = w2
	variable /G root:tempW3 = w3
	variable /G root:tempW4 = w4
	variable step = 0.1
	//Now implement an algorithm, that searches for the the range, where the amplitude is larger than 1% of the maximum value
	threshold = 0.01* peakMax
	start = w1
	stop = w1
	
	if (w4 > 2)
		step = 5
	elseif ( w4 > 1 && w4 <= 2 )
		step = 2
	elseif ( w4 >0.75 && w4 <=1)
		step = 1
	elseif ( w4 > 0.5 && w4 <= 0.75)
		step = 0.2
	endif
	
	do
		start = start - step
		tempValue = VoigtGLS2Function(start) 
	while ( tempValue > threshold)

	do
		stop = stop + step
		tempValue = VoigtGLS2Function(stop) 
	while ( tempValue > threshold)

	result = integrate1D(VoigtGLS2Function,start, stop,1)    //Romberg integration is much faster

	//clean up afterwards
	killvariables /Z root:tempW0, root:tempW1, root:tempW2, root:tempW3, root:tempW4
	return result
end



function VoigtGLS2Function(x)
	variable x
	NVAR w0 = root:tempW0
	NVAR w1 = root:tempW1
	NVAR w2 = root:tempW2
	NVAR w3 = root:tempW3
	NVAR w4 = root:tempW4
	variable result
	result = 0
	if (x >= w1 )
		result  =  ( w3 *  w0 * 2 / pi ) *  ( 2 * w4 * ( x - w1 ) + w2 ) / ( ( w2 + 2 * w4 * ( x - w1 ) )^2 + 4 * ( x - w1 )^2 )   
		result += ( 1 - w3 ) * ( w0 / ( gPf * (  2 * w4 * ( x - w1 ) + w2 ) ) ) * exp ( -gAf  * ( ( x - w1 ) / ( w2 + 2 * w4* ( x - w1 ) ) )^2 ) 
	else
		result  =  ( 2 * w3 * w0 * (w2*exp(w4*(x-w1) ) ) / pi )  / (  ( w2 *exp(w4*(x-w1) ))^2 + 4* ( x - w1 )^2 ) 
		result += ( 1 - w3 ) * ( w0 / ( gPf * ( w2*exp(w4*(x-w1 )) ) ) ) * exp ( - gAf * ( ( x - w1 ) / ( w2 *exp(w4*(x-w1 )) ) )^2 ) 
	endif
	return result
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// The following two functions enable a numerical integration of the voigt-static function over an arbitrary range

static function IntegrateVoigtDublet2(w0, w1, w2, w3, w4,w5,w6,peakMax)
	variable w0
	variable w1
	variable w2
	variable w3
	variable w4
	variable w5
	variable w6
	variable peakMax
	variable start, stop
	variable  result
	variable threshold
	variable tempValue
	//now create a set of global variables
	killvariables /z root:tempW0,root:tempW1,root:tempW2,root:tempW3,root:tempW4
	variable /G root:tempW0 = w0
	variable /G root:tempW1 = w1
	variable /G root:tempW2 = w2
	variable /G root:tempW3 = w3
	variable /G root:tempW4 = w4
	variable /G root:tempW5 = w5
	variable /G root:tempW6 = w6
	variable step = 0.1
	//Now implement an algorithm, that searches for the the range, where the amplitude is larger than 1% of the maximum value
	threshold = 0.01* peakMax
	start = w1
	stop = w1 + w6
	
	if (w4 > 2)
		step = 5
	elseif ( w4 > 1 && w4 <= 2 )
		step = 2
	elseif ( w4 >0.75 && w4 <=1)
		step = 1
	elseif ( w4 > 0.5 && w4 <= 0.75)
		step = 0.2
	endif
	
	do
		start = start - step
		tempValue = VoigtDublet2Function(start) 
	while ( tempValue > threshold)

	do
		stop = stop + step
		tempValue = VoigtDublet2Function(stop) 
	while ( tempValue > threshold)

	result = integrate1D(VoigtDublet2Function,start, stop,1)    //Romberg integration is much faster

	//clean up afterwards
	killvariables /Z root:tempW0, root:tempW1, root:tempW2, root:tempW3, root:tempW4, root:tempW5, root:tempW6
	return result
end

function VoigtDublet2Function(x)
	variable x
	NVAR w0 = root:tempW0
	NVAR w1 = root:tempW1
	NVAR w2 = root:tempW2
	NVAR w3 = root:tempW3
	NVAR w4 = root:tempW4
	NVAR w5 = root:tempW5
	NVAR w6 = root:tempW6
	
	variable result
	result = 0
	
	if (x >= (w1 + w6) )   // both peaks asymmetric
		//first peak
		result  =  ( w3 *  w0 * 2 / pi ) *  ( 2 * w4 * ( x - w1 ) + w2 ) / ( ( w2 + 2 * w4 * ( x - w1 ) )^2 + 4 * ( x - w1 )^2 )   
		result += ( 1 - w3 ) * ( w0 / ( gPf * (  2 * w4 * ( x - w1 ) + w2 ) ) ) * exp ( -gAf  * ( ( x - w1 ) / ( w2 + 2 * w4* ( x - w1 ) ) )^2 ) 
		//second peak
		result +=  ( w3 * w5 * w0 * 2 / pi ) *  ( 2 * w4 * ( x - w6 - w1 ) + w2 ) / ( ( w2 + 2 * w4 * ( x - w6 - w1 ) )^2 + 4 * ( x -  w6 - w1 )^2 )   
		result += ( 1 - w3 ) * ( w0 * w5 / ( gPf * (  2 * w4 * ( x - w6 - w1 ) + w2 ) ) ) * exp ( -gAf  * ( ( x - w6 - w1 ) / ( w2 + 2 * w4* ( x - w6 - w1 ) ) )^2 ) 
	
	elseif  ( x >=	w1 && x < (w1 + w6) )     //the peak at w1 still asymmetric, the other one symmetric
		//first peak at w1 still asymmetric
		result  =  ( w3 *  w0 * 2 / pi ) *  ( 2 * w4 * ( x - w1 ) + w2 ) / ( ( w2 + 2 * w4 * ( x - w1 ) )^2 + 4 * ( x - w1 )^2 )   
		result += ( 1 - w3 ) * ( w0 / ( gPf * (  2 * w4 * ( x - w1 ) + w2 ) ) ) * exp ( -gAf  * ( ( x - w1 ) / ( w2 + 2 * w4* ( x - w1 ) ) )^2 ) 
		//second peak at w1+w6 , now symmetric 
		result +=  ( 2 * w3 * w0 * w5* w2 / pi )  / (  w2^2 + 4* ( x - w6 - w1 )^2 ) 
		result += ( 1 - w3 ) * ( w0 *w5 / ( gPf * w2 ) ) * exp ( - gAf * ( ( x - w6 - w1 ) / w2 )^2 ) 
	else  //both symmetric
		result  =  ( 2 * w3 * w0 * w2 / pi )  / (  w2^2 + 4* ( x - w1 )^2 ) 
		result += ( 1 - w3 ) * ( w0 / ( gPf * w2 ) ) * exp ( - gAf * ( ( x - w1 ) / w2 )^2 ) 
		
		result +=  ( 2 * w3 * w0 * w5* w2 / pi )  / (  w2^2 + 4* ( x - w6 - w1 )^2 ) 
		result += ( 1 - w3 ) * ( w0 *w5 / ( gPf * w2 ) ) * exp ( - gAf * ( ( x - w6 - w1 ) / w2 )^2 ) 
	endif
	
	return result
end



static function CalcSingleVoigtGLS(w0,w1,w2,w3,w4,w5,x)
	variable w0     //area
	variable w1    //position
	variable w2    //width
	variable w3    // GL-ratio
	variable w4    // Asymmetry
	variable w5 // asymmetry  shift
	variable x

	variable result
	result = 0

	 result  += (w3>0)*(w3 )* ( w0 * 2 / pi ) *  ( 2 * w2 / ( 1 + exp (- w4* ( x - w1 - w5 )  )   )  )  /  (   ( 2 * w2 / ( 1 + exp (- w4*(x-w1-w5) ) ) )^2 + 4 * ( x - w1 )^2    )   
	 result += (w3<1)*( 1 - w3 ) * ( w0 / ( gPf * ( 2 * w2 / ( 1 + exp ( - w4*(x-w1-w5) ) ) ) ) ) * exp ( -gAf  * ( ( x - w1 ) / ( 2 * w2 / ( 1 + exp ( - w4*(x-w1-w5) ) ) ) )^2 ) 

	if (w4 >= 0.01)
		result *= integrationCorrection
	endif
	
	return result
end


static function CalcVoigtDoublet(w0,w1,w2,w3,w4,w5,w6,w7,x)
	variable w0     //area
	variable w1    //position
	variable w2    //width
	variable w3    // GL-ratio
	variable w4    // Asymmetry
	variable w5    //asymmetry shift
	variable w6   //peak splitting
	variable w7 //peak ratio ratio
	variable x
	variable result
	result = 0

	//first peak
	result +=  w3* (  (w0 * 2) / pi ) *  ( 2 * w2 / ( 1 + exp ( - w4*(x-w1 - w5 ) ) ) ) / ( ( 2 * w2 / ( 1 + exp ( - w4*(x-w1- w5) ) ) )^2 + 4 * ( x - w1 )^2 )   
	result += ( 1 - w3 ) * ( w0 / ( gPf * (  2 * w2 / ( 1 + exp ( - w4*(x-w1- w5) ) ) ) ) ) * exp ( -gAf  * ( ( x - w1 ) / ( 2 * w2 / ( 1 + exp ( - w4*(x-w1- w5) ) ) ) )^2 ) 
	//second peak
	result +=  ( w3 * w7 * w0 * 2 / pi ) *  ( 2 * w2 / ( 1 + exp ( - w4*(x - w6 - w1 - w5) ) ) ) / ( ( 2 * w2 / ( 1 + exp ( - w4*(x - w6 - w1 - w5) ) ) )^2 + 4 * ( x -  w6 - w1 )^2 )   
	result += ( 1 - w3 ) * ( w0 * w7 / ( gPf * (  2 * w2 / ( 1 + exp ( - w4*(x - w6 - w1 - w5 ) ) )) ) ) * exp ( -gAf  * ( ( x - w6 - w1 ) / (2 * w2 / ( 1 + exp ( - w4*(x - w6 - w1 -w5) ) ) ) )^2 ) 

	return result
end


// static function used after pressing Add peak -> get an estimator for the peak area from the height of the cursor on the display

static function EstimatePeakArea( height , width , glR , asym , asymShift )	
	variable height , width , glR , asym , asymShift
	variable valueAtMaximum
	variable NewWidth = 2 * width / ( 1 + exp ( asym * asymShift  ) )

	valueAtMaximum =  glR* (  2 / pi ) *  ( NewWidth ) / ( ( NewWidth )^2 )   
	valueAtMaximum += ( 1 - glR ) * (1 / ( gPf * ( NewWidth ) ) ) 
	//peak with an fit coefficient of exactly 1


	return  height / valueAtMaximum // by so many times the fit coefficient is too low

end




//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
///			SpecDoubletSK
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////


static function AddVoigtSKDoublet(coefWave,RawYWave,indepCheck,heightA,posA,initialSlope, initialOffset, left,right,Wcoef_length)

string coefWave     //this won't be needed in the future ... for now, leave it here
string RawYWave
variable indepCheck
variable heightA
variable posA	
variable initialSlope
variable initialOffset
variable left
variable right
variable Wcoef_length

NVAR peakToLink = root:STFitAssVar:STPeakToLink
string parameterList = "a;p;w;g;as;at;dr;ds;db"   //ratio doublet, shift doublet, broadening doublet

NVAR linkArea = root:STFitAssVar:AreaLink
NVAR linkPosition = root:STFitAssVar:PositionLink
NVAR linkWidth = root:STFitAssVar:WidthLink
NVAR linkGL = root:STFitAssVar:GLLink
NVAR linkAsym = root:STFitAssVar:AsymLink
NVAR linkSplitting = root:STFitAssVar:SOSLink
NVAR linkMultiRatio = root:STFitAssVar:DoubletRatioLink

NVAR areaLinkUpperFactor = root:STFitAssVar:AreaLinkFactorHigh
NVAR areaLinkLowerFactor = root:STFitAssVar:AreaLinkFactorLow
NVAR positionLinkOffsetMax = root:STFitAssVar:PositionLinkOffsetMax
NVAR positionLinkOffsetMin = root:STFitAssVar:PositionLinkOffsetMin

string name = "CursorPanel#guiCursorDisplay" 	
variable nPeaks,i,numPara,EstimatedPeakArea
variable epsilonVal=1e-5

wave /t source = STsetup  //everything is in the setup
wave sw = selSTSetup

wave /t  numerics = Numerics
wave selNumerics = selNumerics

variable length = DimSize(source,0)
variable NumLength = DimSize(numerics,0)

variable numpeaks = 0
//print numpeaks
variable index
variable newLength


variable numCoef = 9  // number of coefficients.  for extended Multiplet, =33 for Dublet  9
variable numSubPeaks = 2  // number of Peaks in Multiplet.           for extended Multiplet = 10

WaveStats /Q $RawYWave
heightA = vcsr(A,name) - (initialSlope*posA+initialOffset)		//V_min						
EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)	


if (length == 0)
	Redimension /n=(numCoef+5,-1) source     // 5 = bg coefficients
	Redimension /n=(numCoef+5,-1) sw          //  
	
	numpeaks = 0
	//set writing permissions and checkbox controls
	for ( i= 0; i<length + numCoef +5; i+=1)             // Ext-multiplet  20-->38
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor

	source[length][0] = "Offset at E = 0 eV"
	source[length + 1][0] = "Slope"
	source[length + 2][0] = "Parabola"
	source[length + 3][0] = "Pseudo Tougaard (Herrera-Gomez)"
	source[length + 4][0] = "Shirley Step Height"
	source[length + 5][0] =         "Area  (first subpeak)  --------------      Doublet  " + num2str(numpeaks+1) 
	source[length + 6][0] =   "Position                                (subpeak 1)                          "
	source[length + 7][0] =   "Width"
	source[length + 8][0] =   "Gauss-Lorentz Ratio"
	source[length + 9][0] =   "Asymmetry"
	source[length + 10][0] = "Asymmetry Translation"
	source[length + 11][0] = "Doublet Ratio                    subpeak  2 : 1"
	source[length + 12][0] = "Doublet Shift                                   2 - 1"
	source[length + 13][0] = "Doublet Broadening                         2 : 1"
	
	
	

	source[length][1] = "off" 
	source[length + 1][1] = "sl"
	source[length + 2][1] = "prb" 
	source[length + 3][1] = "tgd" 
	source[length + 4][1] = "srl"
	source[length + 5][1] = "a" + num2str(numpeaks+1)
	source[length + 6][1] = "p" + num2str(numpeaks+1)
	source[length + 7][1] = "w" + num2str(numpeaks+1)
	source[length + 8][1] = "g" + num2str(numpeaks+1)
	source[length + 9][1] = "as" + num2str(numpeaks+1)
	source[length + 10][1] = "at" + num2str(numpeaks+1)
	source[length + 11][1] = "dr" + num2str(numpeaks+1)
	source[length + 12][1] = "ds" + num2str(numpeaks+1)
	source[length + 13][1] = "db" + num2str(numpeaks+1)
	
	
	
	source[length][4] = "off" 
	source[length + 1][4] = "sl"
	source[length + 2][4] = "prb" 
	source[length + 3][4] = "tgd" 
	source[length + 4][4] = "srl"
	source[length + 5][4] = "a" + num2str(numpeaks+1)
	source[length + 6][4] = "p" + num2str(numpeaks+1)
	source[length + 7][4] = "w" + num2str(numpeaks+1)
	source[length + 8][4] = "g" + num2str(numpeaks+1)
	source[length + 9][4] = "as" + num2str(numpeaks+1)
	source[length + 10][4] = "at" + num2str(numpeaks+1)
	source[length + 11][4] = "dr" + num2str(numpeaks+1)
	source[length + 12][4] = "ds" + num2str(numpeaks+1)
	source[length + 13][4] = "db" + num2str(numpeaks+1)

	

	EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
	source[length][3] = MyNum2str(initialOffset)//MyNum2str(max(0,V_min)) 
	source[length + 1][3] = MyNum2str(initialSlope)
	source[length + 2][3] = "0" 
	source[length + 3][3] = "0" 
	source[length + 4][3] = "0" //MyNum2str(0.1*abs(heightA-V_min))
	source[length + 5][3] = MyNum2str(EstimatedPeakArea)
	source[length + 6][3] = MyNum2str(posA)
	source[length + 7][3] = MyNum2str(Width_Start)
	source[length + 8][3] = MyNum2str(GLratio_Start)
	source[length + 9][3] = MyNum2str(Asym_Start)
	source[length + 10][3] = MyNum2str(Asym_Shift_Start)
	source[length + 11][3] = "0.5"
	source[length + 12][3] = "1.5"
	source[length + 13][3] = "1"
	
	
	
	
	sw[length +2][4][0] = 48
	sw[length +3][4][0] = 48   //check checkboxes
	
	sw[length +8][4][0] = 48
	sw[length +9][4][0] = 48
	sw[length +10][4][0] = 48
	sw[length +11][4][0] = 48
	sw[length +12][4][0] = 48
	sw[length +13][4][0] = 48
	
	sw[length+2][5][0] = 0   
	sw[length+3][6][0] = 0    
	
	
	source[length][5] = MyNum2str(-10*abs(initialOffset)) 
	source[length + 1][5] = MyNum2str(-10*abs(initialSlope))
	source[length + 2][5] = "-100" 
	source[length + 3][5] = "-1000" 
	source[length + 4][5] = "1e-6"
	source[length + 5][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
	source[length + 6][5] = MyNum2str(posA-1.5)//MyNum2str(right)
	source[length + 7][5] = MyNum2str(Width_Min)
	source[length + 8][5] =  MyNum2str(GLratio_Min)
	source[length + 9][5] = MyNum2str(Asym_Min)
	source[length + 10][5] = MyNum2str(Asym_Shift_Min)
	source[length + 11][5] = "0.02"
	source[length + 12][5] = "0.1"
	source[length + 13][5] = "0.5"

	
	
	
	source[length][6] = MyNum2str(10*abs(initialOffset))
	source[length + 1][6] = MyNum2str(10*abs(initialSlope))
	source[length + 2][6] = "100" 
	source[length + 3][6] = "1000" 
	source[length + 4][6] = MyNum2str(0.7*abs(V_min-heightA))
	source[length + 5][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
	source[length + 6][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
	source[length + 7][6] = MyNum2str(Width_Max )
	source[length + 8][6] = MyNum2str(GLratio_Max)
	source[length + 9][6] = MyNum2str(Asym_Max)
	source[length + 10][6] = MyNum2str(Asym_Shift_Max)
	source[length + 11][6] = "10"
	source[length + 12][6] = "3"
	source[length + 13][6] = "4"




	source[length][7] = "1e-9" 
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9" 
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-8"
	source[length + 6][7] = "1e-9"
	source[length + 7][7] = "1e-9"
	source[length + 8][7] = "1e-9" 
	source[length + 9][7] = "1e-9"
	source[length + 10][7] = "1e-9"
	source[length + 11][7] = "1e-9"
	source[length + 12][7] = "1e-9"
	source[length + 13][7] = "1e-9" 
else
	//now, linking can come into the game ... it will affect the columns 3,4,5,6
	
	newLength = length  + numCoef    // '15' multiplet static function, 33 for decaplet  Ext-multiplet  15-->33
		
	Redimension /n=(newLength,-1) source
	Redimension /n=(newLength,-1) sw	
	
	
	
	numpeaks = floor((length-5)/numCoef)    //needs to be changed   Ext-multiplet   15-->33
	for ( i= length; i<newLength; i+=1)
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor
	
	source[length][0] =         "Area  (first subpeak)  -  --------------      Doublet  " + num2str(numpeaks+1) 
	source[length + 1][0] =   "Position                                (subpeak 1)                          "
	source[length + 2][0] =   "Width"
	source[length + 3][0] =   "Gauss-Lorentz Ratio"
	source[length + 4][0] =   "Asymmetry"
	source[length + 5][0] =   "Asymmetry Translation"
	source[length + 6][0] =   "Doublet Ratio                subpeak 2 : 1"
	source[length + 7][0] =   "Doublet Shift                                2 - 1"
	source[length + 8][0] =   "Doublet Broadening                     2 : 1"
	
	
	source[length][1] = "a" + num2str(numpeaks+1)
	source[length + 1][1] = "p" + num2str(numpeaks+1)
	source[length + 2][1] = "w" + num2str(numpeaks+1)
	source[length + 3][1] = "g" + num2str(numpeaks+1)
	source[length + 4][1] = "as" + num2str(numpeaks+1)
	source[length + 5][1] = "at" + num2str(numpeaks+1)
	source[length + 6][1] = "dr" + num2str(numpeaks+1)
	source[length + 7][1] = "ds" + num2str(numpeaks+1)
	source[length + 8][1] = "db" + num2str(numpeaks+1)


     // start: take care of linking
     if (peakToLink == 0)
		EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
		source[length][3] = MyNum2str(EstimatedPeakArea)
		source[length + 1][3] = MyNum2str(posA)
		source[length + 2][3] = MyNum2str(Width_Start)
		source[length + 3][3] = MyNum2str(GLratio_Start)
		source[length + 4][3] = MyNum2str(Asym_Start)
		source[length + 5][3] = MyNum2str(Asym_Shift_Start)
		source[length + 6][3] = "0.5"
		source[length + 7][3] = "1.5"
		source[length + 8][3] = "1"
	
	
	
		sw[length +3][4][0] = 48
		sw[length +4][4][0] = 48
		sw[length +5][4][0] = 48   //check checkboxes
	
		sw[length +6][4][0] = 48
		sw[length +7][4][0] = 48
		sw[length +8][4][0] = 48
		sw[length +9][4][0] = 48
		sw[length +10][4][0] = 48
		sw[length +11][4][0] = 48
		sw[length +12][4][0] = 48
		sw[length +13][4][0] = 48
	
		source[length][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
		source[length + 1][5] = MyNum2str(posA-1.5)// MyNum2str(right)
		source[length + 2][5] = MyNum2str(Width_Min)
		source[length + 3][5] =  MyNum2str(GLratio_Min)
		source[length + 4][5] = MyNum2str(Asym_Min)
		source[length + 5][5] = MyNum2str(Asym_Shift_Min)
		source[length + 6][5] = "0.02"
		source[length + 7][5] = "0.1"
		source[length + 8][5] = "0.5"
	

		source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		source[length + 2][6] = MyNum2str(Width_Max )
		source[length + 3][6] = MyNum2str(GLratio_Max)
		source[length + 4][6] = MyNum2str(Asym_Max)
		source[length + 5][6] = MyNum2str(Asym_Shift_Max)
		source[length + 6][6] = "10"
		source[length + 7][6] = "3"
		source[length + 8][6] = "4"
	else
		//get the startingIndex of the target peak
		variable startIndexParentPeak = numCoef * (peakToLink -1 ) + 5		//  Ext-multiplet  15 --> 33
	
		if ( linkArea == 0 )
			EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
			source[length][3] = MyNum2str(EstimatedPeakArea)
			sw[length][4][0] = 32
			source[length][5] = MyNum2str(min(10,0.2 * EstimatedPeakArea ))  
			source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		else
			
			source[length][3] = MyNum2str( areaLinkLowerFactor * str2num(source[startIndexParentPeak][3]) )    //start at the lower boundary
			sw[length][4][0] = sw[startIndexParentPeak][4][0]
			source[length][5] = MyNum2str(areaLinkLowerFactor - 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
			source[length ][6] = MyNum2str(areaLinkUpperFactor + 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkPosition == 0 )
			source[length + 1][3] = MyNum2str(posA)
			sw[length + 1][4][0] = 32
			source[length + 1][5] = MyNum2str(posA-1.5) //MyNum2str(right)
			source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		else
			source[length + 1][3] = MyNum2str( str2num( source[startIndexParentPeak + 1][3] ) + positionLinkOffsetMin )
			sw[length + 1][4][0] = sw[startIndexParentPeak +1][4][0]
			source[length + 1][5] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMin-0.01)
			source[length + 1][6] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMax + 0.01)
		endif
		
		if ( linkWidth == 0 )
			source[length + 2][3] = MyNum2str(Width_Start)
			sw[length + 2][4][0] = 32
			source[length + 2][5] = MyNum2str(Width_Min)
			source[length + 2][6] = MyNum2str(Width_Max )
		else
			source[length + 2][3] = source[startIndexParentPeak + 2][3]
			sw[length + 2][4][0] = sw[startIndexParentPeak +2][4][0]
			source[length + 2][5] = StringFromList(2,parameterList) + num2str(peakToLink)
			source[length + 2][6] = StringFromList(2,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkGL == 0 )
			source[length + 3][3] = MyNum2str(GLratio_Start)
			sw[length + 2][4][0] = 32
			source[length + 3][5] =  MyNum2str(GLratio_Min)
			source[length + 3][6] = MyNum2str(GLratio_Max)
		else
			source[length + 3][3] = source[startIndexParentPeak + 3][3]
			sw[length + 3][4][0] = sw[startIndexParentPeak +3][4][0]
			source[length + 3][5] =  StringFromList(3,parameterList) + num2str(peakToLink)
			source[length + 3][6] = StringFromList(3,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkAsym == 0 )
			source[length + 4][3] = MyNum2str(Asym_Start)
			source[length + 5][3] = MyNum2str(Asym_Shift_Start)
			sw[length +3][4][0] = 48
			sw[length +4][4][0] =  48
			sw[length +5][4][0] =  48   //check checkboxes
			source[length + 4][5] = MyNum2str(Asym_Min)
			source[length + 5][5] = MyNum2str(Asym_Shift_Min)
			source[length + 4][6] = MyNum2str(Asym_Max)
			source[length + 5][6] = MyNum2str(Asym_Shift_Max)
		else
			source[length + 4][3] = source[startIndexParentPeak + 4][3]
			source[length + 5][3] = source[startIndexParentPeak + 5][3]
			sw[length +3][4][0] = sw[startIndexParentPeak +3][4][0]
			sw[length +4][4][0] = sw[startIndexParentPeak +4][4][0]
			sw[length +5][4][0] = sw[startIndexParentPeak +5][4][0]
			source[length + 4][5] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][5] = StringFromList(5,parameterList) + num2str(peakToLink)
			source[length + 4][6] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][6] = StringFromList(5,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkMultiRatio == 0)  //link ratio and broadening
			//starting guess       for ratios
			source[length + 6][3] = "0.5"
			
			//hold true or false
			sw[length + 6][4][0] = 48

			
			//limits
			source[length + 6][5] = "0.02"

			
			source[length + 6][6] = "10"

			
		
		else
			
			source[length + 6][3] =  source[startIndexParentPeak + 6][3]
	
			
			sw[length + 6][4][0] = sw[startIndexParentPeak +6][4][0]
	
			
			source[length + 6][5] =  StringFromList(6,parameterList) + num2str(peakToLink)
	
			
			source[length + 6][6] =  StringFromList(6,parameterList) + num2str(peakToLink)


		endif
		
		if ( linkSplitting == 0) //this has to be adapted    // 
			//starting guess       splitting
			source[length + 7][3] = "1.5"

			
			//hold true or false
			sw[length + 7][4][0] = 48

			
			//limits
			source[length + 7][5] = "0.1"

			
			source[length + 7][6] = "3"

			
			//starting guess ..........       now  for broadening
			source[length + 8][3] = "1"
	
			
			//hold true or false
			sw[length + 8][4][0] = 48
	
						
			//limits
			source[length + 8][5] = "0.5"
	
			
			source[length + 8][6] = "4"
	
			
		else
			source[length + 7][3] =    source[startIndexParentPeak + 7][3]

			source[length + 8][3] = source[startIndexParentPeak + 8][3]
		
			
			sw[length + 7][4][0] = sw[startIndexParentPeak +7][4][0]
	
			
			sw[length + 8][4][0] = sw[startIndexParentPeak +8][4][0]


			source[length + 7][5] =  StringFromList(7,parameterList) + num2str(peakToLink)

			
			source[length + 8][5] =  StringFromList(8,parameterList) + num2str(peakToLink)

			
			
			source[length + 7][6] =  StringFromList(7,parameterList) + num2str(peakToLink)

			
			source[length + 8][6] =  StringFromList(8,parameterList) + num2str(peakToLink)
		
		endif
	endif
	// stop: take care of linking
	
	source[length][4] = "a" + num2str(numpeaks+1) 
	source[length + 1][4] = "p" + num2str(numpeaks+1)
	source[length + 2][4] = "w" + num2str(numpeaks+1)
	source[length + 3][4] = "g" + num2str(numpeaks+1) 
	source[length + 4][4] = "as" + num2str(numpeaks+1) 
	source[length + 5][4] = "at" + num2str(numpeaks+1) 
	source[length + 6][4] = "dr" + num2str(numpeaks+1)
	source[length + 7][4] = "ds" + num2str(numpeaks+1)
	source[length + 8][4] = "db" + num2str(numpeaks+1)

	
	
	
	source[length][7] = "1e-8"
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9"
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-9"
	source[length + 6][7] = "1e-9"
	source[length + 7][7] = "1e-9"
	source[length + 8][7] = "1e-9" 


	
endif

	Redimension /n=(NumLength+8,-1) numerics   //has to be changed Ext-multiplet  16-->34 should be, setting 40 instead for Dublet 10?
	Redimension /n=(NumLength+8,-1) selNumerics
	
	//numerics[NumLength][0] = "Multiplet " + MyNum2str(numpeaks+1)
	numerics[NumLength + 0][0] = " Doublet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 1][0] = " Peak 1"
	numerics[NumLength + 4][0] = " Doublet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 5][0] =  " Peak 2"
	
	numerics[NumLength + 1][1] = "Area "
	numerics[NumLength + 5][1] = "Area "


//	numerics[NumLength + 2 ][1] = "Visible Area"
//	numerics[NumLength + 6 ][1] = "Visible Area"
//	numerics[NumLength + 10 ][1] = "Visible Area"
//	numerics[NumLength + 14][1] = "Visible Area"
	
//	numerics[NumLength + 3 ][1] = "Analytical Area"
//	numerics[NumLength + 7 ][1] = "Analytical Area"
//	numerics[NumLength + 11 ][1] = "Analytical Area"
//	numerics[NumLength + 15 ][1] = "Analytical Area"
	
	numerics[NumLength + 1][3] = "Position (Coef.)"
	numerics[NumLength + 5][3] = "Position (Coef.)"

	
	numerics[NumLength + 2][3] = "Effective Position"
	numerics[NumLength + 6][3] = "Effective Position"

	
	numerics[NumLength + 1][5] = "Width (Coef.)"
	numerics[NumLength + 5][5] = "Width (Coef.)"

	numerics[NumLength + 2][5] = "Effective Width"
	numerics[NumLength + 6][5] = "Effective Width"


	numerics[NumLength + 1][7] = "Gauss-Lorentz Ratio"
	
	numerics[NumLength + 1][9] = "Asymmetry (coef)"
	numerics[NumLength + 2][9] = "Effective Asymmetry:"
	numerics[NumLength + 3][9] = "1 - (fwhm_right)/(fwhm_left):"
	 
	 numerics[NumLength + 1][11] = "Asymmetry translation (coef)"
	
	numerics[NumLength+5][9] = "Total multiplet area " 
	numerics[NumLength+6][9] = "Sum of area coefficients" // STnum2str(totalCoefSum)
//	numerics[NumLength+11][9] = "Sum of visible peak areas" //STnum2str(totalVisibleArea)
//	numerics[NumLength + 12][9] = "Sum of analytical areas"  //STnum2str(totalAnalyticalSum)
	
	FancyUp("foe")
	setup2Waves()	
end

/// 2  ////////////////////////////////////////////////////////////
///////////////   Display it in the peak fitting window ///////////////////////////////////////////////

static function PlotDoubletSKDisplay(peakType,RawYWave, RawXWave,coefWave)
	string peakType
	string RawYWave
	string RawXWave
	string coefWave
	string TagName    // the Tag in the result window
	string PeakTag     // text in this tag
	string PkName, parentDataFolder //, cleanUpString=""		
	string BGName //background
	string PeakSumName
	NVAR FitMin = root:STFitAssVar:STFitMin
	NVAR FitMax = root:STFitAssVar:STFitMax
	
	wave cwave = $coefWave
	wave raw = $RawYWave
//	wave xraw = $RawXWave
	variable LenCoefWave = DimSize(cwave,0)
	
	//create some waves, to display the peak
	variable nPeaks = 0
	variable numCoef
	variable numSubPeaks
	variable i,index,k
	variable xmin, xmax, step
	variable TagPosition   //the position of the tag in the result window
	variable totalPeakSumArea, partialPeakSumArea
	 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate  		                     
			break
		case "_calculated_":
			 duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate  
			break
		default:                                                 // if not empty, x-axis wave necessary
			//read in the start x-value and the step size from the x-axis wave
			wave xraw = $RawXWave
			xmax = max(xraw[0],xraw[numpnts(xraw)-1] )
			xmin = min(xraw[0],xraw[numpnts(xraw)-1] )
			step = (xmax - xmin ) / DimSize(xraw,0)
			// now change the scaling of the y-wave duplicate, so it gets equivalent to a data-wave imported from an igor-text file
			duplicate /o raw tempWaveForCutting  
			SetScale /I x, xmin, xmax, tempWaveForCutting  //OKAY, NOW THE SCALING IS ON THE ENTIRE RANGE
			duplicate /o /R=(FitMin,FitMax) tempWaveForCutting WorkingDuplicate  
			killwaves /z tempWaveForCutting
			break
	endswitch
	
	parentDataFolder = GetDataFolder(1)
	
	
	//now make tabular rasa in the case of background functions
	string ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	variable numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	
	// If a wave is given which needs an external x-axis (from an ASCII-file) create a duplicate which receives a proper x-scaling later on
	// the original wave will not be changed
	KillDataFolder /z :Peaks  //if it exists from a previous run, kill it
	//now recreate it, so everything is updated             
	NewDataFolder /O /S :Peaks

 	numCoef =9   //Voigt with Shirley and Slope     //this has to be changed too, if a new static function is implemented   Ext-multiplet  15->33  
 	numSubPeaks = 2  // number of peaks in multiplet
 	
 	nPeaks = (LenCoefWave-5)/numCoef
	
	PeakSumName = "pS_"+RawYWave
			
	duplicate /o WorkingDuplicate $PeakSumName
	wave tempSumDisplay = $PeakSumName
			
			
	//update the graph, remove everything	
	for (i =1; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	string SubPeakName
	variable j, para1,para2,para3
	tempSumDisplay = 0
	variable areaPeak = 0
	//create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
	
	
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i + 5         //numCoef has to be changed for each  new fitting static function
		PkName = "m" + num2istr(i+1) + "_" + RawYWave  //make a propper name
	 	
	 	duplicate /o WorkingDuplicate $PkName	
		wave tempDisplay = $PkName 
		tempDisplay = 0      
	 	
	 	for ( j = 0; j < numSubPeaks; j += 1)     //for 10 subpeaks: j<10   Ext-multiplet    4 ->10
	 	
	 		SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + RawYWave
	 		duplicate /o WorkingDuplicate $SubPeakName
	 		wave subPeak = $SubPeakName
	 		
	 	      para1 = cwave[index]*(j==0) + (j !=0)*cwave[index]*cwave[index+6+3*(j-1)]   
	 	      para2 = cwave[index+1]*(j==0) + (j !=0)*(cwave[index+1]+cwave[index+7+3*(j-1)] ) 
	 	      para3 = cwave[index+2]*(j==0) + (j !=0)*cwave[index+2]*cwave[index+8+3*(j-1)]  
	 	      
	 		subPeak = CalcSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5],x)
	 		areaPeak= IntegrateSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
			subPeak /= areaPeak
			subPeak *= para1
	 		tempDisplay += subPeak
	 		
	 		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
	 		AppendToGraph /w= CursorPanel#guiCursorDisplayFit subPeak    	
	 		
	 	endfor
	 	                                     

		 //overwrite the original values in the wave with the values of a single peak
		//tempDisplay = CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)	
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 6] * cwave[index],cwave[index + 7] + cwave[index+1], cwave[index + 8] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 9] * cwave[index],cwave[index + 10] + cwave[index+1], cwave[index + 8] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 12] * cwave[index],cwave[index + 13] + cwave[index+1], cwave[index + 14] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
	
		tempSumDisplay += tempDisplay
		
		
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
		AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempDisplay                           //now plot it
		
		WaveStats /Q tempDisplay
		tagName = PkName+num2istr(i)
		PeakTag = num2istr(i+1)
		TagPosition = V_maxloc
		
		Tag /w= CursorPanel#guiCursorDisplayFit /C /N= $tagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag
		ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($PkName)=(0,0,0)       // and color-code it	
	endfor
	//get the sum of all peaks and (i) calculate the Shirley, (ii) calculate the line offset and (iii) display the background and the individual sums of peak + Background
	BGName ="bg_"+ RawYWave ///should name the background accordingly
	
	duplicate /o WorkingDuplicate $BGName
	wave tempBGDisplay = $BGName //this is the wave to keep the background
	
	duplicate /o WorkingDuplicate HGB
	wave hgb = HGB
	
	// now calculate the background with tempSumDisplay
	totalPeakSumArea = sum(tempSumDisplay)
	//print totalPeakSumArea
	partialPeakSumArea = 0
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))    //x decreases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[i]
			tempBGDisplay[i] =partialPeakSumArea/totalPeakSumArea 
		endfor
	else //x increases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[numpnts(tempSumDisplay) -1 - i]
			tempBGDisplay[numpnts(tempSumDisplay) -1 - i] = partialPeakSumArea/totalPeakSumArea 
		endfor
	endif
			
	//now add the Herrera-Gomez background
	partialPeakSumArea = 0
	totalPeakSumArea = sum(tempBGDisplay)
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))   //binding energy increases with point index
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[i])
			hgb[i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	else                     //binding energy decreases with point index
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[numpnts(tempSumDisplay)-1-i])
			hgb[numpnts(tempSumDisplay)-1-i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	endif
	hgb *= cwave[3]	
			
	tempBGDisplay *= cwave[4]  //shirley height
	tempBGDisplay += hgb
//	Killwaves /z temporaryShirleyWave
	
//	for (i =0; i<nPeaks;i+=1)
//		index = numCoef*i + 5
//		tempBGDisplay += 1e-3*cwave[3]*cwave[index]*( x - cwave[index+1] )^2 * ( x > cwave[index+1] ) 
//	endfor
			
	tempBGDisplay += cwave[0] + cwave[1]*x + cwave[2]*x^2
	
	AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempBGDisplay 
		
	//now add the background to all peaks
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i
		PkName = "m" + num2istr(i+1) + "_"+RawYWave   //make a propper name
		for ( j = 0; j < numSubPeaks; j += 1)                                                                                 //change here too //////////////////////////////////////////////////////////////////////////// Ext-multiplet   4-->10
	 	
	 		SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + RawYWave
	 		wave subPeak = $SubPeakName
			subPeak += tempBGDisplay
			ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($SubPeakName)=(43520,43520,43520) 
	 	endfor
		
		wave tempDisplay = $PkName        //This needs some explanation, see commentary at the end of the file                                        
		
		 //overwrite the original values in the wave with the values of a single peak
		tempDisplay  += tempBGDisplay
	endfor
		
	tempSumDisplay += tempBGDisplay
	//for now, don't use tempSumDisplay, however, leave it in the code for possible future use
	killwaves /z tempSumDisplay   //remove this line, if the sum of the peaks is going to be used again
	killwaves /z HGB
	WaveStats /Q WorkingDuplicate
//	SetAxis /w = CursorPanel#guiCursorDisplayFit left -0.1*V_max, 1.1*V_max
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	SetAxis/A/R /w = CursorPanel#guiCursorDisplayFit bottom
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	SetDataFolder parentDataFolder 
	killwaves /Z WorkingDuplicate
end




///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////

static function DrawAndEvaluateDoubletSK(dataWave,fitWave,peakType,RawXWave,newFolder)
string dataWave
string fitWave
string peakType
string RawXWave
variable newFolder               //if this value is different from 1, no folder for the results will be created

SVAR projectName = root:STFitAssVar:ProjectName

wave cwave = W_coef
wave origWave = $dataWave
wave fitted = $fitWave
wave epsilon = epsilon
wave hold = hold
wave InitializeCoef = InitializeCoef
wave Min_Limit = Min_Limit
wave Max_Limit = Max_Limit
wave T_Constraints = T_Constraints
wave  CoefLegend = CoefLegend

if ( strlen(fitWave) >= 30)	
	doalert 0, "The name of the fit-wave is too long! Please shorten the names."
	return -1
endif


//define further local variables
variable LenCoefWave = DimSize(cwave,0)	
variable nPeaks
variable index
variable i =0                               //general counting variable
variable numCoef                       //variable to keep the number of coefficients of the selected peak type
							  // numCoef = 3   for Gauss Singlet     and numCoef =5 for VoigtGLS
variable numSubPeaks = 2
variable pointLength, totalArea, partialArea
variable peakMax 
variable TagPosition
variable AnalyticalArea
variable EffectiveFWHM
variable GeneralAsymmetry        //  = 1 - (fwhm_right)/(fwhm_left)

string PkName                          //string to keep the name of a single peak wave
string foldername                       //string to keep the name of the datafolder, which is created later on for the single peak waves
string tempFoldername               //help-string to avoid naming conflicts
string parentDataFolder
string TagName
string PeakTag
string LastGraphName
string NotebookName = "Report"     //this is the initial notebook name, it is changed afterwards
string tempNotebookName
string tempString                          // for a formated output to the notebook
string BGName
//The following switch construct is necessary in order to plot waveform data (usually from igor-text files , *.itx) as well as
//raw spectra which need an extra x-axis (such data come usually from an x-y ASCII file)

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		display /K=1 origWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
		break
	case "_calculated_":
		display /K=1 origWave
		break
	default:
		wave xraw = $RawXWave                                                 // if not empty
		display /K=1 origWave vs xraw        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
endswitch
ModifyGraph mode($dataWave)=3,msize($dataWave)=1.3, marker($dataWave)=8
ModifyGraph mrkThick($dataWave)=0.7
ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
    
LastGraphName = WinList("*", "", "WIN:")    //get the name of the graph

//check if this Notebook already exists
V_Flag = 0
DoWindow $NotebookName   
// if yes, construct a new name
if (V_Flag)
	i = 1
	do 
		tempNoteBookName = NotebookName + num2istr(i)
		DoWindow $tempNotebookName
		i += 1
	while (V_Flag)
	NotebookName = tempNotebookName 
endif
//if not, just proceed

NewNotebook /F=1 /K=1 /N=$NotebookName      //make a new notebook to hold the fit report
Notebook $NoteBookName ,fsize=8




//prepare a new datafolder for the fitting results, in particular the single peaks
parentDataFolder = GetDataFolder(1)    //get the name of the current data folder

if (newFolder == 1)
	NewDataFolder /O /S subfolder
	//now, this folder is the actual data folder, all writing is done here and not in root
endif

duplicate /o fitted tempFitWave
wave locRefTempFit = tempFitWave
locRefTempFit = 0

//now decompose the fit into single peaks --- if a further fit static function is added, a further "case" has to be attached

		numCoef = 9      //has to be changed for a different peak type  Ext-multiplet   15->33
		
		nPeaks = (LenCoefWave-5)/numCoef         //get the number of  peaks from the output wave of the fit
		//check, if the peak type matches the length of the coefficient wave
		//if not so, clean up, inform and exit
		BGName = "PS_bg" +"_" + dataWave 
		duplicate /o fitted $BGName
		wave background = $BGName
		
		duplicate /o fitted HGB
		wave hgb = HGB
		AppendToGraph background
		
		if (mod(LenCoefWave-5,numCoef) != 0)
			DoAlert 0, "Mismatch, probably wrong peak type selected or wrong coefficient file, check your fit and peak type "
			SetDataFolder parentDataFolder 
			KillDataFolder  /Z subfolder
			print " ******* Peak type mismatch - check your fit and peak type ******"
			return 1
		endif 
		
		Notebook $NoteBookName ,text="\r\r" 
		
		//continue here ......
		variable j,para1,para2,para3, sumCoef, sumAnalytical
		
		
		string SubPeakName
		variable areaPeak = 0
		for (i =0; i<nPeaks;i+=1)
			index = numCoef*i + 5
			PkName = "m" + num2istr(i+1)+"_" + dataWave    //make a proper name
			 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
			duplicate /o fitted $PkName
							
			wave W = $PkName        //This needs some explanation, see commentary at the end of the file                                        
			
			
			
			W = 0
			sprintf  tempString, "\r\r\r Doublet  %1g     ======================================================================================\r\r",(i+1)
			Notebook $NoteBookName ,text=tempString
			sumCoef = 0
			sumAnalytical = 0
			for ( j = 0; j < numSubPeaks; j += 1)    // for 10 subpeaks: j<10  Ext-multiplet   4-->10
	 			SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + dataWave
	 			duplicate /o fitted $SubPeakName
		 		wave subPeak = $SubPeakName
		 	      para1 = cwave[index]*(j==0) + (j !=0)*cwave[index]*cwave[index+6+3*(j-1)] 
		 	      sumCoef += para1
		 	      para2 = cwave[index+1]*(j==0) + (j !=0)*(cwave[index+1]+cwave[index+7+3*(j-1)] ) 
		 	      para3 = cwave[index+2]*(j==0) + (j !=0)*cwave[index+2]*cwave[index+8+3*(j-1)]  
		 		
		 		subPeak = CalcSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5],x)
		 		areaPeak= IntegrateSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
				subPeak /= areaPeak
				subPeak *= para1
		 		
		 		
				//AnalyticalArea =  IntegrateSingleVoigtGLS(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5]) //*( ( j==0 ) + ( j != 0)*cwave[index+6+3*(j-1)] )
				//sumAnalytical += AnalyticalArea
				EffectiveFWHM = CalcFWHMSingleVoigtGLS(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
				GeneralAsymmetry = CalcGeneralAsymmetry(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])   
				WaveStats /Q subPeak 
		 		
				sprintf  tempString, " Peak %1g	  Area\t|\tPosition\t|\tFWHM\t|\tGL-ratio\t|\tAsym.\t|\tAsym. Shift\t\r",(j+1)
				Notebook $NoteBookName ,text=tempString
				sprintf  tempString, "\t%s\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t\r" ,  STnum2str(para1), para2,para3 ,cwave[index+3] , cwave[index+4],cwave[index+5]
				Notebook $NoteBookName ,text=tempString	
				sprintf  tempString, "\rEffective maximum position\t\t\t\t%8.2f \r", V_maxloc  // "-> In case of asymmetry, this value does not represent an area any more"
				Notebook $NoteBookName ,text=tempString
				sprintf  tempString, "Effective FWHM\t\t\t\t\t%8.2f \r", EffectiveFWHM	
				Notebook $NoteBookName ,text=tempString	
				sprintf tempString, "Effective Asymmetry = 1 - (fwhm_right)/(fwhm_left)\t\t%8.2f \r\r\r\r" , GeneralAsymmetry
				Notebook $NoteBookName ,text=tempString
		 				
		 		W += subPeak
		 		AppendToGraph subPeak
		 		//ModifyGraph lstyle($SubPeakName)=2
		 		ModifyGraph lstyle($SubPeakName)=0,rgb($SubPeakName)=(43520,43520,43520)
		 	endfor
			
			
			
			
			 //overwrite the original values in the wave with the values of a single peak
			//W =  CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
			locRefTempFit += W         
			
			AppendToGraph W                                                    //now plot it

			//append the peak-tags to the graph, let the arrow point to a maximum
			//append the peak-tags to the graph, let the arrow point to a maximum
			WaveStats /Q W                             // get the location of the maximum
			TagName = "tag"+num2istr(i)           //each tag has to have a name
			PeakTag = num2istr(i+1)                 // The tag displays the peak index
			TagPosition = V_maxloc                 // and is located at the maximum
			Tag  /C /N= $TagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag    // Now put the tag there
			sprintf  tempString, "Total multiplet area\r-------------------------------------\r  %s  \t\t(sum of fit coefficients - usually larger than visible area within measurement window) ",  STnum2str(sumCoef)
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "\r  %s  \t\t(area within measurement window) ",  STnum2str(area(W))
			Notebook $NoteBookName ,text=tempString
			//sprintf tempString, "\r %s  \t\t(sum of analytical areas)", STnum2str(sumAnalytical)
			//Notebook $NoteBookName ,text=tempString
			sprintf tempString, "\r\r==================================================================================================\r\r\r"
			//Notebook $NoteBookName ,text=tempString
			
			
			Notebook $NoteBookName ,text=tempString
			ModifyGraph rgb($PkName)=(10464,10464,10464)              // color code the peak
				
			
		endfor
		
		
		//and now, add the background
		pointLength = numpnts(locRefTempFit)
		totalArea = sum(locRefTempFit)
		partialArea = 0
		
		//distinguish between ascending and descending order of the points in the raw-data wave
		if (pnt2x(locRefTempFit,0) > pnt2x(locRefTempFit,1))   //with increasing index, x decreases
			for (i=pointLength-1; i ==0; i -=1)	
				partialArea += abs(locRefTempFit[i]) 
		
				background[i] = partialArea/totalArea

			endfor
			//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = pointLength; i == 0; i -= 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			background *= cwave[4]
			background += hgb
			//for (i =0; i<nPeaks;i+=1)
			//	index = numCoef*i + 5
		//		background += 1e-3*cwave[3]*cwave[index] * ( x - cwave[index + 1])^2 * ( x > cwave[index+1])
		//	endfor
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
		else
			for (i=0; i<pointLength; i += 1)
					partialArea += abs(locRefTempFit[i]) 
					background[i] =partialArea/totalArea 
			endfor
				//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = 0; i < pointLength; i += 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			
			
			background *= cwave[4]
			background += hgb
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
			
		endif
		//now, everything should be fine with the background .... carry on
		
		locRefTempFit += background
		
		
		tempString = "\r\r\r\r\rFurther Details\r"
		Notebook $NoteBookName ,text=tempString
		tempString = "==================================================================================================="
		Notebook $NoteBookName ,text=tempString
		strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
			case "":                                             //if empty
				 sprintf  tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))           
			break
			case "_calculated_":
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))
			break
			default:                                                 // if not empty
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(areaXY(xraw,origWave))
				break
		endswitch
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "Total area of all peaks in measurement window:\t\t%s \r" STnum2str(area(locRefTempFit) - area(background))
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "Area of the background in measurement window:\t\t%s \r", STnum2str(area(background) )
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\rYou used a simultaneous fit of background  and signal: MAKE SURE the background shape makes sense.\r" 
		Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, "For details on the \r -- Peak shape:  Surface and Interface Analysis (2014), 46, 505 - 511  (If you use this program, please read and cite this paper) \r" 
		//Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, " -- 'Pseudo-Tougaard' and Shirley contribution to the background:  J. Elec. Spectrosc. Rel. Phen (2013), 189, 76 - 80\r" 
		//Notebook $NoteBookName ,text=tempString
		sprintf tempString,"\rPlease note that for asymmetric peaks the fit coefficients for position and FWHM are merely coefficients. \rIn this case, refer to the respective 'effective' values.\r"      
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rBackground\r==================================\rThe background is calculated as follows:  Offset + a*x + b*x^2 + c * (pseudo-tougaard) + d * shirley\r" 
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\r(Here:  Offset=%8.2g;      a =%8.2g;      b =%8.2g;   c =%8.4g;   d =%8.2g; ) \r", cwave[0], cwave[1], cwave[2], cwave[3], cwave[4]
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rThe parameters a and b  serve to cover general slopes or curvatures in the background, for example if the peak sits on a complex mixture of  broad Auger lines or plasmons.\r" 
		Notebook $NoteBookName ,text=tempString
		
		sprintf tempString, "\rPeak Areas\r==================================\rThe peak area is obtained by integrating the peak on an interval of +/- 90*FWHM around the peak position."
		Notebook $NoteBookName ,text=tempString
		
		sprintf tempString, "\rThis value is generally somewhat larger than the visible peak area within the limited measurement window."
		Notebook $NoteBookName ,text=tempString
		
		
		
		//and now add the background to all peaks as well
		for (i =0; i<nPeaks;i+=1)
			PkName = "m" + num2istr(i+1)+"_" + dataWave    					
			wave W = $PkName       
			W += background
			for ( j = 0; j < numSubPeaks; j += 1)     //needs to be changed for another peak  Ext-multiplet   4-->10
	 			SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + dataWave
	 			wave subPeak = $SubPeakName
		 	      subPeak += background
		 	endfor			
		endfor
		

//killwaves /z  fitted     //this applies to the original fit-wave of Igor, since it is a reference to the wave root:Igor-FitWave, the original wave is possibly wrong
//duplicate /o locRefTempFit, $fitWave               //but we are still in the subfolder, 
//killwaves /z locRefTempFit
//wave fitted = $fitWave


	SetDataFolder parentDataFolder 

	//create a copy of the coefficient wave in the subfolder, so the waves 
	//and the complete fitting results are within that folder
	duplicate /o :$dataWave, :subfolder:$dataWave
//	if (WaveExists($RawXWave))
	if (Exists(RawXWave))
		duplicate /o :$RawXWave, :subfolder:$RawXWave
	endif

	//duplicate  :$fitWave, :subfolder:$fitWave
//	killwaves /z :$fitWave            //probably fails, if the fit wave is displayed in the main panel as well
	duplicate /o $fitWave :subfolder:$fitWave
	AppendToGraph :subfolder:$fitWave                                //draw the complete fit
	ModifyGraph rgb($fitWave) = (0,0,0)       //color-code it
	//Remove the original wave, which is located in the parent directory and replace it by the copy in the subfolder
	RemoveFromGraph $"#0" 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph :subfolder:$dataWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
			break
		case "_calculated_":
			AppendToGraph  :subfolder:$dataWave
			break
		default:                                                 // if not empty
			AppendToGraph :subfolder:$dataWave vs :subfolder:$RawXWave        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
	endswitch

	foldername = "Report_" + projectName
	
	//foldername ="Fit_"+ dataWave
	i=1   //index variable for the data folder	
	            //used also for the notebook
	V_Flag = 0
	DoWindow $folderName
	tempFoldername = foldername
	
	if (V_Flag)    //is there already a folder with this name
		do
			V_Flag = 0
			tempFoldername = foldername + "_" + num2istr(i)
			DoWindow $tempFolderName
			i+=1
		while(V_Flag)
		
		if (strlen(tempFoldername) >= 30)	
			//doalert 0, "The output folder name is too long! Please shorten the names. The output folder of the current run is named 'subfolder'."
			string NewName = ""
			
			Prompt NewName, "The wave name is too long, please provide a shorter name "		// Set prompt for y param
			DoPrompt "Shorten the name", NewName
			if (V_Flag)
				return -1								// User canceled
			endif	
			tempFolderName = NewName	
		endif
			RenameDataFolder subfolder, $tempFoldername                   //now rename the peak-folder accordingly
			Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST (2015)" //\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
			//remove illegal characters from the string
			tempFoldername = stringClean(tempFoldername)
			DoWindow /C $tempFoldername
			DoWindow /F $LastGraphName
			DoWindow /C $tempFoldername + "_graph"
			//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"   //valid in Igor 6.x
		//TextBox/N=text0/A=LT tempFoldername        //prints into the graph
	else 
		//no datafolder of this name exist
		RenameDataFolder subfolder, $foldername 
		//TagWindow(foldername)
		Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST (2015)" //\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
		//if ( strsearch(foldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		//	foldername = ReplaceString(".", foldername,"_")
		//endif
		foldername = stringClean(foldername)
		tempFoldername = stringClean(tempFoldername)
		DoWindow /C $foldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
	endif

//make the graph look good
ModifyGraph mode($dataWave)=3 ,msize($dataWave)=1.3 // ,marker($dataWave)=8, opaque($dataWave)=1
ModifyGraph opaque=1,marker($dataWave)=19
ModifyGraph rgb($dataWave)=(60928,60928,60928)
ModifyGraph useMrkStrokeRGB($dataWave)=1
ModifyGraph mrkStrokeRGB($dataWave)=(0,0,0)
//ModifyGraph mrkThick($dataWave)=0.7
//ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
ModifyGraph mirror=2,minor(bottom)=1
Label left "\\f01 intensity (counts)"
Label bottom "\\f01  binding energy (eV)"	
ModifyGraph width=255.118,height=157.465, standoff = 0, gfSize=11

//The following command works easily, but then the resulting graph is not displayed properly in the notebook
//SetAxis/A/R bottom
//instead do it like this:
variable left,right

strswitch(RawXWave)
	 	case "":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	case "_calculated_":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	default:
	 		waveStats /Q $RawXWave
	 		left = V_max
	 		right = V_min
	 	break
 endswitch
 SetAxis bottom left,right
//okay this is not perfectly elegant ... but

WaveStats /Q $dataWave
SetAxis left V_min-0.05*(V_max-V_min), 1.02*V_max
LastGraphName = WinList("*", "", "WIN:")



Notebook  $tempFoldername, selection = {startOfFile,startOfFile}

tempString = "\rReport for fitting project: \t\t " + projectName + "\r"
Notebook  $tempFoldername, text=tempString
Notebook  $tempFoldername, selection = {startOfPrevParagraph,endOfPrevParagraph}, fsize = 12, fstyle = 0

tempString = "\r==================================================================================================="
Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}, text=tempString
Notebook $tempFolderName ,selection = {startOfNextParagraph,startOfNextParagraph}, text="Saved in:\t\t\t\t\t" + IgorInfo(1) + ".pxp \r"
Notebook $tempFolderName ,text="Spectrum:\t\t\t\t" +dataWave
Notebook $tempFolderName ,text="\rApplied peak shape:\t\t\t"+ peakType +"\r\r"

Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}
Notebook  $tempFoldername, picture={$LastGraphName, 0, 1} , text="\r\r\r" 

killwaves /z hgb
KillWindow $LastGraphName
//Notebook  $tempFoldername, text="\r \r"  

KillDataFolder /z tempFoldername

//now clean up
killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr

end





static function EvaluateDoubletSK()

wave cwave = W_Coef /// hard-coded but what the hell....

wave /t output = Numerics    //here we write the results

variable AnalyticalArea = 0
variable EffectiveFWHM = 0
variable GeneralAsymmetry = 0

variable i,j,k,index, index2
variable numpeaks
variable numCoef = 9              //  Ext-multiplet    15--> 33
variable numSubPeaks = 2

variable lengthCoef = numpnts(cwave)
variable lengthNumerics = DimSize(output,0)
string parentFolder = ""
string item = ""
numpeaks = (lengthCoef-5)/numCoef
variable EffectiveArea,EffectivePosition
string wavesInDataFolder = WaveList("*fit_*",";","DIMS:1")
wave fitted = $StringFromList(0,wavesInDataFolder)
variable areaW
string FormatString

variable totalCoefSum = 0
variable totalVisibleArea = 0
variable totalAnalyticalSum = 0
string tempString

variable areaPeak = 0
for ( i = 0; i < numPeaks; i += 1 ) 
	index = numCoef*i + 5                    //  Ext-multiplet  15-->33
	//this static function also needs to analyze the waves to get the effective position etc.
	 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
	duplicate /o fitted tempForAnalysis
							
	wave W = tempForAnalysis
	 
	 //iterate for all subpeaks
	W =  CalcSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
	areaPeak= IntegrateSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	W /= areaPeak
	W *= cwave[index]
	WaveStats/Q W
	//areaW=area(W)                          
	
	//AnalyticalArea =  IntegrateSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	GeneralAsymmetry = CalcGeneralAsymmetry(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])   
	//totalAnalyticalSum += AnalyticalArea
	
	//Now write the results to Numerics //there is no need to re-calculate for each individual peak, the values may be derived from the
	//parameters

	index2 = 8*i                     //////////////    Ext Multiplet  should be 16--->34  setting 40 instead	
	
	// Area
	
	//  peak 1

	output[index2+1][2] = STnum2str(cwave[index])
	output[index2+2][2] = "" 
	output[index2+2][1] = "" 
	output[index2+3][2] = "" 
	output[index2+3][1] = "" 
	
	//  peak 2
	
	output[index2+5][2] = STnum2str(cwave[index]*cwave[index +6])
	output[index2+6][2] = "" 
	output[index2+6][1] = "" 

	output[index2+7][2] = ""
	output[index2+7][1] = ""


	// total area calculation
	
	totalCoefSum +=cwave[index]*(1+cwave[index+6])


	//shifts

	// peak 1
	output[index2+1][4] = STnum2str(cwave[index+1])
	output[index2+2][4] = STnum2str(V_maxloc)
	
	// peak 2
	output[index2+5][4] = STnum2str(cwave[index+1]+cwave[index+7])
	output[index2+6][4] = STnum2str(V_maxloc+cwave[index+7])
	
	
	
	//FWHM
	
	// peak 1
	output[index2+1][6] = STnum2str(cwave[index+2])
	output[index2+2][6] = STnum2str(EffectiveFWHM)
	
	// peak 2
	output[index2+5][6] = STnum2str(cwave[index+2] *cwave[index+8])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+6],cwave[index+1]+cwave[index+7],cwave[index+2]*cwave[index+8],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+6][6] = STnum2str(EffectiveFWHM)
	
	
	//  GL-Ratio
	
	output[index2+1][8] = STnum2str(cwave[index+3])
	
	// Asymmetry
	
	output[index2+1][10]=STnum2str(cwave[index+4])
	 
	output[index2+2][10] =STnum2str(GeneralAsymmetry)

	output[index2+1][12] = STnum2str(cwave[index+5])
	
	
	// total area showing
	
	output[index2+6][10] = STnum2str(totalCoefSum)
	output[index2+7][10] = ""//STnum2str(totalVisibleArea)
	output[index2+7][9] = ""
	output[index2+8][10] = ""//STnum2str(totalAnalyticalSum)
	output[index2+8][9] = ""
	totalCoefSum = 0
//	totalVisibleArea = 0
	//totalAnalyticalSum = 0
	
	
	killwaves /Z W
endfor
	
end



static function RemoveDoublet()
	//CheckLocation()
	//these are needed to be able to call SinglePeakDisplay, in case of the background functions
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR toLink = root:STFitAssVar:STPeakToLink
	NVAR peakToExtract = root:STFitAssVar:STPeakToRemove
	NVAR savedLast = root:STFitAssVar:savedLast
	savedLast = 0 //this change has not been saved yet
	UpdateFitDisplay("fromAddPeak")
	//updateCoefs()
	setup2waves()
	numPeaks -= 1
	numPeaks=max(0,numPeaks)
	toLink = min(toLink,numPeaks)
	//peakToExtract = max(0,numPeaks)
	/////////////////////////////////////////////////////////////


	wave /t source = STsetup
	//NVAR peakToExtract = PeakToDelete
	wave sw = selSTsetup

	wave /t  numerics = Numerics
	wave selNumerics = selNumerics

	variable i,j,k
	variable length = DimSize(source,0)
	variable NumLength = DimSize(numerics,0)

	//this needs to be rewritten for doublet functions as well
	//numPeaks = (length-5)/6

	//this is the simple version of delete which only removes the last entry
	//if (length>=6)
	//Redimension /n=(length-6,-1) source
	//Redimension /n=(length-6,-1) sw
	//endif

	if (length == 5) ///only the background is left
		return 1 /// do nothing, the background may stay there forever
	endif

	string ListOfCurves
	variable numberCurves
	variable startCutIndex, endCutIndex
	variable numCoef = 9
	variable numSubPeaks = 2
	//FancyUP("foe")

	//now do a sophisticated form of delete which removes a certain peak from within the waves
	//for example peak 2
	//peakToExtract = 2 //this needs to be soft-coded later on

	//duplicate the sections that need to go
	//to do so: calculate the indices that have to be removed
	//this needs to be extended for doublet functions as well

	startCutIndex = 5 + (peakToExtract-1)*numCoef
	endCutIndex = startCutIndex + numCoef

	variable startCutIndexNumerics = (peakToExtract-1)* (4*numSubPeaks)
	variable endCutIndexNumerics = startCutIndexNumerics + (4*numSubPeaks)

	//now, check if there are any constraints linked to this peak, if yes, refuse to do the deleting and notify the user
	// that means the ax, px, wx, etc of this peak e.g. a2, w2, etc show up anywhere else in the constraints wave, if so, abort
	variable abortDel = 0

	string planeName = "backColors"
	variable plane = FindDimLabel(sw,2,planeName)

	Variable nplanes = max(1,Dimsize(sw,2))
	if (plane <0)
		Redimension /N=(-1,-1,nplanes+1) sw
		plane = nplanes
		SetDimLabel 2,nplanes,$planeName sw
	endif

	variable Errors = 0
	string tempString
	string CoefficientList = "a;p;w;g;s;t"
	string matchString 
	string badSpotList = ""

	for (j = 0; j<itemsInList(CoefficientList); j += 1)
		matchString = "*" + StringFromList(j,CoefficientList) + num2str(peakToExtract) + "*"
		for (i=0; i < startCutIndex; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
		endfor
		for (i=endCutIndex; i < length; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
		endfor
	endfor

	variable badSpots = ItemsInList(badSpotList)
	variable badSpot
	
	if (Errors != 0)
		tempString = "Other peaks are linked to the one you want to remove. \r\rDelete all references to the peak you want to remove from 'Lower Limit' and 'Upper Limit'."
		Doalert 0, tempString
		tempString = "editDisplayWave(\"foe\")"
		Execute tempString
		// and now do the highlighting
		for ( i = 0; i < badSpots; i += 1 )
			badSpot = str2num(StringFromList(i,badSpotList))
			sw[badSpot][5][plane] =1		
			sw[badSpot][6][plane] =1		
		endfor
	
		//end highlighting
	
		numpeaks += 1
		return -1
	endif

	//everything seems to be fine, now continue
	duplicate /o /r=(0,startCutIndex-1) source $"lowerSectionSetup" 
	wave /t lowerSetup = $"lowerSectionSetup"
	duplicate /o /r=(0,startCutIndex-1) sw $"lowerSectionSw" 
	wave  lowerSW = $"lowerSectionSw"

	duplicate /o /r=(endCutIndex,length-1) source $"upperSectionSetup" 
	wave /t upperSetup = $"upperSectionSetup"
	duplicate /o /r =(endCutIndex, length -1) sw $"upperSectionSw" 
	wave upperSW = $"upperSectionSw"


	duplicate /o /r=(0,startCutIndexNumerics-1) numerics $"lowerSectionNumerics" 
	wave /t lowerNumerics = $"lowerSectionNumerics"
	duplicate /o /r=(0,startCutIndexNumerics-1) selNumerics $"lowerSectionSelNumerics" 
	wave  lowerSelNumerics = $"lowerSectionSelNumerics"

	duplicate /o /r=(endCutIndexNumerics,NumLength-1) numerics $"upperSectionNumerics" 
	wave /t upperNumerics = $"upperSectionNumerics"
	duplicate /o /r =(endCutIndexNumerics, NumLength -1) selNumerics $"upperSectionSelNumerics" 
	wave upperSelNumerics = $"upperSectionSelNumerics"


	//remove also the entries for the numerics wave

	//remove the space for one peak
	Redimension /n=(length -numCoef,-1) source
	Redimension /n=(length -numCoef,-1) sw

	Redimension /n=(NumLength - 4*numSubPeaks,-1) numerics    //four lines per peak if the peak type is singlet
	Redimension /n=(NumLength -4*numSubPeaks,-1) selNumerics

	//and now, copy the stuff back, start with the lowerSection
	for (i = 0; i < startCutIndex; i += 1)
		for ( j =2; j < 8; j +=1) // do not overwrite the legend waves, this would be redundant
			if (j  != 4)
				source[i][j]=lowerSetup[i][j]
			endif
			sw[i][j]=lowerSW[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndex; i < length-numCoef; i += 1)
		for ( j =2; j < 8; j +=1)
			if (j  != 4)
				source[i][j]=upperSetup[i-startCutIndex][j]
			endif
			sw[i][j]=upperSW[i-startCutIndex][j]
		endfor
	endfor

	//now repeat everything for the Numerics wave
	for (i = 0; i < startCutIndexNumerics; i += 1)
		for ( j =2; j < 15; j +=1) // do not overwrite the legend waves, this would be redundant
			numerics[i][j]=lowerNumerics[i][j]
			selNumerics[i][j]=lowerSelNumerics[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndexNumerics; i < NumLength - 4*numSubPeaks -1; i += 1)
		for ( j =2; j < 15; j +=1)
			numerics[i][j]=upperNumerics[i-startCutIndexNumerics][j]
			selNumerics[i][j]=upperSelNumerics[i-startCutIndexNumerics][j]
		endfor
	endfor

	killwaves /z upperSetup, upperSW, lowerSetup, lowerSW, lowerSelNumerics, upperSelNumerics, lowerNumerics, upperNumerics

	//now make sure that all the parameter names, such as a2, a3, etc are updated
	//if the second peak was removed:   old > new 
	//								a1 > a1
	//								a2 > removed
	//								a3 > a2 //k = 0
	//								a4 > a3  //k = 1
	string lowerIndexIn, higherIndexOut

	for ( k = 0; k< numpeaks; k += 1)
		for ( j = 0; j < itemsInList(CoefficientList); j += 1 )
			lowerIndexIn = StringFromList(j,CoefficientList) + Num2str(peakToExtract+k )  
			higherIndexOut = StringFromList(j,CoefficientList) +num2str(peakToExtract + k +1)
			//print lowerIndexIn, higherIndexOut
			for ( i = 0; i < length-numCoef; i += 1 )
				tempString = source[i][5]
				source[i][5]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
				tempString = source[i][6]
				source[i][6]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
			endfor
		endfor
	endfor
	
	///////////////////////////////////////////////////////////
	setup2waves()	
	ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	//this needs to be adapted to the background functions
	RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-1)
	//if (BackgroundType != 0 )
	for (i =2; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	//and now redisplay, if there are any peaks left
	SinglePeakDisplay(peakType,RawYWave,RawXWave, "InitializeCoef")//coefWave)
	FancyUp("foe")
	peakToExtract = max(0,numPeaks)
	SetVariable InputSetLink, limits={0,numPeaks,1}
	SetVariable InputRemoveLink,limits={0,peakToExtract,1}
	SetVariable InputRemoveLink2,limits={0,peakToExtract,1}
end

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////
///////    SpecExtMulti
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////


static function AddVoigtSKExtMultiplet(coefWave,RawYWave,indepCheck,heightA,posA,initialSlope, initialOffset,left,right,Wcoef_length)

string coefWave     //this won't be needed in the future ... for now, leave it here
string RawYWave
variable indepCheck
variable heightA
variable posA	
variable initialSlope
variable initialOffset
variable left
variable right
variable Wcoef_length

NVAR peakToLink = root:STFitAssVar:STPeakToLink
string parameterList = "a;p;w;g;as;at;dr;ds;db;tr;ts;tb;qr;qs;qb;qir;qis;qib;sxr;sxs;sxb;spr;sps;spb;ocr;ocs;ocb;nor;nos;nob;der;des;deb"   //ratio doublet, shift doublet, broadening doublet, ratio triplet ......

NVAR linkArea = root:STFitAssVar:AreaLink
NVAR linkPosition = root:STFitAssVar:PositionLink
NVAR linkWidth = root:STFitAssVar:WidthLink
NVAR linkGL = root:STFitAssVar:GLLink
NVAR linkAsym = root:STFitAssVar:AsymLink
NVAR linkSplitting = root:STFitAssVar:SOSLink
NVAR linkMultiRatio = root:STFitAssVar:DoubletRatioLink

NVAR areaLinkUpperFactor = root:STFitAssVar:AreaLinkFactorHigh
NVAR areaLinkLowerFactor = root:STFitAssVar:AreaLinkFactorLow
NVAR positionLinkOffsetMax = root:STFitAssVar:PositionLinkOffsetMax
NVAR positionLinkOffsetMin = root:STFitAssVar:PositionLinkOffsetMin

string name = "CursorPanel#guiCursorDisplay" 	
variable nPeaks,i,numPara,EstimatedPeakArea
variable epsilonVal=1e-5

wave /t source = STsetup  //everything is in the setup
wave sw = selSTSetup

wave /t  numerics = Numerics
wave selNumerics = selNumerics

variable length = DimSize(source,0)
variable NumLength = DimSize(numerics,0)

variable numpeaks = 0
//print numpeaks
variable index
variable newLength




variable numCoef = 33  // number of coefficients.  for extended Multiplet, =33
variable numSubPeaks = 10  // number of Peaks in Multiplet.           for extended Multiplet = 10

WaveStats /Q $RawYWave
heightA = vcsr(A,name) - (initialSlope*posA+initialOffset)		//V_min						
EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)	


if (length == 0)
	Redimension /n=(numCoef+5,-1) source     // 5 = bg coefficients
	Redimension /n=(numCoef+5,-1) sw          //  
	
	numpeaks = 0
	//set writing permissions and checkbox controls
	for ( i= 0; i<length + numCoef +5; i+=1)             // Ext-multiplet  20-->38
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor

	source[length][0] = "Offset at E = 0 eV"
	source[length + 1][0] = "Slope"
	source[length + 2][0] = "Parabola"
	source[length + 3][0] = "Pseudo Tougaard (Herrera-Gomez)"
	source[length + 4][0] = "Shirley Step Height"
	source[length + 5][0] =         "Area   (first subpeak)  -----   Extended   Multiplet  " + num2str(numpeaks+1) 
	source[length + 6][0] =   "Position                                (subpeak 1)                          "
	source[length + 7][0] =   "Width"
	source[length + 8][0] =   "Gauss-Lorentz Ratio"
	source[length + 9][0] =   "Asymmetry"
	source[length + 10][0] = "Asymmetry Translation"	
	source[length + 11][0] =   "Doublet Ratio                  subpeak 2 : 1"
	source[length + 12][0] =   "Doublet Shift                                  2 - 1"
	source[length + 13][0] =   "Doublet Broadening                       2 : 1"
	source[length + 14][0] =   "Triplet Ratio                     subpeak 3 : 1 "
	source[length + 15][0] = "Triplet Shift                  		             3 - 1"
	source[length + 16][0] = "Triplet Broadening                          3 : 1"
	source[length + 17][0] = "Quadruplet Ratio              subpeak 4 : 1 "
	source[length + 18][0] = "Quadruplet Shift                              4 - 1"
	source[length + 19][0] = "Quadruplet Broadening                   4 : 1"
	source[length + 20][0] =   "Quintuplet Ratio                subpeak 5 : 1"
	source[length + 21][0] =   "Quintuplet Shift                                5 - 1"
	source[length + 22][0] =   "Quintuplet Broadening                     5 : 1"
	source[length + 23][0] =   "Sextuplet Ratio                  subpeak 6 : 1 "
	source[length + 24][0] = "Sextuplet Shift                  		          6 - 1"
	source[length + 25][0] = "Sextuplet Broadening                       6 : 1"
	source[length + 26][0] = "Septuplet Ratio                  subpeak 7 : 1 "
	source[length + 27][0] = "Septuplet Shift                                  7 - 1"
	source[length + 28][0] = "Septuplet Broadening                       7 : 1"
	source[length + 29][0] =   "Octuplet Ratio                    subpeak 8 : 1"
	source[length + 30][0] =   "Octuplet Shift                                    8 - 1"
	source[length + 31][0] =   "Octuplet Broadening                         8 : 1"
	source[length + 32][0] =   "Nonuplet Ratio                   subpeak 9 : 1 "
	source[length + 33][0] = "Nonuplet Shift                  		           9 - 1"
	source[length + 34][0] = "Nonuplet Broadening                        9 : 1"
	source[length + 35][0] = "Decuplet Ratio                   subpeak 10 : 1 "
	source[length + 36][0] = "Decuplet Shift                                   10 - 1"
	source[length + 37][0] = "Decuplet Broadening                        10 : 1"	
	
	

	source[length][1] = "off" 
	source[length + 1][1] = "sl"
	source[length + 2][1] = "prb" 
	source[length + 3][1] = "tgd" 
	source[length + 4][1] = "srl"
	source[length + 5][1] = "a" + num2str(numpeaks+1)
	source[length + 6][1] = "p" + num2str(numpeaks+1)
	source[length + 7][1] = "w" + num2str(numpeaks+1)
	source[length + 8][1] = "g" + num2str(numpeaks+1)
	source[length + 9][1] = "as" + num2str(numpeaks+1)
	source[length + 10][1] = "at" + num2str(numpeaks+1)
	source[length + 11][1] = "dr" + num2str(numpeaks+1)
	source[length + 12][1] = "ds" + num2str(numpeaks+1)
	source[length + 13][1] = "db" + num2str(numpeaks+1)
	source[length + 14][1] = "tr" + num2str(numpeaks+1)
	source[length + 15][1] = "ts" + num2str(numpeaks+1)
	source[length + 16][1] = "tb" + num2str(numpeaks+1)
	source[length + 17][1] = "qr" + num2str(numpeaks+1)
	source[length + 18][1] = "qs" + num2str(numpeaks+1)
	source[length + 19][1] = "qb" + num2str(numpeaks+1)
	source[length + 20][1] = "qir" + num2str(numpeaks+1)
	source[length + 21][1] = "qis" + num2str(numpeaks+1)
	source[length + 22][1] = "qib" + num2str(numpeaks+1)
	source[length + 23][1] = "sxr" + num2str(numpeaks+1)
	source[length + 24][1] = "sxs" + num2str(numpeaks+1)
	source[length + 25][1] = "sxb" + num2str(numpeaks+1)
	source[length + 26][1] = "spr" + num2str(numpeaks+1)
	source[length + 27][1] = "sps" + num2str(numpeaks+1)
	source[length + 28][1] = "spb" + num2str(numpeaks+1)
	source[length + 29][1] = "ocr" + num2str(numpeaks+1)
	source[length + 30][1] = "ocs" + num2str(numpeaks+1)
	source[length + 31][1] = "ocb" + num2str(numpeaks+1)
	source[length + 32][1] = "nor" + num2str(numpeaks+1)
	source[length + 33][1] = "nos" + num2str(numpeaks+1)
	source[length + 34][1] = "nob" + num2str(numpeaks+1)
	source[length + 35][1] = "der" + num2str(numpeaks+1)
	source[length + 36][1] = "des" + num2str(numpeaks+1)
	source[length + 37][1] = "deb" + num2str(numpeaks+1)
	
	
	
	source[length][4] = "off" 
	source[length + 1][4] = "sl"
	source[length + 2][4] = "prb" 
	source[length + 3][4] = "tgd" 
	source[length + 4][4] = "srl"
	source[length + 5][4] = "a" + num2str(numpeaks+1)
	source[length + 6][4] = "p" + num2str(numpeaks+1)
	source[length + 7][4] = "w" + num2str(numpeaks+1)
	source[length + 8][4] = "g" + num2str(numpeaks+1)
	source[length + 9][4] = "as" + num2str(numpeaks+1)
	source[length + 10][4] = "at" + num2str(numpeaks+1)
	source[length + 11][4] = "dr" + num2str(numpeaks+1)
	source[length + 12][4] = "ds" + num2str(numpeaks+1)
	source[length + 13][4] = "db" + num2str(numpeaks+1)
	source[length + 14][4] = "tr" + num2str(numpeaks+1)
	source[length + 15][4] = "ts" + num2str(numpeaks+1)
	source[length + 16][4] = "tb" + num2str(numpeaks+1)
	source[length + 17][4] = "qr" + num2str(numpeaks+1)
	source[length + 18][4] = "qs" + num2str(numpeaks+1)
	source[length + 19][4] = "qb" + num2str(numpeaks+1)
	source[length + 20][4] = "qir" + num2str(numpeaks+1)
	source[length + 21][4] = "qis" + num2str(numpeaks+1)
	source[length + 22][4] = "qib" + num2str(numpeaks+1)
	source[length + 23][4] = "sxr" + num2str(numpeaks+1)
	source[length + 24][4] = "sxs" + num2str(numpeaks+1)
	source[length + 25][4] = "sxb" + num2str(numpeaks+1)
	source[length + 26][4] = "spr" + num2str(numpeaks+1)
	source[length + 27][4] = "sps" + num2str(numpeaks+1)
	source[length + 28][4] = "spb" + num2str(numpeaks+1)
	source[length + 29][4] = "ocr" + num2str(numpeaks+1)
	source[length + 30][4] = "ocs" + num2str(numpeaks+1)
	source[length + 31][4] = "ocb" + num2str(numpeaks+1)
	source[length + 32][4] = "nor" + num2str(numpeaks+1)
	source[length + 33][4] = "nos" + num2str(numpeaks+1)
	source[length + 34][4] = "nob" + num2str(numpeaks+1)
	source[length + 35][4] = "der" + num2str(numpeaks+1)
	source[length + 36][4] = "des" + num2str(numpeaks+1)
	source[length + 37][4] = "deb" + num2str(numpeaks+1)
	

	EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
	source[length][3] = MyNum2str(initialOffset)//num2str(max(0,V_min)) 
	source[length + 1][3] = MyNum2str(initialSlope)
	source[length + 2][3] = "0" 
	source[length + 3][3] = "0" 
	source[length + 4][3] = "0"
	source[length + 5][3] = MyNum2str(EstimatedPeakArea)
	source[length + 6][3] = MyNum2str(posA)
	source[length + 7][3] = MyNum2str(Width_Start)
	source[length + 8][3] = MyNum2str(GLratio_Start)
	source[length + 9][3] = MyNum2str(Asym_Start)
	source[length + 10][3] = MyNum2str(Asym_Shift_Start)
	source[length + 11][3] = "0.5"
	source[length + 12][3] = "1.5"
	source[length + 13][3] = "1"
	source[length + 14][3] = "0.33"
	source[length + 15][3] = "2.5"
	source[length + 16][3] = "1"
	source[length + 17][3] = "0.25"
	source[length + 18][3] = "3.5"
	source[length + 19][3] = "1"
	source[length + 20][3] = "0.5"
	source[length + 21][3] = "4.5"
	source[length + 22][3] = "1"
	source[length + 23][3] = "0.33"
	source[length + 24][3] = "5.5"
	source[length + 25][3] = "1"
	source[length + 26][3] = "0.25"
	source[length + 27][3] = "6.5"
	source[length + 28][3] = "1"
	source[length + 29][3] = "0.5"
	source[length + 30][3] = "7.5"
	source[length + 31][3] = "1"
	source[length + 32][3] = "0.33"
	source[length + 33][3] = "8.5"
	source[length + 34][3] = "1"
	source[length + 35][3] = "0.25"
	source[length + 36][3] = "9.5"
	source[length + 37][3] = "1"
	
	
	
	
	sw[length +2][4][0] = 48
	sw[length +3][4][0] = 48   //check checkboxes
	
	sw[length +8][4][0] = 48
	sw[length +9][4][0] = 48
	sw[length +10][4][0] = 48
	sw[length +11][4][0] = 48
	sw[length +12][4][0] = 48
	sw[length +13][4][0] = 48
	sw[length +14][4][0] = 48
	sw[length +15][4][0] = 48
	sw[length +16][4][0] = 48
	sw[length +17][4][0] = 48
	sw[length +18][4][0] = 48
	sw[length +19][4][0] = 48
	sw[length +20][4][0] = 48
	sw[length +21][4][0] = 48
	sw[length +22][4][0] = 48
	sw[length +23][4][0] = 48
	sw[length +24][4][0] = 48
	sw[length +25][4][0] = 48
	sw[length +26][4][0] = 48
	sw[length +27][4][0] = 48
	sw[length +28][4][0] = 48
	sw[length +29][4][0] = 48
	sw[length +30][4][0] = 48
	sw[length +31][4][0] = 48
	sw[length +32][4][0] = 48
	sw[length +33][4][0] = 48
	sw[length +34][4][0] = 48
	sw[length +35][4][0] = 48
	sw[length +36][4][0] = 48
	sw[length +37][4][0] = 48
	
	sw[length+2][5][0] = 0   
	sw[length+3][6][0] = 0    
	
	
	source[length][5] = MyNum2str(-10*abs(initialOffset)) 
	source[length + 1][5] = MyNum2str(-10*abs(initialSlope))
	source[length + 2][5] = "-100" 
	source[length + 3][5] = "-1000" 
	source[length + 4][5] = "1e-6"
	source[length + 5][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
	source[length + 6][5] = MyNum2str(posA-1.5)//MyNum2str(right)
	source[length + 7][5] = MyNum2str(Width_Min)
	source[length + 8][5] =  MyNum2str(GLratio_Min)
	source[length + 9][5] = MyNum2str(Asym_Min)
	source[length + 10][5] = MyNum2str(Asym_Shift_Min)
	source[length + 11][5] = "0.02"
	source[length + 12][5] = "0.1"
	source[length + 13][5] = "0.5"
	source[length + 14][5] = "0.02"
	source[length + 15][5] = "0.1"
	source[length + 16][5] = "0.5"
	source[length + 17][5] = "0.02"
	source[length + 18][5] = "0.1"
	source[length + 19][5] = "0.5"
	source[length + 20][5] = "0.02"
	source[length + 21][5] = "0.1"
	source[length + 22][5] = "0.5"
	source[length + 23][5] = "0.02"
	source[length + 24][5] = "0.1"
	source[length + 25][5] = "0.5"
	source[length + 26][5] = "0.02"
	source[length + 27][5] = "0.1"
	source[length + 28][5] = "0.5"
	source[length + 29][5] = "0.02"
	source[length + 30][5] = "0.1"
	source[length + 31][5] = "0.5"
	source[length + 32][5] = "0.02"
	source[length + 33][5] = "0.1"
	source[length + 34][5] = "0.5"
	source[length + 35][5] = "0.02"
	source[length + 36][5] = "0.1"
	source[length + 37][5] = "0.5"
	
	
	
	source[length][6] = MyNum2str(10*abs(initialOffset))
	source[length + 1][6] = MyNum2str(10*abs(initialSlope))
	source[length + 2][6] = "100" 
	source[length + 3][6] = "1000" 
	source[length + 4][6] = MyNum2str(0.7*abs(V_min-heightA))
	source[length + 5][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
	source[length + 6][6] =  MyNum2str(posA+1.5)//num2str(left )
	source[length + 7][6] = MyNum2str(Width_Max )
	source[length + 8][6] = MyNum2str(GLratio_Max)
	source[length + 9][6] = MyNum2str(Asym_Max)
	source[length + 10][6] = MyNum2str(Asym_Shift_Max)
	source[length + 11][6] = "10"
	source[length + 12][6] = "3"
	source[length + 13][6] = "4"
	source[length + 14][6] = "10"
	source[length + 15][6] = "4"
	source[length + 16][6] = "4"
	source[length + 17][6] = "10"
	source[length + 18][6] = "5"
	source[length + 19][6] = "4"
	source[length + 20][6] = "10"
	source[length + 21][6] = "6"
	source[length + 22][6] = "4"
	source[length + 23][6] = "10"
	source[length + 24][6] = "7"
	source[length + 25][6] = "4"
	source[length + 26][6] = "10"
	source[length + 27][6] = "8"
	source[length + 28][6] = "4"
	source[length + 29][6] = "10"
	source[length + 30][6] = "9"
	source[length + 31][6] = "4"
	source[length + 32][6] = "10"
	source[length + 33][6] = "10"
	source[length + 34][6] = "4"
	source[length + 35][6] = "10"
	source[length + 36][6] = "11"
	source[length + 37][6] = "4"




	source[length][7] = "1e-9" 
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9" 
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-8"
	source[length + 6][7] = "1e-9"
	source[length + 7][7] = "1e-9"
	source[length + 8][7] = "1e-9" 
	source[length + 9][7] = "1e-9"
	source[length + 10][7] = "1e-9"
	source[length + 11][7] = "1e-9"
	source[length + 12][7] = "1e-9"
	source[length + 13][7] = "1e-9" 
	source[length + 14][7] = "1e-9"
	source[length + 15][7] = "1e-9"
	source[length + 16][7] = "1e-9"
	source[length + 17][7] = "1e-9"
	source[length + 18][7] = "1e-9"
	source[length + 19][7] = "1e-9"
	source[length + 20][7] = "1e-9"
	source[length + 21][7] = "1e-9"
	source[length + 22][7] = "1e-9" 
	source[length + 23][7] = "1e-9"
	source[length + 24][7] = "1e-9"
	source[length + 25][7] = "1e-9"
	source[length + 26][7] = "1e-9"
	source[length + 27][7] = "1e-9"
	source[length + 28][7] = "1e-9"
	source[length + 29][7] = "1e-9"
	source[length + 30][7] = "1e-9"
	source[length + 31][7] = "1e-9" 
	source[length + 32][7] = "1e-9"
	source[length + 33][7] = "1e-9"
	source[length + 34][7] = "1e-9"
	source[length + 35][7] = "1e-9"
	source[length + 36][7] = "1e-9"
	source[length + 37][7] = "1e-9"
else
	//now, linking can come into the game ... it will affect the columns 3,4,5,6
	
	newLength = length  + numCoef    // '15' multiplet static function, 33 for decaplet  Ext-multiplet  15-->33
		
	Redimension /n=(newLength,-1) source
	Redimension /n=(newLength,-1) sw	
	
	
	
	numpeaks = floor((length-5)/numCoef)    //needs to be changed   Ext-multiplet   15-->33
	for ( i= length; i<newLength; i+=1)
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor
	
	source[length][0] =         "Area   (first subpeak)  -----  Extended    Multiplet  " + num2str(numpeaks+1) 
	source[length + 1][0] =   "Position                                (subpeak 1)                          "
	source[length + 2][0] =   "Width"
	source[length + 3][0] =   "Gauss-Lorentz Ratio"
	source[length + 4][0] =   "Asymmetry"
	source[length + 5][0] =   "Asymmetry Translation"
	source[length + 6][0] =   "Doublet Ratio                  subpeak 2 : 1"
	source[length + 7][0] =   "Doublet Shift                                  2 - 1"
	source[length + 8][0] =   "Doublet Broadening                       2 : 1"
	source[length + 9][0] =   "Triplet Ratio                     subpeak 3 : 1 "
	source[length + 10][0] = "Triplet Shift                  		             3 - 1"
	source[length + 11][0] = "Triplet Broadening                          3 : 1"
	source[length + 12][0] = "Quadruplet Ratio              subpeak 4 : 1 "
	source[length + 13][0] = "Quadruplet Shift                              4 - 1"
	source[length + 14][0] = "Quadruplet Broadening                   4 : 1"
	source[length + 15][0] =   "Quintuplet Ratio                subpeak 5 : 1"
	source[length + 16][0] =   "Quintuplet Shift                                5 - 1"
	source[length + 17][0] =   "Quintuplet Broadening                     5 : 1"
	source[length + 18][0] =   "Sextuplet Ratio                  subpeak 6 : 1 "
	source[length + 19][0] = "Sextuplet Shift                  		          6 - 1"
	source[length + 20][0] = "Sextuplet Broadening                       6 : 1"
	source[length + 21][0] = "Septuplet Ratio                  subpeak 7 : 1 "
	source[length + 22][0] = "Septuplet Shift                                  7 - 1"
	source[length + 23][0] = "Septuplet Broadening                       7 : 1"
	source[length + 24][0] =   "Octuplet Ratio                    subpeak 8 : 1"
	source[length + 25][0] =   "Octuplet Shift                                    8 - 1"
	source[length + 26][0] =   "Octuplet Broadening                         8 : 1"
	source[length + 27][0] =   "Nonuplet Ratio                   subpeak 9 : 1 "
	source[length + 28][0] = "Nonuplet Shift                  		           9 - 1"
	source[length + 29][0] = "Nonuplet Broadening                        9 : 1"
	source[length + 30][0] = "Decuplet Ratio                   subpeak 10 : 1 "
	source[length + 31][0] = "Decuplet Shift                                   10 - 1"
	source[length + 32][0] = "Decuplet Broadening                        10 : 1"	
	
	
	source[length][1] = "a" + num2str(numpeaks+1)
	source[length + 1][1] = "p" + num2str(numpeaks+1)
	source[length + 2][1] = "w" + num2str(numpeaks+1)
	source[length + 3][1] = "g" + num2str(numpeaks+1)
	source[length + 4][1] = "as" + num2str(numpeaks+1)
	source[length + 5][1] = "at" + num2str(numpeaks+1)
	source[length + 6][1] = "dr" + num2str(numpeaks+1)
	source[length + 7][1] = "ds" + num2str(numpeaks+1)
	source[length + 8][1] = "db" + num2str(numpeaks+1)
	source[length + 9][1] = "tr" + num2str(numpeaks+1)
	source[length + 10][1] = "ts" + num2str(numpeaks+1)
	source[length + 11][1] = "tb" + num2str(numpeaks+1)
	source[length + 12][1] = "qr" + num2str(numpeaks+1)
	source[length + 13][1] = "qs" + num2str(numpeaks+1)
	source[length + 14][1] = "qb" + num2str(numpeaks+1)
	source[length + 15][1] = "qir" + num2str(numpeaks+1)
	source[length + 16][1] = "qis" + num2str(numpeaks+1)
	source[length + 17][1] = "qib" + num2str(numpeaks+1)
	source[length + 18][1] = "sxr" + num2str(numpeaks+1)
	source[length + 19][1] = "sxs" + num2str(numpeaks+1)
	source[length + 20][1] = "sxb" + num2str(numpeaks+1)
	source[length + 21][1] = "spr" + num2str(numpeaks+1)
	source[length + 22][1] = "sps" + num2str(numpeaks+1)
	source[length + 23][1] = "spb" + num2str(numpeaks+1)
	source[length + 24][1] = "ocr" + num2str(numpeaks+1)
	source[length + 25][1] = "ocs" + num2str(numpeaks+1)
	source[length + 26][1] = "ocb" + num2str(numpeaks+1)
	source[length + 27][1] = "nor" + num2str(numpeaks+1)
	source[length + 28][1] = "nos" + num2str(numpeaks+1)
	source[length + 29][1] = "nob" + num2str(numpeaks+1)
	source[length + 30][1] = "der" + num2str(numpeaks+1)
	source[length + 31][1] = "des" + num2str(numpeaks+1)
	source[length + 32][1] = "deb" + num2str(numpeaks+1)


     // start: take care of linking
     if (peakToLink == 0)
		EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
		source[length][3] = MyNum2str(EstimatedPeakArea)
		source[length + 1][3] = MyNum2str(posA)
		source[length + 2][3] = MyNum2str(Width_Start)
		source[length + 3][3] = MyNum2str(GLratio_Start)
		source[length + 4][3] = MyNum2str(Asym_Start)
		source[length + 5][3] = MyNum2str(Asym_Shift_Start)
		source[length + 6][3] = "0.5"
		source[length + 7][3] = "1.5"
		source[length + 8][3] = "1"
		source[length + 9][3] = "0.33"
		source[length + 10][3] = "2.5"
		source[length + 11][3] = "1"
		source[length + 12][3] = "0.25"
		source[length + 13][3] = "3.5"
		source[length + 14][3] = "1"
		source[length + 15][3] = "0.5"
		source[length + 16][3] = "4.5"
		source[length + 17][3] = "1"
		source[length + 18][3] = "0.33"
		source[length + 19][3] = "5.5"
		source[length + 20][3] = "1"
		source[length + 21][3] = "0.25"
		source[length + 22][3] = "6.5"
		source[length + 23][3] = "1"
		source[length + 24][3] = "0.5"
		source[length + 25][3] = "7.5"
		source[length + 26][3] = "1"
		source[length + 27][3] = "0.33"
		source[length + 28][3] = "8.5"
		source[length + 29][3] = "1"
		source[length + 30][3] = "0.25"
		source[length + 31][3] = "9.5"
		source[length + 32][3] = "1"
	
	
	
		sw[length +3][4][0] = 48
		sw[length +4][4][0] = 48
		sw[length +5][4][0] = 48   //check checkboxes
	
		sw[length +6][4][0] = 48
		sw[length +7][4][0] = 48
		sw[length +8][4][0] = 48
		sw[length +9][4][0] = 48
		sw[length +10][4][0] = 48
		sw[length +11][4][0] = 48
		sw[length +12][4][0] = 48
		sw[length +13][4][0] = 48
		sw[length +14][4][0] = 48
		sw[length +15][4][0] = 48
		sw[length +16][4][0] = 48
		sw[length +17][4][0] = 48
		sw[length +18][4][0] = 48
		sw[length +19][4][0] = 48
		sw[length +20][4][0] = 48
		sw[length +21][4][0] = 48
		sw[length +22][4][0] = 48
		sw[length +23][4][0] = 48
		sw[length +24][4][0] = 48
		sw[length +25][4][0] = 48
		sw[length +26][4][0] = 48
		sw[length +27][4][0] = 48
		sw[length +28][4][0] = 48
		sw[length +29][4][0] = 48
		sw[length +30][4][0] = 48
		sw[length +31][4][0] = 48
		sw[length +32][4][0] = 48
	
		source[length][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
		source[length + 1][5] = MyNum2str(posA-1.5)// MyNum2str(right)
		source[length + 2][5] = MyNum2str(Width_Min)
		source[length + 3][5] =  MyNum2str(GLratio_Min)
		source[length + 4][5] = MyNum2str(Asym_Min)
		source[length + 5][5] = MyNum2str(Asym_Shift_Min)
		source[length + 6][5] = "0.02"
		source[length + 7][5] = "0.1"
		source[length + 8][5] = "0.5"
		source[length + 9][5] = "0.02"
		source[length + 10][5] = "0.1"
		source[length + 11][5] = "0.5"
		source[length + 12][5] = "0.02"
		source[length + 13][5] = "0.1"
		source[length + 14][5] = "0.5"
		source[length + 15][5] = "0.02"
		source[length + 16][5] = "0.1"
		source[length + 17][5] = "0.5"
		source[length + 18][5] = "0.02"
		source[length + 19][5] = "0.1"
		source[length + 20][5] = "0.5"
		source[length + 21][5] = "0.02"
		source[length + 22][5] = "0.1"
		source[length + 23][5] = "0.5"
		source[length + 24][5] = "0.02"
		source[length + 25][5] = "0.1"
		source[length + 26][5] = "0.5"
		source[length + 27][5] = "0.02"
		source[length + 28][5] = "0.1"
		source[length + 29][5] = "0.5"
		source[length + 30][5] = "0.02"
		source[length + 31][5] = "0.1"
		source[length + 32][5] = "0.5"
	

		source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		source[length + 2][6] = MyNum2str(Width_Max )
		source[length + 3][6] = MyNum2str(GLratio_Max)
		source[length + 4][6] = MyNum2str(Asym_Max)
		source[length + 5][6] = MyNum2str(Asym_Shift_Max)
		source[length + 6][6] = "10"
		source[length + 7][6] = "3"
		source[length + 8][6] = "4"
		source[length + 9][6] = "10"
		source[length + 10][6] = "4"
		source[length + 11][6] = "4"
		source[length + 12][6] = "10"
		source[length + 13][6] = "5"
		source[length + 14][6] = "4"
		source[length + 15][6] = "10"
		source[length + 16][6] = "6"
		source[length + 17][6] = "4"
		source[length + 18][6] = "10"
		source[length + 19][6] = "7"
		source[length + 20][6] = "4"
		source[length + 21][6] = "10"
		source[length + 22][6] = "8"
		source[length + 23][6] = "4"
		source[length + 24][6] = "10"
		source[length + 25][6] = "9"
		source[length + 26][6] = "4"
		source[length + 27][6] = "10"
		source[length + 28][6] = "10"
		source[length + 29][6] = "4"
		source[length + 30][6] = "10"
		source[length + 31][6] = "11"
		source[length + 32][6] = "4"
	else
		//get the startingIndex of the target peak
		variable startIndexParentPeak = numCoef * (peakToLink -1 ) + 5		//  Ext-multiplet  15 --> 33
	
		if ( linkArea == 0 )
			EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
			source[length][3] = MyNum2str(EstimatedPeakArea)
			sw[length][4][0] = 32
			source[length][5] = MyNum2str(min(10,0.2 * EstimatedPeakArea ))  
			source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		else
			
			source[length][3] = MyNum2str( areaLinkLowerFactor * str2num(source[startIndexParentPeak][3]) )    //start at the lower boundary
			sw[length][4][0] = sw[startIndexParentPeak][4][0]
			source[length][5] = MyNum2str(areaLinkLowerFactor - 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
			source[length ][6] = MyNum2str(areaLinkUpperFactor + 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkPosition == 0 )
			source[length + 1][3] = MyNum2str(posA)
			sw[length + 1][4][0] = 32
			source[length + 1][5] = MyNum2str(posA-1.5) //MyNum2str(right)
			source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		else
			source[length + 1][3] = MyNum2str( str2num( source[startIndexParentPeak + 1][3] ) + positionLinkOffsetMin )
			sw[length + 1][4][0] = sw[startIndexParentPeak +1][4][0]
			source[length + 1][5] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMin-0.01)
			source[length + 1][6] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMax + 0.01)
		endif
		
		if ( linkWidth == 0 )
			source[length + 2][3] = MyNum2str(Width_Start)
			sw[length + 2][4][0] = 32
			source[length + 2][5] = MyNum2str(Width_Min)
			source[length + 2][6] = MyNum2str(Width_Max )
		else
			source[length + 2][3] = source[startIndexParentPeak + 2][3]
			sw[length + 2][4][0] = sw[startIndexParentPeak +2][4][0]
			source[length + 2][5] = StringFromList(2,parameterList) + num2str(peakToLink)
			source[length + 2][6] = StringFromList(2,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkGL == 0 )
			source[length + 3][3] = MyNum2str(GLratio_Start)
			sw[length + 2][4][0] = 32
			source[length + 3][5] =  MyNum2str(GLratio_Min)
			source[length + 3][6] = MyNum2str(GLratio_Max)
		else
			source[length + 3][3] = source[startIndexParentPeak + 3][3]
			sw[length + 3][4][0] = sw[startIndexParentPeak +3][4][0]
			source[length + 3][5] =  StringFromList(3,parameterList) + num2str(peakToLink)
			source[length + 3][6] = StringFromList(3,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkAsym == 0 )
			source[length + 4][3] = MyNum2str(Asym_Start)
			source[length + 5][3] = MyNum2str(Asym_Shift_Start)
			sw[length +3][4][0] = 48
			sw[length +4][4][0] =  48
			sw[length +5][4][0] =  48   //check checkboxes
			source[length + 4][5] = MyNum2str(Asym_Min)
			source[length + 5][5] = MyNum2str(Asym_Shift_Min)
			source[length + 4][6] = MyNum2str(Asym_Max)
			source[length + 5][6] = MyNum2str(Asym_Shift_Max)
		else
			source[length + 4][3] = source[startIndexParentPeak + 4][3]
			source[length + 5][3] = source[startIndexParentPeak + 5][3]
			sw[length +3][4][0] = sw[startIndexParentPeak +3][4][0]
			sw[length +4][4][0] = sw[startIndexParentPeak +4][4][0]
			sw[length +5][4][0] = sw[startIndexParentPeak +5][4][0]
			source[length + 4][5] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][5] = StringFromList(5,parameterList) + num2str(peakToLink)
			source[length + 4][6] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][6] = StringFromList(5,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkMultiRatio == 0)  //link ratio and broadening
			//starting guess       for ratios
			source[length + 6][3] = "0.5"
			source[length + 9][3] = "0.3"
			source[length + 12][3] = "0.25"
			source[length + 15][3] = "0.5"
			source[length + 18][3] = "0.3"
			source[length + 21][3] = "0.25"
			source[length + 24][3] = "0.5"
			source[length + 27][3] = "0.3"
			source[length + 30][3] = "0.25"
			
			//hold true or false
			sw[length + 6][4][0] = 48
			sw[length + 9][4][0] =  48
			sw[length + 12][4][0] =  48   //check checkboxes
			sw[length + 15][4][0] = 48
			sw[length + 18][4][0] =  48
			sw[length + 21][4][0] =  48
			sw[length + 24][4][0] = 48
			sw[length + 27][4][0] =  48
			sw[length + 30][4][0] =  48
			
			//limits
			source[length + 6][5] = "0.02"
			source[length + 9][5] = "0.02"
			source[length + 12][5] = "0.02"
			source[length + 15][5] = "0.02"
			source[length + 18][5] = "0.02"
			source[length + 21][5] = "0.02"
			source[length + 24][5] = "0.02"
			source[length + 27][5] = "0.02"
			source[length + 30][5] = "0.02"
			
			source[length + 6][6] = "10"
			source[length + 9][6] = "10"
			source[length + 12][6] = "10"
			source[length + 15][6] = "10"
			source[length + 18][6] = "10"
			source[length + 21][6] = "10"
			source[length + 24][6] = "10"
			source[length + 27][6] = "10"
			source[length + 30][6] = "10"
			
		
		else
			
			source[length + 6][3] =  source[startIndexParentPeak + 6][3]
			source[length + 9][3] =  source[startIndexParentPeak + 9][3]
			source[length + 12][3] =  source[startIndexParentPeak + 12][3]
			source[length + 15][3] =  source[startIndexParentPeak + 15][3]
			source[length + 18][3] =  source[startIndexParentPeak + 18][3]
			source[length + 21][3] =  source[startIndexParentPeak + 21][3]
			source[length + 24][3] =  source[startIndexParentPeak + 24][3]
			source[length + 27][3] =  source[startIndexParentPeak + 27][3]
			source[length + 30][3] =  source[startIndexParentPeak + 30][3]
			
			sw[length + 6][4][0] = sw[startIndexParentPeak +6][4][0]
			sw[length + 9][4][0] = sw[startIndexParentPeak +9][4][0]
			sw[length + 12][4][0] = sw[startIndexParentPeak +12][4][0]
			sw[length + 15][4][0] = sw[startIndexParentPeak +15][4][0]
			sw[length + 18][4][0] = sw[startIndexParentPeak +18][4][0]
			sw[length + 21][4][0] = sw[startIndexParentPeak +21][4][0]
			sw[length + 24][4][0] = sw[startIndexParentPeak +24][4][0]
			sw[length + 27][4][0] = sw[startIndexParentPeak +27][4][0]
			sw[length + 30][4][0] = sw[startIndexParentPeak +30][4][0]
			
			source[length + 6][5] =  StringFromList(6,parameterList) + num2str(peakToLink)
			source[length + 9][5] = StringFromList(9,parameterList) + num2str(peakToLink)
			source[length + 12][5] = StringFromList(12,parameterList) + num2str(peakToLink)
			source[length + 15][5] =  StringFromList(15,parameterList) + num2str(peakToLink)
			source[length + 18][5] = StringFromList(18,parameterList) + num2str(peakToLink)
			source[length + 21][5] = StringFromList(21,parameterList) + num2str(peakToLink)
			source[length + 24][5] =  StringFromList(24,parameterList) + num2str(peakToLink)
			source[length + 27][5] = StringFromList(27,parameterList) + num2str(peakToLink)
			source[length + 30][5] = StringFromList(30,parameterList) + num2str(peakToLink)
			
			source[length + 6][6] =  StringFromList(6,parameterList) + num2str(peakToLink)
			source[length + 9][6] =  StringFromList(9,parameterList) + num2str(peakToLink)
			source[length + 12][6] =  StringFromList(12,parameterList) + num2str(peakToLink)
			source[length + 15][6] =  StringFromList(15,parameterList) + num2str(peakToLink)
			source[length + 18][6] =  StringFromList(18,parameterList) + num2str(peakToLink)
			source[length + 21][6] =  StringFromList(21,parameterList) + num2str(peakToLink)
			source[length + 24][6] =  StringFromList(24,parameterList) + num2str(peakToLink)
			source[length + 27][6] =  StringFromList(27,parameterList) + num2str(peakToLink)
			source[length + 30][6] =  StringFromList(30,parameterList) + num2str(peakToLink)

		endif
		
		if ( linkSplitting == 0) //this has to be adapted    // starting parameters now the same
					//starting guess       splitting
			source[length + 7][3] = "1.5"
			source[length + 10][3] = "2.5"
			source[length + 13][3] = "3.5"
			source[length + 16][3] = "4.5"
			source[length + 19][3] = "5.5"
			source[length + 22][3] = "6.5"
			source[length + 25][3] = "7.5"
			source[length + 28][3] = "8.5"
			source[length + 31][3] = "9.5"
			
			//hold true or false
			sw[length + 7][4][0] = 48
			sw[length + 10][4][0] =  48
			sw[length + 13][4][0] =  48   //check checkboxes
			sw[length + 16][4][0] = 48
			sw[length + 19][4][0] =  48
			sw[length + 22][4][0] =  48  
			sw[length + 25][4][0] = 48
			sw[length + 28][4][0] =  48
			sw[length + 31][4][0] =  48  
			
			//limits
			source[length + 7][5] = "0.1"
			source[length + 10][5] = "0.1"
			source[length + 13][5] = "0.1"
			source[length + 16][5] = "0.1"
			source[length + 19][5] = "0.1"
			source[length + 22][5] = "0.1"
			source[length + 25][5] = "0.1"
			source[length + 28][5] = "0.1"
			source[length + 31][5] = "0.1"
			
			source[length + 7][6] = "3"
			source[length + 10][6] = "4"
			source[length + 13][6] = "5"
			source[length + 16][6] = "6"
			source[length + 19][6] = "7"
			source[length + 22][6] = "8"
			source[length + 25][6] = "9"
			source[length + 28][6] = "10"
			source[length + 31][6] = "11"
			
			//starting guess ..........       now  for broadening
			source[length + 8][3] = "1"
			source[length + 11][3] = "1"
			source[length + 14][3] = "1"
			source[length + 17][3] = "1"
			source[length + 20][3] = "1"
			source[length + 23][3] = "1"
			source[length + 26][3] = "1"
			source[length + 29][3] = "1"
			source[length + 32][3] = "1"
			
			//hold true or false
			sw[length + 8][4][0] = 48
			sw[length + 11][4][0] =  48
			sw[length + 14][4][0] =  48   //check checkboxes
			sw[length + 17][4][0] = 48
			sw[length + 20][4][0] =  48
			sw[length + 23][4][0] =  48  
			sw[length + 26][4][0] = 48
			sw[length + 29][4][0] =  48
			sw[length + 32][4][0] =  48  
						
			//limits
			source[length + 8][5] = "0.5"
			source[length + 11][5] = "0.5"
			source[length + 14][5] = "0.5"
			source[length + 17][5] = "0.5"
			source[length + 20][5] = "0.5"
			source[length + 23][5] = "0.5"
			source[length + 26][5] = "0.5"
			source[length + 29][5] = "0.5"
			source[length + 32][5] = "0.5"
			
			source[length + 8][6] = "4"
			source[length + 11][6] = "4"
			source[length + 14][6] = "4"
			source[length + 17][6] = "4"
			source[length + 20][6] = "4"
			source[length + 23][6] = "4"
			source[length + 26][6] = "4"
			source[length + 29][6] = "4"
			source[length + 32][6] = "4"
			
		else
			source[length + 7][3] =    source[startIndexParentPeak + 7][3]
			source[length + 10][3] =  source[startIndexParentPeak + 10][3]
			source[length + 13][3] =  source[startIndexParentPeak + 13][3]
			source[length + 16][3] =  source[startIndexParentPeak + 16][3]
			source[length + 19][3] =  source[startIndexParentPeak + 19][3]
			source[length + 22][3] =  source[startIndexParentPeak + 22][3]
			source[length + 25][3] =  source[startIndexParentPeak + 25][3]
			source[length + 28][3] =  source[startIndexParentPeak + 28][3]
			source[length + 31][3] =  source[startIndexParentPeak + 31][3]
			
			source[length + 8][3] = source[startIndexParentPeak + 8][3]
			source[length + 11][3] =  source[startIndexParentPeak + 11][3]
			source[length + 14][3] =  source[startIndexParentPeak + 14][3]
			source[length + 17][3] = source[startIndexParentPeak + 17][3]
			source[length + 20][3] =  source[startIndexParentPeak + 20][3]
			source[length + 23][3] =  source[startIndexParentPeak + 23][3]
			source[length + 26][3] = source[startIndexParentPeak + 26][3]
			source[length + 29][3] =  source[startIndexParentPeak + 29][3]
			source[length + 32][3] =  source[startIndexParentPeak + 32][3]
			
			sw[length + 7][4][0] = sw[startIndexParentPeak +7][4][0]
			sw[length + 10][4][0] = sw[startIndexParentPeak +10][4][0]
			sw[length + 13][4][0] = sw[startIndexParentPeak +13][4][0]
			sw[length + 16][4][0] = sw[startIndexParentPeak +16][4][0]
			sw[length + 19][4][0] = sw[startIndexParentPeak +19][4][0]
			sw[length + 22][4][0] = sw[startIndexParentPeak +22][4][0]
			sw[length + 25][4][0] = sw[startIndexParentPeak +25][4][0]
			sw[length + 28][4][0] = sw[startIndexParentPeak +28][4][0]
			sw[length + 31][4][0] = sw[startIndexParentPeak +31][4][0]
			
			sw[length + 8][4][0] = sw[startIndexParentPeak +8][4][0]
			sw[length + 11][4][0] = sw[startIndexParentPeak +11][4][0]
			sw[length + 14][4][0] = sw[startIndexParentPeak +14][4][0]
			sw[length + 17][4][0] = sw[startIndexParentPeak +17][4][0]
			sw[length + 20][4][0] = sw[startIndexParentPeak +20][4][0]
			sw[length + 23][4][0] = sw[startIndexParentPeak +23][4][0]
			sw[length + 26][4][0] = sw[startIndexParentPeak +26][4][0]
			sw[length + 29][4][0] = sw[startIndexParentPeak +29][4][0]
			sw[length + 32][4][0] = sw[startIndexParentPeak +32][4][0]

			source[length + 7][5] =  StringFromList(7,parameterList) + num2str(peakToLink)
			source[length + 10][5] = StringFromList(10,parameterList) + num2str(peakToLink)
			source[length + 13][5] = StringFromList(13,parameterList) + num2str(peakToLink)
			source[length + 16][5] =  StringFromList(16,parameterList) + num2str(peakToLink)
			source[length + 19][5] = StringFromList(19,parameterList) + num2str(peakToLink)
			source[length + 22][5] = StringFromList(22,parameterList) + num2str(peakToLink)
			source[length + 25][5] =  StringFromList(25,parameterList) + num2str(peakToLink)
			source[length + 28][5] = StringFromList(28,parameterList) + num2str(peakToLink)
			source[length + 31][5] = StringFromList(31,parameterList) + num2str(peakToLink)
			
			source[length + 8][5] =  StringFromList(8,parameterList) + num2str(peakToLink)
			source[length + 11][5] = StringFromList(11,parameterList) + num2str(peakToLink)
			source[length + 14][5] = StringFromList(14,parameterList) + num2str(peakToLink)
			source[length + 17][5] =  StringFromList(17,parameterList) + num2str(peakToLink)
			source[length + 20][5] = StringFromList(20,parameterList) + num2str(peakToLink)
			source[length + 23][5] = StringFromList(23,parameterList) + num2str(peakToLink)
			source[length + 26][5] =  StringFromList(26,parameterList) + num2str(peakToLink)
			source[length + 29][5] = StringFromList(29,parameterList) + num2str(peakToLink)
			source[length + 32][5] = StringFromList(32,parameterList) + num2str(peakToLink)
			
			
			source[length + 7][6] =  StringFromList(7,parameterList) + num2str(peakToLink)
			source[length + 10][6] =  StringFromList(10,parameterList) + num2str(peakToLink)
			source[length + 13][6] =  StringFromList(13,parameterList) + num2str(peakToLink)
			source[length + 16][6] =  StringFromList(16,parameterList) + num2str(peakToLink)
			source[length + 19][6] =  StringFromList(19,parameterList) + num2str(peakToLink)
			source[length + 22][6] =  StringFromList(22,parameterList) + num2str(peakToLink)
			source[length + 25][6] =  StringFromList(25,parameterList) + num2str(peakToLink)
			source[length + 28][6] =  StringFromList(28,parameterList) + num2str(peakToLink)
			source[length + 31][6] =  StringFromList(31,parameterList) + num2str(peakToLink)
			
			source[length + 8][6] =  StringFromList(8,parameterList) + num2str(peakToLink)
			source[length + 11][6] =  StringFromList(11,parameterList) + num2str(peakToLink)
			source[length + 14][6] =  StringFromList(14,parameterList) + num2str(peakToLink)
			source[length + 17][6] =  StringFromList(17,parameterList) + num2str(peakToLink)
			source[length + 20][6] =  StringFromList(20,parameterList) + num2str(peakToLink)
			source[length + 23][6] =  StringFromList(23,parameterList) + num2str(peakToLink)
			source[length + 26][6] =  StringFromList(26,parameterList) + num2str(peakToLink)
			source[length + 29][6] =  StringFromList(29,parameterList) + num2str(peakToLink)
			source[length + 32][6] =  StringFromList(32,parameterList) + num2str(peakToLink)
		endif
	endif
	// stop: take care of linking
	
	source[length][4] = "a" + num2str(numpeaks+1) 
	source[length + 1][4] = "p" + num2str(numpeaks+1)
	source[length + 2][4] = "w" + num2str(numpeaks+1)
	source[length + 3][4] = "g" + num2str(numpeaks+1) 
	source[length + 4][4] = "as" + num2str(numpeaks+1) 
	source[length + 5][4] = "at" + num2str(numpeaks+1) 
	source[length + 6][4] = "dr" + num2str(numpeaks+1)
	source[length + 7][4] = "ds" + num2str(numpeaks+1)
	source[length + 8][4] = "db" + num2str(numpeaks+1)
	source[length + 9][4] = "tr" + num2str(numpeaks+1)
	source[length + 10][4] = "ts" + num2str(numpeaks+1)
	source[length + 11][4] = "tb" + num2str(numpeaks+1)
	source[length + 12][4] = "qr" + num2str(numpeaks+1)
	source[length + 13][4] = "qs" + num2str(numpeaks+1)
	source[length + 14][4] = "qb" + num2str(numpeaks+1)
	source[length + 15][4] = "qir" + num2str(numpeaks+1)
	source[length + 16][4] = "qis" + num2str(numpeaks+1)
	source[length + 17][4] = "qib" + num2str(numpeaks+1)
	source[length + 18][4] = "sxr" + num2str(numpeaks+1)
	source[length + 19][4] = "sxs" + num2str(numpeaks+1)
	source[length + 20][4] = "sxb" + num2str(numpeaks+1)
	source[length + 21][4] = "spr" + num2str(numpeaks+1)
	source[length + 22][4] = "sps" + num2str(numpeaks+1)
	source[length + 23][4] = "spb" + num2str(numpeaks+1)
	source[length + 24][4] = "ocr" + num2str(numpeaks+1)
	source[length + 25][4] = "ocs" + num2str(numpeaks+1)
	source[length + 26][4] = "ocb" + num2str(numpeaks+1)
	source[length + 27][4] = "nor" + num2str(numpeaks+1)
	source[length + 28][4] = "nos" + num2str(numpeaks+1)
	source[length + 29][4] = "nob" + num2str(numpeaks+1)
	source[length + 30][4] = "der" + num2str(numpeaks+1)
	source[length + 31][4] = "des" + num2str(numpeaks+1)
	source[length + 32][4] = "deb" + num2str(numpeaks+1)
	
	
	
	source[length][7] = "1e-8"
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9"
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-9"
	source[length + 6][7] = "1e-9"
	source[length + 7][7] = "1e-9"
	source[length + 8][7] = "1e-9" 
	source[length + 9][7] = "1e-9"
	source[length + 10][7] = "1e-9"
	source[length + 11][7] = "1e-9"
	source[length + 12][7] = "1e-9"
	source[length + 13][7] = "1e-9"
	source[length + 14][7] = "1e-9"
	source[length + 15][7] = "1e-9"
	source[length + 16][7] = "1e-9"
	source[length + 17][7] = "1e-9" 
	source[length + 18][7] = "1e-9"
	source[length + 19][7] = "1e-9"
	source[length + 20][7] = "1e-9"
	source[length + 21][7] = "1e-9"
	source[length + 22][7] = "1e-9"
	source[length + 23][7] = "1e-9"
	source[length + 24][7] = "1e-9"
	source[length + 25][7] = "1e-9"
	source[length + 26][7] = "1e-9" 
	source[length + 27][7] = "1e-9"
	source[length + 28][7] = "1e-9"
	source[length + 29][7] = "1e-9"
	source[length + 30][7] = "1e-9"
	source[length + 31][7] = "1e-9"
	source[length + 32][7] = "1e-9"
	
endif

	Redimension /n=(NumLength+40,-1) numerics   //has to be changed Ext-multiplet  16-->34 should be, setting 40 instead
	Redimension /n=(NumLength+40,-1) selNumerics
	
	//numerics[NumLength][0] = "Multiplet " + num2str(numpeaks+1)
	numerics[NumLength + 0][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 1][0] = " Peak 1"
	numerics[NumLength + 4][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 5][0] =  " Peak 2"
	numerics[NumLength + 8][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 9][0] =  " Peak 3"
	numerics[NumLength + 12][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 13][0] = " Peak 4"
	numerics[NumLength + 16][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 17][0] =  " Peak 5"
	numerics[NumLength + 20][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 21][0] =  " Peak 6"
	numerics[NumLength + 24][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 25][0] = " Peak 7"
	numerics[NumLength + 28][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 29][0] =  " Peak 8"
	numerics[NumLength + 32][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 33][0] =  " Peak 9"
	numerics[NumLength + 36][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 37][0] = " Peak 10"

	
	numerics[NumLength + 1][1] = "Area "
	numerics[NumLength + 5][1] = "Area "
	numerics[NumLength + 9][1] = "Area "
	numerics[NumLength + 13][1] = "Area "
	numerics[NumLength + 17][1] = "Area "
	numerics[NumLength + 21][1] = "Area "
	numerics[NumLength + 25][1] = "Area "
	numerics[NumLength + 29][1] = "Area "
	numerics[NumLength + 33][1] = "Area "
	numerics[NumLength + 37][1] = "Area "

//	numerics[NumLength + 2 ][1] = "Visible Area"
//	numerics[NumLength + 6 ][1] = "Visible Area"
//	numerics[NumLength + 10 ][1] = "Visible Area"
//	numerics[NumLength + 14][1] = "Visible Area"
	
//	numerics[NumLength + 3 ][1] = "Analytical Area"
//	numerics[NumLength + 7 ][1] = "Analytical Area"
//	numerics[NumLength + 11 ][1] = "Analytical Area"
//	numerics[NumLength + 15 ][1] = "Analytical Area"
	
	numerics[NumLength + 1][3] = "Position (Coef.)"
	numerics[NumLength + 5][3] = "Position (Coef.)"
	numerics[NumLength + 9][3] = "Position (Coef.)"
	numerics[NumLength + 13][3] = "Position (Coef.)"
	numerics[NumLength + 17][3] = "Position (Coef.)"
	numerics[NumLength + 21][3] = "Position (Coef.)"
	numerics[NumLength + 25][3] = "Position (Coef.)"
	numerics[NumLength + 29][3] = "Position (Coef.)"
	numerics[NumLength + 33][3] = "Position (Coef.)"
	numerics[NumLength + 37][3] = "Position (Coef.)"
	
	numerics[NumLength + 2][3] = "Effective Position"
	numerics[NumLength + 6][3] = "Effective Position"
	numerics[NumLength + 10][3] = "Effective Position"
	numerics[NumLength + 14][3] = "Effective Position"
	numerics[NumLength + 18][3] = "Effective Position"
	numerics[NumLength + 22][3] = "Effective Position"
	numerics[NumLength + 26][3] = "Effective Position"
	numerics[NumLength + 30][3] = "Effective Position"
	numerics[NumLength + 34][3] = "Effective Position"
	numerics[NumLength + 38][3] = "Effective Position"
	
	numerics[NumLength + 1][5] = "Width (Coef.)"
	numerics[NumLength + 5][5] = "Width (Coef.)"
	numerics[NumLength + 9][5] = "Width (Coef.)"
	numerics[NumLength + 13][5] = "Width (Coef.)"
	numerics[NumLength + 17][5] = "Width (Coef.)"
	numerics[NumLength + 21][5] = "Width (Coef.)"
	numerics[NumLength + 25][5] = "Width (Coef.)"
	numerics[NumLength + 29][5] = "Width (Coef.)"
	numerics[NumLength + 33][5] = "Width (Coef.)"
	numerics[NumLength + 37][5] = "Width (Coef.)"
	
	numerics[NumLength + 2][5] = "Effective Width"
	numerics[NumLength + 6][5] = "Effective Width"
	numerics[NumLength + 10][5] = "Effective Width"
	numerics[NumLength + 14][5] = "Effective Width"
	numerics[NumLength + 18][5] = "Effective Width"
	numerics[NumLength + 22][5] = "Effective Width"
	numerics[NumLength + 26][5] = "Effective Width"
	numerics[NumLength + 30][5] = "Effective Width"
	numerics[NumLength + 34][5] = "Effective Width"
	numerics[NumLength + 38][5] = "Effective Width"

	numerics[NumLength + 1][7] = "Gauss-Lorentz Ratio"
	
	numerics[NumLength + 1][9] = "Asymmetry (coef)"
	numerics[NumLength + 2][9] = "Effective Asymmetry:"
	numerics[NumLength + 3][9] = "1 - (fwhm_right)/(fwhm_left):"
	 
	 numerics[NumLength + 1][11] = "Asymmetry translation (coef)"
	
	numerics[NumLength+8][9] = "Total multiplet area " 
	numerics[NumLength+9][9] = "--------------------------------------------- " 
	numerics[NumLength+10][9] = "Sum of area coefficients" // STnum2str(totalCoefSum)
//	numerics[NumLength+11][9] = "Sum of visible peak areas" //STnum2str(totalVisibleArea)
//	numerics[NumLength + 12][9] = "Sum of analytical areas"  //STnum2str(totalAnalyticalSum)
	
	FancyUp("foe")
	setup2Waves()	
end

/// 2  ////////////////////////////////////////////////////////////
///////////////   Display it in the peak fitting window ///////////////////////////////////////////////

static function PlotExtMultipletSKDisplay(peakType,RawYWave, RawXWave,coefWave)
	string peakType
	string RawYWave
	string RawXWave
	string coefWave
	string TagName    // the Tag in the result window
	string PeakTag     // text in this tag
	string PkName, parentDataFolder //, cleanUpString=""		
	string BGName //background
	string PeakSumName
	NVAR FitMin = root:STFitAssVar:STFitMin
	NVAR FitMax = root:STFitAssVar:STFitMax
	
	wave cwave = $coefWave
	wave raw = $RawYWave
//	wave xraw = $RawXWave
	variable LenCoefWave = DimSize(cwave,0)
	
	//create some waves, to display the peak
	variable nPeaks = 0
	variable numCoef
	variable numSubPeaks = 10
	variable i,index,k
	variable xmin, xmax, step
	variable TagPosition   //the position of the tag in the result window
	variable totalPeakSumArea, partialPeakSumArea
	 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate  		                     
			break
		case "_calculated_":
			 duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate  
			break
		default:                                                 // if not empty, x-axis wave necessary
			//read in the start x-value and the step size from the x-axis wave
			wave xraw = $RawXWave
			xmax = max(xraw[0],xraw[numpnts(xraw)-1] )
			xmin = min(xraw[0],xraw[numpnts(xraw)-1] )
			step = (xmax - xmin ) / DimSize(xraw,0)
			// now change the scaling of the y-wave duplicate, so it gets equivalent to a data-wave imported from an igor-text file
			duplicate /o raw tempWaveForCutting  
			SetScale /I x, xmin, xmax, tempWaveForCutting  //OKAY, NOW THE SCALING IS ON THE ENTIRE RANGE
			duplicate /o /R=(FitMin,FitMax) tempWaveForCutting WorkingDuplicate  
			killwaves /z tempWaveForCutting
			break
	endswitch
	
	parentDataFolder = GetDataFolder(1)
	
	
	//now make tabular rasa in the case of background functions
	string ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	variable numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	
	// If a wave is given which needs an external x-axis (from an ASCII-file) create a duplicate which receives a proper x-scaling later on
	// the original wave will not be changed
	KillDataFolder /z :Peaks  //if it exists from a previous run, kill it
	//now recreate it, so everything is updated             
	NewDataFolder /O /S :Peaks

 	numCoef =33   //Voigt with Shirley and Slope     //this has to be changed too, if a new static function is implemented   Ext-multiplet  15->33  
 	numSubPeaks = 10  // number of peaks in multiplet
 	
 	nPeaks = (LenCoefWave-5)/numCoef
	
	PeakSumName = "pS_"+RawYWave
			
	duplicate /o WorkingDuplicate $PeakSumName
	wave tempSumDisplay = $PeakSumName
			
			
	//update the graph, remove everything	
	for (i =1; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	string SubPeakName
	variable j, para1,para2,para3
	tempSumDisplay = 0
	variable areaPeak = 0
	//create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
	
	
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i + 5         //numCoef has to be changed for each  new fitting static function
		PkName = "m" + num2istr(i+1) + "_" + RawYWave  //make a propper name
	 	
	 	duplicate /o WorkingDuplicate $PkName	
		wave tempDisplay = $PkName 
		tempDisplay = 0      
	 	
	 	for ( j = 0; j < numSubPeaks; j += 1)     //for 10 subpeaks: j<10   Ext-multiplet    4 ->10
	 	
	 		SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + RawYWave
	 		duplicate /o WorkingDuplicate $SubPeakName
	 		wave subPeak = $SubPeakName
	 		
	 	      para1 = cwave[index]*(j==0) + (j !=0)*cwave[index]*cwave[index+6+3*(j-1)]   
	 	      para2 = cwave[index+1]*(j==0) + (j !=0)*(cwave[index+1]+cwave[index+7+3*(j-1)] ) 
	 	      para3 = cwave[index+2]*(j==0) + (j !=0)*cwave[index+2]*cwave[index+8+3*(j-1)]  
	 	      
	 		subPeak = CalcSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5],x)
	 		areaPeak= IntegrateSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
			subPeak /= areaPeak
			subPeak *= para1
	 		tempDisplay += subPeak
	 		
	 		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
	 		AppendToGraph /w= CursorPanel#guiCursorDisplayFit subPeak    	
	 		
	 	endfor
	 	                                     

		 //overwrite the original values in the wave with the values of a single peak
		//tempDisplay = CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)	
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 6] * cwave[index],cwave[index + 7] + cwave[index+1], cwave[index + 8] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 9] * cwave[index],cwave[index + 10] + cwave[index+1], cwave[index + 8] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 12] * cwave[index],cwave[index + 13] + cwave[index+1], cwave[index + 14] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
	
		tempSumDisplay += tempDisplay
		
		
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
		AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempDisplay                           //now plot it
		
		WaveStats /Q tempDisplay
		tagName = PkName+num2istr(i)
		PeakTag = num2istr(i+1)
		TagPosition = V_maxloc
		
		Tag /w= CursorPanel#guiCursorDisplayFit /C /N= $tagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag
		ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($PkName)=(0,0,0)       // and color-code it	
	endfor
	//get the sum of all peaks and (i) calculate the Shirley, (ii) calculate the line offset and (iii) display the background and the individual sums of peak + Background
	BGName ="bg_"+ RawYWave ///should name the background accordingly
	
	duplicate /o WorkingDuplicate $BGName
	wave tempBGDisplay = $BGName //this is the wave to keep the background
	
	duplicate /o WorkingDuplicate HGB
	wave hgb = HGB
	
	// now calculate the background with tempSumDisplay
	totalPeakSumArea = sum(tempSumDisplay)
	//print totalPeakSumArea
	partialPeakSumArea = 0
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))    //x decreases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[i]
			tempBGDisplay[i] =partialPeakSumArea/totalPeakSumArea 
		endfor
	else //x increases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[numpnts(tempSumDisplay) -1 - i]
			tempBGDisplay[numpnts(tempSumDisplay) -1 - i] = partialPeakSumArea/totalPeakSumArea 
		endfor
	endif
			
	//now add the Herrera-Gomez background
	partialPeakSumArea = 0
	totalPeakSumArea = sum(tempBGDisplay)
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))   //binding energy increases with point index
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[i])
			hgb[i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	else                     //binding energy decreases with point index
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[numpnts(tempSumDisplay)-1-i])
			hgb[numpnts(tempSumDisplay)-1-i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	endif
	hgb *= cwave[3]	
			
	tempBGDisplay *= cwave[4]  //shirley height
	tempBGDisplay += hgb
//	Killwaves /z temporaryShirleyWave
	
//	for (i =0; i<nPeaks;i+=1)
//		index = numCoef*i + 5
//		tempBGDisplay += 1e-3*cwave[3]*cwave[index]*( x - cwave[index+1] )^2 * ( x > cwave[index+1] ) 
//	endfor
			
	tempBGDisplay += cwave[0] + cwave[1]*x + cwave[2]*x^2
	
	AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempBGDisplay 
		
	//now add the background to all peaks
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i
		PkName = "m" + num2istr(i+1) + "_"+RawYWave   //make a proper name
		for ( j = 0; j < numSubPeaks; j += 1)                                                                                 //change here too //////////////////////////////////////////////////////////////////////////// Ext-multiplet   4-->10
	 	
	 		SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + RawYWave
	 		wave subPeak = $SubPeakName
			subPeak += tempBGDisplay
			ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($SubPeakName)=(43520,43520,43520) 
	 	endfor
		
		wave tempDisplay = $PkName        //This needs some explanation, see commentary at the end of the file                                        
		
		 //overwrite the original values in the wave with the values of a single peak
		tempDisplay  += tempBGDisplay
	endfor
		
	tempSumDisplay += tempBGDisplay
	//for now, don't use tempSumDisplay, however, leave it in the code for possible future use
	killwaves /z tempSumDisplay   //remove this line, if the sum of the peaks is going to be used again
	killwaves /z HGB
	WaveStats /Q WorkingDuplicate
//	SetAxis /w = CursorPanel#guiCursorDisplayFit left -0.1*V_max, 1.1*V_max
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	SetAxis/A/R /w = CursorPanel#guiCursorDisplayFit bottom
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	SetDataFolder parentDataFolder 
	killwaves /Z WorkingDuplicate
end




///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////

static function DrawAndEvaluateExtMultipletSK(dataWave,fitWave,peakType,RawXWave,newFolder)
string dataWave
string fitWave
string peakType
string RawXWave
variable newFolder               //if this value is different from 1, no folder for the results will be created

SVAR projectName = root:STFitAssVar:ProjectName

wave cwave = W_coef
wave origWave = $dataWave
wave fitted = $fitWave
wave epsilon = epsilon
wave hold = hold
wave InitializeCoef = InitializeCoef
wave Min_Limit = Min_Limit
wave Max_Limit = Max_Limit
wave T_Constraints = T_Constraints
wave  CoefLegend = CoefLegend

if ( strlen(fitWave) >= 30)	
	doalert 0, "The name of the fit-wave is too long! Please shorten the names."
	return -1
endif


//define further local variables
variable LenCoefWave = DimSize(cwave,0)	
variable nPeaks
variable index
variable i =0                               //general counting variable
variable numCoef                       //variable to keep the number of coefficients of the selected peak type
							  // numCoef = 3   for Gauss Singlet     and numCoef =5 for VoigtGLS
variable numSubPeaks = 10
variable pointLength, totalArea, partialArea
variable peakMax 
variable TagPosition
variable AnalyticalArea
variable EffectiveFWHM
variable GeneralAsymmetry        //  = 1 - (fwhm_right)/(fwhm_left)

string PkName                          //string to keep the name of a single peak wave
string foldername                       //string to keep the name of the datafolder, which is created later on for the single peak waves
string tempFoldername               //help-string to avoid naming conflicts
string parentDataFolder
string TagName
string PeakTag
string LastGraphName
string NotebookName = "Report"     //this is the initial notebook name, it is changed afterwards
string tempNotebookName
string tempString                          // for a formated output to the notebook
string BGName
//The following switch construct is necessary in order to plot waveform data (usually from igor-text files , *.itx) as well as
//raw spectra which need an extra x-axis (such data come usually from an x-y ASCII file)

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		display /K=1 origWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
		break
	case "_calculated_":
		display /K=1 origWave
		break
	default:
		wave xraw = $RawXWave                                                 // if not empty
		display /K=1 origWave vs xraw        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
endswitch
ModifyGraph mode($dataWave)=3,msize($dataWave)=1.3, marker($dataWave)=8
ModifyGraph mrkThick($dataWave)=0.7
ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
    
LastGraphName = WinList("*", "", "WIN:")    //get the name of the graph

//check if this Notebook already exists
V_Flag = 0
DoWindow $NotebookName   
// if yes, construct a new name
if (V_Flag)
	i = 1
	do 
		tempNoteBookName = NotebookName + num2istr(i)
		DoWindow $tempNotebookName
		i += 1
	while (V_Flag)
	NotebookName = tempNotebookName 
endif
//if not, just proceed

NewNotebook /F=1 /K=1 /N=$NotebookName      //make a new notebook to hold the fit report
Notebook $NoteBookName ,fsize=8




//prepare a new datafolder for the fitting results, in particular the single peaks
parentDataFolder = GetDataFolder(1)    //get the name of the current data folder

if (newFolder == 1)
	NewDataFolder /O /S subfolder
	//now, this folder is the actual data folder, all writing is done here and not in root
endif

duplicate /o fitted tempFitWave
wave locRefTempFit = tempFitWave
locRefTempFit = 0

//now decompose the fit into single peaks --- if a further fit static function is added, a further "case" has to be attached

		numCoef = 33      //has to be changed for a different peak type  Ext-multiplet   15->33
		
		nPeaks = (LenCoefWave-5)/numCoef         //get the number of  peaks from the output wave of the fit
		//check, if the peak type matches the length of the coefficient wave
		//if not so, clean up, inform and exit
		BGName = "PS_bg" +"_" + dataWave 
		duplicate /o fitted $BGName
		wave background = $BGName
		
		duplicate /o fitted HGB
		wave hgb = HGB
		AppendToGraph background
		
		if (mod(LenCoefWave-5,numCoef) != 0)
			DoAlert 0, "Mismatch, probably wrong peak type selected or wrong coefficient file, check your fit and peak type "
			SetDataFolder parentDataFolder 
			KillDataFolder  /Z subfolder
			print " ******* Peak type mismatch - check your fit and peak type ******"
			return 1
		endif 
		
		Notebook $NoteBookName ,text="\r\r" 
		
		//continue here ......
		variable j,para1,para2,para3, sumCoef, sumAnalytical
		
		
		string SubPeakName
		variable areaPeak = 0
		for (i =0; i<nPeaks;i+=1)
			index = numCoef*i + 5
			PkName = "m" + num2istr(i+1)+"_" + dataWave    //make a proper name
			 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
			duplicate /o fitted $PkName
							
			wave W = $PkName        //This needs some explanation, see commentary at the end of the file                                        
			
			
			
			W = 0
			sprintf  tempString, "\r\r\r ExtMultiplet  %1g     ======================================================================================\r\r",(i+1)
			Notebook $NoteBookName ,text=tempString
			sumCoef = 0
			sumAnalytical = 0
			for ( j = 0; j < numSubPeaks; j += 1)    // for 10 subpeaks: j<10  Ext-multiplet   4-->10
	 			SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + dataWave
	 			duplicate /o fitted $SubPeakName
		 		wave subPeak = $SubPeakName
		 	      para1 = cwave[index]*(j==0) + (j !=0)*cwave[index]*cwave[index+6+3*(j-1)] 
		 	      sumCoef += para1
		 	      para2 = cwave[index+1]*(j==0) + (j !=0)*(cwave[index+1]+cwave[index+7+3*(j-1)] ) 
		 	      para3 = cwave[index+2]*(j==0) + (j !=0)*cwave[index+2]*cwave[index+8+3*(j-1)]  
		 		
		 		subPeak = CalcSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5],x)
		 		areaPeak= IntegrateSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
				subPeak /= areaPeak
				subPeak *= para1
		 		
		 		
				//AnalyticalArea =  IntegrateSingleVoigtGLS(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5]) //*( ( j==0 ) + ( j != 0)*cwave[index+6+3*(j-1)] )
				//sumAnalytical += AnalyticalArea
				EffectiveFWHM = CalcFWHMSingleVoigtGLS(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
				GeneralAsymmetry = CalcGeneralAsymmetry(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])   
				WaveStats /Q subPeak 
		 		
				sprintf  tempString, " Peak %1g	  Area\t|\tPosition\t|\tFWHM\t|\tGL-ratio\t|\tAsym.\t|\tAsym. Shift\t\r",(j+1)
				Notebook $NoteBookName ,text=tempString
				sprintf  tempString, "\t%s\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t\r" ,  STnum2str(para1), para2,para3 ,cwave[index+3] , cwave[index+4],cwave[index+5]
				Notebook $NoteBookName ,text=tempString	
				sprintf  tempString, "\rEffective maximum position\t\t\t\t%8.2f \r", V_maxloc  // "-> In case of asymmetry, this value does not represent an area any more"
				Notebook $NoteBookName ,text=tempString
				sprintf  tempString, "Effective FWHM\t\t\t\t\t%8.2f \r", EffectiveFWHM	
				Notebook $NoteBookName ,text=tempString	
				sprintf tempString, "Effective Asymmetry = 1 - (fwhm_right)/(fwhm_left)\t\t%8.2f \r\r\r\r" , GeneralAsymmetry
				Notebook $NoteBookName ,text=tempString
		 				
		 		W += subPeak
		 		AppendToGraph subPeak
		 		//ModifyGraph lstyle($SubPeakName)=2
		 		ModifyGraph lstyle($SubPeakName)=0,rgb($SubPeakName)=(43520,43520,43520)
		 	endfor
			
			
			
			
			 //overwrite the original values in the wave with the values of a single peak
			//W =  CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
			locRefTempFit += W         
			
			AppendToGraph W                                                    //now plot it

			//append the peak-tags to the graph, let the arrow point to a maximum
			//append the peak-tags to the graph, let the arrow point to a maximum
			WaveStats /Q W                             // get the location of the maximum
			TagName = "tag"+num2istr(i)           //each tag has to have a name
			PeakTag = num2istr(i+1)                 // The tag displays the peak index
			TagPosition = V_maxloc                 // and is located at the maximum
			Tag  /C /N= $TagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag    // Now put the tag there
			sprintf  tempString, "Total multiplet area\r-------------------------------------\r  %s  \t\t(sum of fit coefficients - usually larger than visible area within measurement window) ",  STnum2str(sumCoef)
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "\r  %s  \t\t(area within measurement window) ",  STnum2str(area(W))
			Notebook $NoteBookName ,text=tempString
			//sprintf tempString, "\r %s  \t\t(sum of analytical areas)", STnum2str(sumAnalytical)
			//Notebook $NoteBookName ,text=tempString
			sprintf tempString, "\r\r==================================================================================================\r\r\r"
			//Notebook $NoteBookName ,text=tempString
			
			
			Notebook $NoteBookName ,text=tempString
			ModifyGraph rgb($PkName)=(10464,10464,10464)              // color code the peak
				
			
		endfor
		
		
		//and now, add the background
		pointLength = numpnts(locRefTempFit)
		totalArea = sum(locRefTempFit)
		partialArea = 0
		
		//distinguish between ascending and descending order of the points in the raw-data wave
		if (pnt2x(locRefTempFit,0) > pnt2x(locRefTempFit,1))   //with increasing index, x decreases
			for (i=pointLength-1; i ==0; i -=1)	
				partialArea += abs(locRefTempFit[i]) 
		
				background[i] = partialArea/totalArea

			endfor
			//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = pointLength; i == 0; i -= 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			background *= cwave[4]
			background += hgb
			//for (i =0; i<nPeaks;i+=1)
			//	index = numCoef*i + 5
		//		background += 1e-3*cwave[3]*cwave[index] * ( x - cwave[index + 1])^2 * ( x > cwave[index+1])
		//	endfor
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
		else
			for (i=0; i<pointLength; i += 1)
					partialArea += abs(locRefTempFit[i]) 
					background[i] =partialArea/totalArea 
			endfor
				//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = 0; i < pointLength; i += 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			
			
			background *= cwave[4]
			background += hgb
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
			
		endif
		//now, everything should be fine with the background .... carry on
		
		locRefTempFit += background
		
		
		tempString = "\r\r\r\r\rFurther Details\r"
		Notebook $NoteBookName ,text=tempString
		tempString = "==================================================================================================="
		Notebook $NoteBookName ,text=tempString
		strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
			case "":                                             //if empty
				 sprintf  tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))           
			break
			case "_calculated_":
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))
			break
			default:                                                 // if not empty
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(areaXY(xraw,origWave))
				break
		endswitch
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "Total area of all peaks in measurement window:\t\t%s \r" STnum2str(area(locRefTempFit) - area(background))
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "Area of the background in measurement window:\t\t%s \r", STnum2str(area(background) )
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\rYou used a simultaneous fit of background  and signal: MAKE SURE the background shape makes sense.\r" 
		Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, "For details on the \r -- Peak shape:  Surface and Interface Analysis (2014), 46, 505 - 511  (If you use this program, please read and cite this paper) \r" 
		//Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, " -- 'Pseudo-Tougaard' and Shirley contribution to the background:  J. Elec. Spectrosc. Rel. Phen (2013), 189, 76 - 80\r" 
		//Notebook $NoteBookName ,text=tempString
		sprintf tempString,"\rPlease note that for asymmetric peaks the fit coefficients for position and FWHM are merely coefficients. \rIn this case, refer to the respective 'effective' values.\r"      
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rBackground\r==================================\rThe background is calculated as follows:  Offset + a*x + b*x^2 + c * (pseudo-tougaard) + d * shirley\r" 
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\r(Here:  Offset=%8.2g;      a =%8.2g;      b =%8.2g;   c =%8.4g;   d =%8.2g; ) \r", cwave[0], cwave[1], cwave[2], cwave[3], cwave[4]
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rThe parameters a and b  serve to cover general slopes or curvatures in the background, for example if the peak sits on a complex mixture of  broad Auger lines or plasmons.\r" 
		Notebook $NoteBookName ,text=tempString
		
		sprintf tempString, "\rPeak Areas\r==================================\rThe peak area is obtained by integrating the peak on an interval of +/- 90*FWHM around the peak position."
		Notebook $NoteBookName ,text=tempString
		
		sprintf tempString, "\rThis value is generally somewhat larger than the visible peak area within the limited measurement window."
		Notebook $NoteBookName ,text=tempString
		
		
		
		//and now add the background to all peaks as well
		for (i =0; i<nPeaks;i+=1)
			PkName = "m" + num2istr(i+1)+"_" + dataWave    					
			wave W = $PkName       
			W += background
			for ( j = 0; j < numSubPeaks; j += 1)     //needs to be changed for another peak  Ext-multiplet   4-->10
	 			SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + dataWave
	 			wave subPeak = $SubPeakName
		 	      subPeak += background
		 	endfor			
		endfor
		

//killwaves /z  fitted     //this applies to the original fit-wave of Igor, since it is a reference to the wave root:Igor-FitWave, the original wave is possibly wrong
//duplicate /o locRefTempFit, $fitWave               //but we are still in the subfolder, 
//killwaves /z locRefTempFit
//wave fitted = $fitWave


	SetDataFolder parentDataFolder 

	//create a copy of the coefficient wave in the subfolder, so the waves 
	//and the complete fitting results are within that folder
	duplicate /o :$dataWave, :subfolder:$dataWave
//	if (WaveExists($RawXWave))
	if (Exists(RawXWave))
		duplicate /o :$RawXWave, :subfolder:$RawXWave
	endif

	//duplicate  :$fitWave, :subfolder:$fitWave
//	killwaves /z :$fitWave            //probably fails, if the fit wave is displayed in the main panel as well
	duplicate /o $fitWave :subfolder:$fitWave
	AppendToGraph :subfolder:$fitWave                                //draw the complete fit
	ModifyGraph rgb($fitWave) = (0,0,0)       //color-code it
	//Remove the original wave, which is located in the parent directory and replace it by the copy in the subfolder
	RemoveFromGraph $"#0" 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph :subfolder:$dataWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
			break
		case "_calculated_":
			AppendToGraph  :subfolder:$dataWave
			break
		default:                                                 // if not empty
			AppendToGraph :subfolder:$dataWave vs :subfolder:$RawXWave        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
	endswitch

	foldername = "Report_" + projectName
	
	//foldername ="Fit_"+ dataWave
	i=1   //index variable for the data folder	
	            //used also for the notebook
	V_Flag = 0
	DoWindow $folderName
	tempFoldername = foldername
	
	if (V_Flag)    //is there already a folder with this name
		do
			V_Flag = 0
			tempFoldername = foldername + "_" + num2istr(i)
			DoWindow $tempFolderName
			i+=1
		while(V_Flag)
		
		if (strlen(tempFoldername) >= 30)	
			//doalert 0, "The output folder name is too long! Please shorten the names. The output folder of the current run is named 'subfolder'."
			string NewName = ""
			
			Prompt NewName, "The wave name is too long, please provide a shorter name "		// Set prompt for y param
			DoPrompt "Shorten the name", NewName
			if (V_Flag)
				return -1								// User canceled
			endif	
			tempFolderName = NewName	
		endif
			RenameDataFolder subfolder, $tempFoldername                   //now rename the peak-folder accordingly
			Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST (2015)" //\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
			//remove illegal characters from the string
			tempFoldername = stringClean(tempFoldername)
			DoWindow /C $tempFoldername
			DoWindow /F $LastGraphName
			DoWindow /C $tempFoldername + "_graph"
			//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"   //valid in Igor 6.x
		//TextBox/N=text0/A=LT tempFoldername        //prints into the graph
	else 
		//no datafolder of this name exist
		RenameDataFolder subfolder, $foldername 
		//TagWindow(foldername)
		Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST (2015)" //\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
		//if ( strsearch(foldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		//	foldername = ReplaceString(".", foldername,"_")
		//endif
		foldername = stringClean(foldername)
		tempFoldername = stringClean(tempFoldername)
		DoWindow /C $foldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
	endif

//make the graph look good
ModifyGraph mode($dataWave)=3 ,msize($dataWave)=1.3 // ,marker($dataWave)=8, opaque($dataWave)=1
ModifyGraph opaque=1,marker($dataWave)=19
ModifyGraph rgb($dataWave)=(60928,60928,60928)
ModifyGraph useMrkStrokeRGB($dataWave)=1
ModifyGraph mrkStrokeRGB($dataWave)=(0,0,0)
//ModifyGraph mrkThick($dataWave)=0.7
//ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
ModifyGraph mirror=2,minor(bottom)=1
Label left "\\f01 intensity (counts)"
Label bottom "\\f01  binding energy (eV)"	
ModifyGraph width=255.118,height=157.465, standoff = 0, gfSize=11

//The following command works easily, but then the resulting graph is not displayed properly in the notebook
//SetAxis/A/R bottom
//instead do it like this:
variable left,right

strswitch(RawXWave)
	 	case "":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	case "_calculated_":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	default:
	 		waveStats /Q $RawXWave
	 		left = V_max
	 		right = V_min
	 	break
 endswitch
 SetAxis bottom left,right
//okay this is not perfectly elegant ... but

WaveStats /Q $dataWave
SetAxis left V_min-0.05*(V_max-V_min), 1.02*V_max
LastGraphName = WinList("*", "", "WIN:")



Notebook  $tempFoldername, selection = {startOfFile,startOfFile}

tempString = "\rReport for fitting project: \t\t " + projectName + "\r"
Notebook  $tempFoldername, text=tempString
Notebook  $tempFoldername, selection = {startOfPrevParagraph,endOfPrevParagraph}, fsize = 12, fstyle = 0

tempString = "\r==================================================================================================="
Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}, text=tempString
Notebook $tempFolderName ,selection = {startOfNextParagraph,startOfNextParagraph}, text="Saved in:\t\t\t\t\t" + IgorInfo(1) + ".pxp \r"
Notebook $tempFolderName ,text="Spectrum:\t\t\t\t" +dataWave
Notebook $tempFolderName ,text="\rApplied peak shape:\t\t\t"+ peakType +"\r\r"

Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}
Notebook  $tempFoldername, picture={$LastGraphName, 0, 1} , text="\r\r\r" 

killwaves /z hgb
KillWindow $LastGraphName
//Notebook  $tempFoldername, text="\r \r"  

KillDataFolder /z tempFoldername

//now clean up
killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr

end





static function EvaluateExtMultipletSK()

wave cwave = W_Coef /// hard-coded but what the hell....

wave /t output = Numerics    //here we write the results

variable AnalyticalArea = 0
variable EffectiveFWHM = 0
variable GeneralAsymmetry = 0

variable i,j,k,index, index2
variable numpeaks
variable numCoef = 33              //  Ext-multiplet    15--> 33
variable numSubPeaks = 10

variable lengthCoef = numpnts(cwave)
variable lengthNumerics = DimSize(output,0)
string parentFolder = ""
string item = ""
numpeaks = (lengthCoef-5)/numCoef
variable EffectiveArea,EffectivePosition
string wavesInDataFolder = WaveList("*fit_*",";","DIMS:1")
wave fitted = $StringFromList(0,wavesInDataFolder)
variable areaW
string FormatString

variable totalCoefSum = 0
variable totalVisibleArea = 0
variable totalAnalyticalSum = 0
string tempString

variable areaPeak = 0
for ( i = 0; i < numPeaks; i += 1 ) 
	index = numCoef*i + 5                     //  Ext-multiplet  15-->33
	//this static function also needs to analyze the waves to get the effective position etc.
	 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
	duplicate /o fitted tempForAnalysis
							
	wave W = tempForAnalysis
	 
	 //iterate for all subpeaks
	W =  CalcSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
	areaPeak= IntegrateSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	W /= areaPeak
	W *= cwave[index]
	WaveStats/Q W
	//areaW=area(W)                          
	
	//AnalyticalArea =  IntegrateSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	GeneralAsymmetry = CalcGeneralAsymmetry(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])   
	//totalAnalyticalSum += AnalyticalArea
	
	//Now write the results to Numerics //there is no need to re-calculate for each individual peak, the values may be derived from the
	//parameters

	index2 = 40*i                     //////////////    Ext Multiplett  should be 16--->34  setting 40 instead	
	
	// Area
	
	//  peak 1

	output[index2+1][2] = STnum2str(cwave[index])
	output[index2+2][2] = "" 
	output[index2+2][1] = "" 
	output[index2+3][2] = "" 
	output[index2+3][1] = "" 
	
	//  peak 2
	
	output[index2+5][2] = STnum2str(cwave[index]*cwave[index +6])
	output[index2+6][2] = "" 
	output[index2+6][1] = "" 

	output[index2+7][2] = ""
	output[index2+7][1] = ""
	
	//  peak 3
	
	output[index2+9][2] = STnum2str(cwave[index]*cwave[index +9])
	output[index2+10][2] = "" 
	output[index2+10][1] = "" 

	output[index2+11][2] = ""
	output[index2+11][1] = ""
	
	//  peak 4

	output[index2+13][2] = STnum2str(cwave[index]*cwave[index +12])
	output[index2+14][2] = ""
	output[index2+14][1] = ""
	
	
	output[index2+15][2] = "" 
	output[index2+15][1] = "" 
	
	// peak 5
	
	output[index2+17][2] = STnum2str(cwave[index]*cwave[index +15])
	output[index2+18][2] = ""
	output[index2+18][1] = ""
	
	
	output[index2+19][2] = "" 
	output[index2+19][1] = "" 
	
	
	//peak 6
	
	output[index2+21][2] = STnum2str(cwave[index]*cwave[index +18])
	output[index2+22][2] = ""
	output[index2+22][1] = ""
	
	
	output[index2+23][2] = "" 
	output[index2+23][1] = "" 
	
	
	
	//peak 7
	
	output[index2+25][2] = STnum2str(cwave[index]*cwave[index +21])
	output[index2+26][2] = ""
	output[index2+26][1] = ""
	
	
	output[index2+27][2] = "" 
	output[index2+27][1] = "" 
	
	
	//peak 8
	
	output[index2+29][2] = STnum2str(cwave[index]*cwave[index +24])
	output[index2+30][2] = ""
	output[index2+30][1] = ""
	
	
	output[index2+31][2] = "" 
	output[index2+31][1] = "" 
	
	
	//peak 9
	
	output[index2+33][2] = STnum2str(cwave[index]*cwave[index +27])
	output[index2+34][2] = ""
	output[index2+34][1] = ""
	
	
	output[index2+35][2] = "" 
	output[index2+35][1] = "" 
	
	
	//peak 10
	
	output[index2+37][2] = STnum2str(cwave[index]*cwave[index +30])
	output[index2+38][2] = ""
	output[index2+38][1] = ""
	
	
	output[index2+39][2] = "" 
	output[index2+39][1] = "" 
	
	

	// total area calculation
	
	totalCoefSum +=cwave[index]*(1+cwave[index+6]+cwave[index+9] + cwave[index+12]+cwave[index+15]+cwave[index+18] + cwave[index+21]+cwave[index+24]+cwave[index+27] + cwave[index+30])


	//shifts

	// peak 1
	output[index2+1][4] = STnum2str(cwave[index+1])
	output[index2+2][4] = STnum2str(V_maxloc)
	
	// peak 2
	output[index2+5][4] = STnum2str(cwave[index+1]+cwave[index+7])
	output[index2+6][4] = STnum2str(V_maxloc+cwave[index+7])
	
	// peak 3
	output[index2+9][4] = STnum2str(cwave[index+1]+cwave[index+10])
	output[index2+10][4] = STnum2str(V_maxloc+cwave[index+10])
	
	// peak 4
	output[index2+13][4] = STnum2str(cwave[index+1]+cwave[index+13])
	output[index2+14][4] = STnum2str(V_maxloc+cwave[index+13])
	
	// peak 5
	output[index2+17][4] = STnum2str(cwave[index+1]+cwave[index+16])
	output[index2+18][4] = STnum2str(V_maxloc+cwave[index+16])
	
	// peak 6
	output[index2+21][4] = STnum2str(cwave[index+1]+cwave[index+19])
	output[index2+22][4] = STnum2str(V_maxloc+cwave[index+19])
	
	// peak 7
	output[index2+25][4] = STnum2str(cwave[index+1]+cwave[index+22])
	output[index2+26][4] = STnum2str(V_maxloc+cwave[index+22])
	
	// peak 8
	output[index2+29][4] = STnum2str(cwave[index+1]+cwave[index+25])
	output[index2+30][4] = STnum2str(V_maxloc+cwave[index+25])
	
	// peak 9
	output[index2+33][4] = STnum2str(cwave[index+1]+cwave[index+28])
	output[index2+34][4] = STnum2str(V_maxloc+cwave[index+28])
	
	// peak 10
	output[index2+37][4] = STnum2str(cwave[index+1]+cwave[index+31])
	output[index2+38][4] = STnum2str(V_maxloc+cwave[index+31])
	
	
	
	//FWHM
	
	// peak 1
	output[index2+1][6] = STnum2str(cwave[index+2])
	output[index2+2][6] = STnum2str(EffectiveFWHM)
	
	// peak 2
	output[index2+5][6] = STnum2str(cwave[index+2] *cwave[index+8])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+6],cwave[index+1]+cwave[index+7],cwave[index+2]*cwave[index+8],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+6][6] = STnum2str(EffectiveFWHM)
	
	// peak 3
	output[index2+9][6] = STnum2str(cwave[index+2] *cwave[index+11])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+9],cwave[index+1]+cwave[index+10],cwave[index+2]*cwave[index+11],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+10][6] = STnum2str(EffectiveFWHM)
	
	// peak 4
	output[index2+13][6] = STnum2str(cwave[index+2] *cwave[index+14])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+12],cwave[index+1]+cwave[index+13],cwave[index+2]*cwave[index+14],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+14][6] = STnum2str(EffectiveFWHM)
	
	// peak 5
	output[index2+17][6] = STnum2str(cwave[index+2] *cwave[index+17])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+15],cwave[index+1]+cwave[index+16],cwave[index+2]*cwave[index+17],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+18][6] = STnum2str(EffectiveFWHM)
	
	// peak 6
	output[index2+21][6] = STnum2str(cwave[index+2] *cwave[index+20])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+18],cwave[index+1]+cwave[index+19],cwave[index+2]*cwave[index+20],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+22][6] = STnum2str(EffectiveFWHM)
	
	// peak 7
	output[index2+25][6] = STnum2str(cwave[index+2] *cwave[index+23])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+21],cwave[index+1]+cwave[index+22],cwave[index+2]*cwave[index+23],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+26][6] = STnum2str(EffectiveFWHM)
	
	// peak 8
	output[index2+29][6] = STnum2str(cwave[index+2] *cwave[index+26])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+24],cwave[index+1]+cwave[index+25],cwave[index+2]*cwave[index+26],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+30][6] = STnum2str(EffectiveFWHM)
	
	// peak 9
	output[index2+33][6] = STnum2str(cwave[index+2] *cwave[index+29])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+27],cwave[index+1]+cwave[index+28],cwave[index+2]*cwave[index+29],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+34][6] = STnum2str(EffectiveFWHM)
	
	// peak 10
	output[index2+37][6] = STnum2str(cwave[index+2] *cwave[index+32])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+30],cwave[index+1]+cwave[index+31],cwave[index+2]*cwave[index+32],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+38][6] = STnum2str(EffectiveFWHM)
	
	
	
	
	
	
	
	
	
	
	//  GL-Ratio
	
	output[index2+1][8] = STnum2str(cwave[index+3])
	
	// Asymmetry
	
	output[index2+1][10]=STnum2str(cwave[index+4])
	 
	output[index2+2][10] =STnum2str(GeneralAsymmetry)

	output[index2+1][12] = STnum2str(cwave[index+5])
	
	
	// total area showing
	
	output[index2+10][10] = STnum2str(totalCoefSum)
	output[index2+11][10] = ""//STnum2str(totalVisibleArea)
	output[index2+11][9] = ""
	output[index2+12][10] = ""//STnum2str(totalAnalyticalSum)
	output[index2+12][9] = ""
	totalCoefSum = 0
//	totalVisibleArea = 0
	//totalAnalyticalSum = 0
	
	
	killwaves /Z W
endfor
	
end



static function RemoveExtMultiplet()
	//CheckLocation()
	//these are needed to be able to call SinglePeakDisplay, in case of the background functions
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR toLink = root:STFitAssVar:STPeakToLink
	NVAR peakToExtract = root:STFitAssVar:STPeakToRemove
	NVAR savedLast = root:STFitAssVar:savedLast
	savedLast = 0 //this change has not been saved yet
	UpdateFitDisplay("fromAddPeak")
	//updateCoefs()
	setup2waves()
	numPeaks -= 1
	numPeaks=max(0,numPeaks)
	toLink = min(toLink,numPeaks)
	//peakToExtract = max(0,numPeaks)
	/////////////////////////////////////////////////////////////


	wave /t source = STsetup
	//NVAR peakToExtract = PeakToDelete
	wave sw = selSTsetup

	wave /t  numerics = Numerics
	wave selNumerics = selNumerics

	variable i,j,k
	variable length = DimSize(source,0)
	variable NumLength = DimSize(numerics,0)

	//this needs to be rewritten for doublet functions as well
	//numPeaks = (length-5)/6

	//this is the simple version of delete which only removes the last entry
	//if (length>=6)
	//Redimension /n=(length-6,-1) source
	//Redimension /n=(length-6,-1) sw
	//endif

	if (length == 5) ///only the background is left
		return 1 /// do nothing, the background may stay there forever
	endif

	string ListOfCurves
	variable numberCurves
	variable startCutIndex, endCutIndex
	variable numCoef =  33
	variable numSubPeaks = 10 
	//FancyUP("foe")

	//now do a sophisticated form of delete which removes a certain peak from within the waves
	//for example peak 2
	//peakToExtract = 2 //this needs to be soft-coded later on

	//duplicate the sections that need to go
	//to do so: calculate the indices that have to be removed
	//this needs to be extended for doublet functions as well

	startCutIndex = 5 + (peakToExtract-1)*numCoef
	endCutIndex = startCutIndex + numCoef

	variable startCutIndexNumerics = (peakToExtract-1)* (4*numSubPeaks)
	variable endCutIndexNumerics = startCutIndexNumerics + (4*numSubPeaks)

	//now, check if there are any constraints linked to this peak, if yes, refuse to do the deleting and notify the user
	// that means the ax, px, wx, etc of this peak e.g. a2, w2, etc show up anywhere else in the constraints wave, if so, abort
	variable abortDel = 0

	string planeName = "backColors"
	variable plane = FindDimLabel(sw,2,planeName)

	Variable nplanes = max(1,Dimsize(sw,2))
	if (plane <0)
		Redimension /N=(-1,-1,nplanes+1) sw
		plane = nplanes
		SetDimLabel 2,nplanes,$planeName sw
	endif

	variable Errors = 0
	string tempString
	string CoefficientList = "a;p;w;g;s;t"
	string matchString 
	string badSpotList = ""

	for (j = 0; j<itemsInList(CoefficientList); j += 1)
		matchString = "*" + StringFromList(j,CoefficientList) + num2str(peakToExtract) + "*"
		for (i=0; i < startCutIndex; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
		endfor
		for (i=endCutIndex; i < length; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
		endfor
	endfor

	variable badSpots = ItemsInList(badSpotList)
	variable badSpot

	if (Errors != 0)
		tempString = "Other peaks are linked to the one you want to remove. \r\rDelete all references to the peak you want to remove from 'Lower Limit' and 'Upper Limit'."
		Doalert 0, tempString
		tempString = "editDisplayWave(\"foe\")"
		Execute tempString
		// and now do the highlighting
		for ( i = 0; i < badSpots; i += 1 )
			badSpot = str2num(StringFromList(i,badSpotList))
			sw[badSpot][5][plane] =1		
			sw[badSpot][6][plane] =1		
		endfor
	
		//end highlighting
	
		numpeaks += 1
		return -1
	endif

	//everything seems to be fine, now continue
	duplicate /o /r=(0,startCutIndex-1) source $"lowerSectionSetup" 
	wave /t lowerSetup = $"lowerSectionSetup"
	duplicate /o /r=(0,startCutIndex-1) sw $"lowerSectionSw" 
	wave  lowerSW = $"lowerSectionSw"

	duplicate /o /r=(endCutIndex,length-1) source $"upperSectionSetup" 
	wave /t upperSetup = $"upperSectionSetup"
	duplicate /o /r =(endCutIndex, length -1) sw $"upperSectionSw" 
	wave upperSW = $"upperSectionSw"


	duplicate /o /r=(0,startCutIndexNumerics-1) numerics $"lowerSectionNumerics" 
	wave /t lowerNumerics = $"lowerSectionNumerics"
	duplicate /o /r=(0,startCutIndexNumerics-1) selNumerics $"lowerSectionSelNumerics" 
	wave  lowerSelNumerics = $"lowerSectionSelNumerics"

	duplicate /o /r=(endCutIndexNumerics,NumLength-1) numerics $"upperSectionNumerics" 
	wave /t upperNumerics = $"upperSectionNumerics"
	duplicate /o /r =(endCutIndexNumerics, NumLength -1) selNumerics $"upperSectionSelNumerics" 
	wave upperSelNumerics = $"upperSectionSelNumerics"


	//remove also the entries for the numerics wave

	//remove the space for one peak
	Redimension /n=(length -numCoef,-1) source
	Redimension /n=(length -numCoef,-1) sw

	Redimension /n=(NumLength - 4*numSubPeaks,-1) numerics    //four lines per peak if the peak type is singlet
	Redimension /n=(NumLength - 4*numSubPeaks,-1) selNumerics

	//and now, copy the stuff back, start with the lowerSection
	for (i = 0; i < startCutIndex; i += 1)
		for ( j =2; j < 8; j +=1) // do not overwrite the legend waves, this would be redundant
			if (j  != 4)
				source[i][j]=lowerSetup[i][j]
			endif
			sw[i][j]=lowerSW[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndex; i < length-numCoef; i += 1)
		for ( j =2; j < 8; j +=1)
			if (j  != 4)
				source[i][j]=upperSetup[i-startCutIndex][j]
			endif
			sw[i][j]=upperSW[i-startCutIndex][j]
		endfor
	endfor

	//now repeat everything for the Numerics wave
	for (i = 0; i < startCutIndexNumerics; i += 1)
		for ( j =2; j < 15; j +=1) // do not overwrite the legend waves, this would be redundant
			numerics[i][j]=lowerNumerics[i][j]
			selNumerics[i][j]=lowerSelNumerics[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndexNumerics; i < NumLength - 4*numSubPeaks-1; i += 1)
		for ( j =2; j < 15; j +=1)
			numerics[i][j]=upperNumerics[i-startCutIndexNumerics][j]
			selNumerics[i][j]=upperSelNumerics[i-startCutIndexNumerics][j]
		endfor
	endfor

	killwaves /z upperSetup, upperSW, lowerSetup, lowerSW, lowerSelNumerics, upperSelNumerics, lowerNumerics, upperNumerics

	//now make sure that all the parameter names, such as a2, a3, etc are updated
	//if the second peak was removed:   old > new 
	//								a1 > a1
	//								a2 > removed
	//								a3 > a2 //k = 0
	//								a4 > a3  //k = 1
	string lowerIndexIn, higherIndexOut

	for ( k = 0; k< numpeaks; k += 1)
		for ( j = 0; j < itemsInList(CoefficientList); j += 1 )
			lowerIndexIn = StringFromList(j,CoefficientList) + num2str(peakToExtract+k )  
			higherIndexOut = StringFromList(j,CoefficientList) +num2str(peakToExtract + k +1)
			//print lowerIndexIn, higherIndexOut
			for ( i = 0; i < length-numCoef; i += 1 )
				tempString = source[i][5]
				source[i][5]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
				tempString = source[i][6]
				source[i][6]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
			endfor
		endfor
	endfor
	
	///////////////////////////////////////////////////////////
	setup2waves()	
	ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	//this needs to be adapted to the background functions
	RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-1)
	//if (BackgroundType != 0 )
	for (i =2; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	//and now redisplay, if there are any peaks left
	SinglePeakDisplay(peakType,RawYWave,RawXWave, "InitializeCoef")//coefWave)
	FancyUp("foe")
	peakToExtract = max(0,numPeaks)
	SetVariable InputSetLink, limits={0,numPeaks,1}
	SetVariable InputRemoveLink,limits={0,peakToExtract,1}
	SetVariable InputRemoveLink2,limits={0,peakToExtract,1}
end

///////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////
////////   SpecMultipletSK
//////////////////////////////////////////////////////////////////


static function AddVoigtSKMultiplet(coefWave,RawYWave,indepCheck,heightA,posA,initialSlope, initialOffset,left,right,Wcoef_length)

string coefWave     //this won't be needed in the future ... for now, leave it here
string RawYWave
variable indepCheck
variable heightA
variable posA	
variable initialSlope
variable initialOffset
variable left
variable right
variable Wcoef_length

NVAR peakToLink = root:STFitAssVar:STPeakToLink
string parameterList = "a;p;w;g;as;at;dr;ds;db;tr;ts;tb;qr;qs;qb"   //ratio doublet, shift doublet, broadening doublet, ratio triplet ......

NVAR linkArea = root:STFitAssVar:AreaLink
NVAR linkPosition = root:STFitAssVar:PositionLink
NVAR linkWidth = root:STFitAssVar:WidthLink
NVAR linkGL = root:STFitAssVar:GLLink
NVAR linkAsym = root:STFitAssVar:AsymLink
NVAR linkSplitting = root:STFitAssVar:SOSLink
NVAR linkMultiRatio = root:STFitAssVar:DoubletRatioLink

NVAR areaLinkUpperFactor = root:STFitAssVar:AreaLinkFactorHigh
NVAR areaLinkLowerFactor = root:STFitAssVar:AreaLinkFactorLow
NVAR positionLinkOffsetMax = root:STFitAssVar:PositionLinkOffsetMax
NVAR positionLinkOffsetMin = root:STFitAssVar:PositionLinkOffsetMin

string name = "CursorPanel#guiCursorDisplay" 	
variable nPeaks,i,numPara,EstimatedPeakArea
variable epsilonVal=1e-5

wave /t source = STsetup  //everything is in the setup
wave sw = selSTSetup

wave /t  numerics = Numerics
wave selNumerics = selNumerics

variable length = DimSize(source,0)
variable NumLength = DimSize(numerics,0)

variable numpeaks = 0
//print numpeaks
variable index
variable newLength


WaveStats /Q $RawYWave
heightA = vcsr(A,name) - (initialSlope*posA+initialOffset)		// V_min						
EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)	


if (length == 0)
	Redimension /n=(length+20,-1) source
	Redimension /n=(length+20,-1) sw
	
	numpeaks = 0
	//set writing permissions and checkbox controls
	for ( i= 0; i<length + 20; i+=1)
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor

	source[length][0] = "Offset at E = 0 eV"
	source[length + 1][0] = "Slope"
	source[length + 2][0] = "Parabola"
	source[length + 3][0] = "Pseudo Tougaard (Herrera-Gomez)"
	source[length + 4][0] = "Shirley Step Height"
	source[length + 5][0] =         "Area  (first subpeak) --------------      Multiplet  " + num2str(numpeaks+1) 
	source[length + 6][0] =   "Position                                (subpeak 1)                          "
	source[length + 7][0] =   "Width"
	source[length + 8][0] =   "Gauss-Lorentz Ratio"
	source[length + 9][0] =   "Asymmetry"
	source[length + 10][0] =   "Asymmetry Translation"
	source[length + 11][0] =   "Doublet Ratio                subpeak 2 : 1"
	source[length + 12][0] =   "Doublet Shift                                2 - 1"
	source[length + 13][0] =   "Doublet Broadening                     2 : 1"
	source[length + 14][0] =   "Triplet Ratio                   subpeak 3 : 1 "
	source[length + 15][0] = "Triplet Shift                   		          3 - 1"
	source[length + 16][0] = "Triplet Broadening                        3 : 1"
	source[length + 17][0] = "Quadruplet Ratio           subpeak 4 : 1 "
	source[length + 18][0] = "Quadruplet Shift                           4 - 1"
	source[length + 19][0] = "Quadruplet Broadening                4 : 1"
	

	source[length][1] = "off" 
	source[length + 1][1] = "sl"
	source[length + 2][1] = "prb" 
	source[length + 3][1] = "tgd" 
	source[length + 4][1] = "srl"
	source[length + 5][1] = "a" + num2str(numpeaks+1)
	source[length + 6][1] = "p" + num2str(numpeaks+1)
	source[length + 7][1] = "w" + num2str(numpeaks+1)
	source[length + 8][1] = "g" + num2str(numpeaks+1)
	source[length + 9][1] = "as" + num2str(numpeaks+1)
	source[length + 10][1] = "at" + num2str(numpeaks+1)
	source[length + 11][1] = "dr" + num2str(numpeaks+1)
	source[length + 12][1] = "ds" + num2str(numpeaks+1)
	source[length + 13][1] = "db" + num2str(numpeaks+1)
	source[length + 14][1] = "tr" + num2str(numpeaks+1)
	source[length + 15][1] = "ts" + num2str(numpeaks+1)
	source[length + 16][1] = "tb" + num2str(numpeaks+1)
	source[length + 17][1] = "qr" + num2str(numpeaks+1)
	source[length + 18][1] = "qs" + num2str(numpeaks+1)
	source[length + 19][1] = "qb" + num2str(numpeaks+1)
	
	source[length][4] = "off" 
	source[length + 1][4] = "sl"
	source[length + 2][4] = "prb" 
	source[length + 3][4] = "tgd" 
	source[length + 4][4] = "srl"
	source[length + 5][4] = "a" + num2str(numpeaks+1)
	source[length + 6][4] = "p" + num2str(numpeaks+1)
	source[length + 7][4] = "w" + num2str(numpeaks+1)
	source[length + 8][4] = "g" + num2str(numpeaks+1)
	source[length + 9][4] = "as" + num2str(numpeaks+1)
	source[length + 10][4] = "at" + num2str(numpeaks+1)
	source[length + 11][4] = "dr" + num2str(numpeaks+1)
	source[length + 12][4] = "ds" + num2str(numpeaks+1)
	source[length + 13][4] = "db" + num2str(numpeaks+1)
	source[length + 14][4] = "tr" + num2str(numpeaks+1)
	source[length + 15][4] = "ts" + num2str(numpeaks+1)
	source[length + 16][4] = "tb" + num2str(numpeaks+1)
	source[length + 17][4] = "qr" + num2str(numpeaks+1)
	source[length + 18][4] = "qs" + num2str(numpeaks+1)
	source[length + 19][4] = "qb" + num2str(numpeaks+1)
	

	EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
	source[length][3] = MyNum2str(initialOffset)//num2str(max(0,V_min)) 
	source[length + 1][3] = MyNum2str(initialSlope)
	source[length + 2][3] = "0" 
	source[length + 3][3] = "0" 
	source[length + 4][3] = "0"  //MyNum2str(0.1*abs(heightA-V_min))
	source[length + 5][3] = MyNum2str(EstimatedPeakArea)
	source[length + 6][3] = MyNum2str(posA)
	source[length + 7][3] = MyNum2str(Width_Start)
	source[length + 8][3] = MyNum2str(GLratio_Start)
	source[length + 9][3] = MyNum2str(Asym_Start)
	source[length + 10][3] = MyNum2str(Asym_Shift_Start)
	source[length + 11][3] = "0.5"
	source[length + 12][3] = "1.5"
	source[length + 13][3] = "1"
	source[length + 14][3] = "0.33"
	source[length + 15][3] = "2.5"
	source[length + 16][3] = "1"
	source[length + 17][3] = "0.25"
	source[length + 18][3] = "3.5"
	source[length + 19][3] = "1"
	
	sw[length +2][4][0] = 48
	sw[length +3][4][0] = 48   //check checkboxes
	
	sw[length +8][4][0] = 48
	sw[length +9][4][0] = 48
	sw[length +10][4][0] = 48
	sw[length +11][4][0] = 48
	sw[length +12][4][0] = 48
	sw[length +13][4][0] = 48
	sw[length +14][4][0] = 48
	sw[length +15][4][0] = 48
	sw[length +16][4][0] = 48
	sw[length +17][4][0] = 48
	sw[length +18][4][0] = 48
	sw[length +19][4][0] = 48
	
	sw[length+2][5][0] = 0   
	sw[length+3][6][0] = 0    
	
	
	source[length][5] = MyNum2str(-10*abs(initialOffset))
	source[length + 1][5] = MyNum2str(-10*abs(initialSlope))
	source[length + 2][5] = "-100" 
	source[length + 3][5] = "-1000" 
	source[length + 4][5] = "1e-6"
	source[length + 5][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
	source[length + 6][5] = MyNum2str(posA-1.5)//MyNum2str(right)
	source[length + 7][5] = MyNum2str(Width_Min)
	source[length + 8][5] =  MyNum2str(GLratio_Min)
	source[length + 9][5] = MyNum2str(Asym_Min)
	source[length + 10][5] = MyNum2str(Asym_Shift_Min)
	source[length + 11][5] = "0.02"
	source[length + 12][5] = "0.1"
	source[length + 13][5] = "0.5"
	source[length + 14][5] = "0.02"
	source[length + 15][5] = "0.1"
	source[length + 16][5] = "0.5"
	source[length + 17][5] = "0.02"
	source[length + 18][5] = "0.1"
	source[length + 19][5] = "0.5"
	
	source[length][6] = MyNum2str(10*abs(initialOffset)) 
	source[length + 1][6] = MyNum2str(10*abs(initialSlope))
	source[length + 2][6] = "100" 
	source[length + 3][6] = "1000" 
	source[length + 4][6] = MyNum2str(0.7*abs(V_min-heightA))
	source[length + 5][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
	source[length + 6][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
	source[length + 7][6] = MyNum2str(Width_Max )
	source[length + 8][6] = MyNum2str(GLratio_Max)
	source[length + 9][6] = MyNum2str(Asym_Max)
	source[length + 10][6] = MyNum2str(Asym_Shift_Max)
	source[length + 11][6] = "10"
	source[length + 12][6] = "3"
	source[length + 13][6] = "4"
	source[length + 14][6] = "10"
	source[length + 15][6] = "3"
	source[length + 16][6] = "4"
	source[length + 17][6] = "10"
	source[length + 18][6] = "3"
	source[length + 19][6] = "4"

	source[length][7] = "1e-9" 
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9" 
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-8"
	source[length + 6][7] = "1e-9"
	source[length + 7][7] = "1e-9"
	source[length + 8][7] = "1e-9" 
	source[length + 9][7] = "1e-9"
	source[length + 10][7] = "1e-9"
	source[length + 11][7] = "1e-9"
	source[length + 12][7] = "1e-9"
	source[length + 13][7] = "1e-9" 
	source[length + 14][7] = "1e-9"
	source[length + 15][7] = "1e-9"
	source[length + 16][7] = "1e-9"
	source[length + 17][7] = "1e-9"
	source[length + 18][7] = "1e-9"
	source[length + 19][7] = "1e-9"
else
	//now, linking can come into the game ... it will affect the columns 3,4,5,6
	
	Redimension /n=(length+15,-1) source
	Redimension /n=(length+15,-1) sw	
	
	newLength = length+ 15
	
	numpeaks = floor((length-5)/15)
	for ( i= length; i<newLength; i+=1)
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor
	
	source[length][0] =         "Area  (first subpeak) --------------      Multiplet  " + num2str(numpeaks+1) 
	source[length + 1][0] =   "Position                                (subpeak 1)                          "
	source[length + 2][0] =   "Width"
	source[length + 3][0] =   "Gauss-Lorentz Ratio"
	source[length + 4][0] =   "Asymmetry"
	source[length + 5][0] =   "Asymmetry Translation"
	source[length + 6][0] =   "Doublet Ratio                subpeak 2 : 1"
	source[length + 7][0] =   "Doublet Shift                                2 - 1"
	source[length + 8][0] =   "Doublet Broadening                     2 : 1"
	source[length + 9][0] =   "Triplet Ratio                   subpeak 3 : 1 "
	source[length + 10][0] = "Triplet Shift                   		          3 - 1"
	source[length + 11][0] = "Triplet Broadening                        3 : 1"
	source[length + 12][0] = "Quadruplet Ratio           subpeak 4 : 1 "
	source[length + 13][0] = "Quadruplet Shift                           4 - 1"
	source[length + 14][0] = "Quadruplet Broadening                4 : 1"
	
	source[length][1] = "a" + num2str(numpeaks+1)
	source[length + 1][1] = "p" + num2str(numpeaks+1)
	source[length + 2][1] = "w" + num2str(numpeaks+1)
	source[length + 3][1] = "g" + num2str(numpeaks+1)
	source[length + 4][1] = "as" + num2str(numpeaks+1)
	source[length + 5][1] = "at" + num2str(numpeaks+1)
	source[length + 6][1] = "dr" + num2str(numpeaks+1)
	source[length + 7][1] = "ds" + num2str(numpeaks+1)
	source[length + 8][1] = "db" + num2str(numpeaks+1)
	source[length + 9][1] = "tr" + num2str(numpeaks+1)
	source[length + 10][1] = "ts" + num2str(numpeaks+1)
	source[length + 11][1] = "tb" + num2str(numpeaks+1)
	source[length + 12][1] = "qr" + num2str(numpeaks+1)
	source[length + 13][1] = "qs" + num2str(numpeaks+1)
	source[length + 14][1] = "qb" + num2str(numpeaks+1)


     // start: take care of linking
     if (peakToLink == 0)
		EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
		source[length][3] = MyNum2str(EstimatedPeakArea)
		source[length + 1][3] = MyNum2str(posA)
		source[length + 2][3] = MyNum2str(Width_Start)
		source[length + 3][3] = MyNum2str(GLratio_Start)
		source[length + 4][3] = MyNum2str(Asym_Start)
		source[length + 5][3] = MyNum2str(Asym_Shift_Start)
		source[length + 6][3] = "0.5"
		source[length + 7][3] = "1.5"
		source[length + 8][3] = "1"
		source[length + 9][3] = "0.33"
		source[length + 10][3] = "2.5"
		source[length + 11][3] = "1"
		source[length + 12][3] = "0.25"
		source[length + 13][3] = "3.5"
		source[length + 14][3] = "1"
	
		sw[length +3][4][0] = 48
		sw[length +4][4][0] = 48
		sw[length +5][4][0] = 48   //check checkboxes
	
		sw[length +6][4][0] = 48
		sw[length +7][4][0] = 48
		sw[length +8][4][0] = 48
		sw[length +9][4][0] = 48
		sw[length +10][4][0] = 48
		sw[length +11][4][0] = 48
		sw[length +12][4][0] = 48
		sw[length +13][4][0] = 48
		sw[length +14][4][0] = 48
	
		source[length][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
		source[length + 1][5] = MyNum2str(posA-1.5)// MyNum2str(right)
		source[length + 2][5] = MyNum2str(Width_Min)
		source[length + 3][5] =  MyNum2str(GLratio_Min)
		source[length + 4][5] = MyNum2str(Asym_Min)
		source[length + 5][5] = MyNum2str(Asym_Shift_Min)
		source[length + 6][5] = "0.02"
		source[length + 7][5] = "0.1"
		source[length + 8][5] = "0.5"
		source[length + 9][5] = "0.02"
		source[length + 10][5] = "0.1"
		source[length + 11][5] = "0.5"
		source[length + 12][5] = "0.02"
		source[length + 13][5] = "0.1"
		source[length + 14][5] = "0.5"
	

		source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		source[length + 2][6] = MyNum2str(Width_Max )
		source[length + 3][6] = MyNum2str(GLratio_Max)
		source[length + 4][6] = MyNum2str(Asym_Max)
		source[length + 5][6] = MyNum2str(Asym_Shift_Max)
		source[length + 6][6] = "10"
		source[length + 7][6] = "3"
		source[length + 8][6] = "4"
		source[length + 9][6] = "10"
		source[length + 10][6] = "3"
		source[length + 11][6] = "4"
		source[length + 12][6] = "10"
		source[length + 13][6] = "3"
		source[length + 14][6] = "4"
	else
		//get the startingIndex of the target peak
		variable startIndexParentPeak = 15 * (peakToLink -1 ) + 5		
	
		if ( linkArea == 0 )
			EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
			source[length][3] = MyNum2str(EstimatedPeakArea)
			sw[length][4][0] = 32
			source[length][5] = MyNum2str(min(10,0.2 * EstimatedPeakArea ))  
			source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		else
			
			source[length][3] = MyNum2str( areaLinkLowerFactor * str2num(source[startIndexParentPeak][3]) )    //start at the lower boundary
			sw[length][4][0] = sw[startIndexParentPeak][4][0]
			source[length][5] = MyNum2str(areaLinkLowerFactor - 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
			source[length ][6] = MyNum2str(areaLinkUpperFactor + 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkPosition == 0 )
			source[length + 1][3] = MyNum2str(posA)
			sw[length + 1][4][0] = 32
			source[length + 1][5] = MyNum2str(posA-1.5) //MyNum2str(right)
			source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		else
			source[length + 1][3] = MyNum2str( str2num( source[startIndexParentPeak + 1][3] ) + positionLinkOffsetMin )
			sw[length + 1][4][0] = sw[startIndexParentPeak +1][4][0]
			source[length + 1][5] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMin-0.01)
			source[length + 1][6] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMax + 0.01)
		endif
		
		if ( linkWidth == 0 )
			source[length + 2][3] = MyNum2str(Width_Start)
			sw[length + 2][4][0] = 32
			source[length + 2][5] = MyNum2str(Width_Min)
			source[length + 2][6] = MyNum2str(Width_Max )
		else
			source[length + 2][3] = source[startIndexParentPeak + 2][3]
			sw[length + 2][4][0] = sw[startIndexParentPeak +2][4][0]
			source[length + 2][5] = StringFromList(2,parameterList) + num2str(peakToLink)
			source[length + 2][6] = StringFromList(2,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkGL == 0 )
			source[length + 3][3] = MyNum2str(GLratio_Start)
			sw[length + 2][4][0] = 32
			source[length + 3][5] =  MyNum2str(GLratio_Min)
			source[length + 3][6] = MyNum2str(GLratio_Max)
		else
			source[length + 3][3] = source[startIndexParentPeak + 3][3]
			sw[length + 3][4][0] = sw[startIndexParentPeak +3][4][0]
			source[length + 3][5] =  StringFromList(3,parameterList) + num2str(peakToLink)
			source[length + 3][6] = StringFromList(3,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkAsym == 0 )
			source[length + 4][3] = MyNum2str(Asym_Start)
			source[length + 5][3] = MyNum2str(Asym_Shift_Start)
			sw[length +3][4][0] = 48
			sw[length +4][4][0] =  48
			sw[length +5][4][0] =  48   //check checkboxes
			source[length + 4][5] = MyNum2str(Asym_Min)
			source[length + 5][5] = MyNum2str(Asym_Shift_Min)
			source[length + 4][6] = MyNum2str(Asym_Max)
			source[length + 5][6] = MyNum2str(Asym_Shift_Max)
		else
			source[length + 4][3] = source[startIndexParentPeak + 4][3]
			source[length + 5][3] = source[startIndexParentPeak + 5][3]
			sw[length +3][4][0] = sw[startIndexParentPeak +3][4][0]
			sw[length +4][4][0] = sw[startIndexParentPeak +4][4][0]
			sw[length +5][4][0] = sw[startIndexParentPeak +5][4][0]
			source[length + 4][5] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][5] = StringFromList(5,parameterList) + num2str(peakToLink)
			source[length + 4][6] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][6] = StringFromList(5,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkMultiRatio == 0)  //link ratio and broadening
			//starting guess       for ratios
			source[length + 6][3] = "0.5"
			source[length + 9][3] = "0.3"
			source[length + 12][3] = "0.25"
			
			//hold true or false
			sw[length + 6][4][0] = 48
			sw[length + 9][4][0] =  48
			sw[length + 12][4][0] =  48   //check checkboxes
			
			//limits
			source[length + 6][5] = "0.02"
			source[length + 9][5] = "0.02"
			source[length + 12][5] = "0.02"
			
			source[length + 6][6] = "10"
			source[length + 9][6] = "10"
			source[length + 12][6] = "10"
			
		
		else
			
			source[length + 6][3] = source[startIndexParentPeak + 6][3]
			source[length + 9][3] =  source[startIndexParentPeak + 9][3]
			source[length + 12][3] =  source[startIndexParentPeak + 12 ][3]
			
			sw[length + 6][4][0] = sw[startIndexParentPeak +6][4][0]
			sw[length + 9][4][0] = sw[startIndexParentPeak +9][4][0]
			sw[length + 12][4][0] = sw[startIndexParentPeak +12][4][0]
			
			source[length + 6][5] =  StringFromList(6,parameterList) + num2str(peakToLink)
			source[length + 9][5] = StringFromList(9,parameterList) + num2str(peakToLink)
			source[length + 12][5] = StringFromList(12,parameterList) + num2str(peakToLink)
			
			source[length + 6][6] =  StringFromList(6,parameterList) + num2str(peakToLink)
			source[length + 9][6] =  StringFromList(9,parameterList) + num2str(peakToLink)
			source[length + 12][6] =  StringFromList(12,parameterList) + num2str(peakToLink)

		endif
		
		if ( linkSplitting == 0) //this has to be adapted
			//starting guess       splitting
			source[length + 7][3] = "0.9"
			source[length + 10][3] = "1.8"
			source[length + 13][3] = "2.7"
			
			//hold true or false
			sw[length + 7][4][0] = 48
			sw[length + 10][4][0] =  48
			sw[length + 13][4][0] =  48   //check checkboxes
			
			//limits
			source[length + 7][5] = "0.1"
			source[length + 10][5] = "0.1"
			source[length + 13][5] = "0.1"
			
			source[length + 7][6] = "3"
			source[length + 10][6] = "3"
			source[length + 13][6] = "3"
			
			//starting guess ..........       now  for broadening
			source[length + 8][3] = "1"
			source[length + 11][3] = "1"
			source[length + 14][3] = "1"
			
			//hold true or false
			sw[length + 8][4][0] = 48
			sw[length + 11][4][0] =  48
			sw[length + 14][4][0] =  48   //check checkboxes
			
			//limits
			source[length + 8][5] = "0.5"
			source[length + 11][5] = "0.5"
			source[length + 14][5] = "0.5"
			
			source[length + 8][6] = "4"
			source[length + 11][6] = "4"
			source[length + 14][6] = "4"
			
		else
			source[length + 7][3] = source[startIndexParentPeak + 7][3]
			source[length + 10][3] =  source[startIndexParentPeak + 10][3]
			source[length + 13][3] =  source[startIndexParentPeak + 13 ][3]
			source[length + 8][3] = source[startIndexParentPeak + 8][3]
			source[length + 11][3] =  source[startIndexParentPeak + 11][3]
			source[length + 14][3] =  source[startIndexParentPeak + 14][3]
			
			sw[length + 7][4][0] = sw[startIndexParentPeak +7][4][0]
			sw[length + 10][4][0] = sw[startIndexParentPeak +10][4][0]
			sw[length + 13][4][0] = sw[startIndexParentPeak +13][4][0]
			sw[length + 8][4][0] = sw[startIndexParentPeak +8][4][0]
			sw[length + 11][4][0] = sw[startIndexParentPeak +11][4][0]
			sw[length + 14][4][0] = sw[startIndexParentPeak +14][4][0]

			source[length + 7][5] =  StringFromList(7,parameterList) + num2str(peakToLink)
			source[length + 10][5] = StringFromList(10,parameterList) + num2str(peakToLink)
			source[length + 13][5] = StringFromList(13,parameterList) + num2str(peakToLink)
			source[length + 8][5] =  StringFromList(8,parameterList) + num2str(peakToLink)
			source[length + 11][5] = StringFromList(11,parameterList) + num2str(peakToLink)
			source[length + 14][5] = StringFromList(14,parameterList) + num2str(peakToLink)
			
			
			source[length + 7][6] =  StringFromList(7,parameterList) + num2str(peakToLink)
			source[length + 10][6] =  StringFromList(10,parameterList) + num2str(peakToLink)
			source[length + 13][6] =  StringFromList(13,parameterList) + num2str(peakToLink)
			
			source[length + 8][6] =  StringFromList(8,parameterList) + num2str(peakToLink)
			source[length + 11][6] =  StringFromList(11,parameterList) + num2str(peakToLink)
			source[length + 14][6] =  StringFromList(14,parameterList) + num2str(peakToLink)
		endif
	endif
	// stop: take care of linking
	
	source[length][4] = "a" + num2str(numpeaks+1) 
	source[length + 1][4] = "p" + num2str(numpeaks+1)
	source[length + 2][4] = "w" + num2str(numpeaks+1)
	source[length + 3][4] = "g" + num2str(numpeaks+1) 
	source[length + 4][4] = "as" + num2str(numpeaks+1) 
	source[length + 5][4] = "at" + num2str(numpeaks+1) 
	source[length + 6][4] = "dr" + num2str(numpeaks+1)
	source[length + 7][4] = "ds" + num2str(numpeaks+1)
	source[length + 8][4] = "db" + num2str(numpeaks+1)
	source[length + 9][4] = "tr" + num2str(numpeaks+1)
	source[length + 10][4] = "ts" + num2str(numpeaks+1)
	source[length + 11][4] = "tb" + num2str(numpeaks+1)
	source[length + 12][4] = "qr" + num2str(numpeaks+1)
	source[length + 13][4] = "qs" + num2str(numpeaks+1)
	source[length + 14][4] = "qb" + num2str(numpeaks+1)
	
	
	
	source[length][7] = "1e-8"
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9"
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-9"
	source[length + 6][7] = "1e-9"
	source[length + 7][7] = "1e-9"
	source[length + 8][7] = "1e-9" 
	source[length + 9][7] = "1e-9"
	source[length + 10][7] = "1e-9"
	source[length + 11][7] = "1e-9"
	source[length + 12][7] = "1e-9"
	source[length + 13][7] = "1e-9"
	source[length + 14][7] = "1e-9"
endif

	Redimension /n=(NumLength+16,-1) numerics
	Redimension /n=(NumLength+16,-1) selNumerics
	
	//numerics[NumLength][0] = "Multiplet " + num2str(numpeaks+1)
	numerics[NumLength + 0][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 1][0] = " Peak 1"
	numerics[NumLength + 4][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 5][0] =  " Peak 2"
	numerics[NumLength + 8][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 9][0] =  " Peak 3"
	numerics[NumLength + 12][0] = " Multiplet  "+ num2str(numpeaks+1) 
	numerics[NumLength + 13][0] = " Peak 4"
	
	numerics[NumLength + 1][1] = "Area "
	numerics[NumLength + 5][1] = "Area "
	numerics[NumLength + 9][1] = "Area "
	numerics[NumLength + 13][1] = "Area "
	
//	numerics[NumLength + 2 ][1] = "Visible Area"
//	numerics[NumLength + 6 ][1] = "Visible Area"
//	numerics[NumLength + 10 ][1] = "Visible Area"
//	numerics[NumLength + 14][1] = "Visible Area"
	
//	numerics[NumLength + 3 ][1] = "Analytical Area"
//	numerics[NumLength + 7 ][1] = "Analytical Area"
//	numerics[NumLength + 11 ][1] = "Analytical Area"
//	numerics[NumLength + 15 ][1] = "Analytical Area"
	
	numerics[NumLength + 1][3] = "Position (Coef.)"
	numerics[NumLength + 5][3] = "Position (Coef.)"
	numerics[NumLength + 9][3] = "Position (Coef.)"
	numerics[NumLength + 13][3] = "Position (Coef.)"
	
	numerics[NumLength + 2][3] = "Effective Position"
	numerics[NumLength + 6][3] = "Effective Position"
	numerics[NumLength + 10][3] = "Effective Position"
	numerics[NumLength + 14][3] = "Effective Position"
	
	numerics[NumLength + 1][5] = "Width (Coef.)"
	numerics[NumLength + 5][5] = "Width (Coef.)"
	numerics[NumLength + 9][5] = "Width (Coef.)"
	numerics[NumLength + 13][5] = "Width (Coef.)"
	
	numerics[NumLength + 2][5] = "Effective Width"
	numerics[NumLength + 6][5] = "Effective Width"
	numerics[NumLength + 10][5] = "Effective Width"
	numerics[NumLength + 14][5] = "Effective Width"

	numerics[NumLength + 1][7] = "Gauss-Lorentz Ratio"
	
	numerics[NumLength + 1][9] = "Asymmetry (coef)"
	numerics[NumLength + 2][9] = "Effective Asymmetry:"
	numerics[NumLength + 3][9] = "1 - (fwhm_right)/(fwhm_left):"
	 
	 numerics[NumLength + 1][11] = "Asymmetry translation (coef)"
	
	numerics[NumLength+8][9] = "Total multiplet area " 
	numerics[NumLength+9][9] = "--------------------------------------------- " 
	numerics[NumLength+10][9] = "Sum of area coefficients" // STnum2str(totalCoefSum)
//	numerics[NumLength+11][9] = "Sum of visible peak areas" //STnum2str(totalVisibleArea)
//	numerics[NumLength + 12][9] = "Sum of analytical areas"  //STnum2str(totalAnalyticalSum)
	
	FancyUp("foe")
	setup2Waves()	
end

/// 2  ////////////////////////////////////////////////////////////
///////////////   Display it in the peak fitting window ///////////////////////////////////////////////

static function PlotMultipletSKDisplay(peakType,RawYWave, RawXWave,coefWave)
	string peakType
	string RawYWave
	string RawXWave
	string coefWave
	string TagName    // the Tag in the result window
	string PeakTag     // text in this tag
	string PkName, parentDataFolder //, cleanUpString=""		
	string BGName //background
	string PeakSumName
	NVAR FitMin = root:STFitAssVar:STFitMin
	NVAR FitMax = root:STFitAssVar:STFitMax
	
	wave cwave = $coefWave
	wave raw = $RawYWave
//	wave xraw = $RawXWave
	variable LenCoefWave = DimSize(cwave,0)
	
	//create some waves, to display the peak
	variable nPeaks = 0
	variable numCoef
	variable i,index,k
	variable xmin, xmax, step
	variable TagPosition   //the position of the tag in the result window
	variable totalPeakSumArea, partialPeakSumArea
	 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate  		                     
			break
		case "_calculated_":
			 duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate  
			break
		default:                                                 // if not empty, x-axis wave necessary
			//read in the start x-value and the step size from the x-axis wave
			wave xraw = $RawXWave
			xmax = max(xraw[0],xraw[numpnts(xraw)-1] )
			xmin = min(xraw[0],xraw[numpnts(xraw)-1] )
			step = (xmax - xmin ) / DimSize(xraw,0)
			// now change the scaling of the y-wave duplicate, so it gets equivalent to a data-wave imported from an igor-text file
			duplicate /o raw tempWaveForCutting  
			SetScale /I x, xmin, xmax, tempWaveForCutting  //OKAY, NOW THE SCALING IS ON THE ENTIRE RANGE
			duplicate /o /R=(FitMin,FitMax) tempWaveForCutting WorkingDuplicate  
			killwaves /z tempWaveForCutting
			break
	endswitch
	
	parentDataFolder = GetDataFolder(1)
	
	
	//now make tabular rasa in the case of background functions
	string ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	variable numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	
	// If a wave is given which needs an external x-axis (from an ASCII-file) create a duplicate which receives a proper x-scaling later on
	// the original wave will not be changed
	KillDataFolder /z :Peaks  //if it exists from a previous run, kill it
	//now recreate it, so everything is updated             
	NewDataFolder /O /S :Peaks

 	numCoef =15   //Voigt with Shirley and Slope 
	nPeaks = (LenCoefWave-5)/numCoef
	
	PeakSumName = "pS_"+RawYWave
			
	duplicate /o WorkingDuplicate $PeakSumName
	wave tempSumDisplay = $PeakSumName
			
			
	//update the graph, remove everything	
	for (i =1; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	string SubPeakName
	variable j, para1,para2,para3
	tempSumDisplay = 0
	variable areaPeak = 0
	//create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
	
	
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i + 5
		PkName = "m" + num2istr(i+1) + "_" + RawYWave  //make a propper name
	 	
	 	duplicate /o WorkingDuplicate $PkName	
		wave tempDisplay = $PkName 
		tempDisplay = 0      
	 	
	 	for ( j = 0; j < 4; j += 1)
	 	
	 		SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + RawYWave
	 		duplicate /o WorkingDuplicate $SubPeakName
	 		wave subPeak = $SubPeakName
	 		
	 	      para1 = cwave[index]*(j==0) + (j !=0)*cwave[index]*cwave[index+6+3*(j-1)]   
	 	      para2 = cwave[index+1]*(j==0) + (j !=0)*(cwave[index+1]+cwave[index+7+3*(j-1)] ) 
	 	      para3 = cwave[index+2]*(j==0) + (j !=0)*cwave[index+2]*cwave[index+8+3*(j-1)]  
	 	      
	 		subPeak = CalcSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5],x)
	 		areaPeak= IntegrateSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
			subPeak /= areaPeak
			subPeak *= para1
	 		tempDisplay += subPeak
	 		
	 		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
	 		AppendToGraph /w= CursorPanel#guiCursorDisplayFit subPeak    	
	 		
	 	endfor
	 	                                     

		 //overwrite the original values in the wave with the values of a single peak
		//tempDisplay = CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)	
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 6] * cwave[index],cwave[index + 7] + cwave[index+1], cwave[index + 8] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 9] * cwave[index],cwave[index + 10] + cwave[index+1], cwave[index + 8] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
		//tempDisplay += CalcSingleVoigtGLS(cwave[index + 12] * cwave[index],cwave[index + 13] + cwave[index+1], cwave[index + 14] * cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
	
		tempSumDisplay += tempDisplay
		
		
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
		AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempDisplay                           //now plot it
		
		WaveStats /Q tempDisplay
		tagName = PkName+num2istr(i)
		PeakTag = num2istr(i+1)
		TagPosition = V_maxloc
		
		Tag /w= CursorPanel#guiCursorDisplayFit /C /N= $tagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag
		ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($PkName)=(0,0,0)       // and color-code it	
	endfor
	//get the sum of all peaks and (i) calculate the Shirley, (ii) calculate the line offset and (iii) display the background and the individual sums of peak + Background
	BGName ="bg_"+ RawYWave ///should name the background accordingly
	
	duplicate /o WorkingDuplicate $BGName
	wave tempBGDisplay = $BGName //this is the wave to keep the background
	
	duplicate /o WorkingDuplicate HGB
	wave hgb = HGB
	
	// now calculate the background with tempSumDisplay
	totalPeakSumArea = sum(tempSumDisplay)
	//print totalPeakSumArea
	partialPeakSumArea = 0
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))    //x decreases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[i]
			tempBGDisplay[i] =partialPeakSumArea/totalPeakSumArea 
		endfor
	else //x increases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[numpnts(tempSumDisplay) -1 - i]
			tempBGDisplay[numpnts(tempSumDisplay) -1 - i] = partialPeakSumArea/totalPeakSumArea 
		endfor
	endif
			
	//now add the Herrera-Gomez background
	partialPeakSumArea = 0
	totalPeakSumArea = sum(tempBGDisplay)
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))   //binding energy increases with point index
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[i])
			hgb[i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	else                     //binding energy decreases with point index
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[numpnts(tempSumDisplay)-1-i])
			hgb[numpnts(tempSumDisplay)-1-i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	endif
	hgb *= cwave[3]	
			
	tempBGDisplay *= cwave[4]  //shirley height
	tempBGDisplay += hgb
//	Killwaves /z temporaryShirleyWave
	
//	for (i =0; i<nPeaks;i+=1)
//		index = numCoef*i + 5
//		tempBGDisplay += 1e-3*cwave[3]*cwave[index]*( x - cwave[index+1] )^2 * ( x > cwave[index+1] ) 
//	endfor
			
	tempBGDisplay += cwave[0] + cwave[1]*x + cwave[2]*x^2
	
	AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempBGDisplay 
		
	//now add the background to all peaks
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i
		PkName = "m" + num2istr(i+1) + "_"+RawYWave   //make a proper name
		for ( j = 0; j < 4; j += 1)
	 	
	 		SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + RawYWave
	 		wave subPeak = $SubPeakName
			subPeak += tempBGDisplay
			ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($SubPeakName)=(43520,43520,43520) 
	 	endfor
		
		wave tempDisplay = $PkName        //This needs some explanation, see commentary at the end of the file                                        
		
		 //overwrite the original values in the wave with the values of a single peak
		tempDisplay  += tempBGDisplay
	endfor
		
	tempSumDisplay += tempBGDisplay
	//for now, don't use tempSumDisplay, however, leave it in the code for possible future use
	killwaves /z tempSumDisplay   //remove this line, if the sum of the peaks is going to be used again
	killwaves /z HGB
	WaveStats /Q WorkingDuplicate
//	SetAxis /w = CursorPanel#guiCursorDisplayFit left -0.1*V_max, 1.1*V_max
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	SetAxis/A/R /w = CursorPanel#guiCursorDisplayFit bottom
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	SetDataFolder parentDataFolder 
	killwaves /Z WorkingDuplicate
end




///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////

static function DrawAndEvaluateMultipletSK(dataWave,fitWave,peakType,RawXWave,newFolder)
string dataWave
string fitWave
string peakType
string RawXWave
variable newFolder               //if this value is different from 1, no folder for the results will be created

SVAR projectName = root:STFitAssVar:ProjectName

wave cwave = W_coef
wave origWave = $dataWave
wave fitted = $fitWave
wave epsilon = epsilon
wave hold = hold
wave InitializeCoef = InitializeCoef
wave Min_Limit = Min_Limit
wave Max_Limit = Max_Limit
wave T_Constraints = T_Constraints
wave  CoefLegend = CoefLegend

if ( strlen(fitWave) >= 30)	
	doalert 0, "The name of the fit-wave is too long! Please shorten the names."
	return -1
endif


//define further local variables
variable LenCoefWave = DimSize(cwave,0)	
variable nPeaks
variable index
variable i =0                               //general counting variable
variable numCoef                       //variable to keep the number of coefficients of the selected peak type
							  // numCoef = 3   for Gauss Singlet     and numCoef =5 for VoigtGLS
variable pointLength, totalArea, partialArea
variable peakMax 
variable TagPosition
variable AnalyticalArea
variable EffectiveFWHM
variable GeneralAsymmetry        //  = 1 - (fwhm_right)/(fwhm_left)

string PkName                          //string to keep the name of a single peak wave
string foldername                       //string to keep the name of the datafolder, which is created later on for the single peak waves
string tempFoldername               //help-string to avoid naming conflicts
string parentDataFolder
string TagName
string PeakTag
string LastGraphName
string NotebookName = "Report"     //this is the initial notebook name, it is changed afterwards
string tempNotebookName
string tempString                          // for a formated output to the notebook
string BGName
//The following switch construct is necessary in order to plot waveform data (usually from igor-text files , *.itx) as well as
//raw spectra which need an extra x-axis (such data come usually from an x-y ASCII file)

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		display /K=1 origWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
		break
	case "_calculated_":
		display /K=1 origWave
		break
	default:
		wave xraw = $RawXWave                                                 // if not empty
		display /K=1 origWave vs xraw        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
endswitch
ModifyGraph mode($dataWave)=3,msize($dataWave)=1.3, marker($dataWave)=8
ModifyGraph mrkThick($dataWave)=0.7
ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
    
LastGraphName = WinList("*", "", "WIN:")    //get the name of the graph

//check if this Notebook already exists
V_Flag = 0
DoWindow $NotebookName   
// if yes, construct a new name
if (V_Flag)
	i = 1
	do 
		tempNoteBookName = NotebookName + num2istr(i)
		DoWindow $tempNotebookName
		i += 1
	while (V_Flag)
	NotebookName = tempNotebookName 
endif
//if not, just proceed

NewNotebook /F=1 /K=1 /N=$NotebookName      //make a new notebook to hold the fit report
Notebook $NoteBookName ,fsize=8




//prepare a new datafolder for the fitting results, in particular the single peaks
parentDataFolder = GetDataFolder(1)    //get the name of the current data folder

if (newFolder == 1)
	NewDataFolder /O /S subfolder
	//now, this folder is the actual data folder, all writing is done here and not in root
endif

duplicate /o fitted tempFitWave
wave locRefTempFit = tempFitWave
locRefTempFit = 0

//now decompose the fit into single peaks --- if a further fit static function is added, a further "case" has to be attached

		numCoef = 15
		nPeaks = (LenCoefWave-5)/numCoef         //get the number of  peaks from the output wave of the fit
		//check, if the peak type matches the length of the coefficient wave
		//if not so, clean up, inform and exit
		BGName = "PS_bg" +"_" + dataWave 
		duplicate /o fitted $BGName
		wave background = $BGName
		
		duplicate /o fitted HGB
		wave hgb = HGB
		AppendToGraph background
		
		if (mod(LenCoefWave-5,numCoef) != 0)
			DoAlert 0, "Mismatch, probably wrong peak type selected or wrong coefficient file, check your fit and peak type "
			SetDataFolder parentDataFolder 
			KillDataFolder  /Z subfolder
			print " ******* Peak type mismatch - check your fit and peak type ******"
			return 1
		endif 
		
		Notebook $NoteBookName ,text="\r\r" 
		
		//continue here ......
		variable j,para1,para2,para3, sumCoef, sumAnalytical
		
		
		string SubPeakName
		variable areaPeak = 0
		for (i =0; i<nPeaks;i+=1)
			index = numCoef*i + 5
			PkName = "m" + num2istr(i+1)+"_" + dataWave    //make a proper name
			 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
			duplicate /o fitted $PkName
							
			wave W = $PkName        //This needs some explanation, see commentary at the end of the file                                        
			
			
			
			W = 0
			sprintf  tempString, "\r\r\r Multiplet  %1g     ======================================================================================\r\r",(i+1)
			Notebook $NoteBookName ,text=tempString
			sumCoef = 0
			sumAnalytical = 0
			for ( j = 0; j < 4; j += 1)
	 			SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + dataWave
	 			duplicate /o fitted $SubPeakName
		 		wave subPeak = $SubPeakName
		 	      para1 = cwave[index]*(j==0) + (j !=0)*cwave[index]*cwave[index+6+3*(j-1)] 
		 	      sumCoef += para1
		 	      para2 = cwave[index+1]*(j==0) + (j !=0)*(cwave[index+1]+cwave[index+7+3*(j-1)] ) 
		 	      para3 = cwave[index+2]*(j==0) + (j !=0)*cwave[index+2]*cwave[index+8+3*(j-1)]  
		 		
		 		subPeak = CalcSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5],x)
		 		areaPeak= IntegrateSingleVoigtGLS(1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
				subPeak /= areaPeak
				subPeak *= para1
		 		
		 		
				//AnalyticalArea =  IntegrateSingleVoigtGLS(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5]) //*( ( j==0 ) + ( j != 0)*cwave[index+6+3*(j-1)] )
				//sumAnalytical += AnalyticalArea
				EffectiveFWHM = CalcFWHMSingleVoigtGLS(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])
				GeneralAsymmetry = CalcGeneralAsymmetry(para1,para2,para3,cwave[index+3],cwave[index+4],cwave[index+5])   
				WaveStats /Q subPeak 
		 		
				sprintf  tempString, " Peak %1g	  Area\t|\tPosition\t|\tFWHM\t|\tGL-ratio\t|\tAsym.\t|\tAsym. Shift\t\r",(j+1)
				Notebook $NoteBookName ,text=tempString
				sprintf  tempString, "\t%s\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t\r" ,  STnum2str(para1), para2,para3 ,cwave[index+3] , cwave[index+4],cwave[index+5]
				Notebook $NoteBookName ,text=tempString	
				sprintf  tempString, "\rEffective maximum position\t\t\t\t%8.2f \r", V_maxloc  // "-> In case of asymmetry, this value does not represent an area any more"
				Notebook $NoteBookName ,text=tempString
				sprintf  tempString, "Effective FWHM\t\t\t\t\t%8.2f \r", EffectiveFWHM	
				Notebook $NoteBookName ,text=tempString	
				sprintf tempString, "Effective Asymmetry = 1 - (fwhm_right)/(fwhm_left)\t\t%8.2f \r\r\r\r" , GeneralAsymmetry
				Notebook $NoteBookName ,text=tempString
		 				
		 		W += subPeak
		 		AppendToGraph subPeak
		 		//ModifyGraph lstyle($SubPeakName)=2
		 		ModifyGraph lstyle($SubPeakName)=0,rgb($SubPeakName)=(43520,43520,43520)
		 	endfor
			
			
			
			
			 //overwrite the original values in the wave with the values of a single peak
			//W =  CalcSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
			locRefTempFit += W         
			
			AppendToGraph W                                                    //now plot it

			//append the peak-tags to the graph, let the arrow point to a maximum
			//append the peak-tags to the graph, let the arrow point to a maximum
			WaveStats /Q W                             // get the location of the maximum
			TagName = "tag"+num2istr(i)           //each tag has to have a name
			PeakTag = num2istr(i+1)                 // The tag displays the peak index
			TagPosition = V_maxloc                 // and is located at the maximum
			Tag  /C /N= $TagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag    // Now put the tag there
			sprintf  tempString, "Total multiplet area\r-------------------------------------\r  %s  \t\t(sum of fit coefficients - usually larger than visible area within measurement window) ",  STnum2str(sumCoef)
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "\r  %s  \t\t(area within measurement window) ",  STnum2str(area(W))
			Notebook $NoteBookName ,text=tempString
			//sprintf tempString, "\r %s  \t\t(sum of analytical areas)", STnum2str(sumAnalytical)
			//Notebook $NoteBookName ,text=tempString
			sprintf tempString, "\r\r==================================================================================================\r\r\r"
			//Notebook $NoteBookName ,text=tempString
			
			
			Notebook $NoteBookName ,text=tempString
			ModifyGraph rgb($PkName)=(10464,10464,10464)              // color code the peak
				
			
		endfor
		
		
		//and now, add the background
		pointLength = numpnts(locRefTempFit)
		totalArea = sum(locRefTempFit)
		partialArea = 0
		
		//distinguish between ascending and descending order of the points in the raw-data wave
		if (pnt2x(locRefTempFit,0) > pnt2x(locRefTempFit,1))   //with increasing index, x decreases
			for (i=pointLength-1; i ==0; i -=1)	
				partialArea += abs(locRefTempFit[i]) 
		
				background[i] = partialArea/totalArea

			endfor
			//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = pointLength; i == 0; i -= 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			background *= cwave[4]
			background += hgb
			//for (i =0; i<nPeaks;i+=1)
			//	index = numCoef*i + 5
		//		background += 1e-3*cwave[3]*cwave[index] * ( x - cwave[index + 1])^2 * ( x > cwave[index+1])
		//	endfor
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
		else
			for (i=0; i<pointLength; i += 1)
					partialArea += abs(locRefTempFit[i]) 
					background[i] =partialArea/totalArea 
			endfor
				//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = 0; i < pointLength; i += 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			
			
			background *= cwave[4]
			background += hgb
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
			
		endif
		//now, everything should be fine with the background .... carry on
		
		locRefTempFit += background
		
		
		tempString = "\r\r\r\r\rFurther Details\r"
		Notebook $NoteBookName ,text=tempString
		tempString = "==================================================================================================="
		Notebook $NoteBookName ,text=tempString
		strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
			case "":                                             //if empty
				 sprintf  tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))           
			break
			case "_calculated_":
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))
			break
			default:                                                 // if not empty
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(areaXY(xraw,origWave))
				break
		endswitch
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "Total area of all peaks in measurement window:\t\t%s \r" STnum2str(area(locRefTempFit) - area(background))
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "Area of the background in measurement window:\t\t%s \r", STnum2str(area(background) )
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\rYou used a simultaneous fit of background  and signal: MAKE SURE the background shape makes sense.\r" 
		Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, "For details on the \r -- Peak shape:  Surface and Interface Analysis (2014), 46, 505 - 511  (If you use this program, please read and cite this paper) \r" 
		//Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, " -- 'Pseudo-Tougaard' and Shirley contribution to the background:  J. Elec. Spectrosc. Rel. Phen (2013), 189, 76 - 80\r" 
		//Notebook $NoteBookName ,text=tempString
		sprintf tempString,"\rPlease note that for asymmetric peaks the fit coefficients for position and FWHM are merely coefficients. \rIn this case, refer to the respective 'effective' values.\r"      
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rBackground\r==================================\rThe background is calculated as follows:  Offset + a*x + b*x^2 + c * (pseudo-tougaard) + d * shirley\r" 
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\r(Here:  Offset=%8.2g;      a =%8.2g;      b =%8.2g;   c =%8.4g;   d =%8.2g; ) \r", cwave[0], cwave[1], cwave[2], cwave[3], cwave[4]
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rThe parameters a and b  serve to cover general slopes or curvatures in the background, for example if the peak sits on a complex mixture of  broad Auger lines or plasmons.\r" 
		Notebook $NoteBookName ,text=tempString
		
		sprintf tempString, "\rPeak Areas\r==================================\rThe peak area is obtained by integrating the peak on an interval of +/- 90*FWHM around the peak position."
		Notebook $NoteBookName ,text=tempString
		
		sprintf tempString, "\rThis value is generally somewhat larger than the visible peak area within the limited measurement window."
		Notebook $NoteBookName ,text=tempString
		
		
		
		//and now add the background to all peaks as well
		for (i =0; i<nPeaks;i+=1)
			PkName = "m" + num2istr(i+1)+"_" + dataWave    					
			wave W = $PkName       
			W += background
			for ( j = 0; j < 4; j += 1)
	 			SubPeakName =  "m" + num2istr(i+1) + "p" + num2str(j+1) + "_" + dataWave
	 			wave subPeak = $SubPeakName
		 	      subPeak += background
		 	endfor			
		endfor
		

//killwaves /z  fitted     //this applies to the original fit-wave of Igor, since it is a reference to the wave root:Igor-FitWave, the original wave is possibly wrong
//duplicate /o locRefTempFit, $fitWave               //but we are still in the subfolder, 
//killwaves /z locRefTempFit
//wave fitted = $fitWave


	SetDataFolder parentDataFolder 

	//create a copy of the coefficient wave in the subfolder, so the waves 
	//and the complete fitting results are within that folder
	duplicate /o :$dataWave, :subfolder:$dataWave
//	if (WaveExists($RawXWave))
	if (Exists(RawXWave))
		duplicate /o :$RawXWave, :subfolder:$RawXWave
	endif

	//duplicate  :$fitWave, :subfolder:$fitWave
//	killwaves /z :$fitWave            //probably fails, if the fit wave is displayed in the main panel as well
	duplicate /o $fitWave :subfolder:$fitWave
	AppendToGraph :subfolder:$fitWave                                //draw the complete fit
	ModifyGraph rgb($fitWave) = (0,0,0)       //color-code it
	//Remove the original wave, which is located in the parent directory and replace it by the copy in the subfolder
	RemoveFromGraph $"#0" 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph :subfolder:$dataWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
			break
		case "_calculated_":
			AppendToGraph  :subfolder:$dataWave
			break
		default:                                                 // if not empty
			AppendToGraph :subfolder:$dataWave vs :subfolder:$RawXWave        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
	endswitch

	foldername = "Report_" + projectName
	
	//foldername ="Fit_"+ dataWave
	i=1   //index variable for the data folder	
	            //used also for the notebook
	V_Flag = 0
	DoWindow $folderName
	tempFoldername = foldername
	
	if (V_Flag)    //is there already a folder with this name
		do
			V_Flag = 0
			tempFoldername = foldername + "_" + num2istr(i)
			DoWindow $tempFolderName
			i+=1
		while(V_Flag)
		
		if (strlen(tempFoldername) >= 30)	
			//doalert 0, "The output folder name is too long! Please shorten the names. The output folder of the current run is named 'subfolder'."
			string NewName = ""
			
			Prompt NewName, "The wave name is too long, please provide a shorter name "		// Set prompt for y param
			DoPrompt "Shorten the name", NewName
			if (V_Flag)
				return -1								// User canceled
			endif	
			tempFolderName = NewName	
		endif
			RenameDataFolder subfolder, $tempFoldername                   //now rename the peak-folder accordingly
			Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST (2015)" //\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
			//remove illegal characters from the string
			tempFoldername = stringClean(tempFoldername)
			DoWindow /C $tempFoldername
			DoWindow /F $LastGraphName
			DoWindow /C $tempFoldername + "_graph"
			//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"   //valid in Igor 6.x
		//TextBox/N=text0/A=LT tempFoldername        //prints into the graph
	else 
		//no datafolder of this name exist
		RenameDataFolder subfolder, $foldername 
		//TagWindow(foldername)
		Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST (2015)" //\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
		//if ( strsearch(foldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		//	foldername = ReplaceString(".", foldername,"_")
		//endif
		foldername = stringClean(foldername)
		tempFoldername = stringClean(tempFoldername)
		DoWindow /C $foldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
	endif

//make the graph look good
ModifyGraph mode($dataWave)=3 ,msize($dataWave)=1.3 // ,marker($dataWave)=8, opaque($dataWave)=1
ModifyGraph opaque=1,marker($dataWave)=19
ModifyGraph rgb($dataWave)=(60928,60928,60928)
ModifyGraph useMrkStrokeRGB($dataWave)=1
ModifyGraph mrkStrokeRGB($dataWave)=(0,0,0)
//ModifyGraph mrkThick($dataWave)=0.7
//ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
ModifyGraph mirror=2,minor(bottom)=1
Label left "\\f01 intensity (counts)"
Label bottom "\\f01  binding energy (eV)"	
ModifyGraph width=255.118,height=157.465, standoff = 0, gfSize=11

//The following command works easily, but then the resulting graph is not displayed properly in the notebook
//SetAxis/A/R bottom
//instead do it like this:
variable left,right

strswitch(RawXWave)
	 	case "":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	case "_calculated_":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	default:
	 		waveStats /Q $RawXWave
	 		left = V_max
	 		right = V_min
	 	break
 endswitch
 SetAxis bottom left,right
//okay this is not perfectly elegant ... but

WaveStats /Q $dataWave
SetAxis left V_min-0.05*(V_max-V_min), 1.02*V_max
LastGraphName = WinList("*", "", "WIN:")



Notebook  $tempFoldername, selection = {startOfFile,startOfFile}

tempString = "\rReport for fitting project: \t\t " + projectName + "\r"
Notebook  $tempFoldername, text=tempString
Notebook  $tempFoldername, selection = {startOfPrevParagraph,endOfPrevParagraph}, fsize = 12, fstyle = 0

tempString = "\r==================================================================================================="
Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}, text=tempString
Notebook $tempFolderName ,selection = {startOfNextParagraph,startOfNextParagraph}, text="Saved in:\t\t\t\t\t" + IgorInfo(1) + ".pxp \r"
Notebook $tempFolderName ,text="Spectrum:\t\t\t\t" +dataWave
Notebook $tempFolderName ,text="\rApplied peak shape:\t\t\t"+ peakType +"\r\r"

Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}
Notebook  $tempFoldername, picture={$LastGraphName, 0, 1} , text="\r\r\r" 

killwaves /z hgb
KillWindow $LastGraphName
//Notebook  $tempFoldername, text="\r \r"  

KillDataFolder /z tempFoldername

//now clean up
killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr

end





static function EvaluateMultipletSK()

wave cwave = W_Coef /// hard-coded but what the hell....

wave /t output = Numerics    //here we write the results

variable AnalyticalArea = 0
variable EffectiveFWHM = 0
variable GeneralAsymmetry = 0

variable i,j,k,index, index2
variable numpeaks
variable numCoef = 15

variable lengthCoef = numpnts(cwave)
variable lengthNumerics = DimSize(output,0)
string parentFolder = ""
string item = ""
numpeaks = (lengthCoef-5)/numCoef
variable EffectiveArea,EffectivePosition
string wavesInDataFolder = WaveList("*fit_*",";","DIMS:1")
wave fitted = $StringFromList(0,wavesInDataFolder)
variable areaW
string FormatString

variable totalCoefSum = 0
variable totalVisibleArea = 0
variable totalAnalyticalSum = 0
string tempString

variable areaPeak = 0
for ( i = 0; i < numPeaks; i += 1 )
	index = 15*i + 5
	//this static function also needs to analyze the waves to get the effective position etc.
	 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
	duplicate /o fitted tempForAnalysis
							
	wave W = tempForAnalysis
	 
	 //iterate for all subpeaks
	W =  CalcSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
	areaPeak= IntegrateSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	W /= areaPeak
	W *= cwave[index]
	WaveStats/Q W
	//areaW=area(W)
	
	//AnalyticalArea =  IntegrateSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	GeneralAsymmetry = CalcGeneralAsymmetry(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])   
	//totalAnalyticalSum += AnalyticalArea
	
	//Now write the results to Numerics //there is no need to re-calculate for each individual peak, the values may be derived from the
	//parameters

	index2 = 16*i
	
	output[index2+1][2] = STnum2str(cwave[index])
	output[index2+2][2] = "" 
	output[index2+2][1] = "" 
	output[index2+3][2] = "" 
	output[index2+3][1] = "" 
	
	output[index2+5][2] = STnum2str(cwave[index]*cwave[index +6])
	output[index2+6][2] = "" 
	output[index2+6][1] = "" 

	output[index2+7][2] = ""
	output[index2+7][1] = ""
	
	
	output[index2+9][2] = STnum2str(cwave[index]*cwave[index +9])
	output[index2+10][2] = "" 
	output[index2+10][1] = "" 

	output[index2+11][2] = ""
	output[index2+11][1] = ""
	
	output[index2+13][2] = STnum2str(cwave[index]*cwave[index +12])
	output[index2+14][2] = ""
	output[index2+14][1] = ""
	
	
	output[index2+15][2] = "" 
	output[index2+15][1] = "" 
	
	totalCoefSum +=cwave[index]*(1+cwave[index+6]+cwave[index+9] + cwave[index+12])

	
	output[index2+1][4] = STnum2str(cwave[index+1])
	output[index2+2][4] = STnum2str(V_maxloc)
	
	output[index2+5][4] = STnum2str(cwave[index+1]+cwave[index+7])
	output[index2+6][4] = STnum2str(V_maxloc+cwave[index+7])
	
	output[index2+9][4] = STnum2str(cwave[index+1]+cwave[index+10])
	output[index2+10][4] = STnum2str(V_maxloc+cwave[index+10])
	
	output[index2+13][4] = STnum2str(cwave[index+1]+cwave[index+13])
	output[index2+14][4] = STnum2str(V_maxloc+cwave[index+13])
	
	
	
	output[index2+1][6] = STnum2str(cwave[index+2])
	output[index2+2][6] = STnum2str(EffectiveFWHM)
	
	output[index2+5][6] = STnum2str(cwave[index+2] *cwave[index+8])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+6],cwave[index+1]+cwave[index+7],cwave[index+2]*cwave[index+8],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+6][6] = STnum2str(EffectiveFWHM)
	
	output[index2+9][6] = STnum2str(cwave[index+2] *cwave[index+11])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+9],cwave[index+1]+cwave[index+10],cwave[index+2]*cwave[index+11],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+10][6] = STnum2str(EffectiveFWHM)
	
	output[index2+13][6] = STnum2str(cwave[index+2] *cwave[index+14])
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index]*cwave[index+12],cwave[index+1]+cwave[index+13],cwave[index+2]*cwave[index+14],cwave[index+3],cwave[index+4],cwave[index+5])
	output[index2+14][6] = STnum2str(EffectiveFWHM)
	
	
	output[index2+1][8] = STnum2str(cwave[index+3])
	
	output[index2+1][10]=STnum2str(cwave[index+4])
	 
	output[index2+2][10] =STnum2str(GeneralAsymmetry)

	output[index2+1][12] = STnum2str(cwave[index+5])
	
	
	
	output[index2+10][10] = STnum2str(totalCoefSum)
	output[index2+11][10] = ""//STnum2str(totalVisibleArea)
	output[index2+11][9] = ""
	output[index2+12][10] = ""//STnum2str(totalAnalyticalSum)
	output[index2+12][9] = ""
	totalCoefSum = 0
//	totalVisibleArea = 0
	//totalAnalyticalSum = 0
	
	
	killwaves /Z W
endfor
	
end



static function RemoveMultiplet()
	//CheckLocation()
	//these are needed to be able to call SinglePeakDisplay, in case of the background functions
	SVAR peakType = root:STFitAssVar:PR_PeakType
	SVAR RawXWave = root:STFitAssVar:PR_XRawDataCursorPanel
	SVAR RawYWave = root:STFitAssVar:PR_nameWorkWave
	SVAR coefWave = root:STFitAssVar:PR_CoefWave
	NVAR numPeaks = root:STFitAssVar:ST_NumPeaks
	NVAR toLink = root:STFitAssVar:STPeakToLink
	NVAR peakToExtract = root:STFitAssVar:STPeakToRemove
	NVAR savedLast = root:STFitAssVar:savedLast
	savedLast = 0 //this change has not been saved yet
	UpdateFitDisplay("fromAddPeak")
	//updateCoefs()
	setup2waves()
	numPeaks -= 1
	numPeaks=max(0,numPeaks)
	toLink = min(toLink,numPeaks)
	//peakToExtract = max(0,numPeaks)
	/////////////////////////////////////////////////////////////


	wave /t source = STsetup
	//NVAR peakToExtract = PeakToDelete
	wave sw = selSTsetup

	wave /t  numerics = Numerics
	wave selNumerics = selNumerics

	variable i,j,k
	variable length = DimSize(source,0)
	variable NumLength = DimSize(numerics,0)

	//this needs to be rewritten for doublet functions as well
	//numPeaks = (length-5)/6

	//this is the simple version of delete which only removes the last entry
	//if (length>=6)
	//Redimension /n=(length-6,-1) source
	//Redimension /n=(length-6,-1) sw
	//endif

	if (length == 5) ///only the background is left
		return 1 /// do nothing, the background may stay there forever
	endif

	string ListOfCurves
	variable numberCurves
	variable startCutIndex, endCutIndex
	variable numCoefs = 15

	//FancyUP("foe")

	//now do a sophisticated form of delete which removes a certain peak from within the waves
	//for example peak 2
	//peakToExtract = 2 //this needs to be soft-coded later on

	//duplicate the sections that need to go
	//to do so: calculate the indices that have to be removed
	//this needs to be extended for doublet functions as well

	startCutIndex = 5 + (peakToExtract-1)*numCoefs
	endCutIndex = startCutIndex + 15

	variable startCutIndexNumerics = (peakToExtract-1)*16
	variable endCutIndexNumerics = startCutIndexNumerics +16

	//now, check if there are any constraints linked to this peak, if yes, refuse to do the deleting and notify the user
	// that means the ax, px, wx, etc of this peak e.g. a2, w2, etc show up anywhere else in the constraints wave, if so, abort
	variable abortDel = 0

	string planeName = "backColors"
	variable plane = FindDimLabel(sw,2,planeName)

	Variable nplanes = max(1,Dimsize(sw,2))
	if (plane <0)
		Redimension /N=(-1,-1,nplanes+1) sw
		plane = nplanes
		SetDimLabel 2,nplanes,$planeName sw
	endif

	variable Errors = 0
	string tempString
	string CoefficientList = "a;p;w;g;s;t"
	string matchString 
	string badSpotList = ""

	for (j = 0; j<itemsInList(CoefficientList); j += 1)
		matchString = "*" + StringFromList(j,CoefficientList) + num2str(peakToExtract) + "*"
		for (i=0; i < startCutIndex; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1
				badSpotList += num2str(i) + ";"	
			endif
		endfor
		for (i=endCutIndex; i < length; i += 1)
			tempString =source[i][5]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][5][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
			tempString =source[i][6]
			abortDel = StringMatch(tempString,matchString)
			if (abortDel != 0)
				Errors += 1
				sw[i][6][plane] =1	
				badSpotList += num2str(i) + ";"
			endif
		endfor
	endfor

	variable badSpots = ItemsInList(badSpotList)
	variable badSpot

	if (Errors != 0)
		tempString = "Other peaks are linked to the one you want to remove. \r\rDelete all references to the peak you want to remove from 'Lower Limit' and 'Upper Limit'."
		Doalert 0, tempString
		tempString = "editDisplayWave(\"foe\")"
		Execute tempString
		// and now do the highlighting
		for ( i = 0; i < badSpots; i += 1 )
			badSpot = str2num(StringFromList(i,badSpotList))
			sw[badSpot][5][plane] =1		
			sw[badSpot][6][plane] =1		
		endfor
	
		//end highlighting
	
		numpeaks += 1
		return -1
	endif

	//everything seems to be fine, now continue
	duplicate /o /r=(0,startCutIndex-1) source $"lowerSectionSetup" 
	wave /t lowerSetup = $"lowerSectionSetup"
	duplicate /o /r=(0,startCutIndex-1) sw $"lowerSectionSw" 
	wave  lowerSW = $"lowerSectionSw"

	duplicate /o /r=(endCutIndex,length-1) source $"upperSectionSetup" 
	wave /t upperSetup = $"upperSectionSetup"
	duplicate /o /r =(endCutIndex, length -1) sw $"upperSectionSw" 
	wave upperSW = $"upperSectionSw"


	duplicate /o /r=(0,startCutIndexNumerics-1) numerics $"lowerSectionNumerics" 
	wave /t lowerNumerics = $"lowerSectionNumerics"
	duplicate /o /r=(0,startCutIndexNumerics-1) selNumerics $"lowerSectionSelNumerics" 
	wave  lowerSelNumerics = $"lowerSectionSelNumerics"

	duplicate /o /r=(endCutIndexNumerics,NumLength-1) numerics $"upperSectionNumerics" 
	wave /t upperNumerics = $"upperSectionNumerics"
	duplicate /o /r =(endCutIndexNumerics, NumLength -1) selNumerics $"upperSectionSelNumerics" 
	wave upperSelNumerics = $"upperSectionSelNumerics"


	//remove also the entries for the numerics wave

	//remove the space for one peak
	Redimension /n=(length-15,-1) source
	Redimension /n=(length-15,-1) sw

	Redimension /n=(NumLength-16,-1) numerics    //four lines per peak if the peak type is singlet
	Redimension /n=(NumLength-16,-1) selNumerics

	//and now, copy the stuff back, start with the lowerSection
	for (i = 0; i < startCutIndex; i += 1)
		for ( j =2; j < 8; j +=1) // do not overwrite the legend waves, this would be redundant
			if (j  != 4)
				source[i][j]=lowerSetup[i][j]
			endif
			sw[i][j]=lowerSW[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndex; i < length-15; i += 1)
		for ( j =2; j < 8; j +=1)
			if (j  != 4)
				source[i][j]=upperSetup[i-startCutIndex][j]
			endif
			sw[i][j]=upperSW[i-startCutIndex][j]
		endfor
	endfor

	//now repeat everything for the Numerics wave
	for (i = 0; i < startCutIndexNumerics; i += 1)
		for ( j =2; j < 15; j +=1) // do not overwrite the legend waves, this would be redundant
			numerics[i][j]=lowerNumerics[i][j]
			selNumerics[i][j]=lowerSelNumerics[i][j]
		endfor	
	endfor
	//and continue with the upper section
	for (i = startCutIndexNumerics; i < NumLength-16; i += 1)
		for ( j =2; j < 15; j +=1)
			numerics[i][j]=upperNumerics[i-startCutIndexNumerics][j]
			selNumerics[i][j]=upperSelNumerics[i-startCutIndexNumerics][j]
		endfor
	endfor

	killwaves /z upperSetup, upperSW, lowerSetup, lowerSW, lowerSelNumerics, upperSelNumerics, lowerNumerics, upperNumerics

	//now make sure that all the parameter names, such as a2, a3, etc are updated
	//if the second peak was removed:   old > new 
	//								a1 > a1
	//								a2 > removed
	//								a3 > a2 //k = 0
	//								a4 > a3  //k = 1
	string lowerIndexIn, higherIndexOut

	for ( k = 0; k< numpeaks; k += 1)
		for ( j = 0; j < itemsInList(CoefficientList); j += 1 )
			lowerIndexIn = StringFromList(j,CoefficientList) + num2str(peakToExtract+k )  
			higherIndexOut = StringFromList(j,CoefficientList) +num2str(peakToExtract + k +1)
			//print lowerIndexIn, higherIndexOut
			for ( i = 0; i < length-15; i += 1 )
				tempString = source[i][5]
				source[i][5]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
				tempString = source[i][6]
				source[i][6]=ReplaceString(higherIndexOut, tempString, lowerIndexIn)
			endfor
		endfor
	endfor
	
	///////////////////////////////////////////////////////////
	setup2waves()	
	ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	//this needs to be adapted to the background functions
	RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-1)
	//if (BackgroundType != 0 )
	for (i =2; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	//and now redisplay, if there are any peaks left
	SinglePeakDisplay(peakType,RawYWave,RawXWave, "InitializeCoef")//coefWave)
	FancyUp("foe")
	peakToExtract = max(0,numPeaks)
	SetVariable InputSetLink, limits={0,numPeaks,1}
	SetVariable InputRemoveLink,limits={0,peakToExtract,1}
	SetVariable InputRemoveLink2,limits={0,peakToExtract,1}
end

/////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
////////   SpecPseudoVoigtSK
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////




static function AddVoigtSKPeak(coefWave,RawYWave,indepCheck,heightA,posA,initialSlope, initialOffset, left,right,Wcoef_length)

string coefWave     //this won't be needed in the future ... for now, leave it here
string RawYWave
variable indepCheck
variable heightA
variable posA	
variable initialSlope
variable initialOffset
variable left
variable right
variable Wcoef_length

NVAR peakToLink = root:STFitAssVar:STPeakToLink
string parameterList = "a;p;w;g;as;at"

NVAR linkArea = root:STFitAssVar:AreaLink
NVAR linkPosition = root:STFitAssVar:PositionLink
NVAR linkWidth = root:STFitAssVar:WidthLink
NVAR linkGL = root:STFitAssVar:GLLink
NVAR linkAsym = root:STFitAssVar:AsymLink

NVAR areaLinkUpperFactor = root:STFitAssVar:AreaLinkFactorHigh
NVAR areaLinkLowerFactor = root:STFitAssVar:AreaLinkFactorLow
NVAR positionLinkOffsetMax = root:STFitAssVar:PositionLinkOffsetMax
NVAR positionLinkOffsetMin = root:STFitAssVar:PositionLinkOffsetMin

string name = "CursorPanel#guiCursorDisplay" 	
variable nPeaks,i,numPara,EstimatedPeakArea
variable epsilonVal=1e-5

wave /t source = STsetup  //everything is in the setup
wave sw = selSTSetup

wave /t  numerics = Numerics
wave selNumerics = selNumerics

variable length = DimSize(source,0)
variable NumLength = DimSize(numerics,0)

variable numpeaks = 0
//print numpeaks
variable index
variable newLength

string message

WaveStats /Q $RawYWave
wave raw = $RawYWave
//consider the full background, so far this only covers slopes


if (length == 0)
	heightA = vcsr(A,name) - (initialSlope*posA+initialOffset)						
	EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)	
	
	Redimension /n=(length+11,-1) source
	Redimension /n=(length+11,-1) sw
	
	numpeaks = 0
	//set writing permissions and checkbox controls
	for ( i= 0; i<length + 11; i+=1)
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor

	source[length][0] = "Offset at E = 0 eV"
	source[length + 1][0] = "Slope"
	source[length + 2][0] = "Parabola"
	source[length + 3][0] = "Pseudo Tougaard (Herrera-Gomez)"
	source[length + 4][0] = "Shirley Step Height"
	source[length + 5][0] = "Area   -------------------------- Peak " + num2str(numpeaks+1)
	source[length + 6][0] = "Position"
	source[length + 7][0] = "Width"
	source[length + 8][0] = "Gauss-Lorentz Ratio"
	source[length + 9][0] = "Asymmetry"
	source[length + 10][0] = "Asymmetry Translation"

	source[length][1] = "off" 
	source[length + 1][1] = "sl"
	source[length + 2][1] = "prb" 
	source[length + 3][1] = "tgd" 
	source[length + 4][1] = "srl"
	source[length + 5][1] = "a" + num2str(numpeaks+1)
	source[length + 6][1] = "p" + num2str(numpeaks+1)
	source[length + 7][1] = "w" + num2str(numpeaks+1)
	source[length + 8][1] = "g" + num2str(numpeaks+1)
	source[length + 9][1] = "as" + num2str(numpeaks+1)
	source[length + 10][1] = "at" + num2str(numpeaks+1)
	
	source[length][4] = "off" 
	source[length + 1][4] = "sl"
	source[length + 2][4] = "prb" 
	source[length + 3][4] = "tgd" 
	source[length + 4][4] = "srl"
	source[length + 5][4] = "a" + num2str(numpeaks+1)
	source[length + 6][4] = "p" + num2str(numpeaks+1)
	source[length + 7][4] = "w" + num2str(numpeaks+1)
	source[length + 8][4] = "g" + num2str(numpeaks+1)
	source[length + 9][4] = "as" + num2str(numpeaks+1)
	source[length + 10][4] = "at" +num2str(numpeaks+1)
	

	EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
	//calculate the offset at E = 0 and the slope accordingly
	
	source[length][3] = MyNum2str(initialOffset) //MyNum2str(max(0,V_min)) 
	source[length + 1][3] = MyNum2str(initialSlope)
	source[length + 2][3] = "0" 
	source[length + 3][3] = "0" 
	source[length + 4][3] = "0" // MyNum2str(0.1*abs(heightA-V_min))
	source[length + 5][3] = MyNum2str(EstimatedPeakArea)
	
	source[length + 6][3] = MyNum2str(posA)
	source[length + 7][3] = MyNum2str(Width_Start)
	source[length + 8][3] = MyNum2str(GLratio_Start)
	source[length + 9][3] = MyNum2str(Asym_Start)
	source[length + 10][3] = MyNum2str(Asym_Shift_Start)

	
	sw[length +2][4][0] = 48
	sw[length +3][4][0] = 48   //check checkboxes
	sw[length +8][4][0] = 48
	sw[length +9][4][0] = 48
	sw[length +10][4][0] = 48
	
	sw[length+2][5][0] = 0   
	sw[length+3][6][0] = 0    
	
	
	source[length][5] = MyNum2str(-10*abs(initialOffset))
	source[length + 1][5] = MyNum2str(-10*abs(initialSlope))
	source[length + 2][5] = "-100" 
	source[length + 3][5] = MyNum2str(-20*abs(heightA-V_min)) 
	source[length + 4][5] = "1e-6"
	source[length + 5][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
	source[length + 6][5] = MyNum2str(posA-1.5)//MyNum2str(right)
	source[length + 7][5] = MyNum2str(Width_Min)
	source[length + 8][5] =  MyNum2str(GLratio_Min)
	source[length + 9][5] = MyNum2str(Asym_Min)
	source[length + 10][5] = MyNum2str(Asym_Shift_Min)

	
	source[length][6] = MyNum2str(10*abs(initialOffset))
	source[length + 1][6] = MyNum2str(10*abs(initialSlope))
	source[length + 2][6] = "100" 
	source[length + 3][6] = MyNum2str(20*abs(heightA-V_min))
	source[length + 4][6] = MyNum2str(0.7*abs(V_min-heightA))
	source[length + 5][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
	source[length + 6][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
	source[length + 7][6] = MyNum2str(Width_Max )
	source[length + 8][6] = MyNum2str(GLratio_Max)
	source[length + 9][6] = MyNum2str(Asym_Max)
	source[length + 10][6] = MyNum2str(Asym_Shift_Max)

	source[length][7] = "1e-9" 
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9" 
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-8"
	source[length + 6][7] = "1e-9"
	source[length + 7][7] = "1e-9"
	source[length + 8][7] = "1e-9" 
	source[length + 9][7] = "1e-9"
	source[length + 10][7] = "1e-9"
else
	//now, linking can come into the game ... it will affect the columns 3,4,5,6
	
	//the height has to be calculated differently now
	
	heightA = vcsr(A,name) - (str2num(source[0][3])+posA*str2num(source[1][3])  )						

	
	EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)	
	
	Redimension /n=(length+6,-1) source
	Redimension /n=(length+6,-1) sw	
	
	newLength = length+ 6
	
	numpeaks = floor((length-5)/6)
	for ( i= length; i<newLength; i+=1)
		sw[i][0][0] = 0                //legende
		sw[i][1][0] = 0           //coef kuerzel
		sw[i][2][0] = 0           //endergebnis
		sw[i][3][0] = (0x02)   //anfangswerte
		sw[i][4][0] = (0x20)    //hold
		sw[i][5][0] = (0x02)    //Min Limit
		sw[i][6][0] = (0x02)    //Max Limit
		sw[i][7][0] = (0x02)    //epsilon
	endfor
	
	source[length][0] = "Area   ----------------------------- Peak " + num2str(numpeaks+1)
	source[length + 1][0] = "Position"
	source[length + 2][0] = "Width"
	source[length + 3][0] = "Gauss-Lorentz Ratio"
	source[length + 4][0] = "Asymmetry"
	source[length + 5][0] = "Asymmetry Translation"

	source[length][1] = "a" + num2str(numpeaks+1)
	source[length + 1][1] = "p" + num2str(numpeaks+1)
	source[length + 2][1] = "w" + num2str(numpeaks+1)
	source[length + 3][1] = "g" + num2str(numpeaks+1)
	source[length + 4][1] = "as" + num2str(numpeaks+1)
	source[length + 5][1] = "at" + num2str(numpeaks+1)


     // start: take care of linking
     if (peakToLink == 0)
		EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
		source[length][3] = MyNum2str(EstimatedPeakArea)
		source[length + 1][3] = MyNum2str(posA)
		source[length + 2][3] = MyNum2str(Width_Start)
		source[length + 3][3] = MyNum2str(GLratio_Start)
		source[length + 4][3] = MyNum2str(Asym_Start)
		source[length + 5][3] = MyNum2str(Asym_Shift_Start)
	
		sw[length +3][4][0] = 48
		sw[length +4][4][0] = 48
		sw[length +5][4][0] = 48   //check checkboxes

	
		source[length][5] = MyNum2str(min(10,0.1 * EstimatedPeakArea ))  //this is the first peak
		source[length + 1][5] = MyNum2str(posA-1.5)// MyNum2str(right)
		source[length + 2][5] = MyNum2str(Width_Min)
		source[length + 3][5] =  MyNum2str(GLratio_Min)
		source[length + 4][5] = MyNum2str(Asym_Min)
		source[length + 5][5] = MyNum2str(Asym_Shift_Min)
	

		source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		source[length + 2][6] = MyNum2str(Width_Max )
		source[length + 3][6] = MyNum2str(GLratio_Max)
		source[length + 4][6] = MyNum2str(Asym_Max)
		source[length + 5][6] = MyNum2str(Asym_Shift_Max)
	else
		//get the startingIndex of the target peak
		variable startIndexParentPeak = 6 * (peakToLink -1 ) + 5		
	
		if ( linkArea == 0 )
			EstimatedPeakArea = EstimatePeakArea( heightA , Width_Start, 5 * GLratio_Min, 5 * Asym_Min , 5 * Asym_Shift_Min)
			source[length][3] = MyNum2str(EstimatedPeakArea)
			sw[length][4][0] = 32
			source[length][5] = MyNum2str(min(10,0.2 * EstimatedPeakArea ))  
			source[length ][6] =  MyNum2str(max(10,30 * EstimatedPeakArea ))
		else
			
			source[length][3] = MyNum2str( areaLinkLowerFactor * str2num(source[startIndexParentPeak][3]) )    //start at the lower boundary
			sw[length][4][0] = sw[startIndexParentPeak][4][0]
			source[length][5] = MyNum2str(areaLinkLowerFactor - 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
			source[length ][6] = MyNum2str(areaLinkUpperFactor + 0.001) + " * " + StringFromList(0,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkPosition == 0 )
			source[length + 1][3] = MyNum2str(posA)
			sw[length + 1][4][0] = 32
			source[length + 1][5] = MyNum2str(posA-1.5) //MyNum2str(right)
			source[length + 1][6] =  MyNum2str(posA+1.5)//MyNum2str(left )
		else
			source[length + 1][3] = MyNum2str( str2num( source[startIndexParentPeak + 1][3] ) + positionLinkOffsetMin )
			sw[length + 1][4][0] = sw[startIndexParentPeak +1][4][0]
			source[length + 1][5] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMin-0.01)
			source[length + 1][6] = StringFromList(1,parameterList) + num2str(peakToLink) + " + " + MyNum2str(positionLinkOffsetMax + 0.01)
		endif
		
		if ( linkWidth == 0 )
			source[length + 2][3] = MyNum2str(Width_Start)
			sw[length + 2][4][0] = 32
			source[length + 2][5] = MyNum2str(Width_Min)
			source[length + 2][6] = MyNum2str(Width_Max )
		else
			source[length + 2][3] = source[startIndexParentPeak + 2][3]
			sw[length + 2][4][0] = sw[startIndexParentPeak +2][4][0]
			source[length + 2][5] = StringFromList(2,parameterList) + num2str(peakToLink)
			source[length + 2][6] = StringFromList(2,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkGL == 0 )
			source[length + 3][3] = MyNum2str(GLratio_Start)
			sw[length + 2][4][0] = 32
			source[length + 3][5] =  MyNum2str(GLratio_Min)
			source[length + 3][6] = MyNum2str(GLratio_Max)
		else
			source[length + 3][3] = source[startIndexParentPeak + 3][3]
			sw[length + 3][4][0] = sw[startIndexParentPeak +3][4][0]
			source[length + 3][5] =  StringFromList(3,parameterList) + num2str(peakToLink)
			source[length + 3][6] = StringFromList(3,parameterList) + num2str(peakToLink)
		endif
		
		if ( linkAsym == 0 )
			source[length + 4][3] = MyNum2str(Asym_Start)
			source[length + 5][3] = MyNum2str(Asym_Shift_Start)
			sw[length +3][4][0] = 48
			sw[length +4][4][0] =  48
			sw[length +5][4][0] =  48   //check checkboxes
			source[length + 4][5] = MyNum2str(Asym_Min)
			source[length + 5][5] = MyNum2str(Asym_Shift_Min)
			source[length + 4][6] = MyNum2str(Asym_Min)
			source[length + 5][6] = MyNum2str(Asym_Shift_Max)
		else
			source[length + 4][3] = source[startIndexParentPeak + 4][3]
			source[length + 5][3] = source[startIndexParentPeak + 5][3]
			sw[length +3][4][0] = sw[startIndexParentPeak +3][4][0]
			sw[length +4][4][0] = sw[startIndexParentPeak +4][4][0]
			sw[length +5][4][0] = sw[startIndexParentPeak +5][4][0]
			source[length + 4][5] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][5] = StringFromList(5,parameterList) + num2str(peakToLink)
			source[length + 4][6] = StringFromList(4,parameterList) + num2str(peakToLink)
			source[length + 5][6] = StringFromList(5,parameterList) + num2str(peakToLink)
		endif
	endif
	// stop: take care of linking
	
	
	source[length][4] = "a" + num2str(numpeaks+1) 
	source[length + 1][4] = "p" + num2str(numpeaks+1)
	source[length + 2][4] = "w" + num2str(numpeaks+1)
	source[length + 3][4] = "g" + num2str(numpeaks+1) 
	source[length + 4][4] = "as" + num2str(numpeaks+1) 
	source[length + 5][4] = "at" + num2str(numpeaks+1) 
	
	
	
	source[length][7] = "1e-8"
	source[length + 1][7] = "1e-9"
	source[length + 2][7] = "1e-9"
	source[length + 3][7] = "1e-9" 
	source[length + 4][7] = "1e-9"
	source[length + 5][7] = "1e-9"
endif

	Redimension /n=(NumLength+4,-1) numerics
	Redimension /n=(NumLength+4,-1) selNumerics
	
	numerics[NumLength][0] = "Peak " + num2str(numpeaks+1)
	numerics[NumLength + 1][1] = "Area"
	//numerics[NumLength +2 ][1] = "Visible Area"
	//numerics[NumLength +3 ][1] = "Analytical Area"
	
	numerics[NumLength + 1][3] = "Position (Coef.)"
	numerics[NumLength + 2][3] = "Effective Position"
	
	numerics[NumLength + 1][5] = "Width (Coef.)"
	numerics[NumLength + 2][5] = "Effective Width"

	numerics[NumLength + 1][7] = "Gauss-Lorentz Ratio"
	
	numerics[NumLength + 1][9] = "Asymmetry (coef)"
	numerics[NumLength + 2][9] = "Effective Asymmetry:"
	numerics[NumLength + 3][9] = "1 - (fwhm_right)/(fwhm_left):"
	 
	 numerics[NumLength + 1][11] = "Asymmetry translation (coef)"
	
	
	FancyUp("foe")
	setup2Waves()	
end

/// 2  ////////////////////////////////////////////////////////////
///////////////   Display it in the peak fitting window ///////////////////////////////////////////////

static function PlotPseudoVoigtSKDisplay(peakType,RawYWave, RawXWave,coefWave)
	string peakType
	string RawYWave
	string RawXWave
	string coefWave
	string TagName    // the Tag in the result window
	string PeakTag     // text in this tag
	string PkName, parentDataFolder //, cleanUpString=""		
	string BGName //background
	string PeakSumName
	NVAR FitMin = root:STFitAssVar:STFitMin
	NVAR FitMax = root:STFitAssVar:STFitMax
	string fitWaveName = "fit_"+RawYWave
	wave cwave = $coefWave
	wave raw = $RawYWave
	wave fitWave =$fitWaveName
//	wave xraw = $RawXWave
	variable LenCoefWave = DimSize(cwave,0)
	
	//create some waves, to display the peak
	variable nPeaks = 0
	variable numCoef
	variable i,index,k
	variable xmin, xmax, step
	variable TagPosition   //the position of the tag in the result window
	variable totalPeakSumArea, partialPeakSumArea
	 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate  		
			//duplicate /o  raw WorkingDuplicate                       
			break
		case "_calculated_":
			 duplicate /o /R=(FitMin,FitMax) raw WorkingDuplicate
			break
		default:                                                 // if not empty, x-axis wave necessary
			//read in the start x-value and the step size from the x-axis wave
			wave xraw = $RawXWave
			xmax = max(xraw[0],xraw[numpnts(xraw)-1] )
			xmin = min(xraw[0],xraw[numpnts(xraw)-1] )
			step = (xmax - xmin ) / DimSize(xraw,0)
			// now change the scaling of the y-wave duplicate, so it gets equivalent to a data-wave imported from an igor-text file
			duplicate /o raw tempWaveForCutting  
			SetScale /I x, xmin, xmax, tempWaveForCutting  //OKAY, NOW THE SCALING IS ON THE ENTIRE RANGE
			duplicate /o /R=(FitMin,FitMax) tempWaveForCutting WorkingDuplicate  
			killwaves /z tempWaveForCutting
			break
	endswitch
	
	parentDataFolder = GetDataFolder(1)
	
	
	//now make tabular rasa in the case of background functions
	string ListOfCurves = TraceNameList("CursorPanel#guiCursorDisplayFit",";",1)
	variable numberCurves = ItemsInList(ListOfCurves)
	//remove only the very last curve, if there are e.g. 3 curves on the graph it has the index #2
	
	// If a wave is given which needs an external x-axis (from an ASCII-file) create a duplicate which receives a proper x-scaling later on
	// the original wave will not be changed
	KillDataFolder /z :Peaks  //if it exists from a previous run, kill it
	//now recreate it, so everything is updated             
	NewDataFolder /O /S :Peaks
//franz
 	numCoef = 6   //Voigt with Shirley and Slope 
	nPeaks = (LenCoefWave-5)/numCoef
	
	PeakSumName = "pS_"+RawYWave
			
	duplicate /o WorkingDuplicate $PeakSumName
	wave tempSumDisplay = $PeakSumName
			
			
	//update the graph, remove everything	
	for (i =1; i<numberCurves; i +=1)
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z $"#"+num2istr(numberCurves-i)
	endfor
	
	tempSumDisplay = 0
	variable areaPeak=0
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i + 5
		PkName = "p" + num2istr(i+1) + "_" + RawYWave  //make a proper name
	 	//create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
		duplicate /o WorkingDuplicate $PkName	

		wave tempDisplay = $PkName                                            

		 //overwrite the original values in the wave with the values of a single peak
		tempDisplay = CalcSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)	
		areaPeak = IntegrateSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
		tempDisplay /= areaPeak
		tempDisplay *= cwave[index]
		
		tempSumDisplay += tempDisplay
		RemoveFromGraph /W=CursorPanel#guiCursorDisplayFit /Z  $PkName#0
		AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempDisplay                           //now plot it
		
		WaveStats /Q tempDisplay
		tagName = PkName+num2istr(i)
		PeakTag = num2istr(i+1)
		TagPosition = V_maxloc
		
		Tag /w= CursorPanel#guiCursorDisplayFit /C /N= $tagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag
		ModifyGraph /w= CursorPanel#guiCursorDisplayFit rgb($PkName)=(0,0,0)       // and color-code it	
	endfor
	//get the sum of all peaks and (i) calculate the Shirley, (ii) calculate the line offset and (iii) display the background and the individual sums of peak + Background
	BGName ="bg_"+ RawYWave ///should name the background accordingly
	
	duplicate /o WorkingDuplicate $BGName
	wave tempBGDisplay = $BGName //this is the wave to keep the background
	
	duplicate /o WorkingDuplicate HGB
	wave hgb = HGB
	
	// now calculate the background with tempSumDisplay
	totalPeakSumArea = sum(tempSumDisplay)
	//print totalPeakSumArea
	partialPeakSumArea = 0
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))    //x decreases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[i]
			tempBGDisplay[i] =partialPeakSumArea/totalPeakSumArea 
		endfor
	else //x increases with index
		for ( i = 0; i < numpnts(tempSumDisplay); i+=1)
			partialPeakSumArea += tempSumDisplay[numpnts(tempSumDisplay) -1 - i]
			tempBGDisplay[numpnts(tempSumDisplay) -1 - i] =partialPeakSumArea/totalPeakSumArea 
		endfor
	endif
			
	//now add the Herrera-Gomez background
	partialPeakSumArea = 0
	totalPeakSumArea = sum(tempBGDisplay)
	if (pnt2x(WorkingDuplicate,0) < pnt2x(WorkingDuplicate,1))   //binding energy increases with point index
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[i])
			hgb[i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	else                     //binding energy decreases with point index   //I'm here with the synchrotron spectra
		for ( i = 0; i < numpnts(tempSumDisplay); i += 1)
			partialPeakSumArea += abs(tempBGDisplay[numpnts(tempSumDisplay)-1-i])
			hgb[numpnts(tempSumDisplay)-1-i] = partialPeakSumArea/totalPeakSumArea	
		endfor
	endif
	hgb *= cwave[3]	
			
	tempBGDisplay *= cwave[4]  //shirley height
	tempBGDisplay += hgb
//	Killwaves /z temporaryShirleyWave
	
//	for (i =0; i<nPeaks;i+=1)
//		index = numCoef*i + 5
//		tempBGDisplay += 1e-3*cwave[3]*cwave[index]*( x - cwave[index+1] )^2 * ( x > cwave[index+1] ) 
//	endfor
			
	tempBGDisplay += cwave[0] + cwave[1]*x + cwave[2]*x^2
	
	AppendToGraph /w= CursorPanel#guiCursorDisplayFit tempBGDisplay 
		
	//now add the background to all peaks
	for (i =0; i<nPeaks;i+=1)
		index = numCoef*i
		PkName = "p" + num2istr(i+1) + "_"+RawYWave   //make a propper name
		wave tempDisplay = $PkName        //This needs some explanation, see commentary at the end of the file                                        
		
		 //overwrite the original values in the wave with the values of a single peak
		tempDisplay  += tempBGDisplay
	endfor
		
	tempSumDisplay += tempBGDisplay
	//for now, don't use tempSumDisplay, however, leave it in the code for possible future use
	killwaves /z tempSumDisplay   //remove this line, if the sum of the peaks is going to be used again
	killwaves /z HGB
	WaveStats /Q WorkingDuplicate
//	SetAxis /w = CursorPanel#guiCursorDisplayFit left -0.1*V_max, 1.1*V_max
	ModifyGraph /w= CursorPanel#guiCursorDisplayFit zero(left)=2 
	SetAxis/A/R /w = CursorPanel#guiCursorDisplayFit bottom
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(left)=2
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit mirror(bottom)=2
	Label  /w = CursorPanel#guiCursorDisplayFit Bottom "\\f01 binding energy (eV)"
	ModifyGraph  /w = CursorPanel#guiCursorDisplayFit minor(bottom)=1,sep(bottom)=2
	SetDataFolder parentDataFolder 
	killwaves /Z WorkingDuplicate
end




///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////

static function DrawAndEvaluatePseudoVoigtSK(dataWave,fitWave,peakType,RawXWave,newFolder)
string dataWave
string fitWave
string peakType
string RawXWave
variable newFolder               //if this value is different from 1, no folder for the results will be created
SVAR projectName = root:STFitAssVar:ProjectName


wave cwave = W_coef
wave origWave = $dataWave
wave fitted = $fitWave
wave epsilon = epsilon
wave hold = hold
wave InitializeCoef = InitializeCoef
wave Min_Limit = Min_Limit
wave Max_Limit = Max_Limit
wave T_Constraints = T_Constraints
wave  CoefLegend = CoefLegend

if ( strlen(fitWave) >= 30)	
	doalert 0, "The name of the fit-wave is too long! Please shorten the names."
	return -1
endif


//define further local variables
variable LenCoefWave = DimSize(cwave,0)	
variable nPeaks
variable index
variable i =0                               //general counting variable
variable numCoef                       //variable to keep the number of coefficients of the selected peak type
							  // numCoef = 3   for Gauss Singlet     and numCoef =5 for VoigtGLS
variable pointLength, totalArea, partialArea
variable peakMax 
variable TagPosition
variable AnalyticalArea
variable EffectiveFWHM
variable GeneralAsymmetry        //  = 1 - (fwhm_right)/(fwhm_left)

string PkName                          //string to keep the name of a single peak wave
string foldername                       //string to keep the name of the datafolder, which is created later on for the single peak waves
string tempFoldername               //help-string to avoid naming conflicts
string parentDataFolder
string TagName
string PeakTag
string LastGraphName
string NotebookName = "Report"     //this is the initial notebook name, it is changed afterwards
string tempNotebookName
string tempString                          // for a formated output to the notebook
string BGName
//The following switch construct is necessary in order to plot waveform data (usually from igor-text files , *.itx) as well as
//raw spectra which need an extra x-axis (such data come usually from an x-y ASCII file)

strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
	case "":                                             //if empty
		display /K=1 origWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
		break
	case "_calculated_":
		display /K=1 origWave
		break
	default:
		wave xraw = $RawXWave                                                 // if not empty
		display /K=1 origWave vs xraw        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
endswitch
ModifyGraph mode($dataWave)=3,msize($dataWave)=1.3, marker($dataWave)=8
ModifyGraph mrkThick($dataWave)=0.7
ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
    
LastGraphName = WinList("*", "", "WIN:")    //get the name of the graph

//check if this Notebook already exists
V_Flag = 0
DoWindow $NotebookName   
// if yes, construct a new name
if (V_Flag)
	i = 1
	do 
		tempNoteBookName = NotebookName + num2istr(i)
		DoWindow $tempNotebookName
		i += 1
	while (V_Flag)
	NotebookName = tempNotebookName 
endif
//if not, just proceed

NewNotebook /F=1 /K=1 /N=$NotebookName      //make a new notebook to hold the fit report
Notebook $NoteBookName ,fsize=8
//Notebook $NoteBookName ,text="\r\r \t\t --- if necessary, insert plot by copy and paste ----    "
Notebook $NoteBookName ,text="\r\r\rPeak Shape:    "+ peakType

//prepare a new datafolder for the fitting results, in particular the single peaks
parentDataFolder = GetDataFolder(1)    //get the name of the current data folder

if (newFolder == 1)
	NewDataFolder /O /S subfolder
	//now, this folder is the actual data folder, all writing is done here and not in root
endif

duplicate /o fitted tempFitWave
wave locRefTempFit = tempFitWave
locRefTempFit = 0

//strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
//	case "":                                             //if empty
//		 sprintf  tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  area(origWave)           
//		break
//	case "_calculated_":
//		sprintf tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  area(origWave)
//		break
//	default:                                                 // if not empty
//		sprintf tempString, "\r\rIntegral area of the raw spectrum (wave area): %20.2f " ,  areaXY(xraw,origWave)
//		break
//endswitch
//Notebook $NoteBookName ,text=tempString

//take the fit-result and analyze the maximum, get the maximum signal, so a significance threshold can be calculated
//WaveStats /Q fitted
//peakMax = V_max

//now decompose the fit into single peaks --- if a further fit static function is added, a further "case" has to be attached

		numCoef = 6
		nPeaks = (LenCoefWave-5)/numCoef         //get the number of  peaks from the output wave of the fit
		//check, if the peak type matches the length of the coefficient wave
		//if not so, clean up, inform and exit
		BGName = "PS_bg" +"_" + dataWave 
		duplicate /o fitted $BGName
		wave background = $BGName
		
		duplicate /o fitted HGB
		wave hgb = HGB
		AppendToGraph background
		
		if (mod(LenCoefWave-5,numCoef) != 0)
			DoAlert 0, "Mismatch, probably wrong peak type selected or wrong coefficient file, check your fit and peak type "
			SetDataFolder parentDataFolder 
			KillDataFolder  /Z subfolder
			print " ******* Peak type mismatch - check your fit and peak type ******"
			return 1
		endif 
		
		Notebook $NoteBookName ,text="\r\r\r"
		
		variable areaPeak = 0
		variable sumCoef = 0
		for (i =0; i<nPeaks;i+=1)
			index = numCoef*i + 5
			PkName = "p" + num2istr(i+1)+"_" + dataWave    //make a proper name
			 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
			duplicate /o fitted $PkName
							
			wave W = $PkName        //This needs some explanation, see commentary at the end of the file                                        
			 
			 //overwrite the original values in the wave with the values of a single peak
			W =  CalcSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
			areaPeak= IntegrateSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
			W /= areaPeak
			W *= cwave[index]
			sumCoef += cwave[index]
			locRefTempFit += W         
			
			AppendToGraph W                                                    //now plot it

			//append the peak-tags to the graph, let the arrow point to a maximum
			//append the peak-tags to the graph, let the arrow point to a maximum
			WaveStats /Q W                             // get the location of the maximum
			TagName = "tag"+num2istr(i)           //each tag has to have a name
			PeakTag = num2istr(i+1)                 // The tag displays the peak index
			TagPosition = V_maxloc                 // and is located at the maximum
			Tag  /C /N= $TagName  /F=0 /L=1  /Y =2.0  $PkName, TagPosition ,PeakTag    // Now put the tag there
			
			ModifyGraph rgb($PkName)=(10464,10464,10464)              // color code the peak
				
			//AnalyticalArea =  IntegrateSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
			
			EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
			GeneralAsymmetry = CalcGeneralAsymmetry(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])   
			
			//sprintf  tempString, "\r\r %1g	Area                                   |  Position |  FWHM   | GL-ratio  |   Asym.   | Asym. S. |\r",(i+1)
			sprintf  tempString, "\r Peak %1g	  Area\t|\tPosition\t|\tFWHM\t|\tGL-ratio\t|\tAsym.\t|\tAsym. Shift\t\r",(i+1)
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "\t%s\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t|\t%8.2f\t\r" , STnum2str(cwave[index]), cwave[index+1] ,cwave[index+2] ,cwave[index+3] , cwave[index+4],cwave[index+5]
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "\rEffective maximum position\t\t\t\t%8.2f \r", V_maxloc  // "-> In case of asymmetry, this value does not represent an area any more"
			Notebook $NoteBookName ,text=tempString
			sprintf  tempString, "Effective FWHM\t\t\t\t\t%8.2f \r"	EffectiveFWHM	
			Notebook $NoteBookName ,text=tempString
			sprintf tempString, "Effective Asymmetry = 1 - (fwhm_right)/(fwhm_left)\t\t%8.2f \r\r\r\r" ,GeneralAsymmetry
			Notebook $NoteBookName ,text=tempString	
		endfor
		
		sprintf  tempString, "Total area of all peaks\r-------------------------------------\r  %s  \t\t(sum of fit coefficients - usually larger than visible area within measurement window) \r\r",  STnum2str(sumCoef)
		Notebook $NoteBookName ,text=tempString
		
		
		
		//and now, add the background
		pointLength = numpnts(locRefTempFit)
		totalArea = sum(locRefTempFit)
		partialArea = 0
		
		//distinguish between ascending and descending order of the points in the raw-data wave
		if (pnt2x(locRefTempFit,0) > pnt2x(locRefTempFit,1))   //with increasing index, x decreases
			for (i=pointLength-1; i ==0; i -=1)	
				partialArea += abs(locRefTempFit[i]) 
		
				background[i] = partialArea/totalArea

			endfor
			//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = pointLength; i == 0; i -= 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			background *= cwave[4]
			background += hgb
			//for (i =0; i<nPeaks;i+=1)
			//	index = numCoef*i + 5
		//		background += 1e-3*cwave[3]*cwave[index] * ( x - cwave[index + 1])^2 * ( x > cwave[index+1])
		//	endfor
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
		else
			for (i=0; i<pointLength; i += 1)
					partialArea += abs(locRefTempFit[i]) 
					background[i] =partialArea/totalArea 
			endfor
				//now add the Herrera-Gomez background
			partialArea = 0
			totalArea = sum(background)
			for ( i = 0; i < pointLength; i += 1)
				partialArea += abs(background[i])
				hgb[i] = partialArea/totalArea	
			endfor
			hgb *= cwave[3]
			
			
			background *= cwave[4]
			background += hgb
			background += cwave[0] + cwave[1]*x + cwave[2]*x^2
			
		endif
		//now, everything should be fine with the background .... carry on
		
		locRefTempFit += background
		
		
		tempString = "\r\r\rFurther Details\r"
		Notebook $NoteBookName ,text=tempString
		tempString = "==================================================================================================="
		Notebook $NoteBookName ,text=tempString
		strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
			case "":                                             //if empty
				 sprintf  tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))           
			break
			case "_calculated_":
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(area(origWave))
			break
			default:                                                 // if not empty
				sprintf tempString, "\r\rArea of the raw spectrum:\t\t\t\t%s \r" ,  STnum2str(areaXY(xraw,origWave))
				break
		endswitch
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "Total area of all peaks in measurement window:\t\t%s \r" STnum2str(area(locRefTempFit) - area(background))
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "Area of the background in measurement window:\t\t%s \r", STnum2str(area(background) ) 
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\rYou used a simultaneous fit of background  and signal: MAKE SURE the background shape makes sense.\r" 
		Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, "For details on the \r -- Peak shape:  Surface and Interface Analysis (2014), 46, 505 - 511  (If you use this program, please read and cite this paper) \r" 
		//Notebook $NoteBookName ,text=tempString
		//sprintf  tempString, " -- 'Pseudo-Tougaard' and Shirley contribution to the background:  J. Elec. Spectrosc. Rel. Phen (2013), 189, 76 - 80\r" 
		//Notebook $NoteBookName ,text=tempString
		sprintf tempString,"\rPlease note that for asymmetric peaks the fit coefficients for position and FWHM are merely coefficients. \rIn this case, refer to the respective 'effective' values.\r"      
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rBackground\r==================================\rThe background is calculated as follows:  Offset + a*x + b*x^2 + c * (pseudo-tougaard) + d * shirley\r" 
		Notebook $NoteBookName ,text=tempString
		sprintf  tempString, "\r(Here:  Offset=%8.2g;      a =%8.2g;      b =%8.2g;   c =%8.4g;   d =%8.2g; ) \r", cwave[0], cwave[1], cwave[2], cwave[3], cwave[4]
		Notebook $NoteBookName ,text=tempString
		
		sprintf  tempString, "\rThe parameters a and b  serve to cover general slopes or curvatures in the background, for example if the peak sits on a complex mixture of  broad Auger lines or plasmons.\r" 
		Notebook $NoteBookName ,text=tempString
		
		sprintf tempString, "\rPeak Areas\r==================================\rThe peak area is obtained by integrating the peak on an interval of +/- 90*FWHM around the peak position"
		Notebook $NoteBookName ,text=tempString
	//	sprintf  tempString,"\r'Fit wave area':     Peak area within the measured energy range"
	//	Notebook $NoteBookName ,text=tempString																			    
		sprintf tempString, "\rThis value is generally somewhat larger than the visible peak area within the limited measurement window."
		Notebook $NoteBookName ,text=tempString
		
		for (i =0; i<nPeaks;i+=1)
			PkName = "p" + num2istr(i+1)+"_" + dataWave    					
			wave W = $PkName       
			W += background			
		endfor
		

//killwaves /z  fitted     //this applies to the original fit-wave of Igor, since it is a reference to the wave root:Igor-FitWave, the original wave is possibly wrong
//duplicate /o locRefTempFit, $fitWave               //but we are still in the subfolder, 
//killwaves /z locRefTempFit
//wave fitted = $fitWave


	SetDataFolder parentDataFolder 

	//create a copy of the coefficient wave in the subfolder, so the waves 
	//and the complete fitting results are within that folder
	duplicate /o :$dataWave, :subfolder:$dataWave
	//if (WaveExists($RawXWave))
	if (Exists(RawXWave))
		duplicate /o :$RawXWave, :subfolder:$RawXWave
	endif

	//duplicate  :$fitWave, :subfolder:$fitWave
//	killwaves /z :$fitWave            //probably fails, if the fit wave is displayed in the main panel as well
	duplicate /o $fitWave :subfolder:$fitWave
	AppendToGraph :subfolder:$fitWave                                //draw the complete fit
	ModifyGraph rgb($fitWave) = (0,0,0)       //color-code it
	//Remove the original wave, which is located in the parent directory and replace it by the copy in the subfolder
	RemoveFromGraph $"#0" 
	strswitch(RawXWave)                                //have a look at the string with the name of the x-axis wave
		case "":                                             //if empty
			AppendToGraph :subfolder:$dataWave                 //the raw-data wave is in true waveform and has an intrinsic scale                     
			break
		case "_calculated_":
			AppendToGraph  :subfolder:$dataWave
			break
		default:                                                 // if not empty
			AppendToGraph :subfolder:$dataWave vs :subfolder:$RawXWave        // the raw-data wave has no intrinsic scale and needs a propper x-axis 
		break
	endswitch

	foldername = "Report_" + dataWave
	
	//foldername ="Fit_"+ dataWave
	i=1   //index variable for the data folder	
	            //used also for the notebook
	V_Flag = 0
	DoWindow $folderName
	tempFoldername = foldername
	
	if (V_Flag)    //is there already a folder with this name
		do
			V_Flag = 0
			tempFoldername = foldername + "_" + num2istr(i)
			DoWindow $tempFolderName
			i+=1
		while(V_Flag)
		
		if ( strlen(tempFoldername) >= 30)	
			//doalert 0, "The output folder name is too long! Please shorten the names. The output folder of the current run is named 'subfolder'."
			string NewName = ""
			
			Prompt NewName, "The wave name is too long, please provide a shorter name "		// Set prompt for y param
			DoPrompt "Shorten the name", NewName
			if (V_Flag)
				return -1								// User canceled
			endif	
			tempFolderName = NewName	
		else
			RenameDataFolder subfolder, $tempFoldername                   //now rename the peak-folder accordingly
			Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST(2015)"//\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
			//remove illegal characters from the string
			tempFoldername = stringClean(tempFoldername)
			DoWindow /C $tempFoldername
			DoWindow /F $LastGraphName
			DoWindow /C $tempFoldername + "_graph"
			//DoWindow /C /W=$LastGraphName $tempFoldername + "_graph"   //valid in Igor 6.x
		endif
		//TextBox/N=text0/A=LT tempFoldername        //prints into the graph
	else 
		//no datafolder of this name exist
		RenameDataFolder subfolder, $foldername 
		//TagWindow(foldername)
		Notebook  $NoteBookName, text="\r\r===================================================================================================\rXPST (2015)" //\t\t\t\t\tSurface and Interface Analysis (2014), 46, 505 - 511"
		//if ( strsearch(foldername,".",0) != -1 )      // strsearch returns -1 if  the string contains no "." 
		//	foldername = ReplaceString(".", foldername,"_")
		//endif
		foldername = stringClean(foldername)
		tempFoldername = stringClean(tempFoldername)
		DoWindow /C $foldername
		DoWindow /F $LastGraphName
		DoWindow /C $tempFoldername + "_graph"
	endif

//make the graph look good
ModifyGraph mode($dataWave)=3 ,msize($dataWave)=1.3 // ,marker($dataWave)=8, opaque($dataWave)=1
ModifyGraph opaque=1,marker($dataWave)=19
ModifyGraph rgb($dataWave)=(60928,60928,60928)
ModifyGraph useMrkStrokeRGB($dataWave)=1
ModifyGraph mrkStrokeRGB($dataWave)=(0,0,0)
//ModifyGraph mrkThick($dataWave)=0.7
//ModifyGraph rgb($dataWave)=(0,0,0)           //color-code it
ModifyGraph mirror=2,minor(bottom)=1
Label left "\\f01 intensity (counts)"
Label bottom "\\f01  binding energy (eV)"	
ModifyGraph width=255.118,height=157.465, standoff = 0, gfSize=11

//The following command works easily, but then the resulting graph is not displayed properly in the notebook
//SetAxis/A/R bottom
//instead do it like this:
variable left,right

strswitch(RawXWave)
	 	case "":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	case "_calculated_":
	 		 left = max(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 		 right = min(leftx($dataWave),pnt2x($dataWave, numpnts($dataWave)-1))
	 	break
	 	default:
	 		waveStats /Q $RawXWave
	 		left = V_max
	 		right = V_min
	 	break
 endswitch
 SetAxis bottom left,right
//okay this is not perfectly elegant ... but

WaveStats /Q $dataWave
SetAxis left V_min-0.05*(V_max-V_min), 1.02*V_max
LastGraphName = WinList("*", "", "WIN:")

Notebook  $tempFoldername, selection = {startOfFile,startOfFile}

tempString = "\rReport for fitting project: \t\t " + projectName + "\r"
Notebook  $tempFoldername, text=tempString
Notebook  $tempFoldername, selection = {startOfPrevParagraph,endOfPrevParagraph}, fsize = 12, fstyle = 0

tempString = "\r==================================================================================================="
Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}, text=tempString
Notebook $tempFolderName ,selection = {startOfNextParagraph,startOfNextParagraph}, text="Saved in:\t\t\t\t\t" + IgorInfo(1) + ".pxp \r"
Notebook $tempFolderName ,text="Spectrum:\t\t\t\t" +dataWave
Notebook $tempFolderName ,text="\rApplied peak shape:\t\t\t"+ peakType +"\r\r"

Notebook  $tempFoldername, selection = {startOfNextParagraph,endOfNextParagraph}
Notebook  $tempFoldername, picture={$LastGraphName, 0, 1} , text="\r\r\r" 




//Notebook  $tempFoldername, selection = {startOfFile,startOfFile}
//tempString = "Fitting results for: " + tempFoldername + "\r"
//Notebook  $tempFoldername, text=tempString
//Notebook  $tempFoldername, selection = {startOfPrevParagraph,endOfPrevParagraph}, fsize = 12, fstyle = 0

//Notebook  $tempFoldername, selection = {startOfNextParagraph,startOfNextParagraph}
//Notebook  $tempFoldername, picture={$LastGraphName, 0, 1} , text="\r" 

killwaves /z hgb
KillWindow $LastGraphName
//Notebook  $tempFoldername, text="\r \r"  

KillDataFolder /z tempFoldername

//now clean up
killvariables  /Z V_chisq, V_numNaNs, V_numINFs, V_npnts, V_nterms,V_nheld,V_startRow, V_Rab, V_Pr
killvariables  /Z V_endRow, V_startCol, V_endCol, V_startLayer, V_endLayer, V_startChunk, V_endChunk, V_siga, V_sigb,V_q,VPr

end





static function EvaluateSingletSK()

wave cwave = W_Coef /// hard-coded but what the hell....

wave /t output = Numerics    //here we write the results
variable AnalyticalArea = 0
variable EffectiveFWHM = 0
variable GeneralAsymmetry = 0

variable i,j,k,index, index2
variable numpeaks
variable numCoef = 6

variable lengthCoef = numpnts(cwave)
variable lengthNumerics = DimSize(output,0)
string parentFolder = ""
string item = ""
numpeaks = (lengthCoef-5)/6
variable EffectiveArea,EffectivePosition
string wavesInDataFolder = WaveList("*fit_*",";","DIMS:1")
wave fitted = $StringFromList(0,wavesInDataFolder)
variable areaW
string FormatString
variable areaPeak
for ( i = 0; i < numPeaks; i += 1 )
	index = 6*i + 5
	//this static function also needs to analyze the waves to get the effective position etc.
	 //create a wave with this name and the correct  scaling and number of datapoints -> copy the fitted wave
	duplicate /o fitted tempForAnalysis
							
	wave W = tempForAnalysis
	 //overwrite the original values in the wave with the values of a single peak
	W =  CalcSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5],x)
	areaPeak= IntegrateSingleVoigtGLS(1,cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	W /= areaPeak
	W *= cwave[index]
	WaveStats/Q W
	areaW=area(W)
	//AnalyticalArea =  IntegrateSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	//print AnalyticalArea
	EffectiveFWHM = CalcFWHMSingleVoigtGLS(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])
	//print EffectiveFWHM
	GeneralAsymmetry = CalcGeneralAsymmetry(cwave[index],cwave[index+1],cwave[index+2],cwave[index+3],cwave[index+4],cwave[index+5])   
	//print GeneralAsymmetry
	//Now write the results to Numerics

	index2 = 4*i
	
	output[index2+1][2] = MyNum2str(cwave[index])
	output[index2+2][2] = ""//MyNum2str(areaW)
	output[index2+2][1] = ""
	output[index2+3][2] = ""//MyNum2str(AnalyticalArea)
	output[index2+3][1] = ""
	
	output[index2+1][4] = MyNum2str(cwave[index+1])
	output[index2+2][4] = MyNum2str(V_maxloc)
	
	output[index2+1][6] = MyNum2str(cwave[index+2])
	output[index2+2][6] = MyNum2str(EffectiveFWHM)
	
	output[index2+1][8] = MyNum2str(cwave[index+3])
	
	output[index2+1][10]=MyNum2str(cwave[index+4])
	sprintf  FormatString, "%10.3 f " GeneralAsymmetry 
	output[index2+2][10] =FormatString

	output[index2+1][12] = MyNum2str(cwave[index+5])
	
	killwaves /Z W
endfor

end

//// MISC functions

//used for a correct display of numbers by some functions
// num2str substitutes
static function /s STnum2str(value)
	variable value
	variable digits
	string output
	
	if (abs(value) <= 1 )
		sprintf output,  "%.4 g  " value
	elseif ( abs(value) <= 10 && abs(value) > 1)
		sprintf output,  "%6.3 f " value
	elseif (abs(value) > 10 && abs(value)<100000)
		sprintf output,  "%8.2 f " value
	elseif (abs(value) >= 100000)
		sprintf output,  "%g " value
	endif
	
	return output
end


static function /t MyNum2str(value)
	variable value
	string message

	if (value==0)
		return "0"
	endif
	
	if (abs(value) < 0.1 || abs(value) > 1e4 )
		sprintf message, "%.4e", value 
	elseif (floor(log(abs(value)))==0 || floor(log(abs(value)))==-1  )
		sprintf message, "%.3f", value 
	elseif (floor(log(abs(value)))==1)
		sprintf message, "%.3f", value 
	elseif (floor(log(abs(value)))==2)
		sprintf message, "%.2f", value 
	else
		sprintf message, "%.2f", value   
	endif
	message = UnPadString(message,0x30)
	message = UnPadString(message,0x2b)
	message = UnPadString(message,0x65)
	message = UnPadString(message,0x30)
	message = UnPadString(message,0x2e)
	
	return message
end


// this replaces num2str for cases where higher accuracy is needed  
static function /t MyNum2strEH(value)
	variable value
	string message
	variable exponent 

	
	if (value==0)
		return "0"
	endif
	
	if (abs(value) < 0.1 || abs(value) > 1e4 )
		sprintf message, "%.5e", value 
	elseif (floor(log(abs(value)))==0 || floor(log(abs(value)))==-1  )
		sprintf message, "%.4f", value 
	elseif (floor(log(abs(value)))==1)
		sprintf message, "%.4f", value 
	elseif (floor(log(abs(value)))==2)
		sprintf message, "%.4f", value 
	else
		sprintf message, "%.4f", value   
	endif
	
	message = UnPadString(message,0x30)
	message = UnPadString(message,0x2b)
	message = UnPadString(message,0x65)
	message = UnPadString(message,0x30)
	message = UnPadString(message,0x2e)
	
	// out: 14.4.18
	//	exponent = (value ? floor(log(abs(value))):0) //if value is zero, set exponent to zero too
	//	
	//	string formatString = ""
	//	
	//	string prefix ="%."
	//	
	//	sprintf formatString, "%d", min(12,abs(min(exponent-6,0))) //not more than 15 digits
	//	
	//	formatString = prefix + formatString + "f"
	//	
	//	sprintf message, formatString, value 
	//	message = UnPadString(message,0x30)
	//	message = UnPadString(message,0x2e)
	return message
end



//////////////////////////////////////////// Pseudo regular expressions

//this is only necessary to be downwards-compatible to Igor 5.02
static function MyGrepString(testString,ListWithItemsToFind)
	string testString
	string ListWithItemsToFind
	variable found = 0
	variable numItems
	variable i
	numItems = ItemsInList(ListWithItemsToFind)
	string item
	for ( i = 0; i < numItems; i += 1)
		item = ""
		item = StringFromList(i,ListWithItemsToFind, ";")
		//now check if this is contained in testString
		item = "*"+item + "*"
		found = stringmatch(testString,item)
		if (found != 0)
			break
		endif
	endfor

	return found   //0 if not found, 1 if found  0 is returned only if nothing was found in the teststring
	
end
