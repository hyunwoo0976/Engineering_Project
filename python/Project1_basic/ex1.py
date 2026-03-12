print("(5+5)*4/2=",(5+5)*4/2)                   #20.0으로 출력
print("python"+"program")                       #두 문장이 붙어서 출력
print("python","program")                       #두 문장이 한 칸 띄어서 출력
print("python","program",sep=" and ")           #두 문장 사이 " and "출력
print(10+10)                                    #20출력
print(10,10)                                    #10 10 출력
print("파이썬"*5)                                #파이썬 문장 5번연달아출력
print("python"+str(5))                          #python5로 출력 str은 문자열 함수임
print("a","b","c",sep="")                       #공백 없이 출력
print("a","b","c",sep=" or ")                   #공백에 " or "출력 즉, a or b or c로 출력
print("국어=%d, 수학=%d, 영어=%d" %(100,90,85))   #%d는 정수형 숫자
print("원의 넓이=%5.2f" %(5*6*3.14))             #%5.2f면 전체숫자가 5글자임. =94.20, 6.2면 최소 6글자 = 94.20처럼 앞에 한칸이 띄워져있음
print("이름:{}, 나이:{}".format("홍길동",20))     #{}은 format 안에 데이터
print("{0}은 초등학교 재학중이고 가장 높은성적은 {1}, 그 다음은{2}이다. {0}은 {1}과목을 잘한다고 소문나있다.".format("홍길동","수학","국어"))
                                                #{0}은 format 0번째에있는 데이터 {2}는 {0},{1}을 지나 {2}위치에 있는 데이터
name="홍길동"
age=20
print(f"이름은 {name}이고 나이는 {age}이다")        #name에 값할당,age에 값할당하고 f-string으로 변수 대입
line="python"
print(f"공부하고있는 언어는 :{line:<10}이다")
print(f"공부하고있는 언어는 :{line:^10}이다")
print(f"공부하고있는 언어는 :{line:>10}이다")        #f"표시할 문자열{변수:정렬기호 자릿수}

city="PAJU"
print("안녕하세요 "+name+" 입니다.")
print("제 나이는 "+str(age)+"세이며,", end="")
print("\t\t사는 곳은 "+city+"이며 "+"고향도 \""+city+"\"입니다.") #보통은 f많이씀

kor,eng,math=100,80,75
print(f"수학은 {math}점, 국어는 {kor}점, 영어는 {eng}점입니다. 총점은 {kor+eng+math}입니다")

basic=2000000
bonus=500000
salary=basic+bonus
print("{0}씨 월급은 기본급{1:,} 보너스{2:,}, 총급여액 {3:,}이다.".format(name,basic,bonus,salary)) #숫자 데이터 세자리마다 콤마 단위를 주기위해 {형식규칙:,}.format(값)

num1=450000
num2=10000.42113
print("num1 변수 {0:0,.2f}, num2 변수 {1:015,.2f}".format(num1,num2)) #{0:0,.2f}에서 맨앞 0은 뒤에 0번쨰 데이터, :0은 나머지를 0으로 채워라 만약 015면 15칸의 숫자중 빈칸을 0으로 채워라 .2f는 소수 2자리까지 출력

