#pragma rtGlobals=1	// Use modern global access method and strict wave access.

Function CompCalc(w, fitw)
	Wave w	// fit parameter�����Ă�wave (�f�t�H���g: w_coef) ���w��
	wave fitw	//fit_XX ���w��
	
	duplicate/O fitw LBG, P1, P2	//fit�J�[�u�Ɠ����_���A�����G�l���M�[�͈͂�wave�쐬
	Wave LBG, P1, Pw

//�ȉ��A�e�s�[�N�����ɕ����Čv�Z
	LBG = w[0]+w[1]*x
	P1 = w[2]*exp(-((x-w[3])/w[4])^2)
	P2 = w[5]*exp(-((x-w[6])/w[7])^2)
end