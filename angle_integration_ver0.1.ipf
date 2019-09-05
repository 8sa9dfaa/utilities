#pragma rtGlobals=1		// Use modern global access method.
macro angle_integration(wavenam,saveas)
string wavenam,saveas
Prompt wavenam,"Select wave",popup wavelist("*",";","") 
variable line,raw
variable i,j
//string wavenam="Sum"
silent 1
pauseupdate
//wavenm="sum"+num2str(i)
line=DimSize($wavenam, 1)
raw=DimSize($wavenam, 0)
Make/N=(raw)/D/O $saveas
$saveas=0

setscale/P x, (Dimoffset($wavenam,0)), (Dimdelta($wavenam,0)), "KE (eV)", $saveas

//j=0
//do
	i=0
	do
		
//		$saveas[j]+=$wavenam[j][i]
		$saveas += $wavenam[p][i]	
		i+=1
	while(i<line)
//	j+=1
//while(j<raw)


endmacro