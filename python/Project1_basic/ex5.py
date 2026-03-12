name=(input("이름을 입력하세요:"))
city, gu, dong=(input("당신이 사는 주소를 시, 구, 동으로 구분하여 입력하세요:")).split(",")

print(f"{name}씨! 당신이 사는 곳은 {city}시 {gu}구 {dong}동 입니다")