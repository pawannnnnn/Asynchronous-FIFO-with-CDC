# async_fifo_cdc.sdc
#
# Dual-clock SDC for async_fifo.
#
# The three sections are:
#   1. Define both clocks (wr_clk and rd_clk, different periods)
#   2. Declare false paths across the synchronizer boundaries so the
#      timing engine doesn't try to time an impossible multi-cycle path
#      that crosses clock domains
#   3. Group synchronizer flops so place-and-route keeps them physically
#      close (reducing the chance of a glitch on a long wire being
#      re-sampled by a far-away flop before it settles)

# ── 1. Clock definitions ──────────────────────────────────────────────
create_clock -name WR_CLK -period 10.0 [get_ports wr_clk]
create_clock -name RD_CLK -period 13.0 [get_ports rd_clk]

# These two clocks are asynchronous: no phase relationship.
# Tell the tool to treat them as unrelated domains.
set_clock_groups -asynchronous \
    -group [get_clocks WR_CLK] \
    -group [get_clocks RD_CLK]

# ── 2. False paths across the CDC synchronizer boundary ───────────────
# The WRITE pointer's Gray code travels: wptr_full → sync_2ff → rptr_empty
# The READ  pointer's Gray code travels: rptr_empty → sync_2ff → wptr_full
#
# The path from the sending flop to the first stage of the 2FF
# synchronizer intentionally has NO timing relationship — that's the
# whole point of the synchronizer. Declaring it a false path stops the
# timing engine from flagging it as a violation.
#
# From write-domain pointer to read-domain synchronizer stage 1:
set_false_path \
    -from [get_cells {u_wptr_full/wr_ptr_gray_reg[*]}] \
    -to   [get_cells {u_sync_wr2rd/stage1_reg[*]}]

# From read-domain pointer to write-domain synchronizer stage 1:
set_false_path \
    -from [get_cells {u_rptr_empty/rd_ptr_gray_reg[*]}] \
    -to   [get_cells {u_sync_rd2wr/stage1_reg[*]}]

# ── 3. Input / output delays (reference only — adjust for your system) ─
set_input_delay  -clock WR_CLK -max 2.0 [get_ports wr_data]
set_input_delay  -clock WR_CLK -max 2.0 [get_ports wr_en]
set_input_delay  -clock RD_CLK -max 2.0 [get_ports rd_en]

set_output_delay -clock RD_CLK -max 2.0 [get_ports rd_data]
set_output_delay -clock WR_CLK -max 2.0 [get_ports full]
set_output_delay -clock RD_CLK -max 2.0 [get_ports empty]
