# Project 9: Mini Processor Using an FSM

[← Project 8](../Project8_Register_Topsystem/README.md) · [Verilog projects](../README.md) · [Design notes](memo/정리.md) · [Background](memo/배경지식.md) · [Error log](memo/error_log.md) · [Next: Project 10 →](../Project10_mini_CPU/README.md)

## Overview

A small processor that coordinates register, ALU, adder, and subtractor blocks with a finite-state machine. It is the bridge between the earlier standalone RTL blocks and the pipelined RISC-V CPU in Project 10.

## Structure

- `src_mini_processer1/m_top_module.v` — top-level data path and control integration
- `src_mini_processer1/m_FSM.v` — finite-state controller
- `src_mini_processer1/m_ALU.v` — arithmetic and logic operations
- `src_mini_processer1/m_register.v` — state-holding register
- `tb/mini_processer1_tb.v` — simulation testbench
- `m_processer1.f` — compilation file list

## Evidence

Development and debugging waveforms are collected in [`img_m_processer1/`](./img_m_processer1/).

> The memo files are retained as documentation placeholders. They should not be interpreted as completed technical notes until their project-specific contents are written.
