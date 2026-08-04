`include "rv64im_core_defines.sv"

module rv64im_core_dcache #(
    parameter CACHE_SIZE        = 4096,
    parameter LINE_SIZE         = 256,   //32 btye, 8 inst
    parameter RW_DATA_WIDTH     = 64,
    parameter RW_ADDR_WIDTH     = 32
)(
    //form mem : slave interface
    input  wire i_mem_req_vld,
    input  wire i_mem_wen,
    input  wire [RW_ADDR_WIDTH-1:0] i_mem_addr,
    input  wire [RW_DATA_WIDTH-1:0] i_mem_wdata,
    input  wire [7:0] i_mem_wmask,
    output wire o_mem_req_rdy,

    input  wire i_mem_rsp_rdy,
    output wire [RW_DATA_WIDTH-1:0] o_mem_rdata,
    output wire o_mem_rsp_vld,

    //to abriter : master interface
    output wire o_abr_valid,
    output wire o_abr_wen,
    output wire [RW_ADDR_WIDTH-1:0] o_abr_addr,
    output wire [RW_DATA_WIDTH-1:0] o_abr_wdata,
    output wire [7:0] o_abr_wmask,
    input  wire [RW_DATA_WIDTH-1:0] i_abr_rdata,
    input  wire i_abr_ready,

    input  wire clk,
    input  wire rstn
);
    //write back and write allocate
    //parameter WAY_NUM = 4;    
    parameter OFFSET_SIZE = $clog2(LINE_SIZE/8);    //5: 32 btye
    parameter ARRY_DEPTH  = CACHE_SIZE/(LINE_SIZE/8)/4;    //5: 32 btye
    parameter INDEX_SIZE  = $clog2(CACHE_SIZE/(LINE_SIZE/8)/4);   //5:every way 32 line
    parameter TAG_SIZE    = RW_ADDR_WIDTH - INDEX_SIZE - OFFSET_SIZE;   //32-4-7=21 
    
    //c1
    //w hit : w
    //r hit : r
    //w miss vic dry    : bus-w -> bus-r & w 
    //w miss no vic dry : bus-r -> w 
    //r miss vic dry    : bus-w -> bus-r & r
    //r miss no vic dry : bus-r -> r
    //state: NORM WBUS RBUS
    //c2
    //hit  :    -> ack
    //miss : bus-r -> ack
    parameter NORM = 2'b00;
    parameter WBUS = 2'b01;
    parameter RBUS = 2'b10;

    reg  [1:0] state;
    wire [1:0] state_ns;
    wire state_en;
    wire state_is_wbus;
    wire state_is_rbus;
    wire state_is_norm;

    wire req_vld;
    wire req_w;
    //wire req_r;
    wire req_hit;
    wire req_miss;
    wire [3:0] way_hit;
    wire [3:0] way_vic;
    wire [3:0] way_dry;
    wire [3:0] way_vld;

    wire vic_dry;
    wire wbus_en;
    wire wbus_done;
    wire rbus_en;
    wire rbus_done;
    wire norm_en;

    reg [TAG_SIZE-1:0] tag_arry0 [ARRY_DEPTH-1:0];
    reg [TAG_SIZE-1:0] tag_arry1 [ARRY_DEPTH-1:0];
    reg [TAG_SIZE-1:0] tag_arry2 [ARRY_DEPTH-1:0];
    reg [TAG_SIZE-1:0] tag_arry3 [ARRY_DEPTH-1:0];
    reg [1:0] sign_arry0 [ARRY_DEPTH-1:0];
    reg [1:0] sign_arry1 [ARRY_DEPTH-1:0];
    reg [1:0] sign_arry2 [ARRY_DEPTH-1:0];
    reg [1:0] sign_arry3 [ARRY_DEPTH-1:0];
    reg [2:0] plru_arry [ARRY_DEPTH-1:0];

    wire [INDEX_SIZE-1:0] idx   = i_mem_addr[(OFFSET_SIZE) +: INDEX_SIZE];
    wire [TAG_SIZE-1:0]   tag   = i_mem_addr[(OFFSET_SIZE+INDEX_SIZE) +: TAG_SIZE];

//c0 stage
    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            state <= 2'b0;
        end else if(state_en) begin
            state <= state_ns;
        end
    end 

    assign wbus_en  = req_miss & vic_dry;
    assign rbus_en  = req_miss & ~vic_dry | wbus_done;
    assign norm_en  = rbus_done;
    assign state_en = norm_en | wbus_en | rbus_en;
    assign state_ns = {2{norm_en}} & NORM
                     | {2{wbus_en}} & WBUS
                    | {2{rbus_en}} & RBUS
                    ;
    assign state_is_norm =(state == NORM);
    assign state_is_wbus =(state == WBUS);
    assign state_is_rbus =(state == RBUS);
//hit or miss
    assign req_vld = i_mem_req_vld & o_mem_req_rdy;
    assign req_w = req_vld & i_mem_wen;
    //assign req_r = req_vld & ~i_mem_wen;

    assign way_hit[3:0] = {(tag_arry3[idx]==tag) , (tag_arry2[idx]==tag) , (tag_arry1[idx]==tag), (tag_arry0[idx]==tag)} & way_vld[3:0];
    assign req_hit  = req_vld & (|way_hit[3:0]);
    assign req_miss = req_vld & ~(|way_hit[3:0]);
//gen vic_dry
    assign vic_dry = |(way_vic[3:0] & way_dry[3:0] & way_vld[3:0]);
    assign way_vld[3:0] = {sign_arry3[idx][0],sign_arry2[idx][0],sign_arry1[idx][0],sign_arry0[idx][0]};
    //plru
    //b0 ? way0/1 : way2/way3
    //b1 ? way0   : way1
    //b2 ? way2   : way3
    //0?0 way3 new   ?00 way0 old
    //1?0 way2 new   ?10 way1 old
    //?01 way1 new   0?1 way2 old
    //?11 way0 new   1?1 way3 old
    assign way_vic[3:0] = {plru_arry[idx][2] & plru_arry[idx][0],  //if valid : the vic way; else: the free way;
                          ~plru_arry[idx][2] & plru_arry[idx][0],
                           plru_arry[idx][1] &~plru_arry[idx][0],
                          ~plru_arry[idx][1] &~plru_arry[idx][0]};
    assign way_dry[3:0] = {sign_arry3[idx][1],sign_arry2[idx][1],sign_arry1[idx][1],sign_arry0[idx][1]};
//ram ctl
    wire [3:0] ram_cs;
    wire ram_wen;
    wire [INDEX_SIZE-1:0]      ram_addr;
    wire [(RW_DATA_WIDTH-1):0] ram_wdata;
    wire [RW_DATA_WIDTH/8-1:0] ram_wmask;
    wire [RW_DATA_WIDTH-1:0] ram_rdata[3:0];
    wire [3:0] ram_bank_sel;
    wire bus_wram_vld;
    wire bus_rram_vld;
    reg [RW_ADDR_WIDTH-1:0] vic_addr_ff;
    reg [RW_ADDR_WIDTH-1:0] addr_ff;
    reg wen_ff;
    reg [1:0] wcnt;
    reg [1:0] rcnt;
    wire [RW_DATA_WIDTH-1:0] rbus_data;

    reg [3:0] way_vic_ff;
    reg [1:0] rram_cnt;

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            wen_ff  <= 0;
            addr_ff <= 0;
        end else if(req_miss) begin
            wen_ff  <= i_mem_wen;
            addr_ff <= i_mem_addr;
        end
    end
    
    assign ram_cs[3:0] = (way_hit[3:0] & {4{req_vld}}) | (way_vic_ff[3:0] & {4{bus_wram_vld}}) | (way_vic_ff[3:0] & {4{bus_rram_vld}});
    assign ram_wen = (state_is_norm & i_mem_wen) | (state_is_rbus & bus_wram_vld);
    assign ram_addr = state_is_wbus                   ? vic_addr_ff[(OFFSET_SIZE) +: INDEX_SIZE] :
                      state_is_rbus                   ? addr_ff[(OFFSET_SIZE) +: INDEX_SIZE]  :
                      idx;
    assign ram_bank_sel = state_is_wbus ? (4'b0001 << rram_cnt) :
                          state_is_rbus ? (4'b0001 << rcnt) :
                          (4'b0001 << i_mem_addr[(OFFSET_SIZE-1) -: 2])
                          ;
    assign ram_wdata = state_is_rbus ? rbus_data : i_mem_wdata;
    assign ram_wmask = state_is_rbus ? 8'hff  : i_mem_wmask;
generate
for(genvar ii=0;ii<4;ii=ii+1) begin : gen_rdata_arry_ii
rv64im_core_ram#(
    .DATA_SIZE                     ( LINE_SIZE/4),
    .ADDR_SIZE                     ( INDEX_SIZE ),
    .DEPTH                         ( ARRY_DEPTH )
)u_rv64im_core_ram(
    .i_ram_cs                       (ram_cs[ii]    ),
    .i_ram_addr                     (ram_addr      ),
    .i_ram_bank_sel                 (ram_bank_sel  ),
    .i_ram_wen                      (ram_wen       ),
    .i_ram_wmask                    (ram_wmask     ),
    .o_ram_rdata                   (ram_rdata[ii] ),
    .i_ram_wdata                    (ram_wdata     ),
    .clk                           (clk           ),
    .rstn                          (rstn          )
);
end
endgenerate

////c1 stage
    wire stall_c1;
    reg vld_c1;    
    wire vld_c1_ns;
    wire [RW_DATA_WIDTH-1:0] data_of_ram;
    reg  [RW_DATA_WIDTH-1:0] data_of_bus;
    reg [3:0] way_hit_ff;
    reg [7:0] wmask_ff;
    reg [RW_DATA_WIDTH-1:0]  wdata_ff;

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            vld_c1 <= 1'b0;
        end else begin
            vld_c1 <= vld_c1_ns;
        end
    end

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            way_hit_ff <= 4'b0;
        end else if(req_hit) begin
            way_hit_ff <= way_hit;
        end
    end

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            way_vic_ff <= 0;
            wmask_ff   <= 0;
            wdata_ff   <= 0;
        end else if(req_miss) begin
            way_vic_ff <= way_vic;
            wmask_ff   <= i_mem_wmask;
            wdata_ff   <= i_mem_wdata;
        end
    end

    assign stall_c1 = o_mem_rsp_vld & ~i_mem_rsp_rdy;
    //assign stall_c1 = 1'b0; //for lsu : i_mem_rsp_rdy == 1'b1 //don't desgin radta of lsu stall;

    assign vld_c1_ns = stall_c1 ? vld_c1 : (req_hit | rbus_done);
    assign data_of_ram = ({RW_DATA_WIDTH{way_hit_ff[3]}} & ram_rdata[3][RW_DATA_WIDTH-1:0])
                       | ({RW_DATA_WIDTH{way_hit_ff[2]}} & ram_rdata[2][RW_DATA_WIDTH-1:0])
                       | ({RW_DATA_WIDTH{way_hit_ff[1]}} & ram_rdata[1][RW_DATA_WIDTH-1:0])
                       | ({RW_DATA_WIDTH{way_hit_ff[0]}} & ram_rdata[0][RW_DATA_WIDTH-1:0])
                       ;
//wbus stage
    wire [RW_ADDR_WIDTH-1:0] vic_addr;
    wire [TAG_SIZE-1:0] vic_tag;
    wire wover_one;

    reg wbus_vld;
    reg wbus_en_ff;
    wire [RW_DATA_WIDTH-1:0] wbus_data;
    wire [RW_ADDR_WIDTH-1:0] wbus_addr;

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            vic_addr_ff <= 0;
        end else if(req_miss) begin
            vic_addr_ff <= vic_addr;
        end
    end
    assign vic_addr = {vic_tag,idx,{OFFSET_SIZE{1'b0}}};
    assign vic_tag  =    ({TAG_SIZE{way_vic[3]}} & tag_arry3[idx][TAG_SIZE-1:0])
                       | ({TAG_SIZE{way_vic[2]}} & tag_arry2[idx][TAG_SIZE-1:0])
                       | ({TAG_SIZE{way_vic[1]}} & tag_arry1[idx][TAG_SIZE-1:0])
                       | ({TAG_SIZE{way_vic[0]}} & tag_arry0[idx][TAG_SIZE-1:0])
                       ;

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            wcnt <= 0;
        end else if(wover_one) begin
            wcnt <= wcnt+1;
        end
    end

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            rram_cnt <= 0;
        end else if(bus_rram_vld) begin
            rram_cnt <= rram_cnt+1;
        end
    end
    assign wbus_done = wover_one & (wcnt == 2'b11);
    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            wbus_en_ff <= 0;
        end else begin
            wbus_en_ff <= wbus_en;
        end
    end
    assign bus_rram_vld =  (wbus_en_ff | wover_one & (wcnt!=2'b11));

    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            wbus_vld <= 0;
        end else begin
            wbus_vld <= (bus_rram_vld | (wbus_vld & ~i_abr_ready));
        end
    end

    assign wbus_addr = {vic_addr_ff[(RW_ADDR_WIDTH-1) -: (TAG_SIZE+INDEX_SIZE)], wcnt , {(OFFSET_SIZE-2){1'b0}}};
    assign wbus_data =   ({RW_DATA_WIDTH{way_vic_ff[3]}} & ram_rdata[3][RW_DATA_WIDTH-1:0])
                       | ({RW_DATA_WIDTH{way_vic_ff[2]}} & ram_rdata[2][RW_DATA_WIDTH-1:0])
                       | ({RW_DATA_WIDTH{way_vic_ff[1]}} & ram_rdata[1][RW_DATA_WIDTH-1:0])
                       | ({RW_DATA_WIDTH{way_vic_ff[0]}} & ram_rdata[0][RW_DATA_WIDTH-1:0])
                       ;
    assign wover_one = i_abr_ready & wbus_vld;


//rbus stage
    reg rbus_vld;
    wire [RW_ADDR_WIDTH-1:0] rbus_addr;
    wire [1:0] bank_of_miss;
    wire [RW_DATA_WIDTH-1:0] miss_wdata;
    reg rbus_done_ff;

generate  
    genvar i;  
    for (i=0; i<(RW_DATA_WIDTH/8); i=i+1) begin : gen_mask
        assign miss_wdata[(i*8) +: 8] = wmask_ff[i] ? wdata_ff[(i*8) +: 8] : i_abr_rdata[(i*8) +: 8];
    end
endgenerate

    assign rbus_done = bus_wram_vld & (rcnt==2'b11);
    assign rbus_addr = {addr_ff[(RW_ADDR_WIDTH-1) -: (TAG_SIZE+INDEX_SIZE)], rcnt , {(OFFSET_SIZE-2){1'b0}}};
    assign bank_of_miss = addr_ff[(OFFSET_SIZE-1) -: 2];
    assign rbus_data = wen_ff & (rcnt == bank_of_miss) ? miss_wdata : 
                                                         i_abr_rdata
                                                         ;
    assign bus_wram_vld = rbus_vld & i_abr_ready;
    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            rcnt <= 0;
        end else if(bus_wram_vld) begin
            rcnt <= rcnt+1;
        end
    end
    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            rbus_vld <= 0;
        end else begin
            rbus_vld <= (rbus_en | (rbus_vld & ~i_abr_ready) | bus_wram_vld & (rcnt!=2'b11));
        end
    end
    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            data_of_bus <= 0;
        end else if(~wen_ff & (rcnt == bank_of_miss) & bus_wram_vld) begin
            data_of_bus <= i_abr_rdata;
        end
    end
    always @( posedge clk or negedge rstn  ) begin
        if(!rstn)begin
            rbus_done_ff <= 0;
        end else if(rbus_done) begin
            rbus_done_ff <= 1'b1;
        end else if(o_mem_rsp_vld & i_mem_rsp_rdy) begin
            rbus_done_ff <= 1'b0;
        end
    end
//abr
    assign o_abr_valid = state_is_wbus ? wbus_vld  : rbus_vld;
    assign o_abr_addr  = state_is_wbus ? wbus_addr : rbus_addr;
    assign o_abr_wen   = state_is_wbus;
    assign o_abr_wdata = wbus_data;
    assign o_abr_wmask = 8'hff;

//update vld, dry
    wire [INDEX_SIZE-1:0] idx_ff;
    wire [INDEX_SIZE-1:0] idx_up_sel;
    assign idx_ff = addr_ff[(OFFSET_SIZE) +: INDEX_SIZE];
    assign idx_up_sel = req_hit ? idx : idx_ff;
//update tag arry
    wire tag_arry_up_en;
    wire [TAG_SIZE-1:0] tag_arry0_ns;
    wire [TAG_SIZE-1:0] tag_arry1_ns;
    wire [TAG_SIZE-1:0] tag_arry2_ns;
    wire [TAG_SIZE-1:0] tag_arry3_ns;
generate
    genvar jj;
    for(jj=0;jj<ARRY_DEPTH;jj=jj+1) begin : u_tag
        always @( posedge clk or negedge rstn  ) begin
            if(!rstn)begin
                tag_arry0[jj] <= 0;
                tag_arry1[jj] <= 0;
                tag_arry2[jj] <= 0;
                tag_arry3[jj] <= 0;
            end else if(tag_arry_up_en & (jj==idx_ff)) begin
                tag_arry0[jj] <= tag_arry0_ns;
                tag_arry1[jj] <= tag_arry1_ns;
                tag_arry2[jj] <= tag_arry2_ns;
                tag_arry3[jj] <= tag_arry3_ns;
            end
        end
    end
endgenerate
    assign tag_arry_up_en = rbus_done;
    assign tag_arry0_ns = tag_arry_up_en  & way_vic_ff[0] ?  addr_ff[(RW_ADDR_WIDTH-1) -: TAG_SIZE] : tag_arry0[idx_ff];
    assign tag_arry1_ns = tag_arry_up_en  & way_vic_ff[1] ?  addr_ff[(RW_ADDR_WIDTH-1) -: TAG_SIZE] : tag_arry1[idx_ff];
    assign tag_arry2_ns = tag_arry_up_en  & way_vic_ff[2] ?  addr_ff[(RW_ADDR_WIDTH-1) -: TAG_SIZE] : tag_arry2[idx_ff];
    assign tag_arry3_ns = tag_arry_up_en  & way_vic_ff[3] ?  addr_ff[(RW_ADDR_WIDTH-1) -: TAG_SIZE] : tag_arry3[idx_ff];
//update sign arry
    wire [1:0] sign_arry_up_en;
    wire dry_way0_ns;
    wire dry_way1_ns;
    wire dry_way2_ns;
    wire dry_way3_ns;
    wire vld_way0_ns;
    wire vld_way1_ns;
    wire vld_way2_ns;
    wire vld_way3_ns;
generate
    genvar kk;
    for(kk=0;kk<ARRY_DEPTH;kk=kk+1) begin : u_sign
        always @( posedge clk or negedge rstn  ) begin
            if(!rstn)begin
                sign_arry0[kk][1] <= 0;
                sign_arry1[kk][1] <= 0;
                sign_arry2[kk][1] <= 0;
                sign_arry3[kk][1] <= 0;
            end else if(sign_arry_up_en[1]  & (kk==idx_up_sel)) begin
                sign_arry0[kk][1] <= dry_way0_ns;
                sign_arry1[kk][1] <= dry_way1_ns;
                sign_arry2[kk][1] <= dry_way2_ns;
                sign_arry3[kk][1] <= dry_way3_ns;
            end
        end
        always @( posedge clk or negedge rstn  ) begin
            if(!rstn)begin
                sign_arry0[kk][0] <= 0;
                sign_arry1[kk][0] <= 0;
                sign_arry2[kk][0] <= 0;
                sign_arry3[kk][0] <= 0;
            end else if(sign_arry_up_en[0] & (kk==idx_ff)) begin
                sign_arry0[kk][0] <= vld_way0_ns;
                sign_arry1[kk][0] <= vld_way1_ns;
                sign_arry2[kk][0] <= vld_way2_ns;
                sign_arry3[kk][0] <= vld_way3_ns;
            end
        end
    end
endgenerate
    assign sign_arry_up_en[1] = req_hit & req_w | rbus_done & wen_ff;
    assign sign_arry_up_en[0] = rbus_done;
    //dry
    //assign dry_way0_ns = rbus_done & way_vic[0] | req_hit & req_w & way_hit[0] ?  1'b1 : sign_arry0[idx_up_sel][1];
    //assign dry_way1_ns = rbus_done & way_vic[1] | req_hit & req_w & way_hit[1] ?  1'b1 : sign_arry1[idx_up_sel][1];
    //assign dry_way2_ns = rbus_done & way_vic[2] | req_hit & req_w & way_hit[2] ?  1'b1 : sign_arry2[idx_up_sel][1];
    //assign dry_way3_ns = rbus_done & way_vic[3] | req_hit & req_w & way_hit[3] ?  1'b1 : sign_arry3[idx_up_sel][1];
    assign dry_way0_ns = req_hit & req_w & way_hit[0] | rbus_done & wen_ff & way_vic_ff[0]?  1'b1 : sign_arry0[idx_up_sel][1];
    assign dry_way1_ns = req_hit & req_w & way_hit[1] | rbus_done & wen_ff & way_vic_ff[1]?  1'b1 : sign_arry1[idx_up_sel][1];
    assign dry_way2_ns = req_hit & req_w & way_hit[2] | rbus_done & wen_ff & way_vic_ff[2]?  1'b1 : sign_arry2[idx_up_sel][1];
    assign dry_way3_ns = req_hit & req_w & way_hit[3] | rbus_done & wen_ff & way_vic_ff[3]?  1'b1 : sign_arry3[idx_up_sel][1];
    //valid
    assign vld_way0_ns = rbus_done & way_vic_ff[0] ?  1'b1 : sign_arry0[idx_ff][0];
    assign vld_way1_ns = rbus_done & way_vic_ff[1] ?  1'b1 : sign_arry1[idx_ff][0];
    assign vld_way2_ns = rbus_done & way_vic_ff[2] ?  1'b1 : sign_arry2[idx_ff][0];
    assign vld_way3_ns = rbus_done & way_vic_ff[3] ?  1'b1 : sign_arry3[idx_ff][0];

//update plru arry
    wire plru_arry_up_en;
    wire [2:0] plru_arry_ns;
    wire [2:0] hit_plru_up;
    wire [2:0] mis_plru_up;
generate
    genvar mm;
    for(mm=0;mm<ARRY_DEPTH;mm=mm+1) begin : u_plru
        always @( posedge clk or negedge rstn  ) begin
            if(!rstn)begin
                plru_arry[mm] <= 0;
            end else if(plru_arry_up_en & (mm==idx_up_sel)) begin
                plru_arry[mm] <= plru_arry_ns;
            end
        end
    end
endgenerate
    assign plru_arry_up_en = req_hit | rbus_done;
    assign plru_arry_ns = req_hit  ? hit_plru_up : mis_plru_up;
    assign hit_plru_up = ({3{way_hit[3]}}    & {1'b0,plru_arry[idx_up_sel][1],1'b0})
                       | ({3{way_hit[2]}}    & {1'b1,plru_arry[idx_up_sel][1],1'b0})
                       | ({3{way_hit[1]}}    & {plru_arry[idx_up_sel][2],1'b0,1'b1})
                       | ({3{way_hit[0]}}    & {plru_arry[idx_up_sel][2],1'b1,1'b1})
                       ;
    assign mis_plru_up = ({3{way_vic_ff[3]}} & {1'b0,plru_arry[idx_up_sel][1],1'b0})
                       | ({3{way_vic_ff[2]}} & {1'b1,plru_arry[idx_up_sel][1],1'b0})
                       | ({3{way_vic_ff[1]}} & {plru_arry[idx_up_sel][2],1'b0,1'b1})
                       | ({3{way_vic_ff[0]}} & {plru_arry[idx_up_sel][2],1'b1,1'b1})
                       ;
//t0 mem
    assign o_mem_rsp_vld = vld_c1;
    assign o_mem_rdata = rbus_done_ff ? data_of_bus : data_of_ram;
    assign o_mem_req_rdy = state_is_norm & ~stall_c1;

    

endmodule //rv64im_core_dcache
