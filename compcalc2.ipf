#pragma rtGlobals=1	// Use modern global access method and strict wave access.

Function CompCalc(w, fitw)
	Wave w	// fit parameter入ってるwave (デフォルト: w_coef) を指定
	wave fitw	//fit_XX を指定
	
	duplicate/O fitw LBG, P1, P2	//fitカーブと同じ点数、同じエネルギー範囲でwave作成
	Wave LBG, P1, Pw

//以下、各ピーク成分に分けて計算
	LBG = w[0]+w[1]*x
	P1 = w[2]*exp(-((x-w[3])/w[4])^2)
	P2 = w[5]*exp(-((x-w[6])/w[7])^2)
end