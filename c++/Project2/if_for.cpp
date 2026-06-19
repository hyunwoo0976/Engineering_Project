/*#include<iostream>

int main_old() {
	double voltage;
	int i;

	for (i = 0; i < 5; i++) {
		std::cout << "측정된 전압을 입력하세요 (V):";
		std::cin >> voltage;
		std::cout << i + 1 << "번째 측정";
		if (voltage >= 5.0) {
			std::cout << "상태 : High! (위험! 과전압 발생)" << std::endl;
		}
		else if (voltage >= 3.0 && voltage < 5.0) {
			std::cout << "상태: Normal (정상 범위)" << std::endl;
		}
		else {
			std::cout << "상태: Low! (저전압 발생)" << std::endl;
		}
	}
	return 0;
}*/