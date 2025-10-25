# configs/tutorial/riscv_mac_test.py
from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.cachehierarchies.classic.no_cache import NoCache
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator

# Cấu hình hệ thống tương tự như trước
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

# Đường dẫn './test_mac' bây giờ sẽ trỏ đến tệp thực thi
board.set_se_binary_workload(BinaryResource("../riscv_test/test_mac"))

simulator = Simulator(board=board)
simulator.run()
