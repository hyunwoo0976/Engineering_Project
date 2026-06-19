#include<iostream>

int main() {
	double voltage;
	int i;

	while (true) {
		std::cout << "전압을 입력하세요(V): ";
		std::cin >> voltage;
		if (voltage == -1) {
			break;
		}
		else {
			for (i = 0; i < (int)voltage; i++) {
				std::cout << "*";
			}
			std::cout << std::endl;
		}
	}
	return 0;
}