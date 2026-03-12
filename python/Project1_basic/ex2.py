name=input("이름을 입력하세요:")
age=input("나이를 입력하세요:")
print("당신의 이름은",name,"이고 나이는",age,"입니다")

year,month,day=input("당신이 태어난 해의 년도, 월 ,일을 차례대로 입력하세요.:").split() #.split()을 해야 여려개의 input가능

print(f"{name}씨! 당신의 생년월일은 {year}년 {month}월 {day}일입니다")