a=100
print(type(a))
b=0
print(type(b))
c="홍길동"
print(type(c))
d=3.2
print(type(d))

grade_list=[100,90,85,95,"80"]
print(grade_list[2])
print(grade_list[0]+grade_list[1])
print(type(grade_list))
print(grade_list[4])

new_list=[]
new_list.append(100)
new_list.append(85)
new_list.append(100)
new_list.append(40)
new_list.append(100)
print(f"{new_list}")
new_list.remove(100)
print(new_list)
del new_list[0]
del new_list[-1]            #-1, 마지막값 삭제
print(new_list)

new1_list=[100,20,30,40,20]
a=new1_list.pop(0)
print(new1_list,a)
new1_list.clear()
print(new1_list)