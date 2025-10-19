# Understanding FPGA Build Reports

This guide explains how to read and interpret synthesis and place-and-route reports for the Lattice ECP5 FPGA.

---

## Quick Reference: Your Blinky Design

From the latest build, here's what your simple LED blinker uses:

```
TRELLIS_FF:      24/43848     0%    (Flip-Flops - your registers)
TRELLIS_COMB:    60/43848     0%    (Combinational Logic - LUTs)
TRELLIS_IO:      10/  245     4%    (I/O pins)
DCCA:             1/   56     1%    (Clock distribution)
```

**Translation**: Your design uses 24 flip-flops, 60 LUTs, 10 I/O pins, and barely scratches the surface of this FPGA's capacity!

---

## Part 1: Basic FPGA Building Blocks

### What is a LUT? (Look-Up Table)

A **LUT** is the fundamental logic building block in an FPGA. Think of it as a small truth table that can implement any logic function.

**ECP5 LUTs**:
- Each LUT has **4 inputs** (called LUT4)
- Can implement any 4-input boolean function
- Example: `Y = (A AND B) OR (C AND NOT D)`

**In Your Blinky**:
```
TRELLIS_COMB: 60/43848   0%
```
- You're using **60 LUTs** out of 43,848 available
- These implement:
  - Counter increment logic (`counter + 1`)
  - Comparison logic (`counter == MAX_COUNT - 1`)
  - LED state toggle (`led_state <= not led_state`)
  - Multiplexers (choosing between reset value or next value)

### What is a Flip-Flop (FF)?

A **flip-flop** is a 1-bit memory element. It stores state and updates on clock edges.

**In Your Blinky**:
```
TRELLIS_FF: 24/43848   0%
```
- You're using **24 flip-flops**
- These store:
  - **23 bits** for the counter (0 to 6,000,000 requires 23 bits)
  - **1 bit** for led_state (on/off)
- Each FF updates on every rising edge of the clock

**Why 24 and not 23+1=24?**
- Sometimes synthesis adds extra FFs for optimization or timing
- Close enough - your design needs ~24 bits of state

---

## Part 2: Device Utilization Report

Let's decode the full report:

### I/O Resources

```
TRELLIS_IO: 10/245   4%
```

**What it is**: Input/Output pins - connections to the outside world

**Your 10 I/O pins**:
- 1 clock input (`clk`)
- 1 reset input (`rst`)
- 8 LED outputs (`led[7:0]`)
- Total: 10 pins

**The FPGA has 245 I/O pins total**, so you're using only 4%.

---

### Clock Resources

```
DCCA: 1/56   1%
```

**What it is**: **D**edicated **C**lock **C**ircuit/**A**rchitecture - special clock distribution network

**Why it matters**:
- Clocks need to reach all FFs at exactly the same time (low skew)
- FPGAs have dedicated clock routing to ensure this
- You're using 1 clock net (your 12 MHz input clock)

**The FPGA has 56 clock networks** - you could drive 55 more independent clock domains if needed.

---

### Memory Resources

```
DP16KD:        0/108    0%
TRELLIS_RAMW:  0/5481   0%
```

**What it is**:
- **DP16KD**: Dual-port 16-kilobit RAM blocks (dedicated memory)
- **TRELLIS_RAMW**: Distributed RAM (using LUTs as memory)

**Your usage**: **NONE** (0)

**Why?** Your counter is just 23 bits - it's implemented using flip-flops, not RAM. You'd use RAM blocks for larger arrays or buffers (like in the Simon Says game storing sequences).

---

### DSP Resources

```
MULT18X18D: 0/72   0%
ALU54B:     0/36   0%
```

**What it is**:
- **MULT18X18D**: Hardware 18×18 bit multipliers
- **ALU54B**: 54-bit arithmetic logic units

**Your usage**: **NONE**

**Why?** Your design only does simple addition (`counter + 1`). The synthesizer implements this using LUTs, not dedicated DSP blocks.

**When you'd use them**: Signal processing, video scaling, audio filters, complex math

---

### PLL Resources

```
EHXPLLL: 0/4   0%
```

**What it is**: **E**nhanced **H**igh-performance **PLL** (Phase-Locked Loop)

**What PLLs do**: Generate different clock frequencies from your input clock

**Your usage**: **NONE**

**Why?** You're using the 12 MHz clock directly. If you wanted a 100 MHz or 50 MHz clock, you'd use a PLL to multiply/divide the input frequency.

---

### Other Specialized Blocks

These are all **0%** in your design:

| Resource | What it does |
|----------|-------------|
| `EXTREFB` | External reference for high-speed I/O |
| `DCUA` | Dual-Channel User Array (high-speed serial) |
| `PCSCLKDIV` | PCIe clock divider |
| `IOLOGIC` | Input/Output logic (DDR, serialization) |
| `SIOLOGIC` | Serializer/Deserializer I/O |
| `GSR` | Global Set/Reset network |
| `JTAGG` | JTAG boundary scan |
| `OSCG` | Internal oscillator |
| `SEDGA` | Soft-error detection |
| `DQSBUFM` | DQS buffer for memory interfaces |

**Bottom line**: You're not using any high-speed I/O, SerDes, PCIe, or DDR memory features. Just basic logic!

---

## Part 3: Yosys Synthesis Report

When you run `make synth`, Yosys also reports resource usage. Look for this section:

```
=== blinky ===

   Number of wires:                 XX
   Number of wire bits:             XXX
   Number of public wires:          X
   Number of public wire bits:      XX
   Number of memories:              X
   Number of memory bits:           X
   Number of processes:             X
   Number of cells:                 XX
     CCU2C                          12   (Carry chain units)
     LUT4                           XX   (4-input LUTs)
     TRELLIS_FF                     24   (Flip-flops)
     TRELLIS_IO                     10   (I/O buffers)
```

### Key Terms:

**CCU2C**: Carry chain units
- Used for fast arithmetic (adders, counters)
- Your counter uses these for the `+1` operation
- More efficient than building adders from LUTs

**Wire bits**: Total number of signal bits in your design
- Includes internal signals, not just I/O

---

## Part 4: Timing Report

After place-and-route, you get a timing report:

```
Info: Max frequency for clock '$glbnet$clk$TRELLIS_IO_IN': 307.03 MHz (PASS at 12.00 MHz)
```

### What This Means:

**Max frequency**: 307.03 MHz
- This is how fast your design *could* run
- The "critical path" (slowest logic path) can complete in 1/307MHz = 3.26 ns

**Your requirement**: 12.00 MHz
- Your design needs to work at 12 MHz (83.33 ns period)
- You have **25× margin** - plenty of headroom!

**PASS**: ✅ Timing is met

### Critical Path Example:

```
Info: Critical path report for clock '$glbnet$clk$TRELLIS_IO_IN' (posedge -> posedge):
Info:       type curr  total name
Info:   clk-to-q  0.40  0.40 Source n15_LUT4_Z_10_D_TRELLIS_FF_Q.Q
Info:    routing  0.80  1.19 Net n15_CCU2C_S0_2_B0[2]
Info:      logic  0.35  1.55 Source n15_CCU2C_S1_2$CCU2_COMB0.FCO
...
Info: 1.82 ns logic, 1.44 ns routing
```

**Reading this**:
- **Total delay**: 3.26 ns (1.82 ns logic + 1.44 ns routing)
- **clk-to-q**: Time for data to leave a flip-flop after clock edge
- **routing**: Time for signal to travel through wires
- **logic**: Time through LUTs and other logic

**In your design**: Logic is slightly slower than routing (1.82 vs 1.44 ns). This is normal for counter logic with carry chains.

---

## Part 5: Slack Analysis

```
Info: Slack histogram:
Info:  legend: * represents 1 endpoint(s)
Info: [ 80076,  80196) |*
Info: [ 80196,  80316) |******
```

**What is slack?**
- Slack = (Required time) - (Actual time)
- Positive slack = ✅ Timing met
- Negative slack = ❌ Timing violation

**Your slack**: ~80,000 to 82,000 (in picoseconds)
- That's about **80-82 ns** of slack
- Remember: your clock period is 83.33 ns
- So you're using only ~3 ns out of 83 ns available
- **Huge margin!**

---

## Part 6: Resource Usage Summary for Common Designs

Here's what typical projects use on the ECP5-45k:

| Project | FFs | LUTs | RAM Blocks | Notes |
|---------|-----|------|------------|-------|
| **Blinky** | 24 | 60 | 0 | Tiny! |
| **Knight Rider** | ~40 | ~100 | 0 | Still tiny |
| **Button Debounce** | ~50 | ~80 | 0 | Per button |
| **Simon Says** | ~500 | ~1000 | 1-2 | Needs memory for sequence |
| **Traffic Light** | ~200 | ~400 | 0 | Complex FSM |
| **VGA Controller** | ~1000 | ~2000 | 4-8 | Frame buffer |
| **Soft CPU (PicoRV32)** | ~2000 | ~4000 | 8-16 | RISC-V processor |

**Your ECP5-45k has**:
- 43,848 LUTs
- 43,848 FFs
- 108 RAM blocks (16kb each = 1.7 Mbit total)

You could fit **hundreds** of blinky designs, or dozens of soft CPUs!

---

## Part 7: How to Get Reports

### During Build:

```bash
make synth    # Yosys synthesis report
make pnr      # nextpnr place-and-route report
```

### Save Reports to File:

```bash
make synth 2>&1 | tee synth_report.txt
make pnr 2>&1 | tee pnr_report.txt
```

### Extract Specific Info:

```bash
# Device utilization
make pnr 2>&1 | grep -A 30 "Device utilisation"

# Timing summary
make pnr 2>&1 | grep "Max frequency"

# Critical path
make pnr 2>&1 | grep -A 50 "Critical path report"
```

---

## Part 8: What to Watch For

### Resource Usage Red Flags:

🟢 **0-50%**: Plenty of room, no worries
🟡 **50-80%**: Getting full, may impact timing
🟠 **80-95%**: Tight fit, routing will be hard
🔴 **>95%**: Danger zone! May not route successfully

### Timing Red Flags:

🟢 **Slack > 10% of period**: Great, safe margin
🟡 **Slack 0-10% of period**: Cutting it close
🔴 **Negative slack**: **FAILS** - design won't work reliably!

### Your Blinky Status:

✅ Resource usage: **0.14%** LUTs (60/43848) - 🟢 Excellent
✅ Timing slack: **~80ns / 83ns period = 96%** - 🟢 Excellent
✅ Max frequency: **307 MHz vs 12 MHz required** - 🟢 25× margin!

---

## Part 9: Practical Examples

### Example 1: Why Does My Counter Use 60 LUTs?

Your 23-bit counter needs:
- **24 flip-flops** (1 per bit, plus led_state)
- **Adder logic** for `counter + 1` (uses carry chains)
- **Comparator** for `counter == MAX_COUNT - 1`
- **Multiplexer** to choose between `0` (reset) or `counter + 1`
- **Toggle logic** for `led_state <= not led_state`

Each of these is built from LUTs!

### Example 2: What If I Made the Counter 32-bit?

```vhdl
signal counter : integer range 0 to 2**32-1;  -- 32 bits instead of 23
```

Expected change:
- **FFs**: 24 → 33 (32 for counter + 1 for led_state)
- **LUTs**: 60 → ~70 (more adder bits, bigger comparator)

Still tiny!

### Example 3: What If I Added 7 More Blinky LEDs?

```vhdl
-- 8 independent blinkers, each with own counter
signal counter : array(0 to 7) of integer;
```

Expected:
- **FFs**: 24 × 8 = 192
- **LUTs**: 60 × 8 = 480
- **I/O**: 10 (same - 8 LEDs, clk, rst)

Still only **1.1%** of FPGA!

---

## Part 10: Advanced: Reading the JSON Netlist

The `.json` file contains the complete netlist. You can inspect it:

```bash
cat build/blinky.json | jq '.modules.blinky.cells' | head -50
```

This shows every cell (LUT, FF, etc.) in your design with connections.

**Warning**: This is very detailed and hard to read! The reports above are much more useful.

---

## Summary: Quick Checklist

When you build a design, check:

1. ✅ **Synthesis completes** - No errors in `make synth`
2. ✅ **All signals resolved** - No "unconnected" warnings
3. ✅ **Resource usage < 80%** - Leave room for routing
4. ✅ **Timing met** - All slacks positive
5. ✅ **I/O constraints applied** - Pins correctly mapped

For blinky, all are ✅!

---

## Next Steps

As you build more complex projects:
- Compare resource usage to these baseline numbers
- Watch for timing violations (negative slack)
- Use timing reports to find slow paths
- Optimize if you're running out of resources

But for now, your blinky is perfectly optimized and ready to flash! 🎉
