//EELS���C�u�����̓ǂݍ���
Menu "Useful Tools"
	"LoadLibrary"
end

Function LoadLibrary()
	
	silent 1
	Delayupdate
	
	SetDataFolder root://�J�����g�f�B���N�g���[��ύX
	
	NewDataFolder/O/S EELSLibrary
	NewPath/C/O myPath,"\Igor Procedures\EELSLibrary"//Igor Procedure����EELSLibrary���w��
	variable i;i=0
	do
		LoadWave/O/H/D/W/P=myPath IndexedFile(myPath,i,".ibw")//myPath��Igor(.ibw)�t�@�C�����J��
		i+=1
	while(Cmpstr(Indexedfile(myPath,i,".ibw"),"")!=0)//.ibw�t�@�C�����Ȃ��Ȃ�܂ŌJ��Ԃ�
	
	SetDataFolder root://�J�����g�f�B���N�g���[��ύX
	
	//data�̓ǂݍ��݂�
	//	display :EELSLibrary:wave��
	//����
end

//EELS���C�u�����̕ۑ�
//�����ɂ��郉�C�u�����͏����Ȃ�
//�����O��ύX����Ƒ��d�ۑ����Ă��܂�
Menu "Useful Tools"
	"SaveLibrary"
end

Function SaveLibrary()
	
	silent 1
	Delayupdate
	
	SetDataFolder root:EELSLibrary//�J�����g�f�B���N�g���[��ύX
	
	NewPath/C/O myPath,"\Igor Procedures\EELSLibrary"//Igor Procedure����EELSLibrary���w��
	variable i;i=0
	do
		Save/C/O/P=myPath $WaveName("",i,4) as WaveName("",i,4)+".ibw"//myPath��Igor(.ibw)�t�@�C����ۑ�
		i+=1
	while(Cmpstr(WaveName("",i,4),"")!=0)//.wave�t�@�C�����Ȃ��Ȃ�܂ŌJ��Ԃ�
	
	SetDataFolder root://�J�����g�f�B���N�g���[��ύX
end

///////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//���O���擪�������Ƃ悭�Ȃ��̂ŋً}�p��Rename�}�N��

macro RenameAddLib()
	
	silent 1
	Delayupdate
	
	SetDataFolder root:EELSLibrary//�J�����g�f�B���N�g���[��ύX
	string nam
	NewPath/C/O myPath,"\Igor Procedures\EELSLibrary"//Igor Procedure����EELSLibrary���w��
	variable i;i=0
	do
		//nam="Lib"+WaveName("",i,4)
		Rename $WaveName("",i,4) $"Lib"+WaveName("",i,4)
		//kill WaveName("",i,4)//myPath��Igor(.ibw)�t�@�C����ۑ�
		i+=1
	while(Cmpstr(WaveName("",i,4),"")!=0)//.wave�t�@�C�����Ȃ��Ȃ�܂ŌJ��Ԃ�
	
	SetDataFolder root://�J�����g�f�B���N�g���[��ύX
end