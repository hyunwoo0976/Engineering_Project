kor=float(input("국어 : "))
eng=float(input("영어 : "))
math=float(input("수학 : "))

tot=(kor+eng+math)
avr=tot/3

print(f"총점 : {tot}")
print(f"평균 : {avr:.2f}")