#include <iostream>
#include <string>
#include <cstdint>
#include <vector>
#include <iomanip>
#include <cstring> 
#include <cfloat>   
#include <cmath>    
#include <cerrno>   

// 기계어 코드와 원본 어셈블리어를 함께 묶어서 저장할 구조체
struct InstructionRecord {
    uint32_t code;
    std::string asm_text;
};

// 레지스터 문자열("x1" 또는 "f1" 등)을 숫자(1 등)로 변환하는 함수
int parseReg(const std::string& regStr) {
    if (regStr.empty()) return 0;
    if (regStr[0] == 'x' || regStr[0] == 'X' || regStr[0] == 'f' || regStr[0] == 'F') {
        return std::stoi(regStr.substr(1));
    }
    return std::stoi(regStr);
}

// 사용자 입력 문자열에서 'x10^'이나 '*10^'을 C++ 표준 'e' 표기법으로 변환해주는 전처리 함수
std::string preprocessNumber(std::string s) {
    // 공백 제거 (편의상)
    // "2.4 x 10^21" 같은 형태를 처리하기 위해 x10^ 형태 치환
    size_t pos;
    while ((pos = s.find("x10^")) != std::string::npos) {
        s.replace(pos, 4, "e");
    }
    while ((pos = s.find("X10^")) != std::string::npos) {
        s.replace(pos, 4, "e");
    }
    while ((pos = s.find("*10^")) != std::string::npos) {
        s.replace(pos, 4, "e");
    }
    return s;
}

// 문자열이 유효한 숫자(정수 또는 실수)인지 확인하는 함수
bool isNumberOrFloat(const std::string& s) {
    if (s.empty()) return false;
    std::string converted = preprocessNumber(s);
    char* end = nullptr;
    std::strtof(converted.c_str(), &end);
    return end == converted.c_str() + converted.length();
}

// 프로그램 시작 시 출력할 사용설명서 함수
void printManual() {
    std::cout << "==================================================\n";
    std::cout << "            RISC-V Mini Assembler v2.0            \n";
    std::cout << "==================================================\n";
    std::cout << "[ 명령어 형식 안내 ]\n";
    std::cout << "1. R-type (add, sub, sll, srl, sra)\n";
    std::cout << "   -> 형식: 명령어 rd, rs1, rs2 (예: add x1 x2 x3)\n";
    std::cout << "2. I-type (addi, andi, jalr, lw, flw)\n";
    std::cout << "   -> 형식: 명령어 rd, rs1, imm (예: flw f1 x2 20)\n";
    std::cout << "3. S-type (sw, fsw)\n";
    std::cout << "   -> 형식: 명령어 rs2, rs1, imm (예: fsw f1 x2 4)\n";
    std::cout << "4. B-type (beq, bne, blt, bge)\n";
    std::cout << "   -> 형식: 명령어 rs1, rs2, imm (예: beq x1 x2 16)\n";
    std::cout << "5. J-type (jal)\n";
    std::cout << "   -> 형식: jal rd, imm         (예: jal x1 100)\n";
    std::cout << "6. Floating-Point R-type (fadd, fsub, fmul)\n";
    std::cout << "   -> 형식: 명령어 rd, rs1, rs2 (예: fadd f1 f2 f3)\n";
    std::cout << "7. 특별 명령어 및 값 입력\n";
    std::cout << "   -> loop                      (출력: 0000006F)\n";
    std::cout << "   -> 정수 입력 (예: 10)        (출력: 0000000A)\n";
    std::cout << "   -> 실수 입력 (예: 3.14, 2.4x10^21 등 지원)\n";
    std::cout << "   * FPU 범위 초과 시 자동 Error 처리\n";
    std::cout << "--------------------------------------------------\n";
    std::cout << "입력을 마치고 변환하려면 'end'를 입력하세요.\n";
    std::cout << "==================================================\n\n";
}

int main() {
    while (true) { // 전체 프로그램 반복 루프 (다시 시작 기능용)
        printManual(); // 사용설명서 출력

        std::vector<InstructionRecord> history; // 헥스 코드와 원본 텍스트를 저장할 벡터

        while (true) { // 명령어 입력 루프
            std::string uop;
            std::cout << "명령어 입력 (변환: end) >> ";
            std::cin >> uop;

            // 'end'를 입력하면 입력 루프 종료 및 변환 시작
            if (uop == "end") {
                break;
            }

            uint32_t machine_code = 0;
            std::string asm_line = uop; // 원본 어셈블리 텍스트 조합용

            // 0-1. 특별 명령어: loop (무한 루프 0000006F)
            if (uop == "loop") {
                machine_code = 0x0000006F;
                asm_line = "loop (jal x0, 0)";
            }
            // 0-2. 숫자(정수 또는 실수, x10^ 표기 포함)만 입력한 경우
            else if (isNumberOrFloat(uop)) {
                std::string processed = preprocessNumber(uop);

                // 소수점('.')이나 지수 표기('e', 'E')가 포함되어 있으면 실수(IEEE 754)로 처리
                if (processed.find('.') != std::string::npos || processed.find('e') != std::string::npos || processed.find('E') != std::string::npos) {
                    errno = 0;
                    char* endptr = nullptr;
                    float f_val = std::strtof(processed.c_str(), &endptr);

                    // FPU 표현 범위 초과(오버플로우/언더플로우) 체크
                    if (errno == ERANGE || std::abs(f_val) > FLT_MAX || (f_val != 0.0f && std::abs(f_val) < FLT_MIN && errno == ERANGE)) {
                        std::cout << "[Error] FPU 표현 범위를 초과했습니다! (허용 범위: 약 +/- 1.18e-38 ~ +/- 3.40e+38)\n";
                        continue; // 명령어 입력을 다시 받음
                    }

                    uint32_t f_bits;
                    std::memcpy(&f_bits, &f_val, sizeof(float)); // float 비트 패턴을 그대로 uint32_t로 복사
                    machine_code = f_bits;
                    asm_line = uop + " (float IEEE-754)";
                }
                else {
                    // 정수 처리
                    machine_code = static_cast<uint32_t>(std::stoul(processed));
                    asm_line = uop + " (raw int value)";
                }
            }
            // 1. J-type: jal rd, imm
            else if (uop == "jal") {
                std::string rd_str;
                int imm;
                std::cin >> rd_str >> imm;
                int rd = parseReg(rd_str);

                asm_line += " " + rd_str + " " + std::to_string(imm);

                uint32_t opcode = 0x6F;
                uint32_t imm_val = imm & 0x1FFFFF;
                uint32_t bit20 = (imm_val >> 20) & 0x1;
                uint32_t bit10_1 = (imm_val >> 1) & 0x3FF;
                uint32_t bit11 = (imm_val >> 11) & 0x1;
                uint32_t bit19_12 = (imm_val >> 12) & 0xFF;

                machine_code = (bit20 << 31) | (bit10_1 << 21) | (bit11 << 20) | (bit19_12 << 12) | (rd << 7) | opcode;
            }
            // 2. R-type: add, sub, sll, srl, sra (rd, rs1, rs2)
            else if (uop == "add" || uop == "sub" || uop == "sll" || uop == "srl" || uop == "sra") {
                std::string rd_str, rs1_str, rs2_str;
                std::cin >> rd_str >> rs1_str >> rs2_str;
                int rd = parseReg(rd_str);
                int rs1 = parseReg(rs1_str);
                int rs2 = parseReg(rs2_str);

                asm_line += " " + rd_str + " " + rs1_str + " " + rs2_str;

                uint32_t opcode = 0x33;
                uint32_t funct3 = 0;
                uint32_t funct7 = 0;

                if (uop == "add") { funct3 = 0x0; funct7 = 0x00; }
                else if (uop == "sub") { funct3 = 0x0; funct7 = 0x20; }
                else if (uop == "sll") { funct3 = 0x1; funct7 = 0x00; }
                else if (uop == "srl") { funct3 = 0x5; funct7 = 0x00; }
                else if (uop == "sra") { funct3 = 0x5; funct7 = 0x20; }

                machine_code = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
            }
            // 3. Floating-Point R-type: fadd, fsub, fmul (rd, rs1, rs2)
            else if (uop == "fadd" || uop == "fsub" || uop == "fmul") {
                std::string rd_str, rs1_str, rs2_str;
                std::cin >> rd_str >> rs1_str >> rs2_str;
                int rd = parseReg(rd_str);
                int rs1 = parseReg(rs1_str);
                int rs2 = parseReg(rs2_str);

                asm_line += " " + rd_str + " " + rs1_str + " " + rs2_str;

                uint32_t opcode = 0x53; // OP-FP
                uint32_t funct3 = 0x0;  // Rounding mode (RNE)
                uint32_t funct7 = 0x00;

                if (uop == "fadd") { funct7 = 0x00; }
                else if (uop == "fsub") { funct7 = 0x04; }
                else if (uop == "fmul") { funct7 = 0x08; }

                machine_code = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
            }
            // 4. I-type: addi, andi, jalr, lw, flw (rd, rs1, imm)
            else if (uop == "addi" || uop == "andi" || uop == "jalr" || uop == "lw" || uop == "flw") {
                std::string rd_str, rs1_str;
                int imm;
                std::cin >> rd_str >> rs1_str >> imm;
                int rd = parseReg(rd_str);
                int rs1 = parseReg(rs1_str);

                asm_line += " " + rd_str + " " + rs1_str + " " + std::to_string(imm);

                uint32_t opcode = 0x13;
                uint32_t funct3 = 0;

                if (uop == "addi") { opcode = 0x13; funct3 = 0x0; }
                else if (uop == "andi") { opcode = 0x13; funct3 = 0x7; }
                else if (uop == "jalr") { opcode = 0x67; funct3 = 0x0; }
                else if (uop == "lw") { opcode = 0x03; funct3 = 0x2; }
                else if (uop == "flw") { opcode = 0x07; funct3 = 0x2; }

                machine_code = ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
            }
            // 5. S-type: sw, fsw (rs2, rs1, imm)
            else if (uop == "sw" || uop == "fsw") {
                std::string rs2_str, rs1_str;
                int imm;
                std::cin >> rs2_str >> rs1_str >> imm;
                int rs2 = parseReg(rs2_str);
                int rs1 = parseReg(rs1_str);

                asm_line += " " + rs2_str + " " + rs1_str + " " + std::to_string(imm);

                uint32_t opcode = 0x23;
                uint32_t funct3 = 0x2;
                if (uop == "fsw") { opcode = 0x27; }

                uint32_t imm_val = imm & 0xFFF;
                uint32_t imm11_5 = (imm_val >> 5) & 0x7F;
                uint32_t imm4_0 = imm_val & 0x1F;

                machine_code = (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode;
            }
            // 6. B-type: beq, bne, blt, bge (rs1, rs2, imm)
            else if (uop == "beq" || uop == "bne" || uop == "blt" || uop == "bge") {
                std::string rs1_str, rs2_str;
                int imm;
                std::cin >> rs1_str >> rs2_str >> imm;
                int rs1 = parseReg(rs1_str);
                int rs2 = parseReg(rs2_str);

                asm_line += " " + rs1_str + " " + rs2_str + " " + std::to_string(imm);

                uint32_t opcode = 0x63;
                uint32_t funct3 = 0;
                if (uop == "beq") funct3 = 0x0;
                else if (uop == "bne") funct3 = 0x1;
                else if (uop == "blt") funct3 = 0x4;
                else if (uop == "bge") funct3 = 0x5;

                uint32_t imm_val = imm & 0x1FFF;
                uint32_t bit12 = (imm_val >> 12) & 0x1;
                uint32_t bit11 = (imm_val >> 11) & 0x1;
                uint32_t bit10_5 = (imm_val >> 5) & 0x3F;
                uint32_t bit4_1 = (imm_val >> 1) & 0xF;

                machine_code = (bit12 << 31) | (bit10_5 << 25) | (rs2 << 20) | (rs1 << 15) |
                    (funct3 << 12) | (bit4_1 << 8) | (bit11 << 7) | opcode;
            }
            else {
                std::cout << "지원하지 않는 명령어입니다. 설명서를 확인하세요.\n";
                continue;
            }

            // 구조체 형태로 벡터에 기록
            history.push_back({ machine_code, asm_line });
        }

        // 결과 출력 (0x 없이 8자리 헥스 + 주석 형태로 출력)
        std::cout << "\n==================================================\n";
        std::cout << "          기계어 변환 결과 (Hex / Asm)            \n";
        std::cout << "==================================================\n";
        for (const auto& item : history) {
            std::cout << std::hex << std::setw(8) << std::setfill('0') << item.code
                << " // " << item.asm_text << "\n";
        }
        std::cout << "==================================================\n";

        // 다시 시작할 것인지 선택지 제공
        std::cout << "\n[1] 초기화하고 다시 작성하기\n";
        std::cout << "[0] 프로그램 종료\n";
        std::cout << "선택 >> ";

        int choice;
        std::cin >> choice;

        if (choice != 1) {
            std::cout << "어셈블러를 종료합니다.\n";
            break; // 전체 루프 탈출 후 프로그램 종료
        }

        std::cout << "\n\n"; // 보기 좋게 빈 줄 추가
    }

    return 0;
}