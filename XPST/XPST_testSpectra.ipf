#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma ModuleName = XPSTtestSpectra



static function main(variable amplitude)

	//---- Gauss Peaks
	make /d /n=1000 /o RegularGauss
	wave RG = RegularGauss
	SetScale /I x, 275, 295, RG
	RG = amplitude*sqrt(4*ln(2)/pi)*exp(-4*ln(2)*(x-285)^2)
	
	make /d /n=1000 /o RegularGaussRev
	wave RGR = RegularGaussRev
	SetScale /I x, 295, 275, RGR
	RGR = amplitude*sqrt(4*ln(2)/pi)*exp(-4*ln(2)*(x-285)^2)
	
	//---- Lorentz Peaks
	make /d /n=1000 /o RegularLorentz
	wave RL = RegularLorentz
	SetScale /I x, 275, 295, RL
	RL = amplitude*(1/(2*pi))*1/((1/2)^2+(x-285)^2)
	
	//Pseudo-Voigt

	duplicate /O RL RegularVoigt
	wave RV = RegularVoigt
	RV += RG
	RV /= 2   //0.5*Gauss and 0.5*Lorentz

end


static function info()
	print "\n"
	print "**************************************************"
	print "Info for testSpectra#main(<area>)"
	print "**************************************************"
	
	print "The parameter determines the area under the curves.\n\n"
	print "For example: testSpectra#main(0.1) creates two Gaussians,"
	print "a Lorentzian, and a Pseudo-Voigt (1:1 Gauss and Lorentzian characteristics)"
	print "- all with an area of 0.1."
	
end