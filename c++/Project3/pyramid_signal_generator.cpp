/*#include<iostream>

int main() {
	int N;
	int i, j, x, y;
	int Line;
	
	while (true) {
		std::cout << "1~9사이의 높이를 입력하세요.: ";
		std::cin >> N;
		if (N == 0) {
			std::cout << "프로그램을 종료합니다.";
			break;
		}
		if (N < 1 || N >9) {
			std::cout << "입력 오류: 1~9 사이의 숫자만 가능합니다." << std::endl;
			continue;
		}
		for (i = 1; i <= N; i++) {
			for (int x = 0; x < N - i;x++) {
				std::cout << " ";
			}
			for (int y = 0; y < 2 * i - 1;y++) {
				std::cout << "*";
			}
			std::cout << std::endl;
		}
	}
	return 0;
}*/