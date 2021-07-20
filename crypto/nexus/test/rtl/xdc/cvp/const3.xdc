create_pblock SLR1
add_cells_to_pblock [get_pblocks SLR1] [get_cells -quiet [list Nexus master_axi miner_saxil]]
resize_pblock [get_pblocks SLR1] -add {SLR1}

create_pblock SLR0
add_cells_to_pblock [get_pblocks SLR0] [get_cells -quiet [list Nexus2]]
resize_pblock [get_pblocks SLR0] -add {SLR0}


create_pblock SLR2
add_cells_to_pblock [get_pblocks SLR2] [get_cells -quiet [list Nexus3]]
resize_pblock [get_pblocks SLR2] -add {SLR2}