# Project 3: Nested Loops & Arrays — Patterns and Voltage Statistics
>Goal: Move from single loops to nested loops and arrays — build 2D star patterns and compute simple statistics (average, max, min) over a fixed-size dataset.

- Files:

1) `diamond.cpp` (active)

    - Reads a size `N` (1–9) and prints a diamond made of `*`, built from an upper pyramid and a lower inverted pyramid, repeating until `0` is entered to quit.

    ```cpp
    for (i = 1; i < N + 1; i++) {          // upper half
        for (int x = 0; x < N - i; x++) std::cout << " ";
        for (int y = 0; y < 2 * i - 1; y++) std::cout << "*";
        std::cout << std::endl;
    }
    for (j = N + 1; j < 2 * N; j++) {      // lower half
        for (int a = 0; a < j - N; a++) std::cout << " ";
        for (int b = 0; b < (2 * N - 1) - 2 * (j - N); b++) std::cout << "*";
        std::cout << std::endl;
    }
    ```

    - Also validates input range (1–9) and re-prompts on invalid input using `continue`.

2) `pyramid_signal_generator.cpp` (kept for reference, commented out)

    - A simpler, single (upper-half-only) pyramid version of the same idea — the direct predecessor to `diamond.cpp`.

3) `MAX_MIN.cpp` (kept for reference, commented out)

    - Reads 10 voltage samples into a `double[10]` array and tracks the running max/min while reading.

4) `Project3.cpp` (kept for reference, commented out)

    - Reads 5 voltage samples into a `double[5]` array, sums them in a separate loop, and computes the average.

### Conclusion & Key Takeaways

* **Nested loops for 2D shapes:** each row of a pattern is itself a small loop (spaces, then stars), and the row count is the outer loop — the same technique used for both the pyramid and the diamond.
* **Arrays for fixed-size datasets:** `double voltage[N]` lets you collect multiple readings before processing them, instead of reacting to one value at a time.
* **Single-pass vs. two-pass processing:** `MAX_MIN.cpp` updates max/min while reading (single pass), while `Project3.cpp` reads first and sums afterward (two pass) — both are valid depending on whether you need all the data before computing the result.
