#pragma rtGlobals=1		// Use modern global access method and strict wave access.
#pragma hide=1
#pragma moduleName = XPSTTC
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


//this macro blocks repeated opening of the ThicknessPanel, there can be only one instance of
//ThicknessPanel active, otherwise there will be trouble with the global variables

static function LaunchSTThicknessPanel()	
	DoWindow STThicknessPanel   //this will write "1" into V_Flag (a system variable of Igor) if the window is open already
	
	if (V_Flag )
		DoWindow /F STThicknessPanel  // if it is already open, bring it to front
		return -1  //and leave without doing anything else
		
	endif
	
	launch()
end



static function launch() 
       
   NewDataFolder /o root:thickenss_calc_variables	
   	
   	variable/G root:thickenss_calc_variables:IA_Value= 100
	variable/G root:thickenss_calc_variables:IB_Value= 10000	
	variable/G root:thickenss_calc_variables:SweepA_Value= 1
	variable/G root:thickenss_calc_variables:SweepB_Value= 1
	variable/G root:thickenss_calc_variables:LambdaA_Value= 2.81	
	variable/G root:thickenss_calc_variables:LambdaB_Value= 3.098	
	variable/G root:thickenss_calc_variables:K_Value=0.04	
	variable/G root:thickenss_calc_variables:Theta_Value=70	
	Variable /G root:thickenss_calc_variables:Approximate = 0	
	Variable /G root:thickenss_calc_variables:Thickness_Value

	if (screenresolution == 96)
		execute "SetIgorOption PanelResolution = 0"
	endif
	
	NewPanel /K=1 /N=STThicknessPanel /W=(22,79,625,341) as "XPS Thickness Calculation"
	ModifyPanel cbRGB=(65534,65534,65534)
	SetDrawLayer UserBack
	SetDrawEnv fsize= 9
	SetDrawLayer UserBack
	SetDrawEnv fsize= 9
	DrawText 10.5,239.5,"K is a function of your(!) spectrometer and the measured materials."
	SetDrawEnv fsize= 9
	DrawText 9.5,251,"You have to calibrate K or estimate it by theory."
	SetDrawEnv fsize= 9
	DrawText 9.5,207.5,"Take care to use correct values for the IMFP. Those will largely"
	SetDrawEnv fsize= 9
	DrawText 10.5,219,"limit the accuracy of d."
	SetDrawEnv fsize= 9
	DrawText 374.25,212,"*Use the division to convert from counts to counts/sec."
	SetDrawEnv fsize= 9
	DrawText 371,251.75,"See also: Surface and Interface Analysis (1980) 2, 222  "
	DrawPICT 43.5,35,0.34,0.34,ProcGlobal#ThicknessGUIBackground
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 327.5,30,"Intensity"
	SetDrawEnv fsize= 9,fstyle= 1,textrgb= (52224,0,0)
	DrawText 304,85,"B"
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 434,41.25,"Divide* by\r# sweeps:"
	SetDrawEnv fsize= 9,fstyle= 1,textrgb= (65280,43520,0)
	DrawText 304,60.5,"A"
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 498,30,"Attenuation length"
	SetDrawEnv fsize= 9,fstyle= 1
	DrawText 433.5,127.5,"Theta = "
	DrawText 451,183,"d =    "
	DrawText 563.5,182,"nm"
	SetDrawEnv fsize= 9, fstyle=1
	DrawText 498,45.75,"[nm]"
	SetDrawEnv fsize= 14,fstyle= 1
	DrawText 21,24.5,"Thickness Calculation"
	GroupBox group0,pos={287.00,11},size={311.00,133}
	GroupBox group4,pos={287.00,147.00},size={311.50,53.00}
	SetVariable Input_IA,fsize=10,pos={325.50,48.50},size={103.50,14.00},title=" "
	SetVariable Input_IA,limits={0,1e+007,0},value= root:thickenss_calc_variables:IA_Value
	SetVariable Input_IB,fsize=10,pos={325.00,73.00},size={103.50,14.00},title=" "
	SetVariable Input_IB,limits={0,1e+007,0},value= root:thickenss_calc_variables:IB_Value
	SetVariable Input_SweepA,fsize=10,pos={431.50,48.50},size={52.50,14.00},title=" "
	SetVariable Input_SweepA,limits={1,1000,1},value= root:thickenss_calc_variables:SweepA_Value
	SetVariable Input_SweepB,fsize=10,pos={431.50,73.00},size={53.00,14.00},title=" "
	SetVariable Input_SweepB,limits={1,1000,1},value= root:thickenss_calc_variables:SweepB_Value
	SetVariable Input_LambdaA,fsize=10,pos={499.00,48.00},size={80.00,14.00},title=" "
	SetVariable Input_LambdaA,limits={0,1000,0},value= root:thickenss_calc_variables:LambdaA_Value
	SetVariable Input_LambdaB,fsize=10,pos={499.50,73.00},size={80.00,14.00},title=" "
	SetVariable Input_LambdaB,limits={0,1000,0},value= root:thickenss_calc_variables:LambdaB_Value
	SetVariable Input_K,fsize=10,pos={318.50,114.00},size={103.00,14.00},title=" K  =  "
	SetVariable Input_K,limits={0,1000,0},value= root:thickenss_calc_variables:K_Value
	SetVariable Input_Theta,pos={471.0,115.00},size={76.00,14.00},title=" "
	SetVariable Input_Theta,fsize=10,limits={0,90,1},value= root:thickenss_calc_variables:Theta_Value
	SetVariable Output_d,pos={474.00,169.00},size={86.00,14.00},title=" "
	SetVariable Output_d,fsize=10,limits={0,0,0},value= root:thickenss_calc_variables:Thickness_Value
	Button Button_Calc,pos={341.00,165.00},fsize=10,size={81.00,21.00},proc=XPSTTC#ST_ThicknessPanelCalc,title="Calculate"
//	Button Button_Exit,pos={536.50,214.00},fsize=10,size={59.50,30.50},proc=XPSTTC#ST_ThicknessPanelExit,title="EXIT"
	
	if (screenresolution == 96)
		execute "SetIgorOption PanelResolution = 1"
	endif
	
	SetWindow STThicknessPanel, hook(arbHookName)=XPSTTC#ExitHook
end



static function ST_ThicknessPanelAppCheck(ctrlName,checked): CheckBoxControl
	string ctrlName
	variable checked
	NVAR value = root:thickenss_calc_variables:Approximate
	value = checked
	
	if (checked == 1)
		SetVariable Input_K disable=2
		SetVariable Input_SigmaA disable = 0
		SetVariable Input_SigmaB disable = 0

	else	
		SetVariable Input_K disable=0
		SetVariable Input_SigmaA disable = 2
		SetVariable Input_SigmaB disable = 2
		
	endif
end



//static function ST_ThicknessPanelExit(ctrlName) : ButtonControl
//	string ctrlName
//	DoWindow /K STThicknessPanel
//	
//	/////////////////////////////////////////////////////////////////////////////////
//      // alternative: without hard-coding the name of the panel to be killed
//      // Let Igor figure out itself, which window to kill
//	////////////////////////////////////////////////////////////////////////////////
//	// 1. Let Igor find out on which panel the button lives
//
//	//string ObjectNames = WinList("*", ";", "WIN:64")  //get the name of all panels (specified by Win:64)
//	//string LastObjectName = StringFromList(0,ObjectNames) //get the name of the top window 
//													       //... this should be the ThicknessPanel as the Button which called this function lives there
//	
//	// 2. And now do DoWindow /K with the name that Igor found, note the usage of 'sprintf'
//	//string cmd                                                            // generate a string to carry our command
//	//sprintf cmd, "DoWindow /K %s", LastObjectName   //DoWindow can't handle strings as arguments
//	//Execute/P cmd                                                    //send this to the command line
//
//			
//end

static function ExitHooK(s)
	Struct WMWinHookStruct &s
	variable hookinfo
	switch(s.eventCode)
		case 2:
			
			KillDataFolder /Z root:thickenss_calc_variables
			hookinfo =1 
			break
	endswitch
	
	return hookinfo
end


static function ST_ThicknessPanelCalc(ctrlName) : ButtonControl
	string ctrlName
	
	//reference all the global variables
	
	NVAR IA = root:thickenss_calc_variables:IA_Value
	NVAR IB = root:thickenss_calc_variables:IB_Value
	NVAR SweepA = root:thickenss_calc_variables:SweepA_Value
	NVAR SweepB = root:thickenss_calc_variables:SweepB_Value
	NVAR LambdaA = root:thickenss_calc_variables:LambdaA_Value
	NVAR LambdaB = root:thickenss_calc_variables:LambdaB_Value
	NVAR SigmaA =  root:thickenss_calc_variables:SigmaA_Value
	NVAR SigmaB = root:thickenss_calc_variables:SigmaB_Value
	NVAR K = root:thickenss_calc_variables:K_Value
	NVAR Theta = root:thickenss_calc_variables:Theta_Value 				 // !! Input in Degree, but Igor calculates in Rad
	NVAR ApproxDecide = root:thickenss_calc_variables:Approximate
	NVAR thicknessResult = root:thickenss_calc_variables:Thickness_Value
	
	//define some auxiliary variables for the calculation
	
	variable d  = 0			//this is, where we put our result
	variable constFac
	variable IntRatio
	variable effectiveLambdaA = LambdaA * cos( Theta*pi/180 )
	variable effectiveLambdaB = LambdaB * cos( Theta*pi/180 )
	
	if ( ApproxDecide == 0)
		constFac = K
		
	else
		constFac = ( LambdaA * SigmaA ) / ( LambdaB * SigmaB )
		
	endif
	
	IntRatio = ( IA / SweepA ) / ( IB / SweepB )
	IntRatio /= constFac

	// now extract  d from IntRatio =  ( 1 - exp ( - d / (LambdaA * cos(Theta*pi/180) ) ) ) / exp ( - ( d / LambdaB * cos(Theta*pi/180)) )
	// do this by simply walking up the distance
	// until     IntRatio - ( 1 - exp ( - d / (LambdaA * cos(Theta*pi/180) ) ) ) / exp ( - ( d / LambdaB * cos(Theta*pi/180)) )   = 0.00001
	
	do
		d += 0.00001	
		
	while ( IntRatio - ( 1 - exp ( - d / effectiveLambdaA  ) ) / exp ( - ( d / effectiveLambdaB  ) )  > 0.00001 )
	
	thicknessResult = d
	SetVariable Output_d,value=root:thickenss_calc_variables:Thickness_Value
	//ValDisplay Output_d,value=#"root:thickenss_calc_variables:Thickness_Value"  			 //Igor requires weird code here, dunno why
end


//this is really not intuitive
//for a picture to ASCII85 converter see:  http://www.webutils.pl/index.php?idx=ascii85 
//  do not copy and paste the <~  and ~>   at the start and end of the ASCII85 string
Picture ThicknessGUIBackground
ASCII85Begin
M,6r;%14!\!!!!.8Ou6I!!!*F!!!'h#R18/!$TNQ#QOi)!HV./639EfIDl0d!!Hq#9gJaZZ
&]:j@0HW2!"!U8=`XQC%`A>I%`AC5.h3Ku!!!mY79FY1De=*8@<,oZ9ke*XDf]i/F<F@kAnba
dJ*f+5!!%Fn8OPjDG[Bdn%CB-uIGak`3!qu*(8*Y<<K[sL3iO5s$H1s)D%e%_0"<Eqk`SN49=
c<T-*b8Y7$*E<FErJZGV-^F$T+G]m(?SB<WdHO"kr3GR''H9U`E8p*aguW0X_']*<V0N,ZtmR
e`b6VmINI'5'Pn4cIqAtTDe?ZXL2K/o:10q\`[fos8Ds^cVpeI$ig8-!2Sh,p4!&B!!#P!JHu
5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80,$K!?&4iokM*?F8"s']*A<9:`KT^5fQbQ't[Pb7hbq'
'G70Ez;F_i2!!!!AFT`lg!!!!s7j%j5!!"-a"<mgG!!#ne+9DNC!$HCe+ohTC!)c<0!WW3#+E
[f2z;F_i2!!!!AFT`lg!!!!s7j%j5!!"-a"<mgG!!#ne+9DNC!$HELC;B6>aFJ?pcIon"<NB0
R4TGJ4iZJd5d$5P/DM6c]KaZ/Pd#bpV!!&ZP9!\M>AD=P0ApAP[gfCUbD'"3)EO0?+,'2\X!I
G1S!.`&p6iaUUhS"8Je##iJ^bI`*B("NhCQqqlS=C!D+pq/R!<<*V6YR<d[Z$0(R+%s/S'@E]
S+6#gHYq#CYJ"P6/mTB]C;mR_!!"t]+oi6;FQeh>Z=Sr^4aXWJF6?<nJ(1`5a3=DQlbi[Z(GD
4'99t8.!!!!_9!\LCEpM:.Z[;H7E.;tO1c>UO[CJThqtBCbrs&N(La!B2OGGY4$:\RNRPj((E
>5&s?bSYX5C)g1rFZ*1!.4nn!"q;@r4(Q=iDdM8/6fP6r*KQ\abg&uJ2dZU!*[h/o*Z?efLs4
8=KoU/`Uh-(BNtiD!'h6L#_83n?+OS@C0E2ok\!SR'qm_t!!#D!L]D,Q`>;mgH`aUt&e.g);#
pXsn.CHV)5C3Sr@JD[?G1+JC4jo<M;EtP"98Ei&VpE)F7.hoBj2?dTgGYW=dCjfmTd@o+9DNC
An"%n+CcmdMVY>T_FJ^eMA>g#l71'4Y[Ko/horoh#O;C!X/lC'J1(I2+Ch\oL^Xe)f<ZC<F<k
!@h9Y5"gpka*9MF)3!!!!%,!b:$0b@KpBMj2JaJr7@bh9=8_u43F^LP<E*G3Wh4n]Kg!!$Ls!
$pK`$gD1OhYHd+gH>N:J/SJ$!%n"tLd,jlOm$YF9_f%r!6U!\"@,WIAjcnm!!#87"<mhL>.J[
Mh5b6)N'sT0,nMMd_hSb8B%gr!5dh8\!,+q+e:"IAZhst<28`IX71bT"$;O)\7a.`(S&4RL]m
I0k!.]:s+okfpPeEieU\<..WHmN/]6;He)7+,10"Zn5;AMYVX.;G&3kVPQfX>YO_L2Ca)I`JK
+Ch]:IBQneFNH(>\hr2\22/6'mT8)'M\e&#CJcq2JggNT!YD!0@+VSh:V7<)!2+_\L]Bt66&!
L>-mR/RS;74X=.2Q9Uq!.%&E!'?bJO=E+9V\k%"S\7`3^qdb-Y^:^4"u?;6D07SPd.l$cV%b"
c86S;AM[hOn7b^RtV4dg1p]hLdrQh+>J!k<Ka1djM6<KB(+Ti[\[U!cCNo3Eg:N::/9MY;%uU
-+Bh2U!.Z=3,6DCL<l^$k1gWR_`H??/6&Eam[',XoZ*?#>0epL<=U!5g/;Qpf#XA@im33)B1+
#%,<HRN]/C>>U[q:GJ&Ns/r\qOV?CTMQg\1*o4"]<W<)&<4F'*KKZJ63.B</ME]R"-^n!2(,F
,6@k$V<jL'*^7Sq!!%>!5Qh)6d+YmCc,P_^R1Tf,cuYF`!<AQdM3c;j#XA@i]gNtE!!!!AFd-
J=!!!!i*J"IrPg$gfpZrq$!/!W]!WXO@71"a)LLV,J"99Q=N"H)@'$u/M/PN)H$>!maaBZ8rK
`rk*!!>SX"98d(fafZ.k^jAn/6E6Q!!!iM!YGFC<5#`^<<$d*0fP[_k-]9M]_e.7JYOd;VG3Q
(aN2G]e^6fg&HDe8L!hLp@ofd>D>.ejSipl`0[79MVY[,XVXiTn_!C:P"i`[;`)Id]Cs:[7`]
UQ^R.nk6XlZ9.Lk:_u!(?.(BZ5(qOq%K-TFcnZ),mM6ls:,Cd3cSQaI'/KYnuD"+'^c?S1$'?
G]9ApZ$,QjBau+B@'>u9a,V0Pf</E<9'H<U$ke*sO>-k^mAXDuD(7$[C-ri."9D(2S-2,MQou
mK$PtFK=cf[cYM*chO9GXbA.=(qO>-k^D2Kdil9nVQM9DFM/3$KBAG>NJB(+Tip6t6eJcGeVL
d2*a(]og0,Uh(*6rdf'IW2%))5HQ=\om>[JcGdkLHl!`(]oiF`0P(b.+mqq[dO@RS&+efY]XY
`E+8PH8MajjC>S0IFL!"hJ?0t,!A]BpUdK'+2:X?5SR/%e557X#c(Cq>_2*]+ms=k:WiD$$c^
^dNS7mX.:!kJ%5l^n15p-5>%"Uqc?J]JAoptf.ogH"nf6/+]&gT(hdJple:Ab._)Bdp-)PjNY
6-+WX!:k_,"NVD]OmZ1%XtZ,"0%`hJdU7Et[[WY9'4jjBE:R&6FePfaK2p'Z@W2AK5aE"<!#\
-Hd\XGdXTsLG,JiN/BXR0>?rLI-c&FaJDPAa^]l.ejUhe8uWKJkcap7u4#nVmm)+,Op".b`k[
HlXV;a@)DM9DF]3]KtPA_)r["TY2T#Xj3%BbZA.\o]Bk+mIdmF6</I?OneKZ=_@ME7Ug?lWK'
F]A<iP"XJQZ7+\j*??#e*s1t)-T;c,!.M,Hr14N@W0ED0H!!kuCN/7p11_BKPiPYAXei%F$(s
\Z4BNCr]>IK2@.4Iej[;(t0Yb9o#5lE1[l@^7L]PdJ/9o3lK59$qCY;'*c2J2Nd`iT,1gE7S%
@E\sGm0*Iinh'7H0n9`rq;d`_0:DY-kM*Zg/Tu?u`XR"UfWd-/)'0h/f:LX'D-Q?nG_PYF6<!
\u[bD1U#+Po=r7&su[RYsEZ/=PKq]!A[/D*-+CjN)C)KRP;9Qkm$Qk^^H"X0Ujj>@)m%bVBn5
_0K&!'/DDp1!IFTP*T$I/1)(S"]oD^juSr5dFk<$?PFXTs40i:nH<JWZ#O/q_,eJGO>])1[KQ
5fRfI`_HgZ;I_qJcIiPoHh0RV=h)5i\Q=hpQ"9;7@P\'q6'3CX!nK@/LY7K6A:jLT]3HLWA=J
nUTFB`DBd\T[YPW0"XSpTlcZZYTb)8T!a]m6S8?GnMEH8sP6?=^jL@dXC1C%q$<!82.kLtK5g
R/K=$1,jHjeIRV-MFt2T!%8*S&KkR?(u;+[*5-=M_M)qjF66.UAu(jnqtGl^87C:uhO'X]*kt
Js;$.db'>,#kdjAY'lkLS\O;"6EB'kZ4.qEm#R,J&GTI:(6J<Ds=nt\9pr-12=`2?;Op$:4f[
6"&/pM*in2nc;SZ6@AJ-p*TdQ<B</$3Z?Vqj$)keh1rkI+"BPf@gT4!9>537"CF=*?@"-Nug/
;Dr*>2j5]fP.,24LT,*+8$[U)J$d849p2:oVB@3/;Sc!9ss-+o>Z8;i9idq_Q5ph4d6^+(c]e
?l>qR@B@%KImo1*Q_`1gjTfs8%;&B%GD'G0+%3QDX/b[V=lM,*!F!</FYJ:WXm-K",5L[t7=?
P#\'d^f6V*\!I'p-jB_b!"EXm]*>kD2K.FlAl(8Ojh7PfddH@Pe/bY=U)B*j]sscDF(aMaLb^
)gUD6j;&%6E+G(kM4!.Z8f1^cQ97ueRoHW-.d)&X=6mSpsDJm;Phbk7Os6&;fh>1>7&+@NYVY
6>q1AO3J(M$ZL:$Qj[En(49Y!!!]@JI$d\</RMl,giT=2=&iYeZ6SV&i2sZ&?VfN=,Nii6ckn
X?q^<b:JY?e1kqle"c8]l=^sgnl^UAp63.(Z!%?(nd#nU5.glt!4>at,AC.A`Z=L`kjWO$ua+
?\aUl0g7N<<$)AAC#fR5,mZQY95-o&\SCh;>_Pb^I`b#QTDQ+V4[9Le=odN+adUT*D_SCSFtA
;Q"5S2%J^/#,Au!"jpE`N=!^bD[+rtCV*JmE1s7YoSU<b!'kO#RKXfGQ"QXNHe+.8NS/)^1qi
@hFmHne8Q)B9Lrus]Je3@:W<>kj=Et6?jLb,8LU&H25X?!<!(b=F5BcC\\\bgVCeobj+P1fUU
BM"b9!OTad9uSTP[\cgJa*5cOrt;:d'c)ap6^\nM(gX2VEsUK9^/%?/;U1`h6b:1kS4P+J#g"
^7n*U]:f*)_!A[-N;>F0$PuWSM+#XKC/i:b<pNb<X%#kG<!qQaage\m5L)$[glPp#W!<=E4+9
H(IV,FRF20o+USi_/AXBN$S?KtFCB#IR_6n>'KV0#5VnQrjfF.JDQ0Mibi:a2-9!U,qU[r.TK
.oq>0CFL+b8qt?;-jp[c=lB_PILm^7XS/5nTK3(G6jQ0\oRm:,7>hq8e,*l,XnD#3LOi#e1,]
nYC%/_YZPJ>'-AY\mmoAq6Ja*5c1*I20ckBSq7%9qoABU8jp/44;ab"1l6EQ3L(".G,OsP)Me
K=&IfGaej#)GMI5Yl&Z_s"JA>$E7lM,qp-+<*8n.saVdeJ4&<.*Ven'GuJQJW._J@!0`jjTcl
#Q7Oa,24D.>%*sak;\ipDr]UH-c8U@Bla:#t#!kfA,>Fag!!%&"N!Os*d[DAo9:%9!6\c0)9+
e@u.sDcIa$=bI5fjRn!9bkC5dkRdC+n-(hRtuj^g?d'CZ1Mjk47g4Yoo)3>KX"A^[tDr@mM#1
BpP[fcsjTl!'i7NL]HYLmG#)TSbT0QpbZsgfWeqo$a6-[eLrL0Q!9#ZQ[ST3S'%sa4P3QQK(t
SO=g5\J#c*UeEATR!&r85<*<8oX"<mhlDJ3_)4SRWPp/9.d"95ls"o6;sWOrm#Xfo#Q*t>Z-B
-%tY4hI$Y82Ue77"Z&E1^a:[E"#bP18Y=-X,F8+_o'C@9!V3>`gG/gBeMHgJp]!!"r)SUBa/$
"R?J*bWWN5nLl;Ui^/.j@j"p#g-"Bt-#s.hlgC);WZQO6c%mkr#l2Z>I+qOe%+0V7o+8bC(g2
(#0bf/Huk3RY&0G<rsK$;XX,o7T#cALleJ.eM3$cn^jQY'r$XKQQ#+,hhpJg^mr+TT&aLSCS&
etWoI#2=X/mFJ6fMl[0aT]!nI!9fuL1Ld0lKH(IC_P0K=CtiR*aJqchV#%gY`]UcX?31,"\B'
I+)<7nm/ur$TZ?mIT0FMplIlHN>.:[PgRQa_h0.@:'e^70b[T<Tl*]7PGb[/@/#-%b*8r>k:5
^/Fr\[Er98mXS(f%qN5fse.C,F)qggjZ?NTe)!T+R\t`.a>OAo^+G;U3.d7?E*<ao`mCEb)_M
99)nr+(St773oa72:TuI-B(5JGK,7ju4$B;haN-n('+ta@1^hm+4W,:g_M[UYJ<D)f!RSP=a+
>k'/.s#'53n(F$f[L^3N90Ah?aWjJ#g"^a,9-^J<D#d!Kc(u[nQJ@f!W1PH8H2DEMKsbUK&'T
p!qI//$V^"Ja*5c&gIqgONaiE[4KD.:>.3\/S;q!@'Cn3)ssIpG,GGeZ60L#;U9qCX.f(F)Xe
7OT/@;h7)CC"'oW+m:]^bD!1Hh%j=;IpBL)F+Ojo#20\@#>NZJWtg_q:%BU/gi*VA5H(?GDhP
d;Jc#MYStm>^U5D$I(cC:c'Ga8YO(Q3@7:&HWOENO^U]X"gRYANl=Z=_.82Qp9Kr=R?;:$9Xb
g5r:+CNZIhN1q5*XojE,B='-C8ENQ\(&d-Yb!$t)W!aqm+=V,-aPQfI%OG'@oL:m/Ah+:0!?.
$&Fr%,q+1l#+"ZQN,K#$\,n.rM"@X/Q1$8q]G4^iW/R+;tcbE?T1TQ:l?uR^IYF<5=Wq/4c:3
-!HER-6/sZ+9DNkO]2FFFmIVHeZ2c@Oc^7I>-u'a^gQgY$f^J@+JK:#B#Dbp(8RsuY3,2YQ`O
46>&aYp!<=O1<**,(<%<(;R-WA-Rg%2C%02$S/BHGP`<RO.Jg^`L@0#:8n9FkNHQf&tjQ90`+
j6)R;*`O%%'06C%T?49o"NeSH=adh]Q26)=F0BZ6!3?sK'cdM?)dhM<`Ah@IX;A$JDqdb!A[,
I6f6S'BC0"I-juaX86d$uW!!!l?u*(WWtG*(Ba1\"F,YDDq:arS;AMZ1=^oOXPQe$K3AGrZ.m
9M3?93Lo'g6c`,Xht1^DLe]C:bYFf2,LL?3C8$pBX0;N:B+[d^P9N$<`JGC*O*AK/+WPf%US`
#D2?\[G?qe[f0cR\*g"m=Nh<V:aulS#Kipi@mShBTjlcbFZ*R%09l:Z5kH]5>GJGG9@'*Mn=K
Ct6p<SBWkgTQ9!J4nf:rGun!cr]!WXVh!YM)!qD9Et-aXqNece'QTGEIpS:UhP7TVTNN%bY1O
c,&3*Rn2PlE&(B&:YHI#-%b*OO)@V$PtF_F6Ci:HhZrr(LD@&/76-HgjfA&iW!]FY-ka-EoY.
KF857`E.?ofNJW,QV+[0!ace*sd*Rjl)]LSS[>7*Wh=oI#=2W(#q=8+'Gk'e_E@bA)YiY>aFm
E*,EGaRF\c+[4h3g'3_S:$BZ=VM=:jd[?bt<748/u2*'QhES0@!ginEA8fl\)'#=V-PpBbZ*9
N<MltY!bp`ct`YQ#-%b*OKUq15gYELGjo+nq/8Y%_#F<0VZe?l5QACL]mFt5^LYG!F&@i+[.*
kNO,&:<S3MKe$nco7&pE]u)*Xoe'L:lebgr;Z0beSCg9`<aT9u!"USFUC'ZUQdHq/f1RXu]I6
dGjsQhQs69=mp[4b%"LQ/YmWI;F[om=cCX<bYsU]oX"@5r9?&]!.jXF=]raZ*S*m&5i7is)KX
tU9J;k(B=F=Q^cDSFo&RagGUVh;'<1pke6cE!bEb/R<LrMpmlY@3j^c>5f!?2mT[Mc:QJr'MA
=Tl&GK9@#W[YM*=?`J5F+bQfYdq:U,JZ]Dd>6NM^sBSn':\N,iu9R>IN/l0si@fjJ9JN"ud;c
k9OMgOK,T.Xi>r<&6kn%eR4<L*0b%9!(nXuJV`X9X0]"r_;2_I_lS`m2SF1p:7/G.)&@AM[s5
S-"UBKGj7r0)Ft]HEXro'[d83*hJf3D5c'pZXO6+NL/)fUl'&@H_^4"sh1V/PR6?WLF1>UPmc
njFfFmG!&%+(0C+IYdnN=5Fec[a#e6qadQ*tp5"W!*MI,S#1)a]OXDFn6aNW!#CWgSJ"lJfnS
nad$J^nh<l\!)Q_,.F$9X%'@Mj2[74JQk![B7%"Ge.#tSH/i_7g%g<J`'Z?q$bH:]FJ3^r3j8
TU#8e_9EQ!PnY)BKq0mn`?IHhD`6IVG+C;D&+p.'KdGZ]kX@=HL#m7"-Q:jp,)t!Jm3Wb79/n
5p%Ug5uJ(U>)`[l!fq:O80<G8fFfd:3d6jg/5Ef(%01ppb=tGo=b10NLhMa$$ORS=\6qZ$b_C
_&\.U4;p$V!J\WtL#23C%Kp;@.YU7ak`6q"kI)jK3<#1=0<TOZ6P+:e\2dU;D4J98hC6/pbp/
dnED+K5Mf8[BOfb"Ta>BK<cI]Dqqn6\V#Df?ZMQJVZ',$<3Nbj]VTU)`DN:HSrB!=-BEWCD@\
#`[g6+23!E/9L7#"ppe!?[%Z#PO=,YI,Jj(EGc@n=O].E]A4-I5^!`[\+IXf)[;*S^@mRs\H(
P?`=?icQ9B/`U<8Kk44TPOJR?VG,&O3KZG3mk?6/]>UdOQ\+;jBRD?3-+m-d=Q!OLbYD2l"Si
U[/?7:m*AcAu\JfPHMB?ZReWoa+C*E5%A9$WBM5Anq)GX!.^6TAK[^T@K$&qB(bH>B'Ia:'3;
*^[q8S9WjD.L-H^4rNf9R[rOOP;9#:ECYf%&!['/BECt#&#-csS85[kVRK(tSp:tENcg+5c'N
BmjUVd&-Zm.R;2#6:DFEYXCDS:q01CTt<()Tk+JRYo^pN.[baLmD\E3d&U5)>!LL:YWQ3c%;H
dr3A#L.iHN^7.&^)M&aTg`/;j7`V9uE5`+SL&90L"\]fX\(;#/>O/BG;bZ8V>c:eu7QY6+3&A
KbH)R)4#I4Mq(fo2)3RLKYg8k--0;$o?@)citA&5A#YojGsN(1[Wa7#S?%!'lD&+qRV5i(nEp
:;*OLeV`T00Wq(aD6:f\BZaVi5bT9Ik^PO'`%U*?q5%8Z=s6l`c[nRLj-*X^jOIZ8;QtQo]JN
>0Z61l,M&$3D!<?\sMa0[GLc>_c\t.j3c\f7'XCeeM3W?T;ret)I0DQL"Z]dn"OTcU.AO/-jh
,f3q*F1C*VQq=AY!e2,#QUO9EY4-&j$6d"K'9KYc1l(3BY_1`T"BR>]"ZR:%V84:VF2:6QV@L
,.Eq5YoQ%9Q_)\jmTk?0D"j($)mBRihM92i26"Utf(jt9r:`TO4?F^>0r8=?t1q3lX1m:t'Os
pPJrYcn/qf2^r+/Hj.^4!WL1M5gqSWmf]pO^1JAQ\)kh#kuTk[P4;c,7L,1\"MlEu"lY!)-=j
C*[po1qg&enu=]kk1E>sF;leOW6YD3n8LNmd#-r24ni30b_Aa!1f^\c_Bmg;?Z2;t;)UeJDag
WF7VANdd?MKH_M26&?!.kk>`!(F;O0a-EU!Lm2fDH,(H2>$[&Wu@`'h+rOpZf$We-:upY%,AP
Qc=ffMX3:d`4pt:D`mY;0_(gD1<[m"]5gD(P$23Kbb*pJ^*m,!!&+'!t.M[:rcf]FO@nrh7Il
dqi1^i"Y"?%L-#1":!8eq2%)ede0qis1E-+8"UqL]i)(%!c%[Vpd=&rED;lU0g4@>ShtX>l5Q
691[t!s]p)7J\O+$M/oBDnHk@X^`=6qdVb(@hJ[M3bLMYHd@gD^e:kq-X7P3HsB@Pu6J>kl=&
jtm&#0:?b9ID<H"(lZ5CI%gA$T3Z&XAGui$2#r/=;D$.6ZW/=5QUpMrYp7JSpt)L_mt)+9>$\
[Z`@P?.35"%(mO(%aY7#Y[;6ZhQ'cf-7`tAhJ'RV<=dO651dq:'-*C369bkdoTc'FDcRc""Qc
c$,4.?=X0(1_.Kqr32=,p9mXj3l=c/BF=L4:h]>gWo^H5mT7)J,+FUDuT$Ra6F'!ZH_/)^mAe
*6lkrD(*HS35<<,gPruTnKX)f5Sa5M*H5@".rObpeBAU:Hp6*ui\Cbu/jF3a#/f,4Y*gc<<TC
Oq`Im3N"q]2c>Gij5:*jVGQ(.:I/IhQY@KFBgJ,$H!m$PbSq3;"%i&EM2l5PgW#6R+%'3<8,*
We!^l*'/2_CtZ*?gfMjq5buI,7']*]OC.sCIqPAKCM3#l&K1bGYoq2DU`_]6`2>Ruj]FfBT:R
B>6'MO5E8g!(^]!GICTdcEK0Z4i!YGFH;?nEFTQ;]Jf^8M\=VhN8c@>AJB(WS4]tIt#akuq4]
/PH;*k,o7hJ5E\s/hYp^G6lL#GNb?$<h",<2g^^/Bln[p54<7OTdICNVpm@.[i4PksOT>h[%r
Zd=1t.?Om)`&8@+h"G!\_JVX@="X6^sXB%b'%7D97@EegWPN@G0jM(TAIm'<^="C)e8i[9Rm"
_khObr3eqA:UgiluGuInd3khgP6-o?`8B\$k^Z-W@3%m<3D?RG(phiohX`hIu&n!s]<hqdl];
!0@Yh%T^o=c[YrcG-<gN^$%aQ1Kcr`kIu@[&7&sTOLQE$T0NiR=%o,^&9@PbD*WDP&>C_sPq+
9f+YD7Kq0u`LW-RU)^.JqL6$p&po1!41<N>EL6lc[/!_>[-!te8`X/U02%3%4X^%0;)6+h1(I
rR0V'MDR?-)FKh`H!g'6Y0Ca`Sm#E[7j,+V-#4`C+pluZ692.lDMj%XSYfB9!KX_YAXR2j_iB
h*=pse?&kf*O'W%k]iN9@7-fB503HK#V8W_`.#S?#6FMAWs,>6FprWDPYf1-=<j/+/opQ)VCD
JHKodknS+3K*j.)f("j:bmh0Yd/E5'tP=9YS4^g<8<D7lhD,4F#4ZR\Hm>T-XMgIOOksos0Dn
XR=:.5sEofY8dprqs3VQ95C+NWpTYW;sj>>'<4$>AAjl&gJ].$U?mX>UoPak6<TC7ptEd5^V@
H/H`pe,G1rL#H`QVd/CV*?N=Ul@P%?5bgM@dU!9cmda,"-7/0Eq!p[*`"B`@'G,O#Xh+4=O?o
mTiSip>>!AO0dW&=3PD#baDBm<POEaM*'Y1QP:Qlj*U`)M&/LIul<Uq]C:Sj"j?8PT>Q/:F[&
;(.9rg70V"m`e+-^=8&(Eml[''f2$(X4j%]h)[.*sESs;#W%_6T5edkdP['Lai^IdXf^Xm-nK
L.#+UU\rW'qIi1L^7<Z_%c7+HlELO*96Pr:W8DB9-k^X9a?*+qQ3./02Z%e,I1gg?.]eM3b$u
c.$R!/[?M]a!]-qnQuUCKh,f^*tRbG40@6.8CR0:eUg*oBEkS>R1fSa"G$h6Iul<gqhOm#AOt
9l=JDXLM4H_f=g=^05iKNU$44!\k+c#%kiZR2.l-nr"DF^hl(gHQ??kE4ZYJ$jqA*@09=%4Xg
9iHdSpTlcF5t7LgB%Ag_lQue'">/m((]D9B`G(#5AU8tO+,)TA(b"lP0TL2[lV))T5-TOJPZp
-?q.4O$hEA30orK^`:NHE:4#qfm<P9\bLmSWRJ?)`9h\6JNLJT@!;_M18;Up>+RUaQHT6XY(F
<73pVsCsIen/'93&h[#XJa`7;iD2["gmLF]grM(Tq$GfC+VKA):\Q]!<G._brKqF<V[+Lp!#j
;dU?:`E83U',(56R="oXBW'\NU`BH^4ou=LZ@7lgA@jnfEO0=9cmT8G$9kgXH>8]ZD.GpXPL%
"!G1rK^g&V2E+V6s%&+YEl%m'&\bcdE[=V-Q#M2X=ZT5Op<_CULRqY:ZK::ntlH_/L4Q\jn5f
3Ye1!73q5+siSPK6UPRJ+qZplI4D*a\3K2X^JaXCgRX["Bc;X_Xm*?:4#qng[f=.S2kbrL-Pl
,)@/`'/5$6<1:M$KhhODn]A\4/9OpFq%^n"qgDf+JBu6j*,?YT"b4@-jdiR&_FoXd?#XjdMK7
#-%Ptga'$&o?E$Z\D_hU<4gBiXeNX1pjYZ"NM#NM)hcV]Y:+J7JpR8hQ#,n^=j91((`HAjLnC
.soOer6jgIO#aPmY=1P?:-[G5!6Gh/PZS\3ih^Ob2.Z^.T75"S4^c-DK2",&rL;K_K)D+Qp`I
^-^,08IlP&%?2,c:/r!$i4h<@Ek!2)IX,,i]]6,!cp.Wp'uM3"**98kn'S&UunN%pO42O)c?[
7M.p)fIlJ[U8r<o*8Y"\G9e;i90L8;mPoj3OI6VeaIY]5l1gT&Bai8^.doYn[&6V/9dOG/%GR
sg+0SX@?WQ<]%/&5nh:$dHLmV5rk,f8`fFa2q4jMSW.)2l_,-rioChS+Fq4TLLHl!15KK1o^!
T0%/QQ0G=Hb:lH#R2Z"o4oXs#'DnHaC$Jr'\n,]//[E4I\K\[b\!p(S.]>!;_42Uu\h'&?"?"
f.:*H=4mu4/&Cq]g29]naF]d,G*lVtZTlZc8>_t#Mg!gF6+6prg.*8`@TbaJdlt,:@qU6RbX,
"PBJI>H[E*reV<?+e+8tU'n'C"b6Ta\\T\BJISKSP1jq%#oD1C[(OSQetIGA.=F^(T*+:DXBE
m]gecjacrqYW=[diLC1G3"Q^O["'X>e&V"EPl)j+:SGt-'uT'3:0Z3Rt#kdbS%$^_=hV\[k.o
l+D,kZ)?%eZAZs>Wo0YV,;1iaV^0J?te]aLAc`CHd3o#IFLX!r)-Z(AaIOebJo#:iCDEL.)Hg
@]F6$[#2+AR8W],!GTht2Jqk$"u8/^[JSOWY$@*a,)Z^Y_C?m7nGOO[$<ml-.Fpb)cTo8%A\`
p[4I7=%8-oC%mRgH=ae';0caO+CEjrfaBj178#q%Je&#./[?K+F>Eaf>I;lIA?e;d(+]a*B0;
D,!D#Sg!g.Dl1mN:FcZE.C]N!%TLm.LaI-KC8s0%kUI;Q7&A2Pmb;W+6(/<s_anZj:#q7iPF]
172`gAq;F.9.KgrUq\P(U&/^LtsSJX<6M;YI4CoCS,?IU?-#RVT,*$M.Amt.t=2<:4#s3g&V3
@.8M)WhRtTfdaTeflqVh:ko``JoCahblBe!,BXO63OY$HZ[*p(]Vfi&*qoTS."@5LG_2)*>he
Z6a3b2.!GG@'`]d0n*&>q["q[[M'T1/'<YVjLRKF8EA1q8+'"d)LXI3.*VGI$'8!9d*j!g2bT
*k-Jsd$^psriEdeV2XM==[1!V*bkY:nX0b*C=Vt_h<'dtr7B/V5PJfuOt9D+s1SL#Zo`PL8%)
[4E5<MTFNA:OZGgY7[`odRG)X945Xpt_&CCLNf?W%W23mW[g6`D0L7+0<>*X"@9GS/u['s`KL
Yjr/D`hM_`D[Q52o#99o.-;ZcX&CRo7%kLG)u>Z[MQorHW(X^H)55"7n,tlMA7YY+@O&eJHH/
$qXs1!U.(!ahS":'/HH8P3<G>1Z7H/&k.\A^b$6FbgmSh^'NGnZij:(Ks-NasrNrgNNm!#j^\
GG'F8s]YHgR'!4FWupp8GX5k?2p'hRN59njF?+/Pp]goP&ZsF:,BumbAZa-iaIL'S/e[=]QAm
"N&AR"LD`Po,phUUcl$1U!&$98BJg1MkHVaVhj`](6r95\oc&#C.p.Y!uRQf#9rWl16oAT/>l
?jQBsldK<-0UBocu[\<$Ht_I1;n6,)m?'A7YY*nk=PMV*r*;)[LradH_kCY,^H',)&Akg?/;e
Z-]d*rlM>pjktH9&=ksQ4m>k'f2__aKg8VVnG\!'0FFYcMp24<%F'@`ttD>G,OQkaG,<P&)+]
GUSFSrEcTTEgpkajNK'@4B@!#P]6;k.!/"2E5bqOcQ;cr:X=PC1C%&/%Q$YmWIT@P_6Ta[47;
>>9S3&\$7,n4EOYrL-cThHBfs,%B]`_^SMB.N.]4!1OF[>#=Nj=s`Aa(=447,nPe*^b[*SD'r
RWll:,r5bc4)<EKZ$QHTU"FoeX0O9(Xun5V9'c_Don,BoZpuEVs4&4jVe0cE&TdLVmt>2iHs(
]A%dh5Nc_K1"Vk8pklh%l:gmY\'[rC<uFd)l:8"g$I\FQZbT<0p"bH#8lk,k%-B9])P.uOXPg
1bcBC&\^IX>48n^1b_l7Z9A-\1oWH)\[VuNucn]IVeF`o?_o(B);$*mJ1PDX.c4jM5QQhl$MG
+.Z=R7!4&B0JOg>S<$K/4Z5f<!.sAN@Zc[$%ICL,'6"TR/:-7i<\*a($INfcU?`26F[n_[oa_
)ChVYOkSj/I?D@W":MIboS=1K/'!AGttl4aZQ54G"%c?]#eY7*;er;5Wn8ane;pG1rM*m@)m6
di:;UK+mk)DIY<&2ZN]Q7a1$Z]#gK?425FPbBn"P,OAO;9`BG]g'?AmCku\H,[.2O+?KoLM"I
^KMV5=NBW'\.<P-8)C#R)jr6U'Lf1oj]h\cVGk"d$PhjBpPIUh>Lc-Q@H^GI<fA*2BTB)d=<p
AVKF4-U>6Ajs)<HD<2J8JXGlcp,JX7,GF-UXZ<D&ri1,k1`D0fNV-KfiE3fCXH\k+AY)d:.O[
VhQ!ccdO>>I5P*NqDub8&S@hZQk0$DW\[KWX_&rTgE6O/Lo'`L4me+=8fq;KRHjW1M*BI^a9i
6GHF6?;F$,@Yt1(^F6qiop+;Ye&)ls:>9/i;+g16)F&B4^<M:-7i?]kTc\j-fZTXi&!K07p<i
PG2t"5BQ41(n>9`aiTftbF"2<N;;`SA%ih&HJZ/nRD3*Bmr(:nj4S(;[<kgdE$uRN+FKGhBap
2eOceGE%L*V9V&HT8Ki(#5\>a^UN9[Jf;d"+h?>;cY<`Lg@WBRWC<0j,bQh"q21V[GoC**92O
4_/4+67.64f[mmXXU&2_=sRSmGkV1cjtKXO4p^/fA?:"oAmc\2Wg^P`WY0Fk2G%Ig<;]E&[Wp
(^\tPngV''I?i6_UbEmMGk"QdjETbUf1O&9Z"b?20_8Yp5E5sba9h\66/$K->^Z&fm1]pdcPU
^S<O@DDnAp:,*M^$0cW`9U55KM;KHW3N&$3L-.Zp]Jb0@tA7?OJbdSFsF#;h1V(L%PC0%^pj-
C^OG$o].75%k0l?9Spp&?Ds5U4gcQZUo<)7jDR4sD`K,-c_$!dk3[F/%6F&@aBN.Bi`8s<UG=
HR%Ua75(PkI[;O?%de/Ki>Gub[kij@2&oXoVO0(Y(3T!0"^og'd'9r$W66&:+)5<)NEU7ark9
:Ic86j)=(!8[l,iRj@[43]u.s.='/jo_#urW9GcDau^ENK'>>-VcLhc<%J8J,[*K5C^D\#!gn
"=.5tsD*M^$2.XoACpk,m;D@_-e9V0>AP1q`PT5OGB#U#GAGmWH47,e@mE/8l>P^S<CTM3+<[
Ujdj\!,VJ$\&[$-i7A/<2WRFZmCUN;g_5g;`JC^J:3NPC0k%J]aDY"Tbf6^MXf<=C<fDe((L#
c,l.sc&46hBJ*Q"&?`=QEofp"G3rJ>I!P57$>AQQh8W<H,k$4AO;ETj,D(0B%[L6\a?-cXmW@
:a/,uc\:5J?H_=kpWh4BuKCi5c"$W(FfER:$?^AG.FroT![O"DETNA]*A]@LE5eFQnMFoi6Uk
Y*_/mmZ!:I#o/uBm4mO*k0L)WtMOX]b>4NND%+4D[2bdTDeN#[Pc\o>M"?1[Pl1S5'5\O[Aea
8TnZU$f?3U_EF(WeA8M5W1]6aoZLRi^'YPLeckulsAH!]I47,ehg>`r0<!FR&QG)J<$oS8:$:
I&uC^Npd+kStiYPV,3p1gh>j5&>(i+-Z?(X;ql5%q-iP0)nE;l"R:5^Nc)8hNaAES>,fl>-8A
bK]:@5A)WO.\HRVg2:X>GUNPh+JOBSJVbJ=-u`#`PD#JFfZEdW+"1$6&I]+CY8utOqHEqjMEm
uUZ?-YUSbB!=gAgYX+#gCYM[\D9=Klp.QD85EE2$5_Q#nI%U+D00:/q)O]5MS8]SL+Wq/qSO?
51d)VHE0q5edne+S,h`g1cW5<VnlHbq^AGFu8!X9;=nU'08.UE@!4sd>IEWc)tVhjnY/s[K?M
m+V6*5/0;`DVqjq@II=,';gbX_l/uioRAH=]I&tsA)K\%@+?9Lc'$K9#S9EVW<80XEIp,uRkS
(cjkRt"01nM\\rajc2I]]?R!s%%B+G.2++67.6h<B4^CZip42r:bTXK7_$M#sK.CV.m4rpVMO
QbhiD;"So25l1gT&Bai8Sp&hYT!lE2RPEDP)=s+*1N-=<]X\plY(.d5,%Xn\kg0dMcd_Q%'tk
UfckulsAH!]I47,d=gL!*\ba0(_F%`:C,;`]/(1,T,]$]31Z63&2or"uF%fal)o4sVj4n#,op
\Lql"$f(MWWB_mJm7chn(>=Bo3_E+V@MUmdiR&+G%EtR^+DMK&P\aq+JdhI"k3+s@/J("XrP(
DN#CAh`*SmqalhP[PkNj=qf;JHU[Qbr3-=B2['`4qSN:=7?..NT25?qAB(=kaO=P+uXu4Ch:X
./h!8Sh1.?S9do%4J&`9q46+>:+N*n=-"Z61X9H7*<u2J#0<(Mpo^1@K]#2Lg\,LJJcYJPgcf
-BlcjVb$3#%7C[G3+013$\IpP[)U2[ldoc[9`Uh*P\)*1#C5$;O(u;_)[d8tKI@6!9X*V%#^I
WH+p6Bo2+/^2c[S@1g[enGk08_bMfrtG!(dcYP["t7ij@2&oV=Y7=HG)#@elbaLWg)dLYAiR4
oZ*_DpK).3OWk`DD*l5oQC5]/cq.JbMkgXG1rLig],)c'IO:JMln/=MX#>:DU0P=3gM=r/V_p
afan/^66LlkX<6M;Vql(?reYiVPm-\H1Em@["qtY7q(H0'?7FX6CY(1cBdU,/!;_O;"JMn=jC
tOJC"BGp5Yh<Lh^`"K`"rkN*aY"tk?lBaSp-VDX&2nc1M)[X!RNJ&,09[JSp&hYB'hhSfGQL8
;nm4o/'#NMe)WY"iku7)s1;X*qAR]NlQ\i:ca-)DO_38Z!9b2L8BGH-+AP#c;+]K,"o58BhdL
tDiFcr4@mq+U$fXR[+^.TGX/\fn?QZ30m<KM7'krs_!J"K!&1Ok8*Q2Zi4Xs%8Z65e:kU,m7O
+,2WlR>FA`"s;iIf7M%L&YfYol5lG?52G[j*%V\C^>Q?,7m0'&+[*V*jo_N^Skd2*kG,Z7mrK
F+MLAho)HG/.$Li1g"Z*jX/7BT,%O%@Uk+f]9-h*S3flirq]l-Mft.+=R"o>1[F]Yfq+qhpJO
gCO+2Kk9[O^+Xr2R<sN@4*>%,-D";YgjId,b8c,9p)1(&L4W8)O'VGKg%DIpbJ=e,MNo#Z::_
=cf?^+W;H^"X3H7YA!Ph!!)g_+AsDRLI,;r$ZbSMs.NTp6eCZ^*b@WZ,$LCrQn#5TL^[7tq;s
g2juX++9)ntQ%tP":bUS#V`"r_J^A@4=Y^6?Mj:c#k8gHGejN+6kZ?nk14S%(<1*?G>*qR,?h
QYUVMEVe$c9DarDm9(F54T6.SVK,U9,OH6T/gKWC<h>!PBIH:cjUd(!1@lbHf$SCq!,&NU"=M
.#9d[$K(pN-Ogi)LOkg*>+J/p-!+^hi+:J0h`'!\cT@dpAAJkjg-YB%J^&&T!4TGKQM*M3Z^l
\e7+d*:[kJ"]?hL"-)p(@?*q*Z>,@%bSm,S4,"OKpD;5S4Q`!#UMpn,BlnTl9r<=camQJ]POn
?#968!6?ep&HJeWoZ]%Vq;3)J&&&\jAWR(`:1HX8lP>Wq!<<f7JI$eU-k#Ua\">Q#ps))ZQ0R
,t=q=btR1t<.:`TO45Qi82;W4o(Zer<(YOT7FCh,ik`Jb=9TK3(G#REfuoMs'ca<(ZAY6>kJO
EdiK!WXVs!YGE\dkV=%nR25\Ye?e^&1a1]Te$QO:_3aR!.$8;(?@]8QdA:I5kVb5Qj!I<#QbS
<4[g-^M+CIj;TqCK9!\Kt76r$tTI7g42">Ohm0L-R#29brO\k,I$::bXqs>[0!:l+7"@1S[Ji
*"]_573CD0W#qO@6Ao%5C["!)R&++ojYn(8M8'"o2u=4fU$6Tj[acD7??T+MpBd!'l)HL]HWE
=cau)=cfSS&%5Lb>0<:%!YGX:!s"435Qj>VaFZ7r-jpZc<Jaa%#gq999!\Kt77&*u+>L/E9f0
tDBI3<>4Rf]NP1?R#/$aWF488[g#-%b*$AC_J5YDGH'S)8KM:!LTo%j1mb1udk8TSt@5;mH);
RGFt<h^>NLtnKMc?*7j!+[1&#_7XDF=?o\.G"ItonpH66PcJ3(?F&:4m"C=rI+;*q`YQtGC/c
7R9>M=-!J\]jEmK*HN4$["+^`.==suUEi^,mFQdJF+AK0bD`me&p6qHMqE7&V^@hK?D_G6CdJ
?s^[k;9c3Z/M05g^.!!1:dPJnSQg$jo*2J>aHG/BBYf=cfRD%rI[O<;^40q-u`8j$T&"d23Gq
!/cFp"@-7e/;Qp'<0C6>*G.Us-s11eU(te)0Mibi:dbF1!8>VJPYmcMO=18JhgRO?A_%O2[^!
7[c%o2^"TTqp!YM*daFZ7r_^n@.Wt0\rAq9Ep_58>#OqG6Ohd<^:!!!]<JI#(MA3jDoR:,>h(
*lYm&hRZb4=k"K!%9#m&YOfuJi'1FLGC!eAbRF\aauo</CF#::a$AN!#-#r#Z)^U6!@+Y6WoM
l\qAG3/4``VM3`o>"9;7t"<p*&O9K@8AO092V/[Xj^!))HM(R,\mXFV6]*A=$Yn2]k"\0?(K`
P^MU1-d&XLIY&B_MK,-l)jrTYSX#1smKTU?kB7ZQN,)9!g"k!WWoLJI#(;A3jC4Op+_F6Q$GH
6Md)RM0&QVkGOSY0i/kj:h0\Q5f#STp7I]UIlS.6"aMoVaF^eCJnRj!+=QGuoq>a%QP^eG!%9
`,&YL9'pYHj$kk1M/#@IEeo=b1]?eB-Ws!cTl#r](31\b)aN=-ULQ"[]Z#h]ah5`lY7!!V;d+
HO2.YO"+fAO6"ogS]Yj<F&HW):*n&W>s++U32NU#QUO5#Xj1_o<TS6^%X+*XiG!=:5>1Y-RW&
Y-s*-37K`]fA-=)A:6>]o,%k&?3%E>([(ZM?'GZ0)O>CE5>0(Cn,c]5nLB%;g7AUp,qo/-[CS
n[aV_M8Vg+-V`=^ik%jqomuXtaEr`XE=0L14?VbjX2tRNnGRb3gE+PQc@![2nc<LpA.q$b!>F
+Nf9a!tl8tLpA/,]ROSV!taP>L<lBqHSt!$pdr(&!,/7>J]P*+`iNNc0=4cN4Za'A.XUk'2BX
.SaY.3k55:[3nRYgs/;Qp'b#jBE^DLc+K.Wr/93IA2F8':X$k)l#+9DP6.;ij#ZV3oKb.W/!E
qll<Y#l9J;h1rW/4^FM"PZ-M[SI$1:<.qd!)Q^T&W*IA\7)E'f%E^3i%PqBKjP=uh[d.;%51G
>Vm.?E!0gKo!g0g%NDV!jgMYk)e]jS#j-7]sF2m"HAM4)K,7DqQbCY*mfOjB*l,\GV!0@`QcA
2l<REG<7W@hOqYOGf,@!@.nO9K?L/-l4UKgBERT^l(+T^=YXQiPqd$dqG$/;Vm4+:A5N5e[ec
1pV(oh#[AQAJX@a#9-g-fIVgor-S8:Ngjt#s6l-T!<=6T#XeaE1M?&\9fSDV>e(Ws#7[Tm<TZ
XdOPdMDAWn5Eo$Rb<RX;B,fP:He5b=3%&@m#2<4?_F%8QXsG3pdWieGO7fX(DB"P^tL9k-N4-
t*mEe].[jaKJJF+ppB2X&mo]iF-4;Ged8g*3cP'';>X>GA)86+<;A2XVJUK;$K8noT]kg&-)]
&UJue8jjKtZq[m^)DV/_fX&`)\Kn7U8ZSMehY77q4XR2;T=V(Q58qeuDT$$<H`[G&c"V"U?*@
\T`GON`g/LBRh<X^VqZ60,IPZ#%aZ^*-seQ&ZI[K\Nt<DK,BeWCGj#tThD[/TXThmA`O7tXMV
oV*N;!WYK"Q)c`Ws*dm,HZj/9ElFD-G>'l+9LqS[)?p3KOJ^VO>&W8d'rf7Mq-Y^V14Un]!!&
icC"D(MVQsiqWG\4d1:VYkLtr0]UCs[H)$%Xu0cfuCEJ*c&JcGdIH3>Emjlr]1SqkkH0`_7HH
[]qr/6\K:q@g9mgf!((!(;AD=V(Q58rl6U@GMK*8>/Y_'Qg8V9;P`?abh2K!WYJG&VrE/71DT
n#."DG-q&oXbCXD(H47)%!!&6"JV[R@@&gh_gC$q0.p(Ff+FUdQd38r"!!$1N<?Mna5(ES-Bq
&.+2_.pr8n?b>W_0ZWDml!__8p2E<g,(jJdqr+A3g1q5cFgIb2L7X..cD7>%KjWVYW0VBA6(p
i8gb'X$mdlJVO:<Q",p[!<<,=%7E5c,/R$pjJ4M?A+ggKY]<U8PopI/;Cn)D!<<*jE<D>'X6`
S:>%ufOO.4;blc-#3CTdoI+gWIuD.Gp4!!%D3C;B6Rc`LEnecKPABZ[:ichrgZX#]b8VsGJq@
+Mr>DWZFa2#,G3D6F8Y*,NA*D"!%Dd\SLN9#P0?&7n/ArU;0?5Yqe,5'+m7eXZ[!-g_rTTUB6
o,++*M,l\p6o*a[_ht]e9P4cl3p4_4<.[1+aU4`uQjAcuVesnmf@A,L`6i`l99]$6=Lb]ApAt
)[`T^5&b(^gBF!.';`"NVHl)cE:sMm4B)!2.@<7"Ce)[R&q,VGV<*EiFL1$N^;.qLCg6aIuR*
ZlT]8`B.Tr!!#8+&;U<He^kEcbnU)p@/Iq4dPPK#!!#8;&;U<HeX$n#AO.$SHoBUueJ6Pq"T\
T']g<hCjB,2NZs4@lAj&qq+92D7f*FcpSEmaSM_#,6!#P\;&Kp8$Tm67(?alB'Ua92=Z68VLm
u]<F+U\>O!;_73"=O7]/)L9^7J;n@J`]1%gRY$,(?E+%s-1(arKHB'#CjQr!rr>J>6H-8!N7h
j7Z!F'Zf4Ta&nF<-imHXBn%S5mp0%FrJDML^!=D.2OVoHKb)!Q]#g%Yu!.YJ$&-3+`[R<c>Ls
!*GJcGe$$m?/_$D_*eQBiI5$N^;.15%mq.%&X"XU)3T!!$ER#Xj1EMCm5]aFXBlJ1MfS!=C6X
7#NT%!!((Q!YM)ur":Te+92BaCC!=Y!`Os,2s:.CA3g1q5irW6!!T7JX>aelGP2XL!'k]=L]@
DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"Ir!!%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT
!(\,]#QOi)JCG0ez80*6e!!!"Le5`LL]8qPJn]^IS4TIa^SH%Rrm2c8#))<B9!!!!s7j(\R5O
ubegH>O%5CD?5&)'/H5Uus]-*m44r[ma:pW]t0!!'_)n,p#@YPuCG\!I'pXY<3I!!!!alH"b]
!!!!i*J"Ir!!%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!
!!i*J"Ir!!%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!
i*J"Ir!!%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*
J"Ir!!%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"
Ir!!%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"Ir
!!%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"Ir!!
%Q!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"Ir!!%Q
!&VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"Ir!!%Q!&
VpDe!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"Ir!!%Q!&Vp
De!!#P1JHu5U!.`Q2L]@DT!(\,]#QOi)JCG0ez80*6e!!!"Le.IK:!!!!i*J"Ir!!%Q!&VpDe
!!#P1JHu5U!.`Q2L]@DT!(^Cl)R0)=!$Hh32f=;<1O&7lZXh/jHO0\6";qdOaI#Ve/t#.d(/=
,Y+rg0C<%8V=4?RF\Y?kMlNZ:&gDc&Wp:S6eJ#bWgV6i\>seEL2B@`=9^m`:+d$PjQo'("Mjh
d06fGk#7T=$.9O>VK6_?4?uhhNIqcM:*pTa9Zq`eChHXn")OZie/0i*ORK?)Kj,d'lgB`^E*S
.7C?^M(3A]dU$ut_HhM9Ls&K-a+X7$g)0"om/[K?N\hFC-+!2j9agfr/Hd1sr1Ggpfpl;n3:F
Z?K^OCV+4p?IS&VpEP#,lU@?t@ff<G(jbc1Y=OPtI=3jia"F]jdIuQjA<sAaXa0ghEqqJBea_
!5O,a;g7Zb3AZ$Um'*gOm!J9A([[eK.p&m\Hc;kM_;+qZ^juUMfWerF4of\^5Qh&k82FeU;^Z
qcm%O,:-PSO$AX^&OmFns[j2R);rjH[u.+&+C'aC]@^]8(f\iR5KH-q.TAOV\tl?khc^]WQ0?
EZG7mZd!Z;[K-%lK``J\om=t)8lLt.5E(I0H_i^EG*k3Dr4;$Os0+,CR-B>oiJ@W1,<=1J,]6
tK;C:8Nj9g>HefAm]5^MjNqAhA5UXX/!5JTuCpM>9X2@Rg,Wdh%Q:g94mFt\q44465idsY5?@
(G'X;M%'/#(_(1u0tg[#9kK!"?[%_h[QKfj245&VO\FJe2KXG449.G-Ei98*B0EDMGSM=0@4c
F0D'tAY=@6Jh]4'oZ<:Eabg)^#T43S(kAGUQ\M%i"X%@q@us,3#]UmMaiVYD@!7c8^%Y1+MS>
0\1Wg9n3Kp_Q0m!!Nd;U0-Os2+P!%INc+KGT7&2JK63S_:p4*KtH%78!uBo)nQ1=(!<kJI2rH
;FF++ok/c5Qh'bVU?Q!_hJVD%tgSV`3"liOs?772<&hgbHd4<1[b4B;DsN8!J#>)L]B\tZm)t
@o=f2&_J*Z80c8&f36secCsrfX+,DIP[`n0)QWmBV=Ps`U]*Le)+@Se\*3jju`SiLQ2f@E<2W
hnO9A>7(8V\Fo<hAFhFB"?FqXj#k*rqHH&-7:qq.G]=XBB'-0IVCj=WM7BAi6<U7@P]@U5Tkb
#LpeT+1HRscl.H@!2N"qhYiHcB@I1Te>ZAiYB>Re"0rr,%q1WP)F'nGF6(nZ!J"2V6i\>Ud7u
>8fth`\Te'N_f^?^?F68G;A"^D/cc+\MF2NE#KBsA&"FsMY6i\>UIMi].=kV^D5&V2RC4ZKdo
jaZkP\>6d&(glT)$1BM8:eo`r.3.P0?=?g_0;?-&+O;`'$BL:oA@mni-t`?L-PkA;P5i2IdOe
;BaB@QB0lHg`:s3$c\Ff^>J*c3]2Bp(pgn<ipGr:266H=<QqB`EW@gC7/?q7@c-F$J4oWUfI`
BOX/8&.:o#-@uog$Lr),['T.#9;[59lmF`3#:,!6l(2!!@?$^]CcTd3>oCokJg_MX'cobBAqt
c<9.n=D<a25G0u`porGYBp75VB2@1-G&@4qe?2'5m#1](q=1daP\1"fJj9GU!+eE]/mW5#D;,
hLC7%/`q#$-ij$U+>/#bVQM!/oZ'*C9]THIbAp?cJ4NZDODbEZT%G3db`2oEPN@Bd%Qf<1DI+
VpW__u09%M_DeXpAgj@!YHPD.`5-h7NEMaFFc3<iq'()SNhV<h8>n"XNnc&7/^YH?729lct@K
KHorsl'"*d[NJ76Z4]2JPruXCM[!nLMo1R[4fuO/dO\.K=pAsoC3\2bu;@,kK+ANrmY@#%^0;
3'DopRgXT"S[ONpjuI)snq^J[-7J!)[^0P-)4pl,mgV)W/ri;'m9=:^0K/,2kTm5S=2D5bG#s
UB@mKZtaEmF3cucG%*p17d>WU3G94uZ<o*WER(.=bOhtd*+akHZGiMa!MC0"Z[b6gfl1dh$\&
*Qq67M!AKE@'Y-bZ'dJ7?V67Et5./LZ<^@)(FMEh=.1M&eR>e*0M:5KR=TF;)o!47[4/7:a@1
5<*"AndpAC@X6gNj;#U$r(;Kg>_DgeY-ujkAgF9_CC1!H1IcE1e%*8$4>>G:D@dFp?aPDV*W.
^DKGaNnSl-k?CPNLQA)/7S^)DTg!MWGaPgnN7ANg[Ik#KY631akJI$eumFns@^!Ud,3kP+>@N
-C2Y7;!NKn".TJ5h0HIJpHu*mUBBDf7cb#h$TE]%abipG"QaAoC[jn`%N&&2;><SUS$NSYP]K
q!GY2\U!dYFm[nje(WTSqp<Z4,3Y!9n#%_?29JF];u\Z&l/r5kWk3KD<qkt6;]Ql!%?DI^gp&
.t`tR90`t[?Ildi2gaiR-/$AUkL(m)$,,5MpqJ+)OES*dU@qJoV,?Z#YSd?h8uU"?0bENWQW;
SS3_>@$se@'X=bP59$;:sj-%>6RL-XOegPpt<E3^V,up#XhJnd6L*j0VBh9N,ZfH*?0)?>J>K
1GZhk;:I2KPVF<Ea%s/4H%:_d+oUSUZ>\TADUU34;0DH.j(QK/'DnL/Sc>Z!?V&mGR^g:cgHF
#-8;ONk`W/?m?"U>=>@D`:rWE/l'@`=5o^,;MF`/,.9\X.d=il-i)b/O)AgD;pT1P"`bS=iE[
#+/#?<Q;(LK8sH1J7`hB1-?>O"BT]XdnH0Us(cWn*CGFo,J9S-74L)WFQcPG>6Jb-![)&cab\
`_F(\\PPtIt6kR:>8iNM,kpnG5Ldm`^YHIgWSlYKOqq[f='Eqc8%=cc+)^gu/9gWbWNR2%J$.
&prM7,MuL&\)=9UFa'<2*0m`f\hd"WWIuS\X%-29ue`F&HU6k>5ZXIZE+)eN>@(DQGRRh@.?5
!:A=q72;hhSW>qJ:ddIPR#]6]o&^Ac!Pd(OH)gf\o,=ddH^%V9r!u+?!^&@ZZDqdDth__Tqpm
H5rN]!:bD[s)tRf#RoZ9<R.f[_MJN!-sjQn<$:d4ZGNblS*F?aF@D/BO`EHYq#r2.jmh*VNAd
$4N0!(4B%=lgXd%1[Bs(.IBV&k>1>[h,]m:mbQXgpP=9ZI\5ie<KbnVQ7Z>+l#[q>DVi#DmO+
]rK\YRP3aaD=hhaY6[ZsJ(m\)2cm3;>o&TtT_:'pPrX-jZE%-ZeE+*S^RpO8n7eb?CS\5m0C3
e8#9pS7W7ag/$Q\(YUj9S!J"o_#7A9.==o^V/JBV59[/hr]Ao"8_Y62qlt;@<)GR[CMp[s%*C
rqP@?kR9&tTh!MMW_uI?3r2rKnrS#9i**]\WG54AWanGt#KM$WYGS?,4S'#Po4W%GuWV^R6:?
<g5C%WM8b.Kd'pnW_eLibps2%=MA6t^0PQ(\3Vb)!Dc;q)8iT/G96*=k:%5f\LX>CA[!Dq,^R
V8>[IUHWo$i:9A8N(@pGBUP\n2FL[[8$A8.?P:&pLh,n\"es(o+AM-Rq'AccLMAb`T7gDV9&J
J$%Zg24cr$49#-g,Ps64uSJ'G8GV4p3XS^YBLBN2-J=P!Z"ph/6CSGgbas0JCT6+s/%9()[98
5KD#P@um"&foc!o_410hu0(Z07Y7pfjat;&p+Cr$d^!<]".R)^An'f/[!9+.'"GdBmkd'"=hQ
OkVi:/O*`Fh:2P<YoFl!WXPP8R$:Z8oTS(qHg-d(0r9T*[>kEpAn)2$7p/::`C2_Rg2H4>&P4
EPGlfTCK1g,@S&@tF?:_(nIpAOaCDtee]nDA<0<4)81g^[nRQ/U*N/*kcg$btT+.D):TN5"W-
(Y#r*9r=Xpd)a:!R)O5jS[.`'9;9W>rPTTUOWO!V#jQNNV<rf=o#mAGh$M[66!s9\in$I_Pbr
B+%S7m:!gdSu\t+IE=UmD@)dB[_Oa6lpa29ZdiSibl6j:X9]gaIZea&u*OX>8p?pn>sAQap-0
=H6+U#XAfjibojP:+8oO#ApiQEGG<3N=1"Z7C@+oGsn$@GOsqb5+<Oa_D9^7h(#?&,6_i5mT0
8+,IT!_@(OjHTD/jN0NUY[:kd7!q'llc;Nn7O]7L(QliE>TEd@B9V44m.V2nhf-s:aL]10OU&
\&oOiF8to;']gJp%<Ym<i6'o!>#TYN\4:Is:Y!s/"B`2>0DX)?gesJE["H-Vf?HqsS_LpG<PY
`^o?;C=@#WL/B<"i3=S3ke`Fj\/M[r+K=9lWW'U\ne_thM7^MYpbH`&CdfRd]S=F4pr:@p'E9
\7b_L)jMEaIp?FtCUFj*:%XkepkWfP^j!S'JShRpDu2sYV&?pn?0]gi"a+pd2Gl[p=ol^DtPY
PUK:oGIc-`JrVk>JJ15TYJR(F@jli+-A':#:+<dp2.F.m#6<u4nm`Qoh:(b@-NVd1HI=m<48E
5oI1NYfrJ*?jAOrsdbSfbQ@;o`nKQ@:CJd.9n!=$]41g_aRapWjatoUQdqbZRBV"tJl`GU0\m
N'm/c6^T;b"p3J"nk/oXag#8mN3\:A4)0([cJsqVHD!5L9oZCZ-[7c20)b#Xl8bG>@cRTO\-r
kb.CZGBDO<;CrN(_Ynd_PuFY%,T7f(';J<d)tsrr@FoW?!2uMi#:aWXKf[25SmqpK8Moad\S7
?uS[io.kO[l_[sKu$$U"*0W'&A'mmE?qLgR<=oVb1*"X/2?>gVHYB?16'm^A[D^9@Kc#O"%[e
<dK9r#u^:P$@WeLrdu&!Y':h<NE6)2PPbX#.(:P<4DCMPTiqCi#a@(5ZWO4gjm.boB(aneT"L
M-#Tl/4XYR4PeE/JT=*nUb-39%'+K>`oXgl.*42p8gjj0'-9ojK.bZ$rEX'bN!k).U4aKom0f
Ng!4qhp%Lu[?aHC_WmD\@jK:&ZlShZMEV8%(en*E%m.SjmRs]`mEj@g(N=MIt2+4^fpggu#-t
obiXf;qICq\D-?KI&]ciG`V'*[:tST002RudEcN*S&W$]>(`nVJGoAo$L),pf2I1&^*f$qpY9
P"F_hBd`qjQF?L:_aEshP4oK0Gs@h1:2XK:8)J(85WSA<:cLncclSXaDQAd+&Y=W^^oV6dQJ>
GX*H\5Fhko_dtIY5Cd.Q#ql[4cV9rDS1juB4YL.7sm-4V)J:BI_Jb'i[F-Q"@5kol?(E&_l'd
up\Z3U3[SQq/A:NE^(!,;%6n'kCo$s`1g2n#$%8E;\IrI@oQu.<n@u^q0($rT45iBoLHqXC8d
fB1XeROT;UI`n`!%@`Ud2k`Q"_s'9flU%.Lf8n?5<VT(N`utI(B6f.,^UOB285OX3S49q^VJA
OR-`4=0>dG*WoB)k/u,8d'6"5UWn9N$F1b#m'6&bkl0)j8j[*D)K-onT)2-V@eWPUjes9V[mT
2boXmd3?ZQp:+8"h$YYG<GV\Fr[1]-q8YGVPVK9*\]5T]]s=[At-?J@\nq2;+K/NT.hW-h?iY
GR-#$;L>qmqY'=4[-RQrbLOPPuBT8l%o:9^7aLMX\@@F]V[H%7\tS5o[_8.:XH)M5Ll:lF3'h
K^=C`T6/XKbpN/3FYFYuC5@o)#@rV@l8@1c$q8-P40'LNEUU*r#ngTR7e:(P&FJ=A]dIZTuS_
QqB>;%F(i+?QL/5ed34$7;^7E1L&[$>@Po[1fbBW>b%LU%2s+-hVkfu%p?<g,$^b7R7@L2'f0
8=9si`#JmlouGNqAjR@A^PoEt\Zl,/oK"i[iG(ic[=;Nl*_*p.ZfcgnqVSEr*s.QWppK0TaTK
V^:<)b0bO:fUlC8WD3nIN(q+]n4r,O*Ce+$)%'SMF+O5!=t1jb[C):<l2*5q<Uli+8_MHe7nY
Hs_/.S>8LlV)0Q^:jM%Ne3AV3]Te,1HDIfegdonhht&-YstJVBf_%5Qfs9r:>Tb)^S[/^D2lO
M+rpe1*E#;nJ+7^Q6-tD/9j_)r1Sd:ep]hmBPM]18GD(EP)Ss`B-iieh?-*/=X]H:U;9(mR9;
>l[Rt?SHT7#'n>GKfo^CPgfc7"YQE\rfpNLTF.3HN4.eUif@b-WZYdZi-NK*4C=e9fsk@iB1h
%j&*emOibRO,&$fW"MA1kbNg*pK>*G=+)_!FedC[r^RX16jmj0S["bMD8D"#UM2mi)TTtA8UE
%>IT,XJ?dGlL@n-;hh\ATZbj0W&NPEi;Yp&tYfm&E3kdbkt8`M0ZiK#G9IC/jrpV5TCmNX4Fo
[hiE24d-qaa]AZ]63]_nAi,YrOkJ"N/iqLheSc6S$7)'gA9-2903%ZrBWoK6[f67PDEHof_Y>
>e?bo8eu0i`e!3Bq8MgguU.(":qH<I:&f381Wf2MP1hegq=,n&%=[$[mNZ><NSY,R>If-_39D
4p[XGR[>YK<4jC[>BpGgPiXk+Z[J5Meul9q#oK:\4CC\QsY2VOPd:d#+G-Bm2+kat&aN$j)fB
QBBUs_'0HT:p^_A*U;jeDHQ.Jf.eE[!Rd[eQ>6<W3bBjo8NK:T-iD8f?^amr.RA+(C$G]%Q+[
&jnK@XujA#qWqnY[`!Sr3=QbM@Pc\9r4n_\*hi\V[gHO`-rs.)3Zke5hho8btZc'"BB7Hna^J
%,GA#C8s-K3q7$:B*uU;iMI>k?$c*%fNTI+qX"#s/"K<5]qJdoKgoVg)YuUJ,T'0IfTGDc;n2
Jb\c`Z2r!;'<"aV7'W!]j#BG=lK[-sjH$nkQQg?T#lbuu;??A%%qacn/M8#%FB3k0o<:K2Y,P
q;%RF>Vu)AM(H+QkuHNQ.Oar*WXqrD)ScZ[8e=jE5NN5VmjI7%^"qmrLuHJFtqR(bYi08,mA/
#Xg_HK8&36B]k#@05RHheKOHq8Kf8_MGN+Eme]<k2ufP>B:>jPI>=f_TpHcsFj0M@C$YD<ZJ?
"=S8Rd?m]e9XTkSiGSG@_oDQ=FO.NrWk4lQ].XYN-;*WCIOp!co`YC1jbdqZI%TGqe=:hcirV
1+ncHY$$<NV%Ai]n5)`&F"`FjkW["Xok(%/iqo=)rdV^&L`DD)`H>3@nrRUAbYag#C#p5W3cF
$N)AEreQ=m4lt<6-4bMIelq&&t*=oN;M989bhkRs<?`gsUrrcK*nhL/.'bGL$5kt*8^V>>+;B
JLYEh.AK%d8S#peu:HcNo*C?kJ3:^d%_Fc2g[]l`8<5#AWu6E+d"E;PF2b3PR]"058NQI@p?$
A@RdRVjm-4FUi^TQHg!BDVr0FpY+Zb8!:V;HCIrdJ_IN?JI>!g]g&k0A!6SCs84\\HlRXi?N9
c-97`g!Of%$X5]u^OhV0O[oKNS,mqHTA/+/(F16:k87-K,3"+a"4e8b!(roa_LDFTj=h+%!:l
U.>uA/of4ie%5qKATh\_:AQLaV/e&r709h]bW3AlK3GqQXf:X:3i#klT":gLEH"6R.:?dB(WP
^+OPiLNh0a1>[epL:Q2:Ejt]ZeAjcJ6ao!8#kTuKC`_GNe+C-@?)f[5^eCTRiCY`X7dh<_b%0
DYM-lQ0U4A%E#2#ADOMraOsn./(X^d2ZM:``e:cga);H(or'lcd?hjL_,DXI!G]r:8N9a-uet
TqJ(/IJ@GiT76WN]2ta-995k$pV)4]5PRfjN::cCN5+:]2q\`_dp/l2Nb_hZ&a5"^GOK;&]@^
u@NZIgo1[06YT/V1bk]<fNS_Mq4R/Y]f"YV&43e.-V\F<5JG5_8[H`NRi6<IEE-Rq(]e/-Z_,
&72$@>S:Z0'L)NDr/-@YK[<%6!%nnNuk\\e#cf].VoVV!VVu5Zm];.l(@[^\GO\RS^@?!rnQP
aid6[KpZq?=^XI<IF6CiNha\6&fp8$Y?G'CT?/4bH@tr_0*b]/r\*0ORZP>'Nk\dT]&SHK=]R
CeOm+)XGIF-*QE^2k"cWQEjrn$'>M"I+lgd=FrZ#BR(G3-j]qbmKPcL8^=hnS&TRsjRpq]56>
SQVM2d;9S"3;U8;_/=AQG:.&$kJXKUgoBDkN&o,L0l']A&mZM`/$S?E7Xr1JleKhP3JdRXf&,
S@9Ps(i8,41$7]VsCIU)B<s.bW4NZS8?"U5;N?+^*]DED4np!oA;?lI#H:2&k)WV=(iF4!_>!
Ufp@lsqmJMa4)ag_hR^89KHBDAtNPXFCfR_#R:QY/@9''hLHTKB=92[Aef6li`3[j4nL:c#=\
)r?'VtepZdHot:(GL\mZJY[E$qVLA;hIYP[UqHY`6i\isf3-n9tGIAQRJf"/`[I<!SUF^u1le
QFMpF9;8s'>jCIP@Po:!,W>$C"em9$aR;-5Y=uH0@/*n:Me\:*<2oZ.+-,=f0JEX(\:.2)k^_
IABan]tp1\1Ah5PU[eTh`M=!@qu#V#.h^)V1crcOZm87JUJAP5:40G/mJl$\k^,;c2u&jM/6^
G<RUs'Q5E.E=U/$*!9Y#`eAWYUX%@6od_24c`7`V9I\:@)Q0A-nIM*%EYlFlEe,40j)coW!@'
>+V70b*,HZ!p-]Qnru>2k6.$"/`G7Y\8K$Imu$>#)2>fCa;!5:RdA?(+i_>FB0>TO-t)d-dZe
#ogJtPK8s[@h@'mc[O$:mIHJk/V:iUe4^S)G^?>-0>"GaBB2:>CBWci5=6_lrVcfhN!:)^jm^
+igH5o'`4YD/t\66Ru+K4[](j-o=kc4YOYG%POk]]oLqH5t9kkA)hpCg'kX8@,8Xo$P^s'E@Q
o_3*`(==B2bm"QBSR-rYfq'0(oC[G,Zo4!F3K"5rl)m5Q7A\>:qG_e@lgoMtlri'uPP`Xf+@$
IPB.s<o3.d`CBgJ<_C<"SUZoYg$<]["L1P>+@d\\guNQuY0CnIaWpG\AZ;$Vu[nZrGEZ3<[oZ
713'7R+5!>I.3]Ur.VqW_BT4fp*b>QJ))'Z:],_T-d3e]=g*Cq[bEL%FfSodXHeRR,*dj6>+A
qoRS3+7HB?MFk.c3+>c1gV5Xt_(V^)[l6\L3LAR?5;t0T],jR!OZa5uZbMg`5l+*FRQsbr$A<
tMkC>B<3=3mL'hpn.a4OWla>'*GNm$B;.B!7crdRu7D5L6Gqqrf^5/2FCtEm!aLDrA"F,Xkea
=!ge4_QnSKZt%t*H*Nd5\1DAV[mcpCi<Xa!ZS8nqRr6\XUUW,MEOXJdP=?.3RJG<0#%&#:g3@
rCgt>[j^[2I%"9uiqh!7%p9P9b29:$asDUnKb?AGgumlKR&WRl4Dl8.j($DHnkcISbh=O=:mS
pKZN'6JW>1IZ31fT4r5CMtpRm^E#emuP/!g%c!c[5nDf%$MGVdTI#BV`N!.A6mQu%^Vn0^\8P
7.l([qPmn=R:F[U=9!d5soT*</ICJM;f/Oi:l.b75DflJ(p0LhOac5]8nOm"_cI/JlCd8&4R`
fY`CGredRho=BS5bscjGCl@\22EUQpn&[N2=].5@_aeq=aX)Y\)Q6<DU+s$&r@A;g&l:6q.<I
VsK-r8$g=Ud2>!),B9+_C2&ehb)#9JVs;)UAjit>'p\(G?04XigU/ouJ,]DXH)/?k(\O?!moI
`Z[n#*_s#o-cX0:8lCkt7_b(OG%8<PMIOCn\?a?4s&T>$QM!Xq$$-UA%/:;MbC_^^-bl9J`O5
2dj\&9YcF*NWV"l0,QnE3uQS7CVqOG3H+=)`EA5I1V'R7akF#3ekVE9[dW>T*`3G29e!E#g.a
%Z]KJ3N*5uYf,8'?5mWQ*3k5fg!R^'lgA,K*>@qY;?FXL0kkLtHYC%r.dJ,C!+e%L)-jp*=K$
kI(dcp_7B$HcD(U2=(Zob%YKq'umhpL>[WD<ge!!$0Olki2'K!HU4.4B\bp0LDhbOU2h*iP\C
FfX"BIB=V[p#6)t!._0Af<!?cG]$5+"X!']XU@c7dl=N,CV]Q\/!H`,"<n"LP`1Ft%b61nRl>
6qK+Pe&K.fIi5SceL@Fq\i&'GKkJEOXpqnhB\Nbb)t]&*c]O@99ra>CBcZmbO>fnB":mYe-V"
TVrWP'$\'Whkl\IabR.?Sh4dbSK6Icj9c9"=f[oh&Dli^.eA)f,(ur,YOt:il6^4.a?,aQXCT
c1B<LO*5cM=c*WT&jia!g"U(8Cn&gnGp(C1S9](b%o;D"^\T4P&1M4t)4k!H)5Bu[jh#dX")u
L-Ddn`1KQ7qKURZ:g:b)KOG-_=)uQ"_`n1*Xdj%IV[f5=a2rqX^of=V93>WqP!S:&k82PisjG
ceN;PaRJ\<I6AQ7j,YX#l^X<H927qZR2'!1.QT*2F3d!^pM+(#0)Z4Z^n=-:1\rKIFA2:e@4K
f:Oj9BE0e_!V7V"moWX.)JqMRVX/S$8uqU!dH.N<F"k07ie!.[B+O(!$lW[R@5<lE5_WS&]uP
-&'>mo(*+5A25YD*ZhiLnK"<Sis+SZS,MoLtLV5?Ye8rXoH\K>IW=%V`SnX`3dR^b5_MNg?@a
6b@?ohS"ZOLlJ9'rD+j=l9MErc=0K)=]6;lb!jm`A83ps@UjeRYl-,1Q=o6HN"A6).NIIeN.-
^2c+F#W)PEXrhJ7?sih0nES;gV#-2h=9dO(#%4:c1O<[!KPqn?CN-9I8ICee(3G#XjbGd7']b
[@sHWN8q*!,0b!51o'g$qXs0l@$WR#lr!8G'+[rDK0a9-'U<90dWZ]"bP[11=.:4s(+i]h0:?
QSL>30$B(_2,l.#HPn\l=1_5:g5e)HThHJTA>^@8uIiQpbaM&(isM,ONkL]CQkF=QQ)hmmgkg
2#a)]QphEHhQh&m2Mn;JS'L/?MH_4VU@qEQiI#W9dM/UVQq$:SO#cLHN!\_HS)PI08""^%#_i
l04);)>ED9>:g"6ZM=@oV[;&]!#X57S!#]*D8\%Xc"2B?FD^ohsB.7.n&;VHmr:(pkppQnM"*
]*?kS9Tf8Y&(q^4*:oS5K!Z1[[Hqg<.c&=(b$Q/&=b?W0?K&TB`41'0VaA2E#/OO@9LCoQhN@
HIQ8"UQ\gf3o.nS[JR/,!_`b=]%t5W$cD9FKU*X0#Vnml;YT-mS'F8UUCXnbH[ScH\T>g"!fa
/mTL#;uhi*VWgM;p_3hX+2\mE"SE!)T[Z/nYoG3QF)!t--1>&e3-h56A\a<!9+:8:C-PYKbFY
5gpUM/F86V;[#%D.W1:Y`8uEA]pAkAn5Gj?CIVY,('(P[?mc>okk+D8%&>W5Q8/QFQeh"#)K0
3+faMO6=Y$.]uV80c<W=#AYB.NR\p#"KaVMUcCOZ4A;S#nF<#@#nqrGtd:8D:\+OYm3Y"(F)%
;8>KZJlW)oDWMgi5_l\hnRU#V]bdACfpGP8EG*fB9]g(p)R;]l@)S=CEl-V"qn##"3h1]LKYt
SOS7joHir1Ma_?!TK_j1*-LBXaNgA?3ugp4p\mMQkTI'[U9]:Krc#)f=_Qa)4'C%Y)4&X;#9J
,_iA""H;QUZHV7o?mcKP&u3%%6@1_E!Z=[D_.p$9,k'3E57*=LIMC\0^da`]MW7&*'4\f]a8f
tP@9#kK8(Lf/$9FK3>1k^!6^VXbd05!b`W^A-TtAXll<NB[\06Bl/WFS+B0m<cB<jbs*89XsZ
7B&uuA`R8VQ+)Jr^H'S@'6YTR;'FdPW?-T4j)0d;$FB2[[0(jMON+7>#2:EF5;'r>;V-/i(XQ
se+)%\)t-lZ0UW9PZ)g"5CRCQ@Ycd4[+fm_4=JZn@<\egeknk]Yt:67VkQ!sBfRnk4SAW0Z]N
!G%Zti]:Jgp?gW3HJh-eeA9`2/d7/:lqO<I=tEAQFh`Su*Ki1lG(/q^kG_Ts#:M(:"0_]*)Wa
[D=0;u3hm[N2pqKU7f2QK2H7\=lC&uGd;E\<0jN%oK@gs!*FNInGQQQFP4rjXQ_%j7!fqK-A$
95C(S-Jo&1Q-S(G449.em5li]p(5jij]!B4Z>XZpa:[Ds%;=I`9?Du(cZ31f"-"i_@p**$_jm
i3f0S')3+O?(bU5#FX"fn/*]/!-oupP/5GH1BP`M@3Y]5XlEuJuR02-?.=0f_QK`_%6T*JEh0
3gg[OjA*_V;K/XmBi;psYP0DB:2>^]1-!5LZ@q,#+cuI^d)VH@PjKf)0N'L?SM/j$qg@dsTAB
`iN<K:unZ+@\*,Rc^4J:*KULeX0+6U3dVV^0IY,e!1heB$'m(rC,FC5FEXA9+CFE%c?(C6c^S
VA/=h=qb!=i%oB+<(Q]*qOp2'"o.4Xjf3L6Q7?++QPQmknP,`ZL4\p!IEGl,I<(Y:Gn@/A`_B
T@#-k(HJ=OF@+@<cbcd>m:_/RhAXV]rB-hije6=70/2GOg7n'S'!p:m*YE%qD&SGK)]+/GOOC
bs-6NA&a=mOfL?S.nf\"=c**s^Zlg+3V(@E16I^kCb_(m'$gj%(Y&Wo?eXa_iTEU4oT:gc7=2
#9&FMTUBi1L?dRo886i2,+-Qs:gS1aq1*p=X)JFt!8R7&:HnAbI)[ciHT0_@&$L4XLNY3s(Ns
pjn6jdLAH"BrXS!d7Ul=QV*/5n'P/lQmnDEk^:mY7*X8N.o=]25![Nk)%hk=5^j<$F@[JTV8=
5W*<FjUT.OBUArYWa+ShR?I>9^"hk6X]9nB:FM8+d1g%g3ln`.[W*`,PqImp:'7=Gi)FN?%g-
9<AOk*]G(XOC<r^D"eA.iV6S3bA%hG:#.+ePRbH2;qL3^fo'JJ!(3g)F#18"Tdk;jVrbALFur
JD"l#*!*L-*nC!0<"rA7OX7D-(B?o-m`oKSQq+ui?FJd\T;$I^Dj$S]X5bpc+%fu7=0*.du.m
*[FkKSTGSH8Cj6O'Pd(X;OH5oWWWIR]"ZK)B+!OUabqdV6+NTbas(chp5B1'?&h1C$%h>:NS!
kLGiu1g2F@l)Rc5G-C^nAC6)>[:YWG!2.>=@n"EP*LD;NahgB!kUcju%^`j0iIM(9_YN$dZ[[
sJ.`VGapN)E"H:/cUF_%&42fB>uB>al_4AZP":RjBV].3@BcTc=X*]t9g-gH?p$Q6t5A.2WY;
N`#dJ36`_iTesomA8AA)60n&%r@<TZ/E_OT+"KuO,].PCQTr9ZT@$B"d:L5ZZYTbBlgs04aPU
+rc=P=Wc$N_AP`6S6322K5Ei7q/3ugMpk)9=WHfM,Y-eP3JeZh)L^m*YT[Kp:;&9-^@LDQ$it
P<(rqNB:rNGVC[tc>^olJi]h\H!XkW;7"r8Wi&*rA*RrZVp<JA7h)dQs)r/1/c:d=HFfI(UM[
lbgS*"R$;E@YpnQ=/<_eWR*[ZIO@E/AN"DZAG5BC'6^ZeRsuBbWtW<9I^MGZn!*VK3)C=gpN_
pb/:H^YhtoGHXE#r&?+Fu%/D&Eb7fgfSaG@MUdR#))JPHEL]:[L(fLAfa.6Zl+Pln_YIpW)[`
Y^h?V!dG.Ds>]H@G/Vo7>o#*6YA3!m+;n^Z<Xr?DPsh-_o'B#Yd/&rY*KG=Q@V(prqkG7@0RF
"T+OZ+OJ*VgX7).[@t;Q-\eDok/cDkp&W!ecR0rtQ>`t,,T-eK"7eZQCgNJVf'@89/6kT%Rca
S8B!gQe[9MEs^jQj3O7mgo9PpKJaQ)NM]'_HgR%#Fo7fhHZ09J9UC1+!US'7E+?rNE"7DKdk9
=U)j9kRbL\"oUq6dO%0sD\QJIksOCcfSubsdm:l'fVK)dCQebSdm;/AW;$T:A:qnJ?+bD:$p9
d1d!-+Ogmk-_bljltkk:HeJAJ)2q<r5d!!eCSPQ$nD!kVr-ZOD^!<g);mHA=b]:&b(W8NSg/G
`T???6:fM,q9aOB*\N[0A7:Z<#1>,dXbbVLU%kf3NLPOX1gf@)c"o$o.tgu+t+@Z+iC+lJmXu
$."e6,:Nnm[8b9u+U&PBdg7SVWr'e$c7A$BAd/WTKY'8D]]1o][qHmlQo`<DW5<;G&DaZZsba
=).MnZq47SjfACA<uj,V>X'1qA]s?71:](/:93klf"qV2mkeTe0KW`6P6Q_3JmMWCC-gXb2:b
Zk[iL6f8$6%3%3YK//;%J_hO]6(&:?TSQQ!U-=qdI&PK3Q*WF0B10*<U)$VVVDX<S&m3fuot=
<7WhgJm4r,tK88mW[&\'S5NNsB^&865'd@4AQ[nlb!BNtRpU300X7kfODd2=7Df6!<Lmk`M<l
@#Q^XrKq"?[Yd1iXZ`@FC7o_NQQ+fk*IN3EWu^.)K>',2TLk#%hCf!9PI1c`_:MYZb()/[W"N
0LT`cRR8.Y!F60@Ef3cE&a<Q2ndjS4Z.$07[j,7,q?,sH4CY"19o(q[ULW;b&CG]gm4tE/%)A
!&rkb$eXXe&=uSN(W+?9@!(jCJ3I6)Vq5$hVa>pin[kOq$;Y5ladl3qr<jg4E(Lp&+XWp=<0F
?b[Z=f%nVg\rX,$0mfsiM\e$IK7ICMmI\"ZT*>07^KpRc2fIQS"p]cpD/RgNk[ushFMd>;UYc
LpR6IhRB;a5)%8[1VhoZspI!>&9XWQGB4Odr<O4(*no,$:u1r.PcVYK1CJ6l&Q5\Y)+q,.*+n
7<PNhDFP[>KBC(&"Q;ba$>L<S%<J/XK#k_nhV/XpU=`sEqH],h8n.%l9;S"PlEa?(.K11'e<=
<fb.jk1b4`p+HFa#.;S-[2?:+]cTG$)IT_t$5/bjRc`LcSc\aq;(XbYndV&!-Xd#G"E;9>3mu
KX*R,%kUVpr'=^oN[&.8YFb8Sc^5;28MB.E#*;g(+\k06j*>]i'BS!%(lIV([:WLN4(/.1"=L
.nEM[UN/$dXF_;(>\r<3I1=Zs!+t6^JhhBLeTDjGF<Xi-,cB%0%K/^<dRQ>(\;j]s2"(.F3]-
];!:<[4XKj"01(A6Yb136\CSS4&$5-SQXb,a",Rs29l&/iVD%q6l_1d?1Je/)Hrq3#3K!'<>`
p1pE6hXD5%+YT4EcQ_"Z[S0h,.Q+,M!,>"80@ZTFeaX!<=7bIF:)&jL)T7Z]sh6\L;&J5SItG
I1ful#!X6=YC\R8Qe%WcPY?rCN5#',VB2;]fAncYh4Lj<>NZ:&gpY+ff%o>[Ap\<K]^MW^qEm
[H2SK*iY.p%K*8*OQhInXR"_AN5=+OWcX:7\\;2*04Q2O2Lb-JqN(X@V-slN=iY^].Jc_>;iC
B'F"5(bW.h0Ca2NeqO.)Ue?9"`e1WS&%g]mblS#r*`Q&"FAqefc"BZS218g.Z*g&">MPI,Cus
F*&Uf^ao6CB-bTH9jG7mZC%@oV&-e!/=X\fiUrPeEBIA/[1^\CPK3od9W;LW6dkQO["m7NT75
&6CJ'2=YJ9!\)#X?"h#dC9Z&YUDKYcg(NU_6g'AFpgk*B/C[*)3#M2p;Lb/.n^n2pNIqZ?&e&
3FC5!>62Z0<>+BatUaV7H&(1B'--:KA-lQY`[)SRsrb:VM3HO>9qr/^dF<XC+f3$+5E!Sl.5\
GmW%=1pM#jA0uF0E($l>&[mnG8l'WG_qndD=q(Zl=g7>_m"jEYKcF4`f/S5X^*?Zh7;/TsJm3
Ld8-TLnMua?1$3\Mpb0P<umrM]LoUh"!e)/5QiJ`^I+a3j1XmIC,R\'(g[6!!g+`/6G%f)Is^
E:&5e3iNtEciSJZ;R\;;Q,d"609OB%5O!=Huq::SM:YNYrq*^"*heLmmBZ-s+T45(S<iSV)qc
Tr>GmTG)W@fsk&qB!EOrql((!+Zao#Z+?HetCWcE",]H$='oN\Uf8\7r5OB8L$e.QY<;.S_:3
h1/jLE7Z/$6164[!GaJY4BgRt;C)@Am?5i^:f1O^[9is[M#b[+^7"Bm["-HomfWT<HSTS#eLK
e3CAKFgRFn4V8E'K1)SM*30M4=I>bk0\h,HK(]8m0d3F\3lGL#`qu-s5!bV$Ru\Jj>qE"n2jE
g\L1]O^uZO!"9Kk#Z+@si_0\!g^GC_:e+-oL;nDHg2m369mu6(PEkca--=Z,3HN4.)=u?V:Y@
meb2Mu]BNCK^GOCj1GOO*qIo2<*2@Q/Y6;=t_c\>aB]j;WCUbPMgh%\6%Zf'EoknO73!*Mf7!
Yj.*cTP@U<2c"U:/E`-)s^:F(o>Y2Ff&.+j=b<tlMS643*h:hak:pp[TUXDBDMKDkh7%rn!@Y
Z+qVp99fo?+6@kdjSU.uWmp>a(f<0i-A$D2gdd1nH+=+O1JICQ3RG#&f?b#!Mk^2),,6\'M6m
)OFPWIe&guun<W!"@a+K4n+Nfk@U&_CICF]s/k5H@OXgt3"Dd%Mk4:b\&#Z]:BeIY^%(m?VA/
T0M6$eb&EKEu+!8Le^16cDSj?q;kcs$tTuU&>Ie!"W]dTSm5[_DVL$3q`F'/EW@dA"<p*^.6-
hKXO3\C%:n$4=`'Vm;jZ$;;Pur^l2%k*"Vk4Vd$7Hc3m/GT?5XMi@9R53oXf6-^XK94?0;Dsl
S83d:/]K"=O@247U3`p,V+TJdJM0_i1SCd>S,o)pSqQ+:>_rP+oq1g5QiJhQ0Tj.d!-$:.&aJ
Hm"dP'(V3r+L@aTSccA(ZAfh1"IKrB2%L"[QNC?ZO'@l;m7upH8DPt=^>5L^Wp2uq[1alZ\[V
NW`dEIRXVM_O?k6eo#CnD(>Q(<lW,WbpOZdV/bqYkC+qZ%`H=O7U-&N=B/RfX/'1931%7NE7U
-K7'T]"L<F^/7Ig\DQ<p^i8=6gk(9Y:S44:(.?ZLT5t$4-e'mB(O4CYdopV"kS-:^XN`oC8=o
qpc&h%=I18qi()SGUkrqISRE6`H\^KY6PRZ%/"Fr$J&-7lm\3Qj^'Ss7T`QAT<_btS+#?',&b
CPHW4tg9W>^q/9Gg;^5-iC_Z7pI'_Q2`:8G10Bn>e)WVJ1ItXc?Q'VQS+!dUWn9N$FV%'m'6&
bkl0;X1o]P4A$70"l_$qEF61Q0Bn:_2)TS];<O2PV"$iCY&HGAF`5I=(IY:qP=gHZQ:XFZos1
ZaI2qr,+lh^;?e_.9ALO\dFfU0?14&2;*;%8,2nF>a_l94(?7W-tjEMNJhRE!:fX$KQY^MV>3
&+:nBo69WXYs/ihmbPM*+>Bqt9XDbQFR&6h[ANgA)B,XUX<):96/XKbGMToWe$cVRc\&ij1;)
3>j<%l"!";O>K;ngT0V/"l1-M9/eB-O2[Io0X"E&B@bodaC\APZH>#.Ls6qISa/'FT"Um8@7P
gR&QAIrrJDG:U<k"Xm*Pi[^rP!cW-F/2Kb`Z]%:(AE&7bt<et&q3D^X(eL1a/IUkPHc-Sc2IN
B]Qg^;"+]_^&-4I=SIWeZLYj7je0usVFfM3HD6cLgPPe<)NS!\nSJ6a9O,r$gnMH/mJf2saS2
bLt>,P[#Vfc"pRPoK*h5jUR$<18<\paJLqTh,.6DEf-,k^/T0A=*C+P\HNnDBR(K!@;_pU2/o
"$fm!L]Bu25H*DgiqJYo+k,mQ,PW,Z"X*fU.p8UQou^`'lM/D2CD71j;ipP1P>BnJC\6?VpYd
dX)<Fot(QBYZj!K0QMZ&Mi*uYrii(-d:[hBnZ_4]ZRDS#1(gVJLImB&G\+T+Jmc\ii+!+_ZQd
/nj4;pE$`a0&-H7f"_#R+6]DjQ*,M[Q$)j_2Z(RVQh<@^Y(T)2!I#EO%j+33oQ,OdXC=tDT3d
]TlD/O6&353hTPF'H<gIHXkg,.c\"I5-1:4*J1Mlh![&4-L!^U2d1R):TVZcuqO+>PcOLb2S;
8p(0%6Wh.U4u;FCk863HF2:h<Xuts7,-im9]2QCm5BKPZ;^tml=OWArYWIX_-G7MWR*66i=2b
)KX>C;i-shJ)'G\ZS7VT!QYWM&HJe,#>6rQELehL^U,dSC:jC=VdGTc"=cS*f8e5Ch0qjR$iE
b?Vh:rH?m<^#DSNPO6#Q<Td<[SIHVVE4d\TV&cXj$P^Jt;uhY58Q560=$f?"jArGDQ&p##3<O
C\P=!)fL#<a8/=D6;*&GJh\$,jMV10fC<elGWPZ-?OE:cf7YO]k"<<7\+HLK%Obc(^gd2mkeh
1Men`0+%\4NdJ&hh2G*Oi<"SC$,Kc<$6`5VD2(62&JBiZ4PK^W"#KHT[F@*0lH`RS&3kZU88/
m*cJAP6?cuf]G@8j)8#W,Pbl_&1P]!^Q.Vuj<OJ,]&u@/%0*$fu)![6!O:W4*_eFjctElLmF$
Jg"\V1ek0F4$R]3D)K4t8dX7#YP8,oX6bmrO+71*4nY&qCQBR][$iH]!4%8C"@+DPfW`3[)0>
)m.D(pR3b.V>Yr]MccP4n^Fi7:[jCm9$C:.7&[)Rm@Sqs["=pq,H]dUMan)O)m?akC(2(ElL#
!q?eqAV:RQN):G./9j.-fG;EX\-\4qc-JBBb97\O8hBKJ?0t,!Dj,PH'Vg[P"-EDiNJ=$9!Xs
^9$dFu,<FI[STp.SER1<[TQUP<qa&$bgUHQVHi3b3o(PRkdjcbB]?8K*5iV!Q;;d`3rShHr)?
i?c5AdV(456I\_.@'Iq\Z7A+AW82!0i)m8Q09,S[7*SU(4HCHFbjHd?:S+!YIBD=WR'&*GBp&
GhbtlNVN8"cHl=?]am?c;-@5R0hBHC-m6pU$BC]nIkZ+'8[CXMAAA@ih./nN)9Mea)Z]GZ5Qj
>dBH]OZn%e%A1*Ne&X.Z/UOt9*DD0MVscDX5ppIY1i<AqhB)C4G%LOt+YpS!V]oCUL-gV"L/C
3glI!UMuR#(H'jm'aVt6!TYohDh'<6hIs([<YWBV*uF++AW82!0i4!QTG!pb(t/f+W_nOXu/,
UdFa1cBAft!]4Uf+;oda+=I(OC(B,DPkK7r8Q%<r$@hR0hd/B-'-p8&OI%hX2h1u$>2Oe;[6'
]W^kkD[Y/WSOBpqG9\(VcIjl/16q"AH17M$s6gP'f2u6em#jIq+Z!%00Nt+9J38gt???CiUSq
A$-]M*-GX.Q/]:`]Beg@Jqt-l<lC;@q6u:*La[VC6/1\sW^@h5KWc,5OSrQpn(t`dB#b'>N]P
`pb<rIkT@"5+LS$TZ[r5ViM3e-)s*7MHeu45(^Um?.U\f&WMh7@m)5(W7IFdi*:Ptg[btYaMq
p`OaSas+5I^TaeE^S$N"$i7WSa!/grdkVpp$UYJp=el]@gkE#iFCFSFH!8%Y$A661BefmqJB<
9>#cR`*=_c9s.)5qm&d.pG&9Mf')mjEh!\OQ?pSq]Sin)Y?i%IIDteV6VUn/La1kB15E:3e`f
1r'\'niUS=HZF-LL^)[<:fdnG9)iB@#.IUZZZFI!jZ*Fn+J1qKkW"m^F5)q$[>AC(P'3fBMtV
hkf5.2E_j8Dr(oW3haUX*hRm'!9=`C#_:?#a3o+ip@$mWYK\\BW86Laeu45gW.XCs]P_N7\JG
E[\rH]5!JoVFDtW]nWO!]F>Pu_L(9QdYmP2b!\t=h9$%)!+e;8,;o5<#uE8neBqbtU*""&LrE
2)OD%t$FsJfVPMh#oP70LurW'7?2K5cJFEJBE@n%V[n6CXAc]/_Qm3+hsgFj\r9&YC8qe<Ve_
X&^k>([7\0?E1^f,&X>-I1k%ih:+CnEn'u16h*+oCm)^?=&d1F90?C*hd,T<r<-g.h(kVf4]\
JBn<f\D-immJq1nslumr8$)qbp'l\'L]G?BqaO-7d`R@n4$>!-ppS!hbc7hE`0$FbFu+g(dB9
>"0DTiPni1b1b71J^YOLTeRac0b$ei4'6B_7?'%4Gk#7?K4k6uL;E-T8kE[/h:/nPq!?;+Qd+
X8QgJ,>RA'OpapTl8@.u>\$60e6L_cC(#Q^$""<mh<9;P2%!%9@lX?^kCV_V*EQ7+G&<5.I\/
j8p\@s/As;\j<+[Vb!;Z?Yc&Z2m5A&;U<723f)Z`'kOUJ!%8s:uLFj5oLEaaGV^cB_R[nVh*^
QCSg](1qlGqF'2-B!>Gom#_5fOBoBu#B^H82DrE>d=EGHTm5/"f:h;n<?:;Ve#$W=#$:9uj;B
XW[3\CDo<<OKG8l$=eoB4GTV+E.bM(YZ,<7(mDeBrE.(>dO*j)0siStjEL8]E"aJ9t'A#go_b
rX/5sOCue+"TXjc>#hIrB:On:g!^i4,V.%g"/=>_j(?b,3`J;@#o,9VSKJ&#OV!<K5fm]PJR=
]XLOmePJ:8^S!<<*"O?1C;z80*6e!!!"Le.IK:!!!!i*J"Ir!!%Q!&VpDe!!#P1JHu5U!.`Q2
L]@DT!(\,]#QOi)J<UrCrrWrDZ5tonU9st$!!#SZ:.26O@"J
ASCII85End
End
