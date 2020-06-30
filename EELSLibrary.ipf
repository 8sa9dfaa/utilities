//EELSライブラリの読み込み
Menu "Useful Tools"
	"LoadLibrary"
end

Function LoadLibrary()
	
	silent 1
	Delayupdate
	
	SetDataFolder root://カレントディレクトリーを変更
	
	NewDataFolder/O/S EELSLibrary
	NewPath/C/O myPath,"\Igor Procedures\EELSLibrary"//Igor Procedure内のEELSLibraryを指定
	variable i;i=0
	do
		LoadWave/O/H/D/W/P=myPath IndexedFile(myPath,i,".ibw")//myPathのIgor(.ibw)ファイルを開く
		i+=1
	while(Cmpstr(Indexedfile(myPath,i,".ibw"),"")!=0)//.ibwファイルがなくなるまで繰り返し
	
	SetDataFolder root://カレントディレクトリーを変更
	
	//dataの読み込みは
	//	display :EELSLibrary:wave名
	//等で
end

//EELSライブラリの保存
//＊既にあるライブラリは消せない
//＊名前を変更すると多重保存してしまう
Menu "Useful Tools"
	"SaveLibrary"
end

Function SaveLibrary()
	
	silent 1
	Delayupdate
	
	SetDataFolder root:EELSLibrary//カレントディレクトリーを変更
	
	NewPath/C/O myPath,"\Igor Procedures\EELSLibrary"//Igor Procedure内のEELSLibraryを指定
	variable i;i=0
	do
		Save/C/O/P=myPath $WaveName("",i,4) as WaveName("",i,4)+".ibw"//myPathにIgor(.ibw)ファイルを保存
		i+=1
	while(Cmpstr(WaveName("",i,4),"")!=0)//.waveファイルがなくなるまで繰り返し
	
	SetDataFolder root://カレントディレクトリーを変更
end

///////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//名前が先頭数字だとよくないので緊急用のRenameマクロ

macro RenameAddLib()
	
	silent 1
	Delayupdate
	
	SetDataFolder root:EELSLibrary//カレントディレクトリーを変更
	string nam
	NewPath/C/O myPath,"\Igor Procedures\EELSLibrary"//Igor Procedure内のEELSLibraryを指定
	variable i;i=0
	do
		//nam="Lib"+WaveName("",i,4)
		Rename $WaveName("",i,4) $"Lib"+WaveName("",i,4)
		//kill WaveName("",i,4)//myPathにIgor(.ibw)ファイルを保存
		i+=1
	while(Cmpstr(WaveName("",i,4),"")!=0)//.waveファイルがなくなるまで繰り返し
	
	SetDataFolder root://カレントディレクトリーを変更
end