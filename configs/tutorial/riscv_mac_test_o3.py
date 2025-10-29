# configs/tutorial/riscv_mac_test_o3.py
# gem5 configuration for testing MAC with O3 (Out-of-Order) CPU

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.private_l1_cache_hierarchy import (
    PrivateL1CacheHierarchy,
)
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator

# System configuration with O3 CPU and cache
# O3 = Out-of-Order CPU, better performance than TIMING (in-order)
cache_hierarchy = PrivateL1CacheHierarchy(l1d_size="32KiB", l1i_size="32KiB")
memory = SingleChannelDDR4_2400(size="2GiB")

processor = SimpleProcessor(
    cpu_type=CPUTypes.O3, isa=ISA.RISCV, num_cores=1  # Out-of-Order CPU
)

board = SimpleBoard(
    clk_freq="3GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy,
)

# Set binary workload
board.set_se_binary_workload(
    BinaryResource(local_path="../riscv_test/test_mac")
)

# Run simulation
simulator = Simulator(board=board)
simulator.run()
