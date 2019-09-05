#pragma rtGlobals=1		// Use modern global access method.

Menu "Useful Tools"
  "changeColor"
End

Proc changeColor(base)
	variable base
	String list =  TraceNameList("", ";", 1)
	Variable abc
	abc = changeColorFunc(list,base)
End

Function changeColorFunc(list,base)
	String list
	variable base
	Variable nmax	
	String wvName
	Variable r, g, b
	Variable i
	String legendStr = ""
	Variable nextTrace = 0
	Silent 1
	nmax = ItemsInList(list)
	list = SortList(list, ";",16)
		for( i = 0; i <nmax; i += 1)
		HLS2RGB(270*(nmax-i-1)/nmax, 0.5, 0.8, r, g, b)
		//HLS2RGB(270*i/nmax, 0.5, 0.8, r, g, b)
		wvName = StringFromList(i, list)
		ModifyGraph RGB($wvName) = (r*65535, g*65535, b*65535)
		ModifyGraph offset($wvName)={0,base*i}
		if(6*i/((nmax > 1) ? nmax - 1 : 1) >= nextTrace)
			legendStr += "\\s("+wvName+") "+wvName+"\r"
			nextTrace += 1
		endif
	endfor
	legendStr = RemoveEnding(legendStr)
	Legend/C/N=traceColor/J/A=RT legendStr
	return 0
End

Function HLS2RGB(h, l, s, red, green, blue) //hue:[0 360] lightness*[0 1] saturation[0 1] rgb[0 1]
	Variable h, l, s
	Variable &red, &green, &blue
	Variable maximum, minimum
	
	
	if(s == 0)
		red = l; green = l; blue = l
		return 0
	endif
	
	maximum = (l <= 0.5) ? l*(1+s) : l*(1-s) + s
	minimum = 2*l - maximum
	substitute(red, mod(h +120, 360), maximum, minimum)
	substitute(green, h, maximum, minimum)
	substitute(blue, mod(h +240, 360), maximum, minimum)
End

Function substitute(value, a, maximum, minimum)
	Variable &value
	Variable a, maximum ,minimum
	if(a < 60)
		value = minimum+(maximum - minimum)*a/60
	elseif(a < 180)
		value = maximum
	elseif(a < 240)
		value = minimum+(maximum - minimum)*(240-a)/60
	else
		value = minimum
	endif
End
