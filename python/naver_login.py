from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
from datetime import datetime

#python ./python/naver_login.py

NAVER_ID = "아이디 입력"
NAVER_PW = "비밀번호 입력"

TARGET_HOUR = 14
TARGET_MINUTE = 7

def wait_until_target_time():
    print("⏳ 목표 시간까지 대기 중...")
    while True:
        now = datetime.now()
        if now.hour == TARGET_HOUR and now.minute == TARGET_MINUTE:
            print(f"✅ {TARGET_HOUR}:{TARGET_MINUTE:02d} 도달! 시작합니다.")
            break
        time.sleep(1)

def naver_login():
    # 수동 설치한 chromedriver 경로
    service = Service("D:/My project/Engineering_Project/python/chromedriver.exe")
    
    options = webdriver.ChromeOptions()
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    
    driver = webdriver.Chrome(service=service, options=options)
    wait = WebDriverWait(driver, 10)

    try:
        driver.get("https://www.naver.com")
        print("🌐 네이버 접속 완료")
        time.sleep(2)

        login_btn = wait.until(EC.element_to_be_clickable(
            (By.XPATH, "//a[contains(@href,'nidlogin.login')]")
        ))
        print("✅ 로그인 버튼 찾음")
        login_btn.click()
        print("✅ 로그인 버튼 클릭")
        time.sleep(2)

        id_input = wait.until(EC.presence_of_element_located((By.ID, "id")))
        id_input.clear()
        id_input.send_keys(NAVER_ID)
        print("✅ 아이디 입력 완료")

        pw_input = driver.find_element(By.ID, "pw")
        pw_input.clear()
        pw_input.send_keys(NAVER_PW)
        print("✅ 비밀번호 입력 완료")

        submit_btn = driver.find_element(By.ID, "log.login")
        submit_btn.click()
        print("🚀 로그인 시도!")

        time.sleep(5)
        print("🎉 완료!")

    except Exception as e:
        print(f"❌ 오류 발생: {e}")

    finally:
        time.sleep(5)
        driver.quit()

wait_until_target_time()
naver_login()