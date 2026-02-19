// LLM顶层模块
// 基于AMBA CHI-H协议，支持snp操作，同步设计
// RN和SN分别对接CHI-H接口
// 集成chi_slv、cmd_ctrl、PCQ、data_ctrl、chi_mst、ecc_ctrl和prefetch_ctrl子模块

// 导入参数
import llm_params::*;

module llm_top (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    input logic clk_en, // 时钟门控使能
    
    // 配置接口
    input logic [1:0] replace_policy,
    input logic ecc_en,
    input logic prefetch_en,
    input logic [2:0] prefetch_depth,
    input logic [15:0] req_timeout,
    input logic [1:0] chi_h_version,
    input logic [2:0] req_priority,
    input logic [4:0] pcq_threshold,
    
    // 配置与状态通道（新增）
    input logic [31:0] cfg_bus_addr,
    input logic [31:0] cfg_bus_wdata,
    output logic [31:0] cfg_bus_rdata,
    input logic cfg_bus_we,
    output logic [127:0] status_bus,
    
    // 状态输出
    output logic [2:0] pipeline_stage,
    output logic [2:0] tag_ecc_error,
    output logic [1:0] split_req_num,
    output logic pcq_congestion,
    output logic out_of_order_en,
    output logic [7:0] snp_resp_latency,
    output logic [31:0] error_report,
    output logic [3:0] pending_req_count,
    
    // RN（Request Node）CHI-H协议接口（向上级Cache）
    // 请求通道
    input logic [CHI_ADDR_WIDTH-1:0] rn_chi_req_addr,
    input logic [CHI_DATA_WIDTH-1:0] rn_chi_req_data,
    input logic [7:0] rn_chi_req_size,
    input logic rn_chi_req_valid,
    input logic rn_chi_req_snp,
    input logic [31:0] rn_chi_req_pld,
    input logic [PRIORITY_WIDTH-1:0] rn_chi_req_priority,
    output logic rn_chi_req_ready,
    
    // 响应通道
    output logic [CHI_DATA_WIDTH-1:0] rn_chi_resp_data,
    output logic rn_chi_resp_valid,
    output logic rn_chi_resp_error,
    output logic [31:0] rn_chi_resp_pld,
    output logic [PRIORITY_WIDTH-1:0] rn_chi_resp_priority,
    input logic rn_chi_resp_ready,
    
    // SN（Snoop Node）CHI-H协议接口（向上级Cache）
    // 请求通道
    output logic [CHI_ADDR_WIDTH-1:0] sn_chi_req_addr,
    output logic [CHI_DATA_WIDTH-1:0] sn_chi_req_data,
    output logic [7:0] sn_chi_req_size,
    output logic sn_chi_req_valid,
    output logic sn_chi_req_snp,
    output logic [31:0] sn_chi_req_pld,
    output logic [PRIORITY_WIDTH-1:0] sn_chi_req_priority,
    input logic sn_chi_req_ready,
    
    // 响应通道
    input logic [CHI_DATA_WIDTH-1:0] sn_chi_resp_data,
    input logic sn_chi_resp_valid,
    input logic sn_chi_resp_error,
    input logic [31:0] sn_chi_resp_pld,
    output logic sn_chi_resp_ready
);
    
    // 子模块之间的信号
    // chi_slv <-> cmd_ctrl
    logic [CHI_ADDR_WIDTH-1:0] cmd_addr;
    logic [CHI_DATA_WIDTH-1:0] cmd_data;
    logic [7:0] cmd_size;
    logic cmd_valid;
    logic cmd_snp;
    logic [3:0] cmd_type;
    logic [31:0] cmd_pld;
    logic [PRIORITY_WIDTH-1:0] cmd_priority;
    logic cmd_ready;
    
    // chi_slv <-> 响应
    logic [CHI_DATA_WIDTH-1:0] rsp_data;
    logic rsp_valid;
    logic rsp_error;
    logic [31:0] rsp_pld;
    logic [PRIORITY_WIDTH-1:0] rsp_priority;
    logic rsp_ready;
    
    // cmd_ctrl <-> PCQ
    logic [CHI_ADDR_WIDTH-1:0] pcq_addr;
    logic [CHI_DATA_WIDTH-1:0] pcq_data;
    logic [7:0] pcq_size;
    logic pcq_valid;
    logic pcq_snp;
    logic [3:0] pcq_type;
    logic [31:0] pcq_pld;
    logic [PRIORITY_WIDTH-1:0] pcq_priority;
    logic pcq_ready;
    
    // cmd_ctrl <-> data_ctrl
    logic [TAG_WIDTH-1:0] tag;
    logic [SET_INDEX_WIDTH-1:0] set_index;
    logic [OFFSET_WIDTH-1:0] offset;
    logic [NUM_WAYS-1:0] way_hit;
    logic [WAY_INDEX_WIDTH-1:0] hit_way;
    logic cache_hit;
    logic [WAY_INDEX_WIDTH-1:0] victim_way;
    logic update_tag;
    logic [TAG_WIDTH-1:0] new_tag;
    logic tag_updated;
    
    // cmd_ctrl <-> chi_mst
    logic [CHI_ADDR_WIDTH-1:0] mst_addr;
    logic [7:0] mst_size;
    logic mst_valid;
    logic mst_snp;
    logic [PRIORITY_WIDTH-1:0] mst_priority;
    logic mst_ready;
    
    // PCQ <-> data_ctrl
    logic [CHI_ADDR_WIDTH-1:0] dc_addr;
    logic [CHI_DATA_WIDTH-1:0] dc_data;
    logic [7:0] dc_size;
    logic dc_valid;
    logic dc_snp;
    logic [3:0] dc_type;
    logic [31:0] dc_pld;
    logic [PRIORITY_WIDTH-1:0] dc_priority;
    logic dc_ready;
    
    // PCQ <-> 其他模块
    logic [CHI_ADDR_WIDTH-1:0] curr_addr;
    logic [CHI_DATA_WIDTH-1:0] curr_data;
    logic [7:0] curr_size;
    logic curr_snp;
    logic [3:0] curr_type;
    logic [31:0] curr_pld;
    logic [PRIORITY_WIDTH-1:0] curr_priority;
    logic curr_valid;
    logic curr_ready;
    
    // data_ctrl <-> 其他模块
    logic [CACHELINE_SIZE*8-1:0] cache_data;
    logic [CACHELINE_SIZE*8-1:0] snp_data;
    logic cache_valid;
    logic snp_valid;
    logic cache_ready;
    logic snp_ready;
    
    // chi_mst <-> 其他模块
    logic [CHI_DATA_WIDTH-1:0] fetch_data;
    logic fetch_valid;
    logic fetch_error;
    logic fetch_ready;
    
    // cmd_ctrl <-> ecc_ctrl
    logic [TAG_WIDTH-1:0] tag_ecc_in;
    logic [ECC_BIT_WIDTH-1:0] tag_ecc_out;
    logic [2:0] tag_error_status;
    logic tag_error_corrected;
    logic [TAG_WIDTH-1:0] tag_corrected;
    
    // data_ctrl <-> ecc_ctrl
    logic [CACHELINE_SIZE*8-1:0] data_ecc_in;
    logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] data_ecc_out;
    logic [2:0] data_error_status;
    logic data_error_corrected;
    logic [CACHELINE_SIZE*8-1:0] data_corrected;
    logic data_write_en;
    
    // cmd_ctrl <-> prefetch_ctrl
    logic [CHI_ADDR_WIDTH-1:0] access_addr;
    logic access_valid;
    logic access_is_write;
    
    // prefetch_ctrl <-> data_ctrl
    logic [CHI_ADDR_WIDTH-1:0] prefetch_addr;
    logic prefetch_valid;
    logic [PRIORITY_WIDTH-1:0] prefetch_priority;
    logic prefetch_ready;
    
    // ecc_ctrl <-> chi_slv
    logic error_report_valid;
    logic [31:0] ecc_error_report;
    
    // 实例化chi_slv模块
    llm_chi_slv chi_slv (
        .clk(clk),
        .rst_n(rst_n),
        .chi_h_version(chi_h_version),
        .snp_resp_latency(snp_resp_latency),
        .error_report(error_report),
        .rn_chi_req_addr(rn_chi_req_addr),
        .rn_chi_req_data(rn_chi_req_data),
        .rn_chi_req_size(rn_chi_req_size),
        .rn_chi_req_valid(rn_chi_req_valid),
        .rn_chi_req_snp(rn_chi_req_snp),
        .rn_chi_req_pld(rn_chi_req_pld),
        .rn_chi_req_priority(rn_chi_req_priority),
        .rn_chi_req_ready(rn_chi_req_ready),
        .rn_chi_resp_data(rn_chi_resp_data),
        .rn_chi_resp_valid(rn_chi_resp_valid),
        .rn_chi_resp_error(rn_chi_resp_error),
        .rn_chi_resp_pld(rn_chi_resp_pld),
        .rn_chi_resp_priority(rn_chi_resp_priority),
        .rn_chi_resp_ready(rn_chi_resp_ready),
        .cmd_addr(cmd_addr),
        .cmd_data(cmd_data),
        .cmd_size(cmd_size),
        .cmd_valid(cmd_valid),
        .cmd_snp(cmd_snp),
        .cmd_type(cmd_type),
        .cmd_pld(cmd_pld),
        .cmd_priority(cmd_priority),
        .cmd_ready(cmd_ready),
        .rsp_data(rsp_data),
        .rsp_valid(rsp_valid),
        .rsp_error(rsp_error),
        .rsp_pld(rsp_pld),
        .rsp_priority(rsp_priority),
        .rsp_ready(rsp_ready),
        .error_report_valid(error_report_valid),
        .ecc_error_report(ecc_error_report)
    );
    
    // 实例化cmd_ctrl模块
    llm_cmd_ctrl cmd_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .replace_policy(replace_policy),
        .ecc_en(ecc_en),
        .cmd_addr(cmd_addr),
        .cmd_data(cmd_data),
        .cmd_size(cmd_size),
        .cmd_valid(cmd_valid),
        .cmd_snp(cmd_snp),
        .cmd_type(cmd_type),
        .cmd_pld(cmd_pld),
        .cmd_priority(cmd_priority),
        .cmd_ready(cmd_ready),
        .pcq_addr(pcq_addr),
        .pcq_data(pcq_data),
        .pcq_size(pcq_size),
        .pcq_valid(pcq_valid),
        .pcq_snp(pcq_snp),
        .pcq_type(pcq_type),
        .pcq_pld(pcq_pld),
        .pcq_priority(pcq_priority),
        .pcq_ready(pcq_ready),
        .tag(tag),
        .set_index(set_index),
        .offset(offset),
        .way_hit(way_hit),
        .hit_way(hit_way),
        .cache_hit(cache_hit),
        .victim_way(victim_way),
        .update_tag(update_tag),
        .new_tag(new_tag),
        .tag_updated(tag_updated),
        .mst_addr(mst_addr),
        .mst_size(mst_size),
        .mst_valid(mst_valid),
        .mst_snp(mst_snp),
        .mst_priority(mst_priority),
        .mst_ready(mst_ready),
        .rsp_data(rsp_data),
        .rsp_valid(rsp_valid),
        .rsp_error(rsp_error),
        .rsp_pld(rsp_pld),
        .rsp_priority(rsp_priority),
        .rsp_ready(rsp_ready),
        .tag_ecc_in(tag_ecc_in),
        .tag_ecc_out(tag_ecc_out),
        .tag_error_status(tag_error_status),
        .tag_error_corrected(tag_error_corrected),
        .tag_corrected(tag_corrected),
        .access_addr(access_addr),
        .access_valid(access_valid),
        .access_is_write(access_is_write),
        .pipeline_stage(pipeline_stage),
        .tag_ecc_error(tag_ecc_error)
    );
    
    // 实例化PCQ模块
    llm_pcq pcq (
        .clk(clk),
        .rst_n(rst_n),
        .req_priority(req_priority),
        .pcq_threshold(pcq_threshold),
        .pcq_congestion(pcq_congestion),
        .out_of_order_en(out_of_order_en),
        .pcq_addr(pcq_addr),
        .pcq_data(pcq_data),
        .pcq_size(pcq_size),
        .pcq_valid(pcq_valid),
        .pcq_snp(pcq_snp),
        .pcq_type(pcq_type),
        .pcq_pld(pcq_pld),
        .pcq_priority(pcq_priority),
        .pcq_ready(pcq_ready),
        .dc_addr(dc_addr),
        .dc_data(dc_data),
        .dc_size(dc_size),
        .dc_valid(dc_valid),
        .dc_snp(dc_snp),
        .dc_type(dc_type),
        .dc_pld(dc_pld),
        .dc_priority(dc_priority),
        .dc_ready(dc_ready),
        .curr_addr(curr_addr),
        .curr_data(curr_data),
        .curr_size(curr_size),
        .curr_snp(curr_snp),
        .curr_type(curr_type),
        .curr_pld(curr_pld),
        .curr_priority(curr_priority),
        .curr_valid(curr_valid),
        .curr_ready(curr_ready)
    );
    
    // 实例化data_ctrl模块
    llm_data_ctrl data_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .prefetch_en(prefetch_en),
        .prefetch_depth(prefetch_depth),
        .split_req_num(split_req_num),
        .dc_addr(dc_addr),
        .dc_data(dc_data),
        .dc_size(dc_size),
        .dc_valid(dc_valid),
        .dc_snp(dc_snp),
        .dc_type(dc_type),
        .dc_pld(dc_pld),
        .dc_priority(dc_priority),
        .dc_ready(dc_ready),
        .tag(tag),
        .set_index(set_index),
        .offset(offset),
        .way_hit(way_hit),
        .hit_way(hit_way),
        .cache_hit(cache_hit),
        .victim_way(victim_way),
        .update_tag(update_tag),
        .new_tag(new_tag),
        .tag_updated(tag_updated),
        .data_corrected(data_corrected),
        .data_error_status(data_error_status),
        .data_error_corrected(data_error_corrected),
        .data_ecc_in(data_ecc_in),
        .data_ecc_out(data_ecc_out),
        .data_write_en(data_write_en),
        .prefetch_addr(prefetch_addr),
        .prefetch_valid(prefetch_valid),
        .prefetch_priority(prefetch_priority),
        .prefetch_ready(prefetch_ready),
        .cache_data(cache_data),
        .snp_data(snp_data),
        .cache_valid(cache_valid),
        .snp_valid(snp_valid),
        .cache_ready(cache_ready),
        .snp_ready(snp_ready)
    );
    
    // 实例化chi_mst模块
    llm_chi_mst chi_mst (
        .clk(clk),
        .rst_n(rst_n),
        .req_timeout(req_timeout),
        .pending_req_count(pending_req_count),
        .mst_addr(mst_addr),
        .mst_size(mst_size),
        .mst_valid(mst_valid),
        .mst_snp(mst_snp),
        .mst_priority(mst_priority),
        .mst_ready(mst_ready),
        .sn_chi_req_addr(sn_chi_req_addr),
        .sn_chi_req_data(sn_chi_req_data),
        .sn_chi_req_size(sn_chi_req_size),
        .sn_chi_req_valid(sn_chi_req_valid),
        .sn_chi_req_snp(sn_chi_req_snp),
        .sn_chi_req_pld(sn_chi_req_pld),
        .sn_chi_req_priority(sn_chi_req_priority),
        .sn_chi_req_ready(sn_chi_req_ready),
        .sn_chi_resp_data(sn_chi_resp_data),
        .sn_chi_resp_valid(sn_chi_resp_valid),
        .sn_chi_resp_error(sn_chi_resp_error),
        .sn_chi_resp_pld(sn_chi_resp_pld),
        .sn_chi_resp_ready(sn_chi_resp_ready),
        .fetch_data(fetch_data),
        .fetch_valid(fetch_valid),
        .fetch_error(fetch_error),
        .fetch_ready(fetch_ready)
    );
    
    // 实例化ecc_ctrl模块
    llm_ecc_ctrl ecc_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .tag_in(tag_ecc_in),
        .tag_ecc_in('0),
        .tag_write_en(update_tag),
        .tag_ecc_out(tag_ecc_out),
        .tag_error_status(tag_error_status),
        .tag_error_corrected(tag_error_corrected),
        .tag_corrected(tag_corrected),
        .data_in(data_ecc_in),
        .data_ecc_in('0),
        .data_write_en(data_write_en),
        .data_ecc_out(data_ecc_out),
        .data_error_status(data_error_status),
        .data_error_corrected(data_error_corrected),
        .data_corrected(data_corrected),
        .error_report_valid(error_report_valid),
        .error_report(ecc_error_report)
    );
    
    // 实例化prefetch_ctrl模块
    llm_prefetch_ctrl prefetch_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .prefetch_en(prefetch_en),
        .prefetch_depth(prefetch_depth),
        .prefetch_policy(2'b00), // 默认顺序预取
        .access_addr(access_addr),
        .access_valid(access_valid),
        .access_is_write(access_is_write),
        .prefetch_addr(prefetch_addr),
        .prefetch_valid(prefetch_valid),
        .prefetch_priority(prefetch_priority),
        .prefetch_ready(prefetch_ready)
    );
    
    // 连接其他信号
    assign curr_ready = cache_ready && snp_ready;
    assign cache_ready = curr_ready;
    assign snp_ready = curr_ready;
    assign fetch_ready = curr_ready;
    
endmodule