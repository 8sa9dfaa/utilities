#pragma TextEncoding = "UTF-8"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
// 2018 改良用メモ
// - Data load までとそれ以降の処理(theta/tilt offset の区別とか)を分離して、別パネルを開くようにしよう。
// - ２回微分は今の所使わないでおいといた方が良いかも。代わりに curv. plot とか含めたパネル作っても良いが...
// - 現在見てる E-k map についての MDC/EDC plot は需要があるかもしれない。offsetとかの自動設定は難しいが。
// - CEmapの対称化はどうだろう？

//
// 2016/04/06
// 暇ができたので大型アップデート。SOLEIL(CASSIOPEE), UVSOR, DA30 それぞれのデータ形式に対応させた。
//
////////////////////////////////////////////////////////////////////////
//	ARPES 3D data (KE, theta_x, theta_y) 処理用マクロ (阪大　大坪)
//
//  - include "XX" ってファイルを全て Igor の user procedure 以下のどこかに保存しておくと自動読込
//  - 個人用だったので全体的にコメントがかなり少なめです。
//  - chunkloader (by Scienta) で読んだ後、コマンドラインで "ConvertSES()" を実行。その後 "ARPES"
//     メニューから "Make 2D cut @ CASSIOPEE" を実行すると 3D データ処理開始。以後の操作は直感
//     的にできるようにしてありますが、疑問点があれば大坪までご連絡ください。
////////////////////////////////////////////////////////////////////////
// 2014/01/22	v5
//		ちょっとだけ改良。KE初期値の自動判断とか、もう使ってない変数を消したりとか。

#pragma rtGlobals=1		// Use modern global access method.
#include "ARPES_1cutPanel"	// SES macro で出てくる 1 slice 毎のデータの処理。3D data にはあまり関係なし。
#include "MPanel_v4"			// 上述 1cutPanel で使うfunction/Proc。少しだけ 3D処理にも少しだけ使う？
#include "OpenHook_v5"		// txt データをドラッグ＆ドロップで読むためのマクロ。一応 SES/MBS 両方に対応...したはず。
#include "F1_Av7"			// 3D データ処理のfunction/Proc はだいたいここにあります。
#include "Others_v5"			// 雑多なマクロ群...だが、一部は3D処理でも使用。
#include "CL_simple"			// コアレベル解析用。
#include "GetEMDCon2Dwave"	//EMDC作成用

#include "DLoadPanel_v1"	//データロード用に独立したパネル関連
#include "DLoad_v2"	//新型データロードマクロ ver2 (ARPES v7 対応)
#include "chunkloader_oh_v2"	//新型データロードマクロ for DA30

//Menu "ARPES"
//	"Analyze 3D ARPES data", CE_Panel()//	for 3D data
//	"E vs k plot_1cut", Panel_ARPES()// for 2D data
//	"DataLoad Format Scienta txt", DLchange_SES()
//	"DataLoad Format MBS", DLchange_MBS()
//End

Menu "ARPES_v7.0"
	"Auto Data Load", DL_Panel()
	"3D ARPES analysis", CE_Panel_v7()
	"E vs k plot_ single cut", Panel_ARPES()// for 2D data
End



//ARPES, 3D処理用マクロのメインパネル。
Macro CE_Panel_v7()

Variable/G Default_Colordir	// カラースケールの方向。0: 通常, 1:逆方向
String/G Default_Color//"BlueHot"

if(strlen(Default_Color)==0)	//作りたての場合はデフォ値を入れる。
	Default_Colordir = 1	// カラースケールの方向。0: 通常, 1:逆方向
	Default_Color = "Grays"//"BlueHot"
endif

//Variable/G CBoxVal
//String/G Pup_CC="Grays"

Variable/G Eana_type
//　SOLEIL: 1, UVSOR: 2, DA: 3. アナライザのタイプ設定

	Variable/G KE, ofFlip ofTheta, phi, PhEn, WFunc, EF, Dwin, skip
//初回かどうかチェック。初回じゃない場合には過去パラメータ等を読み込む
	if(Exists("Reference")!=0)
		KE = Reference[0]	;	ofFlip = Reference[1];	ofTheta = Reference[2];	phi = Reference[3]
		PhEn = Reference[4]	;	WFunc = Reference[5];	EF = Reference[6];			Dwin = Reference[7]
		skip = Reference[8]

		CheckDisplayed/A EC_angle//; print V_flag
		if(V_flag != 1)
			NewImage/N=EC_deg EC_angle
			ModifyGraph zero=1
			ModifyGraph width={perUnit,10,top},height={perUnit,10,left}
			ModifyImage EC_angle ctab= {*,*,$Default_Color,Default_Colordir}
		endif
		dowindow/F EC_deg
	else
		if(DTypeLocal == 5)
			ThetaMake2()
		endif
		
		if(DTypeLocal == 4)
			M3Dw_Proc()
			SeekIniValues()
		else
			SeekIniValues()
			M3Dw_Proc()
		endif

		GetEC_angle(KE)
		duplicate/O EC_angle EC_angle_noOF
		NewImage/N=EC_deg EC_angle
		ModifyGraph zero=1
		ModifyGraph width={perUnit,10,top},height={perUnit,10,left}
		ModifyImage EC_angle ctab= {*,*,$Default_Color,Default_Colordir}
	endif	

	PauseUpdate; Silent 1		//building window...
	NewPanel/K=1/N=CE_v7/W=(900, 100, 1350, 260)
	ModifyPanel cbRGB=(45000, 65000, 45000)
	SetDrawLayer Userback
	SetDrawEnv fsize= 14,textxjust= 2,textyjust= 1, textrgb=(65000, 00000, 00000), save

	SetVariable KEval, pos={10, 10}, size={200, 20}, title="Kinetic energy (eV)", live = 1
	SetVariable KEval, fsize=12,value=KE, proc=KEchange, limits={-inf, inf, 0.02}
	SetVariable OFFval, pos={10, 35}, size={200, 20}, title="Tilt Offset (deg.)    ", live=1
	SetVariable OFFval, fsize=12,value=ofFlip, proc=TFoff, limits={-45, 45, 0.1}
	SetVariable OFTval, pos={10, 60}, size={200, 20}, title="Theta Offset (deg.)", live=1
	SetVariable OFTval, fsize=12,value=ofTheta, proc=TFoff, limits={-40, 40, 0.1}
		
	SetVariable HNval, pos={240, 10}, size={200, 20}, title="Photon energy (eV) ", live=1
	SetVariable HNval, fsize=12,value=PhEn, limits={7, 200, 0.1}
	SetVariable WFval, pos={240, 35}, size={200, 20}, title="Work function (eV)  ", live=1
	SetVariable WFval, fsize=12,value=Wfunc, limits={1, 10, 0.1}
	SetVariable EFval, pos={240, 60}, size={200, 20}, title="Fermi energy (eV)   ", live=1
	SetVariable EFval, fsize=12,value=EF, limits={-1, 200, 0.1}

	Button MakeKxyCEb, pos={30,90}, size={400,30}, proc=MakeKbutton, title="Convert to kxky/ Change Parameter", fsize=15

	PopupMenu CC_pop, pos={10, 130}, size={200, 30}, title="Data Format", bodywidth = 120
	PopupMenu CC_pop, fsize=14,value= #"\"*COLORTABLEPOPNONAMES*\""//value=CtabList()
	PopUpMenu CC_pop, proc=PMenu_CC

	CheckBox CBox_CC, pos={220,130}, size={100,30}, title="Rev. Color?", value=Default_Colordir
	CheckBox CBox_CC, proc=CBox_CC, fsize = 12
	
	Button QuitCEPanel, pos={310,125}, size={120,30}, proc=QuitCE7, title="Quit", fsize = 18
EndMacro

Proc QuitCE7(ctrlName) : ButtonControl
	String ctrlName
	
	DoWindow/K CE_v7
	DoWindow/K Win_Kline
	DoWindow/K ECplot_Kxy
	DoWindow/K EC_deg
	DoWindow/K EvsK_map
	DoWindow/K ChunkLoaderControlPanel
	
	MakeRef()
End

Proc M3Dw_Proc()
	Variable/G Eana_type
	//　SOLEIL: 1, UVSOR: 2, DA: 3. アナライザのタイプ設定
	Variable/G KE

	Make3Dwave(Eana_type)
	
//	if(Eana_type == 3)
////print "AA"
////		setdatafolder root:tempdata	
////		DoWindow/K Win_CE_ver6
////		Variable iniE = DimOffset(scan3Draw,2), delE = DimDelta(scan3Draw,2), nE = DimSize(scan3Draw,2)
////		Variable/G KE, ofFlip ofTheta, phi, PhEn, WFunc, EF, Dwin, skip = 1
////		KE = iniE + delE * nE * 0.5	
////		PhEn = 21.22		// 3D scan を行うのは大抵 He I だろ、と予想
////		EF = 16.7
////		Wfunc = 4.5
////		Dwin = 10
//		seekinivalues()
//		if(PhEn < 22)
//			if(PhEn>20)
//			PhEn = 21.22
//			EF = 16.7
//			endif
//		endif
//		GetEC_angle(KE)
//		duplicate/O EC_angle EC_angle_noOF
//		CE_Panel()
//		skip = 0
////		abort
//	endif
	
End

Proc MakeRef()
	Variable/G KE, ofFlip ofTheta, phi, PhEn, WFunc, EF, Dwin, skip
	Make/N=9/O Reference
	Reference[0] = KE;		Reference[1] = ofFlip;	Reference[2] = ofTheta;	Reference[3] = phi
	Reference[4] = PhEn;	Reference[5] = WFunc;	Reference[6] = EF;			Reference[7] = Dwin
	Reference[8] = skip
End


////旧型(v6)
//Macro CE_Panell()
//
//Variable/G DataType=0
////初回かどうかチェック。初回じゃない場合には過去パラメータ等を読み込む
//	if(Exists("Data_Type")!=0)
//		DataType = Data_Type[0]
//	endif
////　SOLEIL: 0, UVSOR: 1, DA: 2
//	Variable/G KE, ofFlip ofTheta, phi, PhEn, WFunc, EF, Dwin, skip
//
//	if(Exists("Reference")!=0)
//		KE = Reference[0]	;	ofFlip = Reference[1];	ofTheta = Reference[2];	phi = Reference[3]
//		PhEn = Reference[4]	;	WFunc = Reference[5];	EF = Reference[6];			Dwin = Reference[7]
//		skip = Reference[8]
//	endif	
//
//	if(Exists("Scan3Draw")!=0)
//	if(skip ==0)
////		SeekIniValues()
//		CheckDisplayed/A EC_angle//; print V_flag
//		if(V_flag != 1)
//			NewImage/N=EC_deg EC_angle
//			ModifyGraph zero=1
//			ModifyGraph width={perUnit,10,top},height={perUnit,10,left}
////SetAxis/R left 3,-3
//		endif
//		dowindow/F EC_deg
//	endif
//	endif
//	
//
//	PauseUpdate; Silent 1		//building window...
//	NewPanel/K=1/N=Win_CE_ver6/W=(900, -50, 1350, 150)
//	ModifyPanel cbRGB=(65000, 65000, 55000)
//	SetDrawLayer Userback
//	SetDrawEnv fsize= 14,textxjust= 2,textyjust= 1, textrgb=(65000, 00000, 00000), save
//
//	PopupMenu DTypeP, pos={0, 10}, size={200, 30}, title="Data Format", bodywidth = 120
//	PopupMenu DTypeP, fsize=12,value="Choose Here;SOLEIL;UVSOR;DA30;PF2A (ibw);Others/I don't know", proc=PMenuControl
//	Button DLoadb, pos={10,35}, size={95,20}, proc=DataLoadP, title="Data Load!", fsize=12
//	Button M3Dwb, pos={110,35}, size={100,20}, proc=M3DwP, title="Make 3D wave", fsize=12
//
//	SetVariable KEval, pos={10, 60}, size={200, 20}, title="Kinetic energy (eV)", live = 1
//	SetVariable KEval, fsize=12,value=KE, proc=KEchange, limits={-inf, inf, 0.02}
//	SetVariable OFFval, pos={10, 85}, size={200, 20}, title="Tilt Offset (deg.)    ", live=1
//	SetVariable OFFval, fsize=12,value=ofFlip, proc=TFoff, limits={-45, 45, 0.1}
//	SetVariable OFTval, pos={10, 110}, size={200, 20}, title="Theta Offset (deg.)", live=1
//	SetVariable OFTval, fsize=12,value=ofTheta, proc=TFoff, limits={-40, 40, 0.1}
//		
//	SetVariable HNval, pos={240, 10}, size={200, 20}, title="Photon energy (eV) ", live=1
//	SetVariable HNval, fsize=12,value=PhEn, limits={7, 200, 0.1}
//	SetVariable WFval, pos={240, 35}, size={200, 20}, title="Work function (eV)  ", live=1
//	SetVariable WFval, fsize=12,value=Wfunc, limits={1, 10, 0.1}
//	SetVariable EFval, pos={240, 60}, size={200, 20}, title="Fermi energy (eV)   ", live=1
//	SetVariable EFval, fsize=12,value=EF, limits={-1, 200, 0.1}
//
//	Button MakeKxyCEb, pos={10,135}, size={200,20}, proc=MakeKbutton, title="Convert to kxky", fsize=12
//	Button ChangeKxyCEb, pos={240,85}, size={200,20}, proc=MakeKbutton, title="Change Parameter", fsize=12
//
////	Button MakeKEb, pos={10,240}, size={200,30}, proc=MakeKbutton, title="Make k", fsize = 15
////	SetVariable OFPval, pos={10, 200}, size={200, 30}, title="Phi for k (deg.)     "
////	SetVariable OFPval, fsize=14,value=Phi, proc=PhiChange, limits={-180, 180, 0.05}
////	Button MakeEk, pos = {240, 120}, size = {200,30}, proc= MakeEK, title = "Make E vs K", fsize = 15
//	SetVariable DifWval, pos={240,110}, size = {200,20}, title = "Diff. windowSize", fsize=12, value=Dwin, limits={1,inf,1}, live=1
//	Button Make2DEkb, pos = {240, 135}, size = {200,20}, proc= Make2DEk, title = "Make E vs K (2dif)", fsize = 12
//	
//	Button QuitCEPanel, pos={130,165}, size={200,30}, proc=QuitCE, title="Quit", fsize = 18
//EndMacro

Proc MakeKxyCE(ctrlName): ButtonControl
	String ctrlName
//	MakeKxyCE2()
	DetEdgeKx(EC_angle);	Variable/G VkMin, VkMax
	VkMin *= sqrt(PhEn-Wfunc-(EF-KE))/1.95; VkMax *= sqrt(PhEn-Wfunc-(EF-KE))/1.95
//print vkmin, vkmax
	KxyCEmake(PhEn, Wfunc, (EF-KE), 250,250, VkMin, VkMax)
	CheckDisplayed/A EC_kxy//; print V_flag
	if(V_flag != 1)
	NewImage/N=ECplot_Kxy EC_kxy
//ModifyGraph width={perUnit,400,top},height={perUnit,400,left}
ModifyGraph width={perUnit,150,top},height={perUnit,150,left}
//SetAxis/R left 3,-3
	endif
	dowindow/F ECplot_Kxy
	
	Variable/G Default_Colordir	// カラースケールの方向。0: 通常, 1:逆方向
	String/G Default_Color
	ModifyImage EC_kxy ctab= {*,*,$Default_Color,Default_Colordir}
	
	ModifyGraph width = 0, height = 0
End

Proc Make2DEk(ctrlName): ButtonControl
	String ctrlName
	
	Variable/G ik, fk, nk, ofFlip, ofTheta, PhEn, Wfunc, KE, EF, Phi, Dwin
//	KwMake(ik, fk, nk, phi)
	GetEKcut_2dif(ik, fk, nk, phi, -ofFlip, -ofTheta, PhEn, Wfunc, EF, Dwin)
//	PhiChange("",phi,"","")
	
//	Duplicate/O Vk BEvsK_
	DrawARPESMap(Vk_2dif, "EvsK_map_d2", "k\B//\M (Å\S-1\M)", "Binding energy (eV)", 200,100)
//	DrawARPESMap(Vk_2dif, "EvsK_map_d2", "k\B//\M (ﾅ\S-1\M)", "Binding energy (eV)", 150,200)
	ModifyGraph grid=2
	ModifyGraph width=0,height=0
EndMacro


Proc MakeEK(ctrlName): ButtonControl
	String ctrlName
	
	Variable/G ik, fk, nk, ofFlip, ofTheta, PhEn, Wfunc, KE, EF, Phi
//	KwMake(ik, fk, nk, phi)
	GetEKcut(ik, fk, nk, phi, -ofFlip, -ofTheta, PhEn, Wfunc, EF)
//	PhiChange("",phi,"","")
	
//	Duplicate/O Vk BEvsK_
//	DrawARPESMap(Vk, "EvsK_map", "k\B//\M (ﾅ\S-1\M)", "Binding energy (eV)", 200,100)
	DrawARPESMap(Vk, "EvsK_map", "\f02k\f00\B//\M (Å\S-1\M)", "Binding energy (eV)", 150,200)
	ModifyGraph grid=2
	ModifyGraph width=0,height=0
EndMacro

Proc PhiChange(ctrlName,varNum,varStr,varName) : SetVariableControl
String ctrlName
Variable varNum // value of variable as number
String varStr // value of variable as string
String varName // name of variable
	Variable/G ik, fk, nk, ofFlip, ofTheta, PhEn, Wfunc, KE, EF
	String str = "kw"
	KwMake(ik, fk, nk, varNum)
	MakeAw(0, 0, PhEn, Wfunc, KE, EF, $str)
//	MakeAw(ofFlip, ofTheta, PhEn, Wfunc, KE, EF, $str)
EndMacro


Proc MakeKbutton(ctrlName): ButtonControl
	String ctrlName
	 Kplot_Panel()
endMacro

//Proc MakeKbutton(ctrlName): ButtonControl
//	String ctrlName
//	
//	Variable/G ofTheta, ofFlip, PhEn, Wfunc, EF, KE
//	String str = "kw"
//	KwMakeM()
//	MakeAw(0, 0, PhEn, Wfunc, KE, EF, $str)
////	MakeAw(ofFlip, ofTheta, PhEn, Wfunc, KE, EF, $str)
//	AppendToGraph/T TiltW vs ThetaW
//Endmacro
//Proc KwMakeM(InitialK, FinalK, NumpntsK)
//	Variable InitialK, FinalK, NumpntsK
//	Variable/G phi
//	KwMake(InitialK, FinalK, NumpntsK, phi)
//	Variable/G ik = InitialK, fk=FinalK, nk=NumpntsK
//EndMacro

Proc TFoff(ctrlName,varNum,varStr,varName) : SetVariableControl
String ctrlName
Variable varNum // value of variable as number
String varStr // value of variable as string
String varName // name of variable

Variable/G ofFlip, ofTheta
Variable IniF, dF, IniT, dT
IniF = Dimoffset(EC_angle_noOf,1)+ofFlip; dF = DimDelta(EC_angle,1)
IniT = Dimoffset(EC_angle_noOf,0)+ofTheta; dT = DimDelta(EC_angle,0)
//Setscale/P x, IniT, dT, "Theta angle (deg.)", EC_angle
//Setscale/P y, IniF, dF, "Tilt angle (deg.)", EC_angle
Setscale/P x, IniT, dT, "Theta angle (deg.)", Scan3Draw
Setscale/P y, IniF, dF, "Tilt angle (deg.)", Scan3Draw
GetEC_angle(KE)

EndMacro

Proc KEchange(ctrlName,varNum,varStr,varName) : SetVariableControl
String ctrlName
Variable varNum // value of variable as number
String varStr // value of variable as string
String varName // name of variable
Variable/G ofFlip, ofTheta
	GetEC_angle(varNum)
//	GetEC_angle3(varNum, 0.1)
//	TFoff(ctrlName, varNum, varStr, varName)
EndMacro

Proc QuitCE(ctrlName) : ButtonControl
	String ctrlName
	
	Variable/G KE, ofFlip ofTheta, phi, PhEn, WFunc, EF, Dwin, skip
	Make/N=9/O Reference
	Reference[0] = KE;		Reference[1] = ofFlip;	Reference[2] = ofTheta;	Reference[3] = phi
	Reference[4] = PhEn;	Reference[5] = WFunc;	Reference[6] = EF;			Reference[7] = Dwin
	Reference[8] = skip
	
//	SetDataFolder root:
//	DoWindow/K ARPES_CE
	DoWindow/K Win_CE_ver6
	DoWindow/K Win_Kline
	DoWindow/K ECplot_Kxy
	DoWindow/K EC_deg
	DoWindow/K EvsK_map
	DoWindow/K ChunkLoaderControlPanel
End

Proc Dum(ctrlName) : ButtonControl
	String ctrlName
	
	Abort ("Not implemented yet. Sorry...")
End

Proc DumV(ctrlName,varNum,varStr,varName) : SetVariableControl
String ctrlName
Variable varNum // value of variable as number
String varStr // value of variable as string
String varName // name of variable
	
	Abort ("Not implemented yet. Sorry...")
End

Macro Kplot_Panel()

	if(Exists("Scan3Draw")==0)
		Abort("Make 3D wave at first.")
	endif

//	KE = EF
	GetEC_angle(KE)
	MakeKxyCE("")
//	dowindow/F EC_deg

	CheckDisplayed/A EC_Kxy//; print V_flag
	if(V_flag != 1)
	NewImage/N=ECplot_Kxy EC_kxy
	ModifyGraph zero=1
	ModifyGraph width={perUnit,300,top},height={perUnit,300,left}
//SetAxis/R left 3,-3
	endif
	dowindow/F ECplot_Kxy

	Variable/G KXX, KYY, KangV, KpntV = 401, Kinit = VkMin

	PauseUpdate; Silent 1		//building window...
	if(checkname("Win_Kline",9)==0)
		NewPanel/K=1/N=Win_Kline/W=(1100, 380, 1350, 460)
	else
		Dowindow/F Win_Kline
	endif
	ModifyPanel cbRGB=(65000, 65000, 65000)
	SetDrawLayer Userback
	SetDrawEnv fsize= 14,textxjust= 2,textyjust= 1, textrgb=(65000, 00000, 00000), save

//	SetVariable XPval, pos={10, 20}, size={200, 30}, title="kx (1/A)"
//	SetVariable XPval, fsize=14,value=KXX, proc=KlinePlot, limits={-inf, inf, 0.01}
//	SetVariable YPval, pos={10, 50}, size={200, 30}, title="ky (1/A)"
//	SetVariable YPval, fsize=14,value=KYY, proc=KlinePlot, limits={-inf, inf, 0.01}
	SetVariable AngPval, pos={10, 10}, size={200, 30}, title="Angle (deg.)"
	SetVariable AngPval, fsize=14,value=KangV, proc=KlinePlot, limits={-inf, inf, 0.5}
	SetVariable PntPval, pos={10, 40}, size={200, 30}, title="K points"
	SetVariable PntPval, fsize=14,value=KpntV, proc=KlinePlot, limits={5, inf, 5}
//	SetVariable KiniPval, pos={10, 140}, size={200, 30}, title="Initial k value (1/A)"
//	SetVariable KiniPval, fsize=14,value=Kinit, proc=KlinePlot, limits={-inf, inf, 0.05}
	
	KlinePlot("",0,"","")
	PlotWindowHook()
	movewindow/W=EvsK_map 400,50,700,300
	Variable/G Default_Colordir	// カラースケールの方向。0: 通常, 1:逆方向
	String/G Default_Color
	Dowindow/F EvsK_map
	ModifyImage Vk ctab= {*,*,$Default_Color,Default_Colordir}
EndMacro

Proc KlinePlot(ctrlName,varNum,varStr,varName) : SetVariableControl
String ctrlName
Variable varNum // value of variable as number
String varStr // value of variable as string
String varName // name of variable

	Variable MaxEn = dimoffset(Scan3Draw,2) + dimdelta(Scan3Draw,2) * (dimsize(Scan3Draw,2)-1)

	GetEC_angle(MaxEn)
	MakeKxyCE("")
	KxyMake(KXX, KYY, KangV, KpntV)
	GetEC_angle(KE)
	MakeKxyCE("")
	
	CheckDisplayed/A ky
	if(V_flag != 1)
	Appendtograph/T ky vs kx
	endif
	dowindow/F ECplot_Kxy
	
	MakeEk("")
End

Function PMenuControl(ctrlName, popNum, posStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String posStr
	
//	print popNum
	Variable/G DataType = popNum-1
//	print DataType

//	if(DataType == 4)
//		abort "Sorry, this function has not been implemented yet..."
//	endif
End

Proc M3DwP(ctrlName) : ButtonControl
	String ctrlName
	
	Variable/G DataType, KE

	if(Exists("Data_Type")!=0)
		DataType = Data_Type[0]
	endif

	Make3Dwave(DataType)
	
	if(DataType == 3)
//print "AA"
		setdatafolder root:tempdata	
		DoWindow/K Win_CE_ver6
//		Variable iniE = DimOffset(scan3Draw,2), delE = DimDelta(scan3Draw,2), nE = DimSize(scan3Draw,2)
//		Variable/G KE, ofFlip ofTheta, phi, PhEn, WFunc, EF, Dwin, skip = 1
//		KE = iniE + delE * nE * 0.5	
//		PhEn = 21.22		// 3D scan を行うのは大抵 He I だろ、と予想
//		EF = 16.7
//		Wfunc = 4.5
//		Dwin = 10
		seekinivalues()
		if(PhEn < 22)
			if(PhEn>20)
			PhEn = 21.22
			EF = 16.7
			endif
		endif
		GetEC_angle(KE)
		duplicate/O EC_angle EC_angle_noOF
		CE_Panel()
		skip = 0
//		abort
	endif
	
	GetEC_angle(KE)
	duplicate/O EC_angle EC_angle_noOF
	NewImage/N=EC_deg EC_angle
	ModifyGraph zero=1
	ModifyGraph width={perUnit,10,top},height={perUnit,10,left}
End

Function PMenu_CC(ctrlName, popNum, posStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String posStr
	
	String/G Default_Color = posStr
	Variable/G Default_Colordir
	
	CCfunc(Default_Color, Default_Colordir)
End

Function CBox_CC(ctrlName, checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	Variable/G Default_Colordir=checked
	String/G Default_Color
	
	CCfunc(Default_Color, Default_Colordir)
End

Function CCfunc(Cname, Rev)
	String Cname
	Variable Rev
	
//	print Cname, Rev
	Dowindow/F EC_deg
	ModifyImage EC_angle ctab= {*,*,$Cname,rev}
	
	Wave EC_kxy
	CheckDisplayed/A EC_kxy; print V_flag
		if(V_flag == 1)
			Dowindow/F ECplot_Kxy
			ModifyImage EC_kxy ctab= {*,*,$Cname,rev}
			Dowindow/F EvsK_map
			ModifyImage Vk ctab= {*,*,$Cname,rev}
		endif
End