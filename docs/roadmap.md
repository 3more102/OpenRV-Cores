# OpenRV-Cores development roadmap

| Stage | Goal | Exit condition |
|---|---|---|
| **v0.2** | Initial OpenRV32 single-cycle implementation | Source, 10 directed tests, CI, halt diagnostic interface in repository |
| v0.3 | RV32I architectural semantics | Basic machine-mode trap/CSR model, access errors, alignment exception behavior, `riscv-tests` subset |
| v0.4 | Multi-cycle/pipelined core | 4 or 5 stages, hazards, forwarding, branch flushing, assertions |
| v0.5 | Standard bus and SoC | Memory ready/valid or recognized bus protocol; UART, timer and interrupts |
| v0.6 | First FPGA target | FPGA clock/reset handling, BRAM-friendly memory, timing/resource reports |
| v0.7 | Verification hardening | Randomized instruction sequences, reference model, coverage, formal assertions |
| v1.0 | Documented reusable core | Interface specification, reproducible simulation/synthesis, regression evidence |
| Later | Optional extensions | RV32M, RV32C, external debug, and additional core variants |

A CORE-V-like organization is an aspirational *structure*, not a claim of equivalent design maturity.
