#include "arch/riscv/insts/mac.hh"

// BAO GỒM CÁC HEADER CẦN THIẾT (đầy đủ hơn)
#include <sstream> // Cần cho std::stringstream

#include "arch/riscv/isa.hh"          // Cần cho IntReg, registerName, intRegClass
#include "arch/riscv/op_class.hh"     // Cần cho OpClass enum (IntAluOp)
#include "base/loader/symtab.hh"    // Cần cho loader::SymbolTable definition
#include "cpu/base.hh"              // Cần cho BaseCPU
#include "cpu/exec_context.hh"
#include "cpu/static_inst.hh"       // Cần cho registerName và các hàm trợ giúp khác
#include "cpu/thread_context.hh"    // Cần cho ThreadContext (để lấy ISA)
#include "cpu/trace/inst_record.hh" // Cần cho trace::InstRecord definition
#include "sim/faults.hh"            // Cần cho NoFault

namespace gem5
{
namespace RiscvISA
{

MAC_R::MAC_R(const ExtMachInst &machInst) :
    // Constructor lớp cha chuẩn: mnemonic, machInst, OpClass
    RiscvStaticInst("mac", machInst, OpClass::IntAluOp)
{
    // Các chỉ số thanh ghi (src1, src2, dest)
    // được tự động thiết lập bởi lớp cha
    // khi sử dụng format 'R' trong file .isa. Không cần gán thủ công ở đây.
}

std::string
MAC_R::generateDisassembly(Addr pc, const loader::SymbolTable *symtab) const
{
    std::stringstream ss;
    // Sử dụng các hàm trợ giúp chuẩn để lấy chỉ số và tên thanh ghi
    // destRegIdx(0) là thanh ghi đích đầu tiên (và duy nhất cho R-type)
    // srcRegIdx(0) là thanh ghi nguồn đầu tiên (rs1)
    // srcRegIdx(1) là thanh ghi nguồn thứ hai (rs2)
    ss << mnemonic << " "
       << registerName(intRegClass[destRegIdx(0)]) << ", "
       << registerName(intRegClass[srcRegIdx(0)]) << ", "
       << registerName(intRegClass[srcRegIdx(1)]);
    return ss.str();
}

Fault
MAC_R::execute(ExecContext *xc, trace::InstRecord *traceData) const
{
    // Lấy chỉ số thanh ghi bằng hàm trợ giúp chuẩn
    RegId rd = destRegIdx(0);
    RegId rs1 = srcRegIdx(0);
    RegId rs2 = srcRegIdx(1);

    // Đọc giá trị từ thanh ghi nguồn bằng hàm chuẩn
    IntReg val_s1 = xc->readIntRegOperand(this, 0); // Đọc rs1
    IntReg val_s2 = xc->readIntRegOperand(this, 1); // Đọc rs2
    IntReg val_d_old = xc->readIntRegOperand(this, 2);
    // Đọc rd (rd cũng là src thứ 3)

    // Thực hiện phép toán MAC
    IntReg result = val_d_old + (val_s1 * val_s2);

    // Ghi kết quả vào thanh ghi đích bằng API chuẩn
    // setIntRegOperand nhận chỉ số đích (0 cho R type) và giá trị
    xc->setIntRegOperand(this, 0, result);

    // Cập nhật Program Counter bằng hàm trợ giúp chuẩn từ RiscvStaticInst
    advancePC(xc->pcState());

    return NoFault;
}

} // namespace RiscvISA
} // namespace gem5
