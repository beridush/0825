#-*-coding:UTF-8 -*-
#coding = utf-8

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import Select
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.chrome.service import Service
import time
import datetime
import selenium
import urllib.parse
import sqlite3
import re
import json
from msvcrt import getch
# import requests

####################################################
CHROME_DRIVER_PATH = R'D:\重灌備份\使用者資料夾\[Python]\UberEats外送熱點彙整\chromedriver.exe'
SQLITE_DATABASE_PATH = R'D:\重灌備份\使用者資料夾\[Python]\UberEats外送熱點彙整\data.db'
HOME_URL = 'https://www.ubereats.com/tw'
WAIT_BROWSER_SEC = 2
DB_CONNECTION = None
DB_CURSOR = None
DRIVER = None
WAIT = None

# ADDRESS = '桃園市觀音區觀新路56號' #觀音區公所
# ADDRESS = '桃園市觀音區中山路二段668號' #新坡派出所
# ADDRESS = '桃園市觀音區大同一路22號' #和勝企業股份有限公司
ADDRESS = '草漯國中'
####################################################

def find_element_custom(selector):
    try:
        return DRIVER.find_element(By.CSS_SELECTOR, selector)
    except selenium.common.exceptions.NoSuchElementException:
        return None


def find_element_text_custom(selector, text_when_element_not_found):
    try:
        return DRIVER.find_element(By.CSS_SELECTOR, selector).text
    except selenium.common.exceptions.NoSuchElementException:
        return text_when_element_not_found


def get_restaurant_address():
    try:
        elem_p = DRIVER.find_element(By.CSS_SELECTOR, 'p.bx.c5.dc')
        address = elem_p.text #連子節點的字串都會抓到
        for elem in elem_p.find_elements(By.CSS_SELECTOR, '*'): #獲得所有子節點
            address = address.replace(elem.text, '') #將子節點字串逐個移除
        address = address.strip()
        if address[-1] == ',': #如果最後一個字元是逗號
            address = address[:-1] #移除最後一個字元
        return address
    except selenium.common.exceptions.NoSuchElementException:
        return None


def sleep_and_print(seconds, description): #不考慮傳入非整數的情況
    print(f'{description} sleep ', end='', flush=True)
    while seconds > 0:
        print(f'{seconds}..', end='', flush=True)
        time.sleep(1)
        seconds -= 1
    print() #換列


def main():
    db_setting('on')
    # get_restaurant_detail_of_district('XinWu', '新屋區')
    # get_restaurant_detail_of_district('GuanYin', '觀音區')
    # get_restaurant_detail_of_district('DaYuan', '大園區')
    print('1:抓取餐廳ID與URL 2:用已有的ID抓取詳細資料')
    op = int(input('選擇:'))
    if op == 1:
        district_en, district_zh = choose_district()
        get_restaurant_id_of_district(district_en, district_zh)

    elif op == 2:
        district_en, district_zh = choose_district()
        get_restaurant_detail_of_district(district_en, district_zh)

    db_setting('off')
    quit()
    ######################     以下先不做     ######################

    for index, href in enumerate(hrefs_restaurant):
    # for href in hrefs_restaurant:
        print(f'\r{index+1}/{len_hrefs}', end='')
        DRIVER.get(href)
        DRIVER.execute_script("document.querySelectorAll('div.cv.dw.cd.ag.c0 > span').forEach(span => span.parentElement.removeChild(span))") #用JS移除多餘的span否則會影響describe字串
        # input() #debug當斷點用
        name = find_element_text_custom('h1.ec.ed', '查詢餐廳名字失敗')
        describe = find_element_text_custom('div.cv.dw.cd.ag.c0', '查詢描述失敗').replace('\r', '').replace('\n', '').strip() #運費、運送時間、評價
        rating = find_element_text_custom('div.cv.dw.cd.ag.c0 > div:nth-last-child(3)', '查詢星數失敗').strip()
        count = find_element_text_custom('div.cv.dw.cd.ag.c0 > div:nth-last-child(1)', '查詢評價次數失敗').replace('500+', '500').replace('(', '').replace(')', '').strip()
        address = get_restaurant_address()

        with open('output.tsv', 'a+', encoding='UTF-8') as f:
            print(f'{datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\t{urllib.parse.unquote(href)}\t{name}\t{address}\t{rating}\t{count}\t{describe}', file=f)
        
def choose_district():
    DB_CURSOR.execute("SELECT en,zh FROM DistrictMapping")
    rows_district_mapping = DB_CURSOR.fetchall()
    for index, row in enumerate(rows_district_mapping):
        print(f'{index}:{row[1]} ', end='', flush=True)
    print() #換列
    op_district = int(input('選擇:'))
    return rows_district_mapping[op_district][0], rows_district_mapping[op_district][1]
    

def get_restaurant_id_of_district(district_en, district_zh):
    global DB_CURSOR
    DB_CURSOR.execute("SELECT Id,Road FROM Address WHERE District = ? AND LastUse IS NULL", [district_zh])
    rows = DB_CURSOR.fetchall()
    for row in rows:
        count_used = DB_CURSOR.execute("SELECT COUNT(*) FROM Address WHERE District = ? AND LastUse IS NOT NULL", [district_zh]).fetchone()[0]
        count_not_yet = DB_CURSOR.execute("SELECT COUNT(*) FROM Address WHERE District = ? AND LastUse IS NULL", [district_zh]).fetchone()[0]
        count_all = DB_CURSOR.execute("SELECT COUNT(*) FROM Address WHERE District = ?", [district_zh]).fetchone()[0]
        count_current_district_restaurant = DB_CURSOR.execute(f"SELECT COUNT(*) FROM {district_en}").fetchone()[0]
        print(f'{district_zh} 已使用:{count_used} 未使用:{count_not_yet} 總共:{count_all} 餐廳URL:{count_current_district_restaurant}')
        get_restaurant_id_of_address(district_en, district_zh + row[1])
        DB_CURSOR.execute("UPDATE Address SET LastUse = ? WHERE Id = ?", [datetime.datetime.now(),row[0]]) #該地址使用過以後留一個timestamp
        DB_CONNECTION.commit()


def get_restaurant_id_of_address(district_en, address):
    browser_setting('on')
    DRIVER.get(HOME_URL)
    elem_address = DRIVER.find_element(By.CSS_SELECTOR, 'input#location-typeahead-home-input')
    elem_address.click()
    elem_address.send_keys(address)
    sleep_and_print(3, '等待地址選單跳出') #等待地址選單跳出
    elem_address.send_keys(Keys.RETURN) #按Enter

    '''原本全部餐廳都顯示完的時候，「顯示更多餐廳」的按鈕會消失，所以可以用這個
    try:
        for i in range(99999):
            WAIT.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'button.be.bf.bg.bh.bi.bj.ag.bk.bl.b6.bm.bn.bo.bp.bq.br.bs'))).click()
            print(f'{datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")} loop {i} finish')
    except selenium.common.exceptions.TimeoutException:
        pass #已經沒有更多餐廳了，離開迴圈
    '''

    #一直點按鈕讓所有的餐廳都出現在頁面上
    for i in range(99999):
        DRIVER.execute_script("window.scrollTo(0, document.body.scrollHeight)") #捲動到頁面底部比較方便肉眼除錯
        try:
            WAIT.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'div.gh.gi.gj.gg.gx'))) #找不到結果，出現這個東西時要離開迴圈
        except selenium.common.exceptions.TimeoutException: #找不到「找不到結果」=還有餐廳
            try:
                WAIT.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'button.be.bf.bg.bh.bi.bj.ag.bk.bl.b6.bm.bn.bo.bp.bq.br.bs'))).click()
            except selenium.common.exceptions.TimeoutException: #「顯示更多餐廳」按鈕消失
                break
            else:
                print(f'{datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")} loop {i} finish')
        else: #找到「找不到結果」=已經沒餐廳了
            break

    #把每間餐廳的網址存在hrefs_restaurant
    elems_restaurant_anchor = DRIVER.find_elements(By.CSS_SELECTOR, 'div.gl.gq.gr > div.h5 > div.af.al > a')
    hrefs_restaurant = [elem.get_attribute('href') for elem in elems_restaurant_anchor]
    len_hrefs = len(hrefs_restaurant)
    print(f'開始遍歷{len_hrefs}家餐廳頁面')

    for href in hrefs_restaurant:
        m = re.match(r'https:\/\/www\.ubereats\.com\/tw\/store\/(.+?)\/(.+)', href)
        # restaurant_name = urllib.parse.unquote(m.group(1)) #覺得店名還是Detail的時候再抓比較好
        restaurant_id = m.group(2)
        restaurant_url = href
        if is_restaurant_exist(district_en, restaurant_id): #如果DB已經有這個ID就不INSERT
            continue
        else:
            DB_CURSOR.execute(f"INSERT INTO {district_en} (Id,Url,IdTime) VALUES (?,?,?)", [restaurant_id, restaurant_url, datetime.datetime.now()])
            DB_CONNECTION.commit()
    
    browser_setting('off')


def get_restaurant_id_of_multiple_address(list_address):
    for address in list_address:
        get_restaurant_id_of_address(address)


def get_restaurant_detail_of_district(district_en, district_zh):
    global DB_CURSOR
    browser_setting('on')
    DB_CURSOR.execute(f"SELECT Id FROM {district_en} WHERE DetailTime IS NULL")
    rows = DB_CURSOR.fetchall()

    # for row in rows:
    for index, row in enumerate(rows):
        count_has_detail = DB_CURSOR.execute(f"SELECT COUNT(*) FROM {district_en} WHERE DetailTime IS NOT NULL").fetchone()[0]
        count_no_detail = DB_CURSOR.execute(f"SELECT COUNT(*) FROM {district_en} WHERE DetailTime IS NULL").fetchone()[0]
        count_all = DB_CURSOR.execute(f"SELECT COUNT(*) FROM {district_en}").fetchone()[0]
        print(f'{district_zh} 已詳查:{count_has_detail} 未詳查:{count_no_detail} 總共:{count_all} {datetime.datetime.now()}')
        get_restaurant_detail_of_id(district_en, row[0])
        if index != 0 and index % 50 == 0:
            print('重啟瀏覽器避免記憶體溢出')
            browser_setting('off')
            browser_setting('on')
    browser_setting('off')


def get_restaurant_detail_of_id(district_en, id):
    url = DB_CURSOR.execute(f"SELECT Url FROM {district_en} WHERE Id = ?", [id]).fetchone()[0]
    DRIVER.get(url)
    # DRIVER.execute_script("document.querySelectorAll('div.cv.dw.cd.ag.c0 > span').forEach(span => span.parentElement.removeChild(span))") #用JS移除多餘的span否則會影響describe字串
    try:
        webelement_script = DRIVER.find_element(By.CSS_SELECTOR, 'main#main-content > script[type="application/ld+json"]')
    except selenium.common.exceptions.NoSuchElementException: #這裡沒有餐點可提供…
        return 
    restaurant_detail = json.loads(webelement_script.get_attribute('innerHTML')) #用.text只能得到空字串
    name = restaurant_detail['name']
    try:
        star = restaurant_detail['aggregateRating']['ratingValue']
        times = restaurant_detail['aggregateRating']['reviewCount']
    except KeyError: #有些餐廳沒有星數&評價次數，就跳過
        # star = None
        # times = None
        return
    address = get_restaurant_address()


    # a = restaurant_detail['openingHoursSpecification'][0]['opens']
    # b = restaurant_detail['openingHoursSpecification'][0]['closes']
    # print(f'{name} {a} {b}')

    # if name and star and times and address:
    if True:
        DB_CURSOR.execute(f"UPDATE {district_en} SET Name = ?, Address = ?, Star = ?, Times = ?, DetailTime = ? WHERE Id = ?", [name,address,star,times,datetime.datetime.now(),id]) #該地址使用過以後留一個timestamp
        DB_CONNECTION.commit()
    else: #只要其中一項是None就不寫入DB
        return


def db_setting(switch):
    global DB_CONNECTION, DB_CURSOR
    if switch == 'on':
        DB_CONNECTION = sqlite3.connect(SQLITE_DATABASE_PATH)
        DB_CURSOR = DB_CONNECTION.cursor()
    elif switch == 'off':
        DB_CURSOR = None
        DB_CONNECTION.close()
        DB_CONNECTION = None


def browser_setting(switch):
    global DRIVER, WAIT
    if switch == 'on':
        # DRIVER = webdriver.Chrome(executable_path=CHROME_DRIVER_PATH)

        # options = webdriver.ChromeOptions()
        # options.add_experimental_option("excludeSwitches", ["enable-automation"])
        # options.add_experimental_option('useAutomationExtension', False)
        # options.add_experimental_option("prefs", {"profile.password_manager_enabled": False, "credentials_enable_service": False})
        #, chrome_options=options
        DRIVER = webdriver.Chrome(service=Service(CHROME_DRIVER_PATH))
        DRIVER.maximize_window()
        sleep_and_print(WAIT_BROWSER_SEC, f'等待{WAIT_BROWSER_SEC}秒以確保瀏覽器啟動完成')
        WAIT = WebDriverWait(DRIVER, 5)
    elif switch == 'off':
        DRIVER.close()
        DRIVER = None
        WAIT = None
        sleep_and_print(WAIT_BROWSER_SEC, f'瀏覽器關閉後等待{WAIT_BROWSER_SEC}秒避免馬上再次開啟發生問題')

def is_restaurant_exist(district_en, id):
    global DB_CURSOR
    DB_CURSOR.execute(f"SELECT COUNT(*) FROM {district_en} WHERE Id = ?", [id])
    if DB_CURSOR.fetchone()[0] >= 1:
        return True
    else:
        return False


if __name__ == '__main__':
    main()