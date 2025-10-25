from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.cachehierarchies.classic.no_cache import NoCache
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator

# 1. Cấu hình Cache
cache_hierarchy = NoCache()

# 2. Cấu hình Bộ nhớ
# Dùng một kênh DDR4 đơn giản
memory = SingleChannelDDR4_2400(size="2GiB")

# 3. Cấu hình Bộ xử lý (CPU)
processor = SimpleProcessor(
    cpu_type=CPUTypes.TIMING, # Tương đương TimingSimpleCPU
    isa=ISA.RISCV,            # Tương đương build/RISCV
    num_cores=1
)

# 4. Cấu hình Bo mạch (Board)
board = SimpleBoard(
    clk_freq="3GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy,
)

# 5. Cấu hình Workload (Tệp nhị phân)
# Chúng ta dùng 'set_se_binary_workload' và chỉ cần truyền
# đường dẫn (dạng string) của tệp nhị phân.
board.set_se_binary_workload(
    BinaryResource("tests/test-progs/hello/bin/riscv/linux/hello")
)

# 6. Khởi chạy và Chạy mô phỏng
simulator = Simulator(board=board)
print("--- Bắt đầu mô phỏng Hello World cho RISC-V ---")
simulator.run()
print("--- Mô phỏng kết thúc ---")