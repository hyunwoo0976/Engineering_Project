#include<iostream>

int main() {
	int age;
	double weight;

	int a = 10;
	int b = 3;

	std::cout << "당신의 나이는 ? : ";
	std::cin >> age;

	std::cout << "당신의 몸무게는 ? : ";
	std::cin >> weight;

	std::cout << "당신의 나이는 " << age << "살 입니다." << std::endl;
	std::cout << "무게가" << weight << "라니! 정말 돼지시군요!!!" << std::endl;

	std::cout << "더하기: " << age + weight << std::endl;
	std::cout << "빼기: " << age - weight << std::endl;
	std::cout << "곱하기: " << age * weight << std::endl;

	std::cout << "나누기(정수): " << age / weight << std::endl;

	std::cout << "나누기(실수): " << (double)age / weight << std::endl;

	std::cout << "나머지: " << a % b << std::endl;
	return 0;
}