#pragma once
#include "arch/riscv/insts/static_inst.hh" // Sửa đổi đường dẫn include

namespace gem5
{
namespace RiscvISA
{

class MAC_R : public RiscvStaticInst
{
  public:
    MAC_R(const ExtMachInst &machInst);
    std::string generateDisassembly(Addr pc,
        const SymbolTable *symtab) const override;
    Fault execute(ExecContext *xc,
        Trace::InstRecord *traceData) const override;
};

} // namespace RiscvISA
} // namespace gem5