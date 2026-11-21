# OpenRV-Cores

**Open-source RISC-V CPU development in SystemVerilog.** The first core, **OpenRV32**, is a small single-cycle RV32I-*subset* processor with a deterministic simulation SoC and self-checking regressions.

> **Status — v0.2, educational prototype.** Not a complete standards-compliant RV32I core, not a verified ASIC/FPGA IP block, and not affiliated with the OpenHW Foundation. The architecture and RTL are original to this project.

## What works today

- **32-bit datapath:** 32 architectural integer registers (`x0` is constant zero), PC initialized to zero.
- **RV32I-style integer operations:** arithmetic, bitwise logic, signed/unsigned comparisons, shifts, LUI and AUIPC.
- **Control flow:** six conditional branches, JAL and JALR.
- **Memory operations:** LB/LBU/LH/LHU/LW and SB/SH/SW, byte strobes, sign extension.
- **Development scaffold:** 1 KiB simulation instruction ROM, 1 KiB data RAM, 10 self-checking regressions.
- **Debug hooks:** `halted_o` and a documented 3-bit halt reason (simulation protocol, *not* RISC-V trap CSRs).
- **Continuous integration:** Python ROM integrity checks and RTL simulation with Icarus Verilog.

## Quick start

Ubuntu / Debian:

```bash
sudo apt-get update
sudo apt-get install -y iverilog make python3
make check   # ROM formatting and tool sanity
make test    # generate programs, compile RTL, execute all 10 regressions
```

Expected output: `PASS: test 1` through `PASS: test 10` if the simulations succeed. CI runs the same commands on pushes and pull requests.

## Repository layout

```text
OpenRV-Cores/
├── rtl/
│   ├── rv32_core.sv            # RV32I-subset single-cycle RTL
│   └── rv32_soc.sv             # 1 KiB ROM/RAM simulation harness
├── tb/tb_rv32_soc.sv          # Self-checking SystemVerilog testbench
├── scripts/
│   ├── gen_programs.py        # Generates reproducible machine-code ROMs
│   └── check_hex.py           # Static ROM image checks
├── tests/*.hex                # 10 generated regression programs
├── docs/
│   ├── architecture.md        # Datapath and interface specification
│   └── roadmap.md             # FPGA, pipeline and compliance milestones
├── .github/workflows/rtl.yml # Automated tests
└── Makefile
```

## Current limitations

The design assumes **zero-wait-state combinational** instruction and data memory. It does **not** implement architectural traps (`mtvec`, `mepc`, `mcause`), privilege modes, CSRs, interrupts, bus handshakes, debug specification, compressed instructions, atomics, multiply/divide, caches or memory protection. ECALL, EBREAK, illegal instructions, and misalignment stop the processor and report an implementation-specific halt code, instead of taking RISC-V exceptions.

Therefore the repository makes **no compliance, synthesis-quality, silicon, frequency, or FPGA-resource claims**. The long-term goal is a small configurable family of reusable cores; the current implementation is the baseline for verification and architectural expansion.

## Architecture and references

- [Architecture and block diagram](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Official RISC-V unprivileged ISA](https://docs.riscv.org/reference/isa/unpriv/)
- [OpenHW CORE-V family](https://github.com/openhwfoundation/core-v-cores) — inspiration for modular project organization, **not** a code dependency

## License

MIT, see [LICENSE](LICENSE).
