#include "arch/riscv/insts/mac.hh"

#include "arch/riscv/isa/decoder.hh"
#include "cpu/exec_context.hh"

namespace gem5
{
namespace RiscvISA
{

MAC_R::MAC_R(const ExtMachInst &machInst) :
    RiscvStaticInst(machInst, "mac", "MAC_R")
{
    // Lấy các toán hạng từ lệnh
    src1 = machInst.rs1;
    src2 = machInst.rs2;
    dest = machInst.rd;
}

std::string
MAC_R::generateDisassembly(Addr pc, const SymbolTable *symtab) const
{
    return mnemonic + " " + int_reg::reg_names[dest] + ", " +
           int_reg::reg_names[src1] + ", " + int_reg::reg_names[src2];
}

Fault
MAC_R::execute(ExecContext *xc, Trace::InstRecord *traceData) const
{
    // Đọc giá trị từ các thanh ghi nguồn
    IntReg val_s1 = xc->readIntReg(src1);
    IntReg val_s2 = xc->readIntReg(src2);
    IntReg val_d_old = xc->readIntReg(dest);

    // Thực hiện phép toán
    IntReg result = val_d_old + (val_s1 * val_s2);

    // Ghi kết quả trở lại thanh ghi đích
    xc->setIntReg(dest, result);

    // Cập nhật PC để trỏ đến lệnh tiếp theo
    xc->pcState(xc->pcState().nextInstAddr());
    return NoFault;
}

} // namespace RiscvISA
} // namespace gem5