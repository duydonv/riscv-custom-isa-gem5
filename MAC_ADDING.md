# HƯỚNG DẪN THÊM LỆNH MAC VÀO GEM5

## MỤC LỤC
1. [Kiến trúc gem5 RISC-V ISA](#1-kiến-trúc-gem5-risc-v-isa)
2. [PHƯƠNG ÁN A: Sử dụng ROp Format (ĐÃ TRIỂN KHAI)](#2-phương-án-a-sử-dụng-rop-format)
3. [PHƯƠNG ÁN B: Sử dụng Custom Class (HƯỚNG DẪN CHI TIẾT)](#3-phương-án-b-sử-dụng-custom-class)
4. [RISC-V Custom Opcode Encoding](#4-risc-v-custom-opcode-encoding)
5. [Testing và Verification](#5-testing-và-verification)

---

## 1. KIẾN TRÚC GEM5 RISC-V ISA

### 1.1. Cấu trúc thư mục

```
src/arch/riscv/
├── isa/
│   ├── main.isa              # File ISA chính, include tất cả
│   ├── decoder.isa           # Decoder - ánh xạ opcode → instruction
│   ├── bitfields.isa         # Định nghĩa các bit field (RD, RS1, RS2...)
│   ├── operands.isa          # Định nghĩa operands (Rd, Rs1, Rs2...)
│   ├── formats/
│   │   ├── formats.isa       # Include các format files
│   │   ├── basic.isa         # Template cơ bản (BasicDeclare, BasicConstructor, BasicExecute)
│   │   ├── standard.isa      # Định nghĩa ROp, IOp, UOp, BOp, JOp, CSROp...
│   │   ├── mem.isa           # Load/Store instructions
│   │   ├── fp.isa            # Floating-point instructions
│   │   └── ...
│   └── templates/
│       └── templates.isa     # Templates cho code generation
├── insts/
│   ├── static_inst.hh/cc     # Base class RiscvStaticInst
│   ├── standard.hh/cc        # RegOp, ImmOp, SystemOp, CSROp
│   ├── mem.hh/cc             # Memory operations
│   ├── amo.hh/cc             # Atomic operations
│   └── SConscript            # Build configuration
└── ...
```

### 1.2. Cách hoạt động ISA Description Language

gem5 sử dụng ISA Description Language để tự động generate C++ code:
- **Format**: Template cho một nhóm instructions (ví dụ: ROp cho R-type)
- **Operands**: Biến đại diện cho thanh ghi (Rd, Rs1, Rs2...)
- **Code block**: `{{ ... }}` chứa logic thực thi instruction

---

## 2. PHƯƠNG ÁN A: Sử dụng ROp Format (ĐÃ TRIỂN KHAI) ✅

### 2.1. Đặc điểm
- ✅ **ĐƠN GIẢN**: Chỉ cần thêm vài dòng vào decoder.isa
- ✅ **NHANH**: Không cần tạo thêm file .hh/.cc
- ⚠️ **HẠN CHẾ**: Khó customize behavior phức tạp

### 2.2. Code đã triển khai

Trong file `src/arch/riscv/isa/decoder.isa` (dòng ~2616):

```cpp
// Custom instruction MAC (Multiply-Accumulate)
// Using custom-0 opcode space (0x02 = OPCODE5)
// Full opcode: 0x0B (0b0001011)
// Encoding: mac rd, rs1, rs2  =>  rd = rd + (rs1 * rs2)
0x02: decode FUNCT3 {
format ROp {
        0x0: decode FUNCT7 {
            0x00: mac({{
                // MAC operation: rd = rd + (rs1 * rs2)
                // Note: Rd is both source and destination
                Rd = rvSext(Rd + (Rs1_sd * Rs2_sd));
            }}, IntMultOp);
        }
    }
}
```

### 2.3. Cơ chế hoạt động

ISA parser tự động sinh ra:
1. **Class**: `Mac` kế thừa từ `RegOp`
2. **Constructor**: Khởi tạo instruction với mnemonic "mac"
3. **execute()**: Thực thi code trong `{{ ... }}`
4. **generateDisassembly()**: Sinh chuỗi "mac rd, rs1, rs2"
5. **Operand tracking**: Tự động nhận diện Rd (dest), Rs1, Rs2 (source)

**QUAN TRỌNG**: Trong code `Rd = rvSext(Rd + ...)`, Rd xuất hiện cả 2 vế:
- **Vế trái**: Destination operand
- **Vế phải**: Source operand (ISA parser tự động đọc giá trị cũ)

---

## 3. PHƯƠNG ÁN B: Sử dụng Custom Class (HƯỚNG DẪN CHI TIẾT) 🔧

### 3.1. Đặc điểm
- ⚙️ **LINH HOẠT**: Kiểm soát hoàn toàn behavior
- 📝 **RÕ RÀNG**: Logic tách biệt, dễ debug
- ⚠️ **PHỨC TẠP**: Nhiều file, nhiều bước

### 3.2. So sánh operand handling

| Khía cạnh | ROp Format (Phương án A) | Custom Class (Phương án B) |
|-----------|-------------------------|----------------------------|
| **Operand declaration** | Tự động (từ biến trong code) | Thủ công (trong constructor) |
| **Read old Rd value** | Tự động | Phải đọc manually |
| **Code location** | Inline trong decoder.isa | Tách riêng trong .cc |
| **Debugging** | Khó (generated code) | Dễ (source code rõ ràng) |

### 3.3. Các bước triển khai PHƯƠNG ÁN B

#### **BƯỚC 1: Tạo file mac.hh**

File: `src/arch/riscv/insts/mac.hh`

```cpp
#ifndef __ARCH_RISCV_INSTS_MAC_HH__
#define __ARCH_RISCV_INSTS_MAC_HH__

#include "arch/riscv/insts/static_inst.hh"
#include "base/types.hh"

namespace gem5 {
    namespace loader { class SymbolTable; }
    namespace trace { class InstRecord; }
    class ExecContext;
    class Fault;
}

namespace gem5
{
namespace RiscvISA
{

/**
 * Multiply-Accumulate instruction
 * Format: MAC rd, rs1, rs2
 * Operation: rd = rd + (rs1 * rs2)
 */
class MAC_R : public RiscvStaticInst
{
  public:
    // Constructor
    MAC_R(const ExtMachInst &machInst);

    // Override: Generate disassembly string
    std::string generateDisassembly(Addr pc,
        const loader::SymbolTable *symtab) const override;

    // Override: Execute instruction
    Fault execute(ExecContext *xc,
        trace::InstRecord *traceData) const override;
};

} // namespace RiscvISA
} // namespace gem5

#endif // __ARCH_RISCV_INSTS_MAC_HH__
```

#### **BƯỚC 2: Tạo file mac.cc**

File: `src/arch/riscv/insts/mac.cc`

```cpp
#include "arch/riscv/insts/mac.hh"

#include <sstream>

#include "arch/riscv/isa.hh"
#include "arch/riscv/regs/int.hh"
#include "base/loader/symtab.hh"
#include "cpu/exec_context.hh"
#include "cpu/static_inst.hh"

namespace gem5
{
namespace RiscvISA
{

MAC_R::MAC_R(const ExtMachInst &machInst) :
    // Khởi tạo: mnemonic "mac", machInst, OpClass = IntMultOp
    RiscvStaticInst("mac", machInst, IntMultOp)
{
    // Khai báo operands thủ công:
    // - 2 source registers: rs1 (index 0), rs2 (index 1)
    // - 1 destination register: rd (index 0)
    //
    // QUAN TRỌNG: Rd vừa là source VÀ destination
    // Để đọc giá trị cũ của Rd, ta cần add nó vào source operand list

    // Option 1: Chỉ khai báo rs1, rs2 là source (đơn giản nhưng phải đọc Rd manual)
    // Cách này sử dụng API readIntReg trực tiếp

    // Option 2: Khai báo rs1, rs2, rd đều là source (chuẩn nhưng phức tạp hơn)
    // Cách này cho phép dùng readIntRegOperand(this, 2) để đọc Rd

    // Ở đây dùng Option 1 (đơn giản hơn)
    flags[IsInteger] = true;
    flags[IsMultOp] = true;
}

std::string
MAC_R::generateDisassembly(Addr pc, const loader::SymbolTable *symtab) const
{
    std::stringstream ss;
    // Format: mac rd, rs1, rs2
    ss << mnemonic << " "
       << registerName(intRegClass[destRegIdx(0)]) << ", "
       << registerName(intRegClass[srcRegIdx(0)]) << ", "
       << registerName(intRegClass[srcRegIdx(1)]);
    return ss.str();
}

Fault
MAC_R::execute(ExecContext *xc, trace::InstRecord *traceData) const
{
    // Đọc giá trị từ rs1 và rs2 (source operands)
    IntReg rs1_val = xc->readIntRegOperand(this, 0);  // rs1
    IntReg rs2_val = xc->readIntRegOperand(this, 1);  // rs2

    // ⚠️ QUAN TRỌNG: Đọc giá trị CŨ của rd
    // Cách 1: Đọc trực tiếp từ register file (KHUYẾN NGHỊ)
    RegId rd_regid = destRegIdx(0);
    IntReg rd_old = xc->getReg(rd_regid);

    // Cách 2: Nếu đã khai báo rd là source operand thứ 3 trong constructor
    // IntReg rd_old = xc->readIntRegOperand(this, 2);

    // Thực hiện phép toán MAC
    IntReg result = rd_old + (rs1_val * rs2_val);

    // Sign extend kết quả (quan trọng cho RV64)
    result = rvSext(result);

    // Ghi kết quả vào rd
    xc->setIntRegOperand(this, 0, result);

    // Cập nhật PC (chuyển sang instruction tiếp theo)
    advancePC(xc->pcState());

    return NoFault;
}

} // namespace RiscvISA
} // namespace gem5
```

#### **BƯỚC 3: Include vào includes.isa**

File: `src/arch/riscv/isa/includes.isa` (dòng ~52)

```cpp
output header {{
// ... existing includes ...
#include "arch/riscv/insts/amo.hh"
#include "arch/riscv/insts/bs.hh"
#include "arch/riscv/insts/compressed.hh"
#include "arch/riscv/insts/mac.hh"          // ← THÊM DÒNG NÀY
#include "arch/riscv/insts/mem.hh"
// ... rest of includes ...
}};
```

#### **BƯỚC 4: Thêm vào SConscript**

File: `src/arch/riscv/insts/SConscript` (dòng ~42)

```python
Source('amo.cc', tags=['riscv isa'])
Source('bs.cc', tags=['riscv isa'])
Source('compressed.cc', tags=['riscv isa'])
Source('mac.cc', tags=['riscv isa'])        # ← THÊM DÒNG NÀY
Source('mem.cc', tags=['riscv isa'])
# ... rest of sources ...
```

#### **BƯỚC 5: Sử dụng trong decoder.isa**

File: `src/arch/riscv/isa/decoder.isa` (dòng ~2616)

**Xóa code PHƯƠNG ÁN A:**
```cpp
// XÓA block này nếu đang dùng
0x02: decode FUNCT3 {
    format ROp {
        0x0: decode FUNCT7 {
            0x00: mac({{ ... }}, IntMultOp);
        }
    }
}
```

**Thay bằng:**
```cpp
// Custom instruction MAC using custom class
// Full opcode: 0x0B (custom-0)
0x02: decode FUNCT3 {
    0x0: decode FUNCT7 {
        0x00: MAC_R::mac({{
            // Empty code block - logic in mac.cc
            // Hoặc có thể để trống hoàn toàn
        }});
    }
}
```

**HOẶC** (cách ngắn gọn hơn):
```cpp
0x02: decode FUNCT3 {
    0x0: decode FUNCT7 {
        0x00: new MAC_R(machInst);
    }
}
```

#### **BƯỚC 6: Build**

```bash
cd /home/duydong/gem5
python3 $(which scons) build/RISCV/gem5.opt -j$(nproc)
```

### 3.4. Debug và troubleshooting

**Nếu gặp lỗi compilation:**

1. **Missing header**: Kiểm tra `#include` trong mac.cc
2. **Undefined reference**: Kiểm tra SConscript đã thêm mac.cc chưa
3. **Operand index out of range**: Sửa cách đọc Rd (dùng `xc->getReg()`)

**Kiểm tra generated code:**

```bash
# Xem code được generate từ decoder.isa
cat build/RISCV/arch/riscv/generated/decoder.cc | grep -A 20 "class Mac"
```

---

## 4. RISC-V CUSTOM OPCODE ENCODING

### 4.1. Opcode space

RISC-V spec dành riêng 4 opcode cho custom instructions:

| Full Opcode | OPCODE5 | QUADRANT | Name | Sử dụng |
|-------------|---------|----------|------|---------|
| 0x0B (0b0001011) | 0x02 | 0x3 | custom-0 | ✅ **ĐANG DÙNG** |
| 0x2B (0b0101011) | 0x0A | 0x3 | custom-1 | Available |
| 0x5B (0b1011011) | 0x16 | 0x3 | custom-2 | RV64+ only |
| 0x7B (0b1111011) | 0x1E | 0x3 | custom-3 | Available |

**Giải thích encoding:**
```
Full_Opcode[6:0] = OPCODE5[4:0] << 2 | QUADRANT[1:0]
Full_Opcode[6:0] = 0x02 << 2 | 0x3 = 0b00010_11 = 0x0B ✅
```

### 4.2. MAC instruction encoding

```
31        25 24    20 19    15 14  12 11     7 6       0
+-----------+--------+--------+------+--------+---------+
|  FUNCT7   |  rs2   |  rs1   |FUNCT3|   rd   | OPCODE  |
+-----------+--------+--------+------+--------+---------+
| 0000000   |  rs2   |  rs1   | 000  |   rd   | 0001011 |
| (0x00)    | [24:20]| [19:15]|(0x0) | [11:7] |  (0x0B) |
+-----------+--------+--------+------+--------+---------+
```

**Ví dụ: `mac x3, x10, x5`**
```
rs1 = x10 = 10 = 0b01010
rs2 = x5  = 5  = 0b00101
rd  = x3  = 3  = 0b00011

Machine code:
0000000_00101_01010_000_00011_0001011
= 0x00A501AB (hex)
```

### 4.3. Sử dụng trong Assembly

**Cách 1: Inline assembly với `.insn` directive**
```c
int c = initial_value;
__asm__ volatile (
    ".insn r 0x0B, 0x0, 0x0, %0, %1, %2"
    : "+r" (c)           // output: c (read-write)
    : "r" (a), "r" (b)   // inputs: a, b (read-only)
);
// c = c + (a * b)
```

**Cách 2: Define macro**
```c
#define MAC(rd, rs1, rs2) \
    __asm__ volatile ( \
        ".insn r 0x0B, 0x0, 0x0, %0, %1, %2" \
        : "+r" (rd) \
        : "r" (rs1), "r" (rs2) \
    )

// Usage:
MAC(c, a, b);  // c = c + (a * b)
```

**Cách 3: Custom assembler (advanced)**
```assembly
# Thêm vào binutils
.macro mac rd, rs1, rs2
    .insn r 0x0B, 0, 0, \rd, \rs1, \rs2
.endm

# Sử dụng
mac x3, x10, x5
```

---

## 5. TESTING VÀ VERIFICATION

### 5.1. Chuẩn bị test program

**File: test_mac.c**
```c
#include <stdio.h>

int main() {
    int a = 10;
    int b = 5;
    int c = 3;

    printf("Before MAC: c = %d\n", c);
    printf("Computing: c = c + (a * b) = %d + (%d * %d)\n", c, a, b);

    // Execute MAC instruction
    __asm__ volatile (
        ".insn r 0x0B, 0x0, 0x0, %0, %1, %2"
        : "+r" (c)
        : "r" (a), "r" (b)
    );

    printf("After MAC: c = %d\n", c);
    printf("Expected: %d\n", 3 + (10 * 5));

    if (c == 53) {
        printf("✅ MAC instruction PASSED!\n");
        return 0;
    } else {
        printf("❌ MAC instruction FAILED!\n");
        printf("   Got: %d, Expected: 53\n", c);
        return 1;
    }
}
```

### 5.2. Compile test program

```bash
cd /home/duydong/riscv_test

# Compile với RISC-V GCC
riscv64-unknown-elf-gcc -march=rv64i -mabi=lp64 -static \
    -o test_mac test_mac.c

# Kiểm tra encoding của MAC instruction
riscv64-unknown-elf-objdump -d test_mac | grep -A 5 "<main>"
```

### 5.3. gem5 simulation script

**File: configs/tutorial/riscv_mac_test.py**
```python
from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.cachehierarchies.classic.no_cache import NoCache
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator
import sys
import os

# Parse command line arguments
output_dir = sys.argv[1] if len(sys.argv) > 1 else "m5out_mac_test"

# Configure system
cache_hierarchy = NoCache()
memory = SingleChannelDDR4_2400(size="2GiB")

processor = SimpleProcessor(
    cpu_type=CPUTypes.TIMING,
    isa=ISA.RISCV,
    num_cores=1
)

board = SimpleBoard(
    clk_freq="3GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy,
)

# Set workload - use absolute path
workload_path = os.path.join(
    os.path.dirname(__file__),
    "../../riscv_test/test_mac"
)
board.set_se_binary_workload(BinaryResource(local_path=workload_path))

# Create simulator with custom output directory
simulator = Simulator(
    board=board,
    full_system=False,
    redirect_stdout=True,
    redirect_stderr=True
)

# Override output directory
simulator.m5out_dir = output_dir

print(f"Starting simulation...")
print(f"Output directory: {output_dir}")
simulator.run()

print(f"\n✅ Simulation complete!")
print(f"Results saved to: {output_dir}/")
```

### 5.4. Run tests

```bash
cd /home/duydong/gem5

# Test 1: With MAC instruction
build/RISCV/gem5.opt \
    configs/tutorial/riscv_mac_test.py \
    m5out_with_mac

# Test 2: Comparison baseline (simple arithmetic)
# Create test without MAC for comparison
build/RISCV/gem5.opt \
    configs/tutorial/riscv_baseline_test.py \
    m5out_baseline

# Compare results
diff m5out_with_mac/stats.txt m5out_baseline/stats.txt
```

### 5.5. Verify results

```bash
# Check stdout
cat m5out_with_mac/board.processor.cores0.core.stdout

# Check stats
grep -E "sim_ticks|sim_insts|numCycles" m5out_with_mac/stats.txt

# Check for MAC instruction execution
grep -i "mac" m5out_with_mac/board.pc.com_1.device.terminal
```

### 5.6. Expected output

**Successful MAC execution:**
```
Before MAC: c = 3
Computing: c = c + (a * b) = 3 + (10 * 5)
After MAC: c = 53
Expected: 53
✅ MAC instruction PASSED!
```

**Stats comparison (example):**
```
WITH MAC:
- sim_ticks: 45000
- sim_insts: 25
- numCycles: 45

WITHOUT MAC (using mul + add):
- sim_ticks: 52000
- sim_insts: 26
- numCycles: 52

Speedup: ~13% faster with MAC
```

---

## 6. SO SÁNH HAI PHƯƠNG ÁN

| Tiêu chí | PHƯƠNG ÁN A (ROp) | PHƯƠNG ÁN B (Custom) |
|----------|-------------------|----------------------|
| **Lines of code** | ~10 lines | ~150 lines |
| **Files modified** | 1 file (decoder.isa) | 4 files (.hh, .cc, includes, SConscript, decoder) |
| **Flexibility** | ⚠️ Limited | ✅ Full control |
| **Performance** | ✅ Same (compiled code identical) | ✅ Same |
| **Debug ease** | ⚠️ Hard (generated code) | ✅ Easy (source available) |
| **Maintainability** | ✅ Simple | ⚠️ More complex |
| **Build time** | ✅ Fast (ISA parser only) | ⚠️ Slower (compile .cc) |
| **Best for** | Simple instructions | Complex instructions |

### Recommendation:
- **Use PHƯƠNG ÁN A** for: Simple operations, standard R/I/S type
- **Use PHƯƠNG ÁN B** for: Complex logic, custom operand handling, special flags

---

## 7. TROUBLESHOOTING

### 7.1. Common errors

**Error: "instruction definition with no active format"**
- **Cause**: Forgot `format ROp { ... }` wrapper
- **Fix**: Wrap instruction definition in format block

**Error: "undefined reference to MAC_R::execute"**
- **Cause**: mac.cc not included in SConscript
- **Fix**: Add `Source('mac.cc')` to SConscript

**Error: "operand index out of range"**
- **Cause**: Trying to read non-existent operand
- **Fix**: Use `xc->getReg(destRegIdx(0))` instead of `readIntRegOperand(this, 2)`

### 7.2. Debug tips

```bash
# Check generated decoder
vim build/RISCV/arch/riscv/generated/decoder.cc

# Check generated instruction classes
vim build/RISCV/arch/riscv/generated/inst-constrs.cc

# Enable debug flags
build/RISCV/gem5.opt --debug-flags=Decode,ExecEnable configs/test.py

# Trace instruction execution
build/RISCV/gem5.opt --debug-flags=Exec configs/test.py
```

---

## 8. REFERENCES

### gem5 Documentation
- gem5.org - Official documentation
- gem5 Bootcamp: https://gem5bootcamp.github.io/
- RISC-V in gem5: `src/arch/riscv/isa/README.md`

### RISC-V Specifications
- RISC-V ISA Manual: https://riscv.org/technical/specifications/
- Custom Extensions: Volume I, Chapter 25
- Encoding: Volume I, Chapter 2

### Code Examples
- Standard instructions: `src/arch/riscv/isa/decoder.isa` (line 2286+)
- Custom classes: `src/arch/riscv/insts/amo.hh`
- Format definitions: `src/arch/riscv/isa/formats/standard.isa`

---

## APPENDIX: QUICK REFERENCE

### gem5 Build Commands
```bash
# Full build
python3 $(which scons) build/RISCV/gem5.opt -j$(nproc)

# Clean build
rm -rf build/RISCV
python3 $(which scons) build/RISCV/gem5.opt -j$(nproc)

# Build with debug symbols
python3 $(which scons) build/RISCV/gem5.debug -j$(nproc)
```

### RISC-V Toolchain
```bash
# Compile RISC-V program
riscv64-unknown-elf-gcc -march=rv64i -mabi=lp64 -static -o prog prog.c

# Disassemble
riscv64-unknown-elf-objdump -d prog

# Check encoding
riscv64-unknown-elf-objdump -d prog | grep ".insn"
```

### gem5 Simulation
```bash
# Run simulation
build/RISCV/gem5.opt [options] config.py

# Common options
--debug-flags=Exec,Decode    # Enable debug output
--debug-file=debug.txt        # Redirect debug to file
--outdir=custom_output        # Custom output directory
```

---

**Last updated**: 2025-10-29
**gem5 version**: Latest (RISC-V support)
**Author**: AI Assistant + User Implementation
