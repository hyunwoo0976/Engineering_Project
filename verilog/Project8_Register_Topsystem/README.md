# Project 8: Register Top System

[← Project 7](../Project7_Shift_register/README.md) · [Verilog projects](../README.md) · [Design notes](memo/정리.md) · [Background](memo/배경지식.md) · [Error log](memo/error_log.md) · [Next: Project 9 →](../Project9_mini_processer_using_FSM/README.md)

## Overview

A top-level register system built from a dual-port register file and a multiplexer. This project connects previously isolated sequential blocks into one data path and verifies the integrated behavior with a dedicated testbench.

## Structure

- `src_Register2/Top_system.v` — top-level integration
- `src_Register2/dual_port_reg.v` — dual-port register storage
- `src_Register2/MUX.v` — output selection
- `tb/Top_system_tb.v` — simulation testbench
- `Top_system.f` — compilation file list

## Evidence

The block diagram, intermediate debugging captures, and final waveform are in [`img_top system/`](./img_top%20system/).

> The memo files are retained as documentation placeholders. They should not be interpreted as completed technical notes until their project-specific contents are written.
