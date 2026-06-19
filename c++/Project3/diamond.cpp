#include<iostream>

int main() {
	int N;
	int i, j;

	while (true) {
		std::cout << "1~9까지 숫자를 입력하세요.";
		std::cin >> N;
		if (N == 0) {
			std::cout << "종료되었습니다" << std::endl;
			break;
		}
		if (N < 1 || N >9) {
			std::cout << "오류!! 1에서 9까지의 숫자를 입력해주세요.";
			continue;
		}
		for (i = 1; i < N + 1; i++) {
			for (int x = 0; x < N - i; x++) {
				std::cout << " ";
			}
			for (int y = 0; y < 2 * i - 1;y++) {
				std::cout << "*";
			}
			std::cout << std::endl;
		}
		for (j = N+1; j < 2 * N ; j++) {
			for (int a = 0; a < j - N; a++) {
				std::cout << " ";
			}
			for (int b = 0; b < (2 * N - 1) - 2 * (j - N); b++) {
				std::cout << "*";
			}
			std::cout << std::endl;
		}
	}
	return 0;
}