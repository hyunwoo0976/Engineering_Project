/*#include<iostream>

int main() {
	double voltage[10];
	int i;
	double max, min;

	std::cout << "1번째 전압을 입력하세요";
	std::cin >> voltage[0];

	max = voltage[0];
	min = voltage[0];

	for (i = 1; i < 10; i++) {
		std::cout << i + 1 << "번째 전압을 입력하세요";
		std::cin >> voltage[i];
		if (voltage[i] >= max) {
			max = voltage [i];
		}
		if (voltage[i] < min) {
			min = voltage[i];
		}
	}

	std::cout << "최대값" << max << "이고, 최솟값은 " << min << "이다" << std::endl;
	return 0;
}*/