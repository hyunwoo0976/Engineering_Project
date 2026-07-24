# Project 1: C++ Basics — Variables, I/O, and Operators
>Goal: Get comfortable with the fundamentals of C++ — declaring variables, reading input with `std::cin`, printing output with `std::cout`, and using arithmetic operators.

- Files:

1) `standard.cpp`

    - Reads an integer age from the user and prints it back in a sentence.

    ```cpp
    std::cout <<"나이를 입력하세요: ";
    std::cin >> age;
    std::cout << "당신의 나이는 "<< age << "살이군요." <<std::endl;
    ```

    - The simplest possible input/output loop: prompt -> read -> format a response.

2) `Project1/Project1.cpp`

    - Reads `age` (int) and `weight` (double), then demonstrates every basic arithmetic operator between them.

    ```cpp
    std::cout << "더하기: " << age + weight << std::endl;
    std::cout << "빼기: " << age - weight << std::endl;
    std::cout << "곱하기: " << age * weight << std::endl;
    std::cout << "나누기(정수): " << age / weight << std::endl;
    std::cout << "나누기(실수): " << (double)age / weight << std::endl;
    std::cout << "나머지: " << a % b << std::endl;
    ```

    - Shows the difference between integer division and floating-point division, and introduces the modulo operator (`%`) with two `int` constants.

3) `Project1/Project2.cpp`

    - Placeholder file (currently empty), reserved for a follow-up exercise.

### Conclusion & Key Takeaways

* **Type awareness:** mixing `int` and `double` in an expression implicitly promotes the result to `double`, which matters for accurate division.
* **Explicit casting:** `(double)age / weight` shows how to force floating-point division when both operands would otherwise be truncated.
* **I/O basics:** `std::cin >>` / `std::cout <<` are the entry point for every later, more complex program in this repo.
