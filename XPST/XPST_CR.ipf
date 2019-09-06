#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma moduleName = CursorRange


static function wCut()
	
	string targetName //= CsrWave(A)+"_c"

	// All that stuff  only prevents user errors - maybe Igor has not the most efficient language
	strswitch (CsrWave(A))
		case "":       //A not on graph
			strswitch (CsrWave(B) )
				case "":  // B missing as well
					DoAlert 0, "Please set cursor A and B on the curve to mark the range wich you want to cut. Use Ctrl+I to activate cursors..."
					return 1
				default:
					DoAlert 0, "You also have to use cursor A"
					return 1 // A is not there but B
			endswitch
		break
		default:       // A is on graph
			strswitch (CsrWave(B) )
				case "":  // B is missing
					DoAlert 0, "You have also to use cursor B"
					return 1
				default:
				break // A and B are there, proceed
			endswitch
		endswitch
	string tempTargetName
	variable i=1
		//this part needs to deal with different data folders and tell the user
	//where the new wave was created
	wave originalWave = CsrWaveRef(A)
	//get the data folder
	targetName = GetWavesDataFolder(originalWave,2) + "_c"
	
	do
		tempTargetName = targetName + num2istr(i)
		i+=1
	while(exists(tempTargetName))

	
	targetName = tempTargetName
	//duplicate /O /R=(hcsr(A),hcsr(B)) $(CsrWave(A)), $targetName
	duplicate /O /R=(hcsr(A),hcsr(B)) originalWave, $targetName
	Display /K=1 $targetName
	//change the name for modify graph
	//extract the part after the last : from targetName
	variable items = ItemsInList(targetName,":")
	string bareName = stringFromList(items-1,targetName,":") 
	ModifyGraph rgb($bareName) = (0,0,65500)  // Color code it accordingly

end


static function xyCut()
	strswitch (CsrWave(A))
		case "":       //A not on grah
			strswitch (CsrWave(B) )
				case "":  // B missing as well
					DoAlert 0, "Please set cursor A and B on the curve to mark the range which you want to cut. Use Ctrl+I to activate cursors..."
					return 1
				default:
					DoAlert 0, "You also have to use cursor A"
					return 1 // A is not there but B
			endswitch
		break
		default:       // A is on graph
			strswitch (CsrWave(B) )
				case "":  // B is missing
					DoAlert 0, "You have also to use cursor B"
					return 1
				default:
				break // A and B are there, proceed
			endswitch
		endswitch
	
	string LastGraphName = WinList("*", "", "WIN:")
	
	//print LastGraphName
	//string name = XWaveRefFromTrace( LastGraphName,CsrWave(A))
	

	wave originalWave = CsrWaveRef(A)
	wave xVals = CsrXWaveRef(A)
	
	string targetName = GetWavesDataFolder(originalWave,2) + "_c"
	string targetX = GetWavesDataFolder(xVals,2) + "_c"
	
	
	string tempTargetNameY, tempTargetNameX
	variable i=1
	do
		tempTargetNameY = targetName + num2istr(i)
		tempTargetNameX = targetX + num2istr(i)
		i+=1
	while(exists(tempTargetNameY))
	
	targetName = tempTargetNameY
	targetX = tempTargetNameX
	

	
	duplicate /o /r=(pcsr(A),pcsr(B)) originalWave, $targetName
	duplicate /o /r=(pcsr(A),pcsr(B)) xVals, $targetX
	
	display /K=1 $targetName vs $targetX
	
	variable items = ItemsInList(targetName,":")
	string bareName = stringFromList(items-1,targetName,":") 
	ModifyGraph rgb($bareName) = (0,0,65500)  // Color code it accordingly
	
end




//////////////////////////////////////////////////////////////////////////////////////////////////////////
//		Peak Integration
////////////////////////////////////////////////////////////////////////////////////////////////////////

static Function xyArea()
	//place the cursors on the graph, make sure both are there!
	print "Use this function if you have a plot of wave 'A' vs. wave 'B'!"

	strswitch (CsrWave(A))
		case "":       //A not on graph
			strswitch (CsrWave(B) )
				case "":  // B missing as well
					DoAlert 0, "Please set cursor A and B on the curve to mark the range which you want to cut. Use Ctrl+I to activate cursors..."
					return 1
				default:
					DoAlert 0, "You also have to use cursor A"
					return 1 // A is not there but B
			endswitch
			break
		default:       // A is on graph
			strswitch (CsrWave(B) )
				case "":  // B is missing
					DoAlert 0, "You have also to use cursor B"
					return 1
				default:
					break // A and B are there, proceed
			endswitch
	endswitch

	string LastGraphName = WinList("*", "", "WIN:")
	wave xvals = XWaveRefFromTrace(LastGraphName,CsrWave(A))
	wave yVals = CsrWaveRef(A)



	variable offset
	// compensate for values below zero
	if (yvals[pcsr(A)]<0 || yvals[pcsr(B)] < 0)
		offset = abs(min(yVals[pcsr(A)], yVals[pcsr(B)]))
		yvals += offset
	endif

	//get the area between the cursors
	print "The area between", xvals[pcsr(A)], "and", xvals[pcsr(B)] , "with background is:"
	variable areaRaw =abs(areaXY(xvals,yvals, xvals[pcsr(A)], xvals[pcsr(B)] ) )
	print areaRaw


	//subtract the base-area
	print "The area without background is:"
	variable baseline = abs(xvals[pcsr(A)] - xvals[pcsr(B)])

	variable rectHeight = abs(min(yVals[pcsr(A)], yVals[pcsr(B)]))
	variable areaBackground = baseline * rectHeight   // rectangular region
	areaBackground += 0.5 * baseline * ( abs(max(yVals[pcsr(A)], yVals[pcsr(B)])) - abs(min(yVals[pcsr(A)], yVals[pcsr(B)])) )  // + triangle
	variable areaCorrect = areaRaw - areaBackground

	print areaCorrect

end



static Function wArea()
	//place the cursors on the graph, make sure both are there!
	strswitch (CsrWave(A))
		case "":       //A not on graph
			strswitch (CsrWave(B) )
				case "":  // B missing as well
					DoAlert 0, "Please set cursor A and B on the curve to mark the range which you want to cut. Use Ctrl+I to activate cursors..."
					return 1
				default:
					DoAlert 0, "You also have to use cursor A"
					return 1 // A is not there but B
			endswitch
			break
		default:       // A is on graph
			strswitch (CsrWave(B) )
				case "":  // B is missing
					DoAlert 0, "You have also to use cursor B"
					return 1
				default:
					break // A and B are there, proceed
			endswitch
	endswitch

	string LastGraphName = WinList("*", "", "WIN:")
	//wave xvals = XWaveRefFromTrace(LastGraphName,CsrWave(A))
	wave yVals = CsrWaveRef(A)
	variable offset
	// compensate for values below zero
	if (yvals[xcsr(A)]<0 || yvals[xcsr(B)] < 0)
		offset = abs(min(yVals[xcsr(A)], yVals[xcsr(B)]))
		yvals += offset
	endif

	//get the area between the cursors
	print "The area between", xcsr(A), "and", xcsr(B) , "with background is:"
	variable areaRaw = abs(area(yvals, xcsr(A), xcsr(B) )) 
	print areaRaw


	//subtract the base-area
	print "The area without background is:"
	variable baseline = abs(xcsr(A) - xcsr(B))

	variable rectHeight = abs(min(yVals[pcsr(A)], yVals[pcsr(B)]))
	variable areaBackground = baseline * rectHeight   // rectangular region
	areaBackground += 0.5 * baseline * ( abs(max(yVals[pcsr(A)], yVals[pcsr(B)])) - abs(min(yVals[pcsr(A)], yVals[pcsr(B)])) )  // + triangle
	variable areaCorrect = areaRaw - areaBackground

	print areaCorrect

end


