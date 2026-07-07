from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
from datetime import datetime

#python ./python/keyescape.py

# ⏰ 실행할 시간 설정
TARGET_HOUR = 15
TARGET_MINUTE = 4

def wait_until_target_time():
    print("⏳ 목표 시간까지 대기 중...")
    while True:
        now = datetime.now()
        if now.hour == TARGET_HOUR and now.minute == TARGET_MINUTE:
            print(f"✅ {TARGET_HOUR}:{TARGET_MINUTE:02d} 도달! 시작합니다.")
            break
        time.sleep(1)

def keyescape_reservation():
    service = Service("D:/My project/Engineering_Project/python/chromedriver.exe")

    options = webdriver.ChromeOptions()
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--no-sandbox")
    # 실제 사람처럼 보이게 User-Agent 설정
    options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36")

    driver = webdriver.Chrome(service=service, options=options)
    wait = WebDriverWait(driver, 10)

    try:
        # 버튼 클릭 없이 바로 예약 페이지로 이동
        driver.get("https://www.keyescape.com/reservation.php")
        print("🌐 예약 페이지 직접 접속!")
        time.sleep(3)
        print("🎉 완료! 현재 URL:", driver.current_url)

    except Exception as e:
        print(f"❌ 오류 발생: {e}")

    finally:
        time.sleep(10)
        driver.quit()

wait_until_target_time()
keyescape_reservation()