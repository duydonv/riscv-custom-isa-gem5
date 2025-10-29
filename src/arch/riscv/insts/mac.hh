#pragma once

// BAO GỒM CÁC HEADER CẦN THIẾT TỪ CÁC FILE MẪU
#include "arch/riscv/insts/static_inst.hh"
#include "base/types.hh" // Cho Addr

// Cần forward declare hoặc include các kiểu dữ liệu
// Dùng forward declaration để tránh include
// quá nhiều nếu chỉ cần con trỏ/tham chiếu
namespace gem5 {
    namespace loader { class SymbolTable; }
    namespace trace { class InstRecord; }
    class ExecContext; // Forward declare ExecContext
    class Fault;       // Forward declare Fault
} // namespace gem5


namespace gem5
{
namespace RiscvISA
{

class MAC_R : public RiscvStaticInst
{
  public:
    // Constructor
    MAC_R(const ExtMachInst &machInst);

    // Chữ ký hàm override đúng chuẩn (dùng loader:: và trace::)
    std::string generateDisassembly(Addr pc,
        const loader::SymbolTable *symtab) const override;

    // Chữ ký hàm override đúng chuẩn
    Fault execute(ExecContext *xc,
        trace::InstRecord *traceData) const override;
};

} // namespace RiscvISA
} // namespace gem5
