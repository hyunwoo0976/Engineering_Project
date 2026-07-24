# Project 2: Control Flow — if/else, for, and while
>Goal: Practice conditional branching and looping by modeling a simple voltage-monitoring routine, then compare a `for`-loop version against a `while`-loop version of the same idea.

- Files:

1) `if_for.cpp` (active)

    - Reads a voltage value and draws a bar of `*` characters whose length equals the (truncated) voltage, repeating until `-1` is entered.

    ```cpp
    while (true) {
        std::cin >> voltage;
        if (voltage == -1) break;
        for (i = 0; i < (int)voltage; i++) std::cout << "*";
        std::cout << std::endl;
    }
    ```

    - Combines an outer `while (true)` sentinel loop with an inner `for` loop that does the actual rendering — a common "read until sentinel, then process" pattern.

2) `Hard.cpp` (kept for reference, commented out)

    - Classifies 5 measured voltages with `if / else if / else` into **High (>=5.0V)**, **Normal (3.0–5.0V)**, and **Low (<3.0V)**, looping a fixed 5 times with a `for` loop.

3) `While.cpp` (kept for reference, commented out)

    - Same High/Normal/Low classification logic as `Hard.cpp`, but restructured around a `while (true)` loop with a `-1` sentinel to exit, instead of a fixed count.

### Conclusion & Key Takeaways

* **Sentinel-controlled loops:** `while (true)` + `break` on a sentinel value (`-1`) is a flexible alternative to a `for` loop when the number of iterations isn't known ahead of time.
* **Cascading conditionals:** `if / else if / else` naturally expresses mutually exclusive range checks (High / Normal / Low).
* **Nested loops:** `if_for.cpp` shows how an outer loop (input handling) and inner loop (output rendering) can be composed to build small text-based visualizations.
