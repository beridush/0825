[General]
SyntaxVersion=2
BeginHotkey=113
BeginHotkeyMod=0
PauseHotkey=113
PauseHotkeyMod=2
StopHotkey=113
StopHotkeyMod=3
RunOnce=1
EnableWindow=
MacroID=ebada94c-a45a-4a84-81c7-346283aecf1c
Description=龍騎士炸點數喝水_後台
Enable=0
AutoRun=0
[Repeat]
Type=0
Number=1
[SetupUI]
Type=2
QUI=
[Relative]
SetupOCXFile=
[Comment]

[Script]
/*******************
工作環境 
小型工作列2列
楓之谷視窗化，維持在初始左上角不動，不調整視窗大小

hp筆電座標 <- Hankv4座標
x-4,y-3 <- x,y
以下都以Hankv4座標為準 
血條 左上228,611 右下332,624 中心點280,618(617.5) 中心點色碼0000DD
幽靈船6 人站到最左邊 色碼88FFFF x座標25 人站到最右邊 x座標122 中心點x73.5
*******************/

UserVar job_uservar = DropList{"黑騎士":"黑騎士"|"火毒":"火毒"|"聖騎士":"聖騎士"|"神射手":"神射手"}=0 "角色" '差別在於輔助技能
UserVar who_keep_hp_uservar = DropList{"腳本":"腳本"|"寵物":"寵物"}=0 "誰喝紅水"
'是否要維持人物在幽靈船6的中間方便炸圖
UserVar is_central_uservar = DropList{"好":"好"|"不要":"不要"}=0 "地圖中央"
/*
停用 = 要自己放輔助技能,自己打怪,應該會搭配腳本喝紅水使用
只放輔助 = 手動練等時讓腳本定時放輔助技能
全自動=會放輔助技能也會按全圖技,應該會搭配地圖中央使用
*/
UserVar skill_mode_uservar = DropList{"停用":"停用"|"只放輔助":"只放輔助"|"全自動":"全自動"}=0 "按技能"
UserVar sell_equipment_delay_uservar = 0 "賣裝間隔(秒)" '0=不賣裝
UserVar sell_equipment_start_uservar = 97 "賣裝範圍起點"
UserVar sell_equipment_end_uservar = 97 "賣裝範圍終點"

Global MAPLESTORY_WINDOW_CLASS, LIFE_X, LIFE_Y, LIFE_COLOR, _
MINI_MAP_X, MINI_MAP_Y, MINI_MAP_COLOR, MINI_MAP_CENTRAL_X, _
FDM, SDM, HWND

'需要轉全域變數的UserVar
Global WHICH_COMPUTER, JOB, SKILL_MODE, SELL_EQUIPMENT_DELAY, SELL_EQUIPMENT_START, SELL_EQUIPMENT_END

MAPLESTORY_WINDOW_CLASS = "MapleStoryClass"
LIFE_X = 272
LIFE_Y = 588
LIFE_COLOR = "ee0000" '大漠=rrggbb 799x599=dd0000 800x600=ee0000 大漠色碼慣用小寫英文字母

MINI_MAP_X = 127 '幽靈船6小地圖的右下角座標
MINI_MAP_Y = 135
MINI_MAP_COLOR = "ffff88" '小地圖自己的色碼 大漠=rrggbb 大漠色碼慣用小寫英文字母
MINI_MAP_CENTRAL_X = 66 '幽靈船6的中心X座標

FDM = 1.0 'FLASK_DURATION_MULTIPLE
SDM = 0.5 'SKILL_DURATION_MULTIPLE

HWND = Plugin.Window.Foreground()
'HWND = 336544

JOB = job_uservar
SKILL_MODE = skill_mode_uservar
SELL_EQUIPMENT_DELAY = sell_equipment_delay_uservar
SELL_EQUIPMENT_START = sell_equipment_start_uservar
SELL_EQUIPMENT_END = sell_equipment_end_uservar


Set dm = createobject("dm.dmsoft")
dm_ret = dm.Reg("adern93e07d8fb879d35106ab6068bb76dac95","test.ver.info")
If dm_ret = 1 Then 
	TracePrint "大漠付費註冊成功"
Else 
	TracePrint "大漠付費註冊失敗,返回值是:" & dm_ret
	EndScript
End If

dm.SetPath "C:\DaMo" '設定大漠插件基本目錄
dm_ret = dm.BindWindowEx(hwnd, "gdi", "normal", "dx.keypad.state.api", "", 0)


DimEnv THREAD_ID_LIFE_FLASK, _
       THREAD_ID_KEEP_CENTRAL, _
       THREAD_ID_FLASK_AND_SKILL, _
       THREAD_ID_SELL_EQUIPMENT

If who_keep_hp_uservar = "腳本" Then 
	THREAD_ID_LIFE_FLASK = BeginThread(life_flask) '後台改寫完成
End If

If is_central_uservar = "好" Then 
	THREAD_ID_KEEP_CENTRAL = BeginThread(keep_central) '後台改寫完成
End If

If SKILL_MODE <> "停用" Then 
	THREAD_ID_FLASK_AND_SKILL = BeginThread(flask_and_skill) '後台改寫完成
End If

/*
還沒改寫成後台
If SELL_EQUIPMENT_DELAY > 0 Then 
	THREAD_ID_SELL_EQUIPMENT = BeginThread(sell_equipment)	
End If
*/

Do While True '無限迴圈防止腳本停止
    Delay 1000   
Loop
  
Sub life_flask()
	Set dm = createobject("dm.dmsoft")
	dm_ret = dm.BindWindowEx(hwnd, "gdi", "normal", "dx.keypad.state.api", "", 0)
	Do While True
		
		'str_color = Plugin.Bkgnd.GetPixelColor(HWND, LIFE_X, LIFE_Y)
		str_color = dm.GetColor(LIFE_X, LIFE_Y)
		If str_color <> LIFE_COLOR Then
			'Call Plugin.Bkgnd.KeyPress(Hwnd, 54) '6
			dm.KeyPressChar "6"
			TracePrint "喝紅水 " & Plugin.Sys.GetDateTime
			
			Dim is_percent_flask : is_percent_flask = True
			If is_percent_flask Then
				Delay 0.6 * 1000 '楓之谷UI回血動畫，如果喝的是照比例補的大水，就可以延遲久一點避免浪費
			End If
		End If
		Delay 0.1 * 1000
	Loop
End Sub

Sub flask_and_skill()
	Set dm = createobject("dm.dmsoft")
	dm_ret = dm.BindWindowEx(hwnd, "gdi", "normal", "dx.keypad.state.api", "", 0)
	Dim supports_1 '因為Global不支援陣列只能寫在這裡
	'所有需要定時吃或施放的東西都寫入陣列裡
	'按鍵, 持續時間, TracePrint用, 上次按鍵時間(ms), 持續時間倍率
	
	If JOB = "黑騎士" Then 
		supports_1 = Array( _
                           Array("8", 600, "敏捷藥丸(+迴避率)", -1, 0.9), _
                           Array("9", 600, "命中藥丸", -1, 0.9), _
                           Array("0", 300, "加量章魚燒", -1, 0.9), _
                           Array("-", 600, "速度藥丸", -1, 0.9), _
                           Array("S", 200, "快速之槍", -1, 0.9), _
                           Array("D", 165, "禦魔陣", -1, 0.9), _
                           Array("F", 300, "神聖之火", -1, 0.9), _
                           Array("=", 180, "寵物食品", -1, 1), _
                           Array("G", 300, "楓葉祝福", -1, 0.9), _
                           Array("H", 1200, "暗之靈魂", -1, 0.9) _
                          )
	ElseIf JOB = "火毒" Then
		supports_1 = Array( _
                           Array("8", 600, "敏捷藥丸(+迴避率)", -1, 0.9), _
                           Array("9", 600, "命中藥丸", -1, 0.9), _
                           Array("0", 300, "雙份日式炒麵", -1, 0.9), _
                           Array("-", 600, "速度藥丸", -1, 0.9), _
                           Array("S", 600, "魔心防禦", -1, 0.9), _
                           Array("D", 110, "極速詠唱", -1, 0.9), _
                           Array("G", 300, "楓葉祝福", -1, 0.9), _
                           Array("=", 180, "寵物食品", -1, 1) _
                          )
	ElseIf JOB = "聖騎士" Then
		supports_1 = Array( _
                           Array("8", 600, "敏捷藥丸(+迴避率)", -1, 0.9), _
                           Array("9", 600, "命中藥丸", -1, 0.9), _
                           Array("0", 300, "加量章魚燒", -1, 0.9), _
                           Array("-", 600, "速度藥丸", -1, 0.9), _
                           Array("S", 200, "快速之棍", -1, 0.9), _
                           Array("D", 300, "聖靈之棍", -1, 0.9), _
                           Array("F", 300, "格擋", -1, 0.9), _
                           Array("Y",  21, "鬼神之擊", -1, 1), _
                           Array("=", 180, "寵物食品", -1, 1), _
                           Array("G", 300, "楓葉祝福", -1, 0.9) _
                          )
	ElseIf JOB = "神射手" Then
		supports_1 = Array( _
                           Array("8", 600, "敏捷藥丸(+迴避率)", -1, 0.9), _
                           Array("9", 600, "命中藥丸", -1, 0.9), _
                           Array("0", 300, "加量章魚燒", -1, 0.9), _
                           Array("-", 600, "速度藥丸", -1, 0.9), _
                           Array("S", 200, "快速之弩", -1, 0.9), _
                           Array("D", 600, "無形之箭", -1, 0.9), _
                           Array("F", 300, "會心之眼", -1, 0.9), _
                           Array("H", 180, "黑暗狙擊", -1, 0.9), _
                           Array("V", 200, "召喚銀隼", -1, 0.9), _
                           Array("=", 180, "寵物食品", -1, 1), _
                           Array("G", 300, "楓葉祝福", -1, 0.9) _
                          )
	End If

	dimensional_1_max_index = UBound(supports_1)
	dimensional_2_max_index = UBound(supports_1(0))
	'宣告(x,y)這種陣列，只能填入常數數字，無法使用變數宣告，所以必須根據supports_1的大小修改本列
	'20是先擴多一點以免不夠用
	Dim supports_2(20, 4)
	For i = 0 To dimensional_1_max_index
		For j = 0 To dimensional_2_max_index
			supports_2(i, j) = supports_1(i)(j)
		Next
	Next
	
	' (x, y)版本
	Do While True
		For i = 0 To UBound(supports_2)
			If VarType(supports_2(i, 0)) = vbEmpty Then 
				'遇到空的就不繼續
				Exit For
			End If
			now_ms = Plugin.Sys.GetTime()
    		If supports_2(i, 3) = - 1  Or now_ms - supports_2(i, 3) >= supports_2(i, 1) * 1000 * supports_2(i, 4) Then 
				Delay 1.5 * 1000 '短時間內放太多不同招,楓之谷無法接受
				If SKILL_MODE = "只放輔助" Then 
					'手動練等時不會停下來等腳本放招,所以要按多次一點
					'KeyPress supports_2(i, 0), 5
					For 5
						dm.KeyPressChar supports_2(i, 0)
					Next
				ElseIf SKILL_MODE = "全自動" Then
    				'KeyPress supports_2(i, 0), 1
    				dm.KeyPressChar supports_2(i, 0)
				End If
				TracePrint supports_2(i, 2) & " " & Plugin.Sys.GetDateTime
    			supports_2(i, 3) = now_ms
			End If
		Next
		
		If SKILL_MODE = "只放輔助" Then 
			Delay 0.1 * 1000
		ElseIf SKILL_MODE = "全自動" Then 
			'KeyPress "T", 1 '全圖技
			dm.KeyPressChar "T"
			If JOB = "黑騎士" Then 
				Delay 1 * 1000
			ElseIf JOB = "火毒" Then
				'火流星清比較快,而且硬直很久,不用太密集放招也沒關係,不然沒辦法走回中間
				'Delay 2 * 1000
				Randomize
				lowerbound = 2000
				upperbound = 5000
				rnd_ms = Int((upperbound - lowerbound + 1) * Rnd + lowerbound)
				TracePrint "Delay "&rnd_ms
				'Delay rnd_ms
				Delay 1 * 1000 '101 CD
			Else 
				Delay 1 * 1000
			End If
		End If
	Loop
End Sub

Sub keep_central()
	Set dm = createobject("dm.dmsoft")
	dm_ret = dm.BindWindowEx(hwnd, "gdi", "normal", "dx.keypad.state.api", "", 0)
	Dim last_arrow : last_arrow = "none"
	Do While True
		dm_ret = dm.FindColor(0,0,MINI_MAP_X,MINI_MAP_Y,MINI_MAP_COLOR,1.0,0,intX,intY)
		'FindColor 0,0,MINI_MAP_X,MINI_MAP_Y,MINI_MAP_COLOR,intX,intY
		If dm_ret = 1 Then 
			If intX < MINI_MAP_CENTRAL_X And last_arrow <> "go_right" Then 
				/*
				KeyUp "Left", 1
				KeyUp "Right", 1
				KeyDown "Right", 1
				*/
				dm.KeyUpChar "Left"
				dm.KeyUpChar "Right"
				dm.KeyDownChar "Right"
				last_arrow = "go_right"
				TracePrint "往右走 "&Plugin.Sys.GetDateTime
			ElseIf intX >= MINI_MAP_CENTRAL_X And last_arrow <> "go_left" Then 
				/*
				KeyUp "Left", 1
				KeyUp "Right", 1
				KeyDown "Left", 1
				*/
				dm.KeyUpChar "Left"
				dm.KeyUpChar "Right"
				dm.KeyDownChar "Left"
				last_arrow = "go_left"
				TracePrint "往左走 "&Plugin.Sys.GetDateTime
			End If
		End If
		Delay 5 * 1000
	Loop
End Sub

Sub sell_equipment()
	Dim last_sell_ms : last_sell_ms = Plugin.Sys.GetTime()
	Dim now_ms
	Do While True
		now_ms = Plugin.Sys.GetTime()
		If now_ms - last_sell_ms > SELL_EQUIPMENT_DELAY * 1000 Then 
			Call Plugin.Sys.SetCLB("@販售道具 裝備欄 "&SELL_EQUIPMENT_START&" "&SELL_EQUIPMENT_END)
			
			PauseThread THREAD_ID_LIFE_FLASK
			PauseThread THREAD_ID_KEEP_CENTRAL
			PauseThread THREAD_ID_FLASK_AND_SKILL
			
			KeyPress "Enter", 1 '進入輸入模式
			Delay 250
			KeyPress "Up", 1
//			KeyDown "Ctrl", 1
//			KeyPress "V", 1
//			KeyUp "Ctrl", 1
			Delay 250
			KeyPress "Enter", 1 '送出
			Delay 250
			KeyPress "Esc", 1 '離開輸入模式
			Delay 250
			
			ContinueThread THREAD_ID_LIFE_FLASK
			ContinueThread THREAD_ID_KEEP_CENTRAL
			ContinueThread THREAD_ID_FLASK_AND_SKILL
			
			last_sell_ms = now_ms
		End If
		Delay 1 * 1000
	Loop
End Sub

Sub OnScriptExit()
	TracePrint "OnScriptExit 解除綁定"
	dm.UnBindWindow
End Sub
