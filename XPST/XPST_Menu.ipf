#pragma rtGlobals=1		// Use modern global access method.
#pragma hide=1

 menu "XPST"
		
	"Fit Assistant", /Q, XPSTFA#LaunchCursorPanel()
	"Thickness Calculation", /Q, XPSTTC#LaunchSTThicknessPanel()	
	"Reduce Points", /Q, XPSTRP#LaunchSingleWavePanel()
	"Subtract Baseline", /Q, XPSTBL#LaunchLinePanel()
	"Subtract Shirley", /Q, XPSTSP#LaunchShirlPanel()
	"-"
	"Help", /Q, NotifyHelp()
end
