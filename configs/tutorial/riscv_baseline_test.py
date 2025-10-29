# configs/tutorial/riscv_baseline_test.py
# Baseline test WITHOUT MAC instruction (for comparison)

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.no_cache import NoCache
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator

# System configuration (same as MAC test for fair comparison)
cache_hierarchy = NoCache()
memory = SingleChannelDDR4_2400(size="2GiB")

processor = SimpleProcessor(
    cpu_type=CPUTypes.TIMING, isa=ISA.RISCV, num_cores=1
)

board = SimpleBoard(
    clk_freq="3GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy,
)

# Set binary workload - using relative path from gem5 directory
board.set_se_binary_workload(
    BinaryResource(local_path="../riscv_test/test_baseline")
)

# Run simulation
simulator = Simulator(board=board)
simulator.run()
