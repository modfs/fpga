create_pblock pblock_Nexus2
create_pblock pblock_Nexus2_1
add_cells_to_pblock [get_pblocks pblock_Nexus2_1] [get_cells -quiet [list Nexus2]]
resize_pblock [get_pblocks pblock_Nexus2_1] -add {SLICE_X0Y254:SLICE_X116Y959}
resize_pblock [get_pblocks pblock_Nexus2_1] -add {DSP48E2_X0Y102:DSP48E2_X15Y383}
resize_pblock [get_pblocks pblock_Nexus2_1] -add {RAMB18_X0Y102:RAMB18_X7Y383}
resize_pblock [get_pblocks pblock_Nexus2_1] -add {RAMB36_X0Y51:RAMB36_X7Y191}
resize_pblock [get_pblocks pblock_Nexus2_1] -add {URAM288_X0Y68:URAM288_X1Y255}
create_pblock pblock_Nexus3
create_pblock pblock_Nexus3_1
add_cells_to_pblock [get_pblocks pblock_Nexus3_1] [get_cells -quiet [list Nexus3]]
resize_pblock [get_pblocks pblock_Nexus3_1] -add {SLICE_X120Y263:SLICE_X232Y959}
resize_pblock [get_pblocks pblock_Nexus3_1] -add {DSP48E2_X16Y106:DSP48E2_X31Y383}
resize_pblock [get_pblocks pblock_Nexus3_1] -add {RAMB18_X9Y106:RAMB18_X13Y383}
resize_pblock [get_pblocks pblock_Nexus3_1] -add {RAMB36_X9Y53:RAMB36_X13Y191}
resize_pblock [get_pblocks pblock_Nexus3_1] -add {URAM288_X2Y72:URAM288_X4Y255}
