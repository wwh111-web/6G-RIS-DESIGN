%%% ========================================
%% 宽带相位优化主程序 - 基于|γ_on·γ*_off+1|²指标
%% 目标:使RIS单元在目标频段内相位差接近180度
%% 增加:有效带宽和平均幅度统计
%% 优化算法:粒子群优化 (PSO)
%% ========================================

clear;
clc;
close all;
seed = 3;
rng(seed);
fprintf('=== 基于宽带相位一致性的RIS优化程序 ===\n');
fprintf('=== 优化算法: 粒子群优化 (PSO) ===\n');
fprintf('=== 优化目标: min Σ|γ_on(fk)·γ*_off(fk)+1|² ===\n');
fprintf('=== 目标频段: 6.425-7.125 GHz (700 MHz) ===\n');
fprintf('=== 增强功能: 有效带宽 + 平均幅度统计 ===\n');

%% 全局变量声明
global Res
global cst mws app ver fullfilename exportpath original_fullfilename
global function_evaluation_history

%% 初始化函数评估历史记录
function_evaluation_history = [];

%% 目标频段设置
target_freq_start = 6.425;  % GHz
target_freq_end = 7.125;    % GHz
freq_step = 0.010;          % 10 MHz步进
target_freqs = target_freq_start:freq_step:target_freq_end;
num_freq_points = length(target_freqs);

fprintf('目标频段: %.3f - %.3f GHz\n', target_freq_start, target_freq_end);
fprintf('频率采样点数: %d (步进: %.1f MHz)\n', num_freq_points, freq_step*1000);

%% 初始化工作环境
work_dir = fullfile(pwd, 'CST_optimization_temp');
if ~exist(work_dir, 'dir')
    mkdir(work_dir);
    fprintf('创建工作目录: %s\n', work_dir);
end

exportpath = work_dir;

%% 启动CST
fprintf('正在启动CST Studio...\n');
try
    cst = actxserver('CSTStudio.application');
    mws = invoke(cst, 'NewMWS');
    app = invoke(mws, 'GetApplicationName');
    ver = invoke(mws, 'GetApplicationVersion');
    fprintf('CST Studio启动成功: %s %s\n', app, ver);
catch ME
    error('CST Studio启动失败: %s\n请确保CST Studio已正确安装并注册。', ME.message);
end

%% 查找并打开CST文件
fprintf('正在查找CST文件...\n');
possible_files = {'ThreeModel2.cst', 'cuitiejun.cst'};
fullfilename = '';

for i = 1:length(possible_files)
    temp_filename = which(possible_files{i});
    if ~isempty(temp_filename)
        fullfilename = temp_filename;
        fprintf('找到CST文件: %s\n', possible_files{i});
        break;
    end
end

if isempty(fullfilename)
    invoke(mws, 'Quit');
    error('找不到任何CST文件。请确保以下文件之一在MATLAB路径中:%s', strjoin(possible_files, ', '));
end

original_fullfilename = fullfilename;
[~, name, ext] = fileparts(fullfilename);
work_filename = fullfile(exportpath, [name, '_work', ext]);

try
    invoke(mws, 'OpenFile', fullfilename);
    fprintf('成功打开CST文件: %s\n', fullfilename);
    invoke(mws, 'SaveAs', work_filename, 'True');
    fprintf('创建工作副本: %s\n', work_filename);
    fullfilename = work_filename;
catch ME
    invoke(mws, 'Quit');
    error('CST文件操作失败: %s', ME.message);
end

%% 设置五参数优化参数
fprintf('=== 五参数映射和约束设置 ===\n')

% 初始参数:A0, B0, C0, D0, h1
% h1初始值设为5
x0 = [2; 5; 1; 10; 1.524];

% 约束条件矩阵 (PSO中用于惩罚函数)
A_paper = [0, 1, 1, 0, 0];  % B0 + C0 ≤ 8
b_paper = 8;

% 变量边界（与ResultFu.m保持一致）
lb = [1.0; 0.1; 0.1; 1.0; 1.524];
ub = [17.0; 8.0; 8.0; 17.0; 1.524];

%% 边界条件检查和修正
fprintf('=== 初始参数边界条件检查 ===\n');
x0_original = x0;
x0_modified = false;

% 检查下边界
for i = 1:length(x0)
    if x0(i) < lb(i)
        fprintf('警告: 参数%d (%.3f) 小于下边界 (%.3f),自动修正为下边界值\n', i, x0(i), lb(i));
        x0(i) = lb(i);
        x0_modified = true;
    end
end

% 检查上边界
for i = 1:length(x0)
    if x0(i) > ub(i)
        fprintf('警告: 参数%d (%.3f) 大于上边界 (%.3f),自动修正为上边界值\n', i, x0(i), ub(i));
        x0(i) = ub(i);
        x0_modified = true;
    end
end

% 检查线性约束
constraint_violation = A_paper * x0 - b_paper;
if constraint_violation > 0
    fprintf('警告: 初始参数违反线性约束 B0+C0≤8 (当前值: %.3f)\n', A_paper * x0);
    current_sum = x0(2) + x0(3);
    if current_sum > b_paper
        scale_factor = b_paper / current_sum * 0.95;
        x0(2) = x0(2) * scale_factor;
        x0(3) = x0(3) * scale_factor;
        fprintf('自动修正: B0=%.3f, C0=%.3f (总和=%.3f)\n', x0(2), x0(3), x0(2)+x0(3));
        x0_modified = true;
    end
end

if x0_modified
    fprintf('初始参数已修正:\n');
    fprintf('  原始: A0=%.3f, B0=%.3f, C0=%.3f, D0=%.3f, h1=%.3f\n', x0_original);
    fprintf('  修正: A0=%.3f, B0=%.3f, C0=%.3f, D0=%.3f, h1=%.3f\n', x0);
else
    fprintf('初始参数满足所有约束条件:\n');
    fprintf('  A0 = %.3f, B0 = %.3f, C0 = %.3f, D0 = %.3f, h1= %.3f\n', x0);
    fprintf('  约束 B0+C0 = %.3f ≤ %.1f ✓\n', x0(2)+x0(3), b_paper);
end

%% PSO优化器设置
fprintf('\n=== 粒子群优化器参数设置 ===\n');

% PSO参数
nvars = 5;  % 5个优化变量
SwarmSize = 20;  % 粒子群大小
MaxIterations = 25;  % 最大迭代次数
MaxStallIterations = 25;  % 最大停滞迭代次数
% c1 c2 w用的matlab自动设置，和论文参数一致
fprintf('粒子群大小: %d\n', SwarmSize);
fprintf('最大迭代次数: %d\n', MaxIterations);
fprintf('最大停滞迭代次数: %d\n', MaxStallIterations);
fprintf('优化变量数: %d\n', nvars);

options = optimoptions('particleswarm', ...
    'SwarmSize', SwarmSize, ...
    'MaxIterations', MaxIterations, ...
    'MaxStallIterations', MaxStallIterations, ...
    'Display', 'iter', ...
    'PlotFcn', 'pswplotbestf', ...
    'OutputFcn', @pso_optimization_logger, ...
    'FunctionTolerance', 1e-10, ...
    'UseParallel', false, ...
    'UseVectorized', false);

%% 运行PSO优化
try
    fprintf('\n=== 开始宽带相位优化 (PSO算法) ===\n');
    fprintf('优化指标: Σ|γ_on(fk)·γ*_off(fk)+1|²\n');
    fprintf('物理意义: 使所有频点的相位差接近180度\n');
    fprintf('优化参数: 5个几何参数 (A0, B0, C0, D0, h1)\n');
    fprintf('优化算法: 粒子群优化 (Particle Swarm Optimization)\n');
    
    % 定义包含约束的目标函数
    objective_func = @(x) ValueFun_WidebanPhase_PSO(x, target_freqs, A_paper, b_paper);
    
    [x_opt, fval] = particleswarm(objective_func, nvars, lb, ub, options);
    
    fprintf('\n=== 优化完成 ===\n');
    fprintf('最优解:\n');
    fprintf('  A0 = %.4f\n', x_opt(1));
    fprintf('  B0 = %.4f\n', x_opt(2));
    fprintf('  C0 = %.4f\n', x_opt(3));
    fprintf('  D0 = %.4f\n', x_opt(4));
    fprintf('  h1 = %.4f\n', x_opt(5));
    fprintf('\n最优指标值: %.6f\n', fval);
    fprintf('物理含义: 频段内相位差偏离180度的总误差\n');
    
    % 验证约束
    fprintf('\n约束验证:\n');
    fprintf('  B0 + C0 = %.4f (约束: ≤ %.1f)\n', x_opt(2) + x_opt(3), b_paper);
    if x_opt(2) + x_opt(3) <= b_paper
        fprintf('  约束满足 ✓\n');
    else
        fprintf('  警告: 约束可能未完全满足!\n');
    end
    
catch ME
    fprintf('优化过程中出现错误: %s\n', ME.message);
end

%% 清理资源
fprintf('正在清理资源...\n');
try
    invoke(mws, 'Quit');
    fprintf('CST Studio已关闭\n');
catch
    fprintf('关闭CST Studio时出现警告\n');
end

fprintf('=== 程序结束 ===\n');

%% ========================================
%% 主要评价函数 - 基于宽带相位一致性指标 (PSO版本)
%% ========================================

function modeValue = ValueFun_WidebanPhase_PSO(x, target_freqs, A_paper, b_paper)
    
    global mws exportpath fullfilename
    global function_evaluation_history
    
    % 记录函数评估开始时间
    eval_start_time = datetime('now');
    
    % 确保x是列向量 (PSO中x是行向量)
    x = x(:);
    
    % 提取五个参数
    A0 = x(1); B0 = x(2); C0 = x(3); D0 = x(4); h1 = x(5);
    
    fprintf('评估参数: A0=%.4f, B0=%.4f, C0=%.4f, D0=%.4f, h1=%.4f\n', A0, B0, C0, D0, h1);
    
    %% 约束检查
    constraint_violated = false;
    violation_reason = '';
    
    % 检查边界约束（与ResultFu.m保持一致）
    lb = [1.0; 0.1; 0.1; 1.0; 1.524];
    ub = [17.0; 8.0; 8.0; 17.0; 1.524];
    
    for i = 1:length(x)
        if x(i) < lb(i) || x(i) > ub(i)
            constraint_violated = true;
            violation_reason = sprintf('%s参数%d越界[%.3f∉[%.1f,%.1f]]', violation_reason, i, x(i), lb(i), ub(i));
        end
    end
    
    % 检查线性约束 B0 + C0 ≤ 8.0
    constraint_value = A_paper * x - b_paper;
    if constraint_value > 0
        constraint_violated = true;
        violation_reason = sprintf('%s线性约束违反[B0+C0=%.3f>8.0]', violation_reason, B0+C0);
        % PSO中添加惩罚项
        penalty = 1e4 * constraint_value;
    else
        penalty = 0;
    end
    
    %% PIN二极管参数
    ROFF = 10; COFF = 100e-15; LOFF = 450e-12;
    RON = 1; CON = 0; LON = 450e-12;
    
    % 如果违反约束,返回惩罚值
    if constraint_violated
        modeValue = 1e6 + penalty;  % 大惩罚值
        record_failed_evaluation(x, modeValue, eval_start_time, violation_reason);
        fprintf('  约束违反: %s → 惩罚值=%.6f\n', violation_reason, modeValue);
        return;
    end
    
    try
        pause(20/1000);
        
        try
            invoke(mws, 'SaveAs', fullfilename, 'True');
            invoke(mws, 'DeleteResults');
        catch
            fprintf('警告: 保存或删除结果时出现问题\n');
        end
        
        %% 设置几何参数
        invoke(mws, 'StoreParameter', 'A0', A0);
        invoke(mws, 'StoreParameter', 'B0', B0);
        invoke(mws, 'StoreParameter', 'C0', C0);
        invoke(mws, 'StoreParameter', 'D0', D0);
        invoke(mws, 'StoreParameter', 'h1', h1);
        invoke(mws, 'Rebuild');
        
        %% ON状态仿真
        fprintf('  开始ON状态仿真...\n');
        invoke(mws, 'DeleteResults');
        
        invoke(mws, 'StoreParameter','Rpin',RON); 
        invoke(mws, 'StoreParameter','Cpin',CON); 
        invoke(mws, 'StoreParameter','Lpin',LON); 
        
        invoke(mws,'Rebuild');
        invoke(mws, 'Save');
        
        if ~run_simulation('ON')
            modeValue = 1e6 + penalty;
            record_failed_evaluation(x, modeValue, eval_start_time, 'ON状态仿真失败');
            return;
        end
        
        if ~extract_s_parameters('ON')
            modeValue = 1e6 + penalty;
            record_failed_evaluation(x, modeValue, eval_start_time, 'ON状态S参数提取失败');
            return;
        end
        fprintf('*** ON状态完成 ***\n');
       
        %% OFF状态仿真
        fprintf('  开始OFF状态仿真...\n');
        
        invoke(mws, 'StoreParameter','Rpin',ROFF); 
        invoke(mws, 'StoreParameter','Cpin',COFF); 
        invoke(mws, 'StoreParameter','Lpin',LOFF); 
        
        invoke(mws,'Rebuild');
        invoke(mws, 'Save');
        
        if ~run_simulation('OFF')
            modeValue = 1e6 + penalty;
            record_failed_evaluation(x, modeValue, eval_start_time, 'OFF状态仿真失败');
            return;
        end
        
        if ~extract_s_parameters('OFF')
            modeValue = 1e6 + penalty;
            record_failed_evaluation(x, modeValue, eval_start_time, 'OFF状态S参数提取失败');
            return;
        end
        fprintf('*** OFF状态完成 ***\n');
        
        %% 计算宽带相位指标(增强版:包含有效带宽和平均幅度)
        fprintf('  计算宽带相位一致性指标(含有效带宽和平均幅度)...\n');
        [modeValue, additional_metrics] = calculate_wideband_phase_metric_enhanced(target_freqs);
        
        % 添加约束惩罚
        modeValue = modeValue + penalty;
        
        % 记录成功的评估
        eval_end_time = datetime('now');
        eval_duration = seconds(eval_end_time - eval_start_time);

        eval_record = struct();
        eval_record.evaluation_id = length(function_evaluation_history) + 1;
        eval_record.timestamp = eval_start_time;
        eval_record.parameters = x;
        eval_record.function_value = modeValue;
        eval_record.constraint_violated = false;
        eval_record.violation_reason = '';
        eval_record.failure_reason = '';
        eval_record.evaluation_duration = eval_duration;
        eval_record.success = true;
        
        % 添加额外的性能指标
        eval_record.effective_bandwidth_mhz = additional_metrics.effective_bandwidth_mhz;
        eval_record.effective_bandwidth_ratio = additional_metrics.effective_bandwidth_ratio;
        eval_record.son_avg_db = additional_metrics.son_avg_db;
        eval_record.soff_avg_db = additional_metrics.soff_avg_db;
        eval_record.avg_phase_diff = additional_metrics.avg_phase_diff;

        function_evaluation_history = [function_evaluation_history; eval_record];
        
        % 保存函数评估历史
        save('function_evaluation_log.mat', 'function_evaluation_history');
        
    catch ME
        fprintf('仿真过程出现错误: %s\n', ME.message);
        modeValue = 1e6 + penalty;
        record_failed_evaluation(x, modeValue, eval_start_time, sprintf('仿真异常: %s', ME.message));
    end
    
    fprintf('  评估结果 (宽带相位指标): %.6f (评估ID: %d)\n', modeValue, length(function_evaluation_history));
end

%% ========================================
%% 增强版宽带相位指标计算
%% 新增:有效带宽 + Son/Soff平均幅度统计
%% ========================================

function [metric, additional_metrics] = calculate_wideband_phase_metric_enhanced(target_freqs)
    
    global exportpath
    
    % 初始化额外指标
    additional_metrics = struct();
    additional_metrics.effective_bandwidth_mhz = 0;
    additional_metrics.effective_bandwidth_ratio = 0;
    additional_metrics.son_avg_db = 0;
    additional_metrics.soff_avg_db = 0;
    additional_metrics.avg_phase_diff = 0;
    
    % 验证数据文件
    if ~verify_exported_data(exportpath)
        fprintf('    数据文件验证失败\n');
        metric = 1e6;
        return;
    end
    
    try
        % 导入S11数据
        off_ph = importdata(fullfile(exportpath, 's11_off_ph.txt'));
        off_ph_x = off_ph.data(:,1);  % 频率 (GHz)
        off_ph_y = off_ph.data(:,2);  % 相位 (度)
        
        off_amp = importdata(fullfile(exportpath, 's11_off_amp.txt'));
        off_amp_x = off_amp.data(:,1);
        off_amp_y = off_amp.data(:,2);  % 幅度 (dB)
        
        on_ph = importdata(fullfile(exportpath, 's11_on_ph.txt'));
        on_ph_x = on_ph.data(:,1);
        on_ph_y = on_ph.data(:,2);
        
        on_amp = importdata(fullfile(exportpath, 's11_on_amp.txt'));
        on_amp_x = on_amp.data(:,1);
        on_amp_y = on_amp.data(:,2);
        
        % 相位连续性处理
        off_ph_y = process_phase_continuity(off_ph_y);
        on_ph_y = process_phase_continuity(on_ph_y);
        
        % 初始化
        metric = 0;
        num_valid_points = 0;
        
        % 存储每个频点的详细信息
        phase_diff_details = zeros(length(target_freqs), 1);
        metric_contribution = zeros(length(target_freqs), 1);
        son_amp_details = zeros(length(target_freqs), 1);
        soff_amp_details = zeros(length(target_freqs), 1);
        
        fprintf('    开始计算宽带相位指标...\n');
        fprintf('    目标频段: %.3f - %.3f GHz (%d个频点)\n', ...
                min(target_freqs), max(target_freqs), length(target_freqs));
        
        % 对每个目标频点计算指标
        for i = 1:length(target_freqs)
            fk = target_freqs(i);  % GHz
            
            % 插值获取gamma值和幅度
            gamma_off = interpolate_gamma_improved(fk, off_ph_x, off_amp_y, off_ph_y);
            gamma_on = interpolate_gamma_improved(fk, on_ph_x, on_amp_y, on_ph_y);
            
            % 插值获取幅度值(dB)
            son_amp_db = interp1(on_amp_x, on_amp_y, fk, 'spline');
            soff_amp_db = interp1(off_amp_x, off_amp_y, fk, 'spline');
            
            % 计算 γ_on · γ*_off
            gamma_product = gamma_on * conj(gamma_off);
            
            % 计算 |γ_on · γ*_off + 1|²
            metric_value = abs(gamma_product + 1)^2;
            
            % 累加到总metric
            metric = metric + metric_value;
            num_valid_points = num_valid_points + 1;
            
            % 记录详细信息
            phase_diff_details(i) = angle(gamma_product) * 180/pi;  % 转换为度数
            metric_contribution(i) = metric_value;
            son_amp_details(i) = son_amp_db;
            soff_amp_details(i) = soff_amp_db;
            
            % 每10个频点显示一次进度
            if mod(i, 10) == 0 || i == length(target_freqs)
                fprintf('      进度: %d/%d (%.1f%%), 当前频点: %.4f GHz, metric贡献: %.6f\n', ...
                       i, length(target_freqs), 100*i/length(target_freqs), fk, metric_value);
            end
        end
        
        %% ========================================
        %% 计算有效带宽(相位差在180°±10°的频段范围)
        %% ========================================
        
        fprintf('\n    === 有效带宽计算 ===\n');
        
        % 将相位差转换到0-180度范围
        phase_diff_normalized = abs(phase_diff_details);
        phase_diff_normalized(phase_diff_normalized > 180) = 360 - phase_diff_normalized(phase_diff_normalized > 180);
        
        % 找出相位差在170°-190°范围内的频点(180°±10°)
        phase_threshold_low = 170;
        phase_threshold_high = 190;
        valid_phase_indices = find(phase_diff_normalized >= phase_threshold_low & ...
                                   phase_diff_normalized <= phase_threshold_high);
        
        if ~isempty(valid_phase_indices)
            % 寻找最长连续频段
            freq_step = target_freqs(2) - target_freqs(1);  % GHz
            
            % 找连续段
            continuous_segments = [];
            current_segment_start = valid_phase_indices(1);
            current_segment_end = valid_phase_indices(1);
            
            for i = 2:length(valid_phase_indices)
                if valid_phase_indices(i) == valid_phase_indices(i-1) + 1
                    % 连续
                    current_segment_end = valid_phase_indices(i);
                else
                    % 断开,保存当前段
                    continuous_segments = [continuous_segments; ...
                                          current_segment_start, current_segment_end];
                    current_segment_start = valid_phase_indices(i);
                    current_segment_end = valid_phase_indices(i);
                end
            end
            % 保存最后一段
            continuous_segments = [continuous_segments; ...
                                  current_segment_start, current_segment_end];
            
            % 找最长段
            segment_lengths = continuous_segments(:,2) - continuous_segments(:,1) + 1;
            [max_length, max_idx] = max(segment_lengths);
            longest_segment = continuous_segments(max_idx, :);
            
            % 计算有效带宽
            effective_bandwidth_ghz = max_length * freq_step;
            effective_bandwidth_mhz = effective_bandwidth_ghz * 1000;
            
            % 计算有效带宽占比
            total_bandwidth_ghz = target_freqs(end) - target_freqs(1);
            effective_bandwidth_ratio = effective_bandwidth_ghz / total_bandwidth_ghz * 100;
            
            fprintf('    有效频点数: %d/%d\n', length(valid_phase_indices), length(target_freqs));
            fprintf('    最长连续段: 索引 [%d:%d], 长度 %d 点\n', ...
                    longest_segment(1), longest_segment(2), max_length);
            fprintf('    有效带宽: %.1f MHz (%.3f GHz)\n', ...
                    effective_bandwidth_mhz, effective_bandwidth_ghz);
            fprintf('    有效带宽占比: %.1f%%\n', effective_bandwidth_ratio);
            fprintf('    有效频段范围: %.4f - %.4f GHz\n', ...
                    target_freqs(longest_segment(1)), target_freqs(longest_segment(2)));
            
            additional_metrics.effective_bandwidth_mhz = effective_bandwidth_mhz;
            additional_metrics.effective_bandwidth_ratio = effective_bandwidth_ratio;
        else
            fprintf('    警告: 未找到满足相位差条件的频点(180°±10°)\n');
            additional_metrics.effective_bandwidth_mhz = 0;
            additional_metrics.effective_bandwidth_ratio = 0;
        end
        
        %% ========================================
        %% 计算Son和Soff的平均幅度
        %% ========================================
        
        fprintf('\n    === 平均幅度统计 ===\n');
        
        son_avg_db = mean(son_amp_details);
        soff_avg_db = mean(soff_amp_details);
        
        son_std_db = std(son_amp_details);
        soff_std_db = std(soff_amp_details);
        
        fprintf('    Son (ON状态) 平均幅度: %.2f dB\n', son_avg_db);
        fprintf('    Son 标准差: %.2f dB\n', son_std_db);
        fprintf('    Son 范围: [%.2f, %.2f] dB\n', min(son_amp_details), max(son_amp_details));
        
        fprintf('    Soff (OFF状态) 平均幅度: %.2f dB\n', soff_avg_db);
        fprintf('    Soff 标准差: %.2f dB\n', soff_std_db);
        fprintf('    Soff 范围: [%.2f, %.2f] dB\n', min(soff_amp_details), max(soff_amp_details));
        
        fprintf('    幅度差 (Son - Soff): %.2f dB\n', son_avg_db - soff_avg_db);
        
        additional_metrics.son_avg_db = son_avg_db;
        additional_metrics.soff_avg_db = soff_avg_db;
        
        %% ========================================
        %% 原有的统计信息
        %% ========================================
        
        fprintf('\n    === 宽带相位指标计算完成 ===\n');
        fprintf('    总metric值: %.6f\n', metric);
        fprintf('    有效频点数: %d\n', num_valid_points);
        fprintf('    平均metric贡献: %.6f\n', metric/num_valid_points);
        
        % 统计相位差
        avg_phase_diff = mean(phase_diff_details);
        std_phase_diff = std(phase_diff_details);
        additional_metrics.avg_phase_diff = avg_phase_diff;
        
        fprintf('    相位差统计:\n');
        fprintf('      平均值: %.1f° (理想值: 180°)\n', avg_phase_diff);
        fprintf('      标准差: %.1f°\n', std_phase_diff);
        fprintf('      范围: [%.1f°, %.1f°]\n', min(phase_diff_details), max(phase_diff_details));
        
        % 找出最好和最差的频点
        [min_metric_contrib, min_idx] = min(metric_contribution);
        [max_metric_contrib, max_idx] = max(metric_contribution);
        fprintf('    最佳频点: %.4f GHz, metric贡献: %.6f, 相位差: %.1f°\n', ...
                target_freqs(min_idx), min_metric_contrib, phase_diff_details(min_idx));
        fprintf('    最差频点: %.4f GHz, metric贡献: %.6f, 相位差: %.1f°\n', ...
                target_freqs(max_idx), max_metric_contrib, phase_diff_details(max_idx));
        
        % 数值稳定性处理
        if ~isfinite(metric) || metric < 0
            fprintf('    警告: metric值异常,使用惩罚值\n');
            metric = 1e6;
        end
        
        %% ========================================
        %% 在命令行显示关键性能摘要
        %% ========================================
        
        fprintf('\n    ╔═══════════════════════════════════════════╗\n');
        fprintf('    ║       本次评估性能摘要                        ║\n');
        fprintf('    ╠═══════════════════════════════════════════╣\n');
        fprintf('    ║ • Metric值:           %.6f          ║\n', metric);
        fprintf('    ║ • 有效带宽:           %.1f MHz (%.1f%%)   ║\n', ...
                additional_metrics.effective_bandwidth_mhz, ...
                additional_metrics.effective_bandwidth_ratio);
        fprintf('    ║ • Son平均幅度:        %.2f dB              ║\n', son_avg_db);
        fprintf('    ║ • Soff平均幅度:       %.2f dB              ║\n', soff_avg_db);
        fprintf('    ║ • 平均相位差:         %.1f°                ║\n', avg_phase_diff);
        fprintf('    ╚═══════════════════════════════════════════╝\n');
        
    catch ME
        fprintf('    计算失败: %s\n', ME.message);
        metric = 1e6;
    end
end

%% ========================================
%% 辅助函数
%% ========================================

function record_failed_evaluation(x, modeValue, eval_start_time, failure_reason)
    global function_evaluation_history
    
    eval_end_time = datetime('now');
    eval_duration = seconds(eval_end_time - eval_start_time);
    
    eval_record = struct();
    eval_record.evaluation_id = length(function_evaluation_history) + 1;
    eval_record.timestamp = eval_start_time;
    eval_record.parameters = x;
    eval_record.function_value = modeValue;
    eval_record.constraint_violated = false;
    eval_record.violation_reason = '';
    eval_record.failure_reason = failure_reason;
    eval_record.evaluation_duration = eval_duration;
    eval_record.success = false;
    
    % 失败时的指标设为0
    eval_record.effective_bandwidth_mhz = 0;
    eval_record.effective_bandwidth_ratio = 0;
    eval_record.son_avg_db = 0;
    eval_record.soff_avg_db = 0;
    eval_record.avg_phase_diff = 0;
    
    function_evaluation_history = [function_evaluation_history; eval_record];
    save('function_evaluation_log.mat', 'function_evaluation_history');
end

function [stop, options] = pso_optimization_logger(optimValues, state)
    persistent iteration_history;
    global function_evaluation_history;
    stop = false;
    
    switch state
        case 'init'
            iteration_history = [];
            fprintf('\n=== 开始记录粒子群优化过程 ===\n');
            fprintf('优化目标: min Σ|γ_on(fk)·γ*_off(fk)+1|²\n');
            fprintf('物理意义: 使所有频点的相位差接近180度\n');
            fprintf('优化算法: 粒子群优化 (PSO)\n');
            fprintf('性能指标: Metric值、有效带宽、Son/Soff平均幅度\n');
            fprintf('\n%s\n', repmat('=', 1, 80));
            
        case 'iter'
            current_iter = struct();
            current_iter.iteration = optimValues.iteration;
            current_iter.funccount = optimValues.funccount;
            current_iter.bestfval = optimValues.bestfval;
            current_iter.meanfval = optimValues.meanfval;
            current_iter.stalliterations = optimValues.stalliterations;
            current_iter.bestx = optimValues.bestx;
            current_iter.timestamp = datetime('now');
            
            % 获取最新评估的额外指标
            if ~isempty(function_evaluation_history)
                current_iter.total_evaluations = length(function_evaluation_history);
                
                % 提取最新的性能指标
                latest_eval = function_evaluation_history(end);
                current_iter.effective_bandwidth_mhz = latest_eval.effective_bandwidth_mhz;
                current_iter.effective_bandwidth_ratio = latest_eval.effective_bandwidth_ratio;
                current_iter.son_avg_db = latest_eval.son_avg_db;
                current_iter.soff_avg_db = latest_eval.soff_avg_db;
                current_iter.avg_phase_diff = latest_eval.avg_phase_diff;
            else
                current_iter.total_evaluations = 0;
                current_iter.effective_bandwidth_mhz = 0;
                current_iter.effective_bandwidth_ratio = 0;
                current_iter.son_avg_db = 0;
                current_iter.soff_avg_db = 0;
                current_iter.avg_phase_diff = 0;
            end
            
            iteration_history = [iteration_history; current_iter];
            save('optimization_history_pso_wideband_phase.mat', 'iteration_history');
            
            fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
            fprintf('║ 迭代 %d - 性能摘要                                         ║\n', optimValues.iteration);
            fprintf('╠═══════════════════════════════════════════════════════════╣\n');
            fprintf('║ 函数评估: %d 次                                            ║\n', optimValues.funccount);
            fprintf('║ 最佳Metric值: %.6f                                        ║\n', optimValues.bestfval);
            fprintf('║ 平均Metric值: %.6f                                        ║\n', optimValues.meanfval);
            fprintf('║ 停滞迭代数: %d                                             ║\n', optimValues.stalliterations);
            fprintf('║ 最佳参数: A0=%.3f, B0=%.3f, C0=%.3f, D0=%.3f, h1=%.3f  ║\n', optimValues.bestx);
            fprintf('╠═══════════════════════════════════════════════════════════╣\n');
            fprintf('║ 性能指标:                                                  ║\n');
            fprintf('║   • 有效带宽:     %.1f MHz (%.1f%%)                     ║\n', ...
                    current_iter.effective_bandwidth_mhz, current_iter.effective_bandwidth_ratio);
            fprintf('║   • Son平均幅度:  %.2f dB                                  ║\n', ...
                    current_iter.son_avg_db);
            fprintf('║   • Soff平均幅度: %.2f dB                                  ║\n', ...
                    current_iter.soff_avg_db);
            fprintf('║   • 平均相位差:   %.1f° (目标: 180°)                      ║\n', ...
                    current_iter.avg_phase_diff);
            fprintf('╚═══════════════════════════════════════════════════════════╝\n');
            
        case 'done'
            fprintf('\n%s\n', repmat('=', 1, 80));
            fprintf('=== 粒子群优化完成 ===\n');
            fprintf('总迭代次数: %d\n', length(iteration_history));
            
            if ~isempty(function_evaluation_history)
                fprintf('总函数评估次数: %d\n', length(function_evaluation_history));
                successful_evaluations = sum([function_evaluation_history.success]);
                fprintf('成功评估: %d (%.1f%%)\n', successful_evaluations, ...
                       100*successful_evaluations/length(function_evaluation_history));
            end
            
            if ~isempty(iteration_history)
                best_iter = iteration_history(end);
                fprintf('\n最优结果:\n');
                fprintf('最优参数: A0=%.4f, B0=%.4f, C0=%.4f, D0=%.4f, h1=%.4f\n', best_iter.bestx);
                fprintf('最优Metric值: %.6f\n', best_iter.bestfval);
                fprintf('\n最优性能指标:\n');
                fprintf('  • 有效带宽: %.1f MHz (%.1f%%)\n', ...
                        best_iter.effective_bandwidth_mhz, best_iter.effective_bandwidth_ratio);
                fprintf('  • Son平均幅度: %.2f dB\n', best_iter.son_avg_db);
                fprintf('  • Soff平均幅度: %.2f dB\n', best_iter.soff_avg_db);
                fprintf('  • 平均相位差: %.1f°\n', best_iter.avg_phase_diff);
                
                save('final_optimization_result_pso_wideband_phase.mat', 'best_iter', 'iteration_history');
            end
            
            fprintf('%s\n', repmat('=', 1, 80));
    end
end

function success = run_simulation(state)
    global mws
    global Res
    
    fprintf('    执行%s状态仿真...\n', state);
    
    solver = invoke(mws, 'FDSolver');
    TryN = 1;
    NumberOfTries = 3;
    success = false;
    
    while TryN <= NumberOfTries
        try
            fprintf('    %s状态仿真尝试 %d/%d\n', state, TryN, NumberOfTries);
            Res = solver.invoke('Start');
            if(Res~=0)
                success = true;
                fprintf('    -> %s状态仿真成功\n', state);
                break;
            else
                fprintf('    -> %s状态仿真错误代码: %d\n', state, Res);
                TryN = TryN + 1;  % 增加重试计数
                
                if TryN > NumberOfTries
                    fprintf('    %s状态仿真失败（错误代码: %d）\n', state, Res);
                    return;
                end
                
                pause(2);  % 等待后重试
            end
        catch ME
            fprintf('    -> %s状态仿真异常: %s\n', state, ME.message);
            TryN = TryN + 1;
            
            if TryN > NumberOfTries
                fprintf('    %s状态仿真失败\n', state);
                return;
            end
            
            pause(2);
        end
    end
    
    if success
        invoke(mws, 'Save');
    end
end

function success = extract_s_parameters(state)
    global mws exportpath
    
    success = false;
    
    try
        fprintf('    提取%s状态S参数...\n', state);
        
        SelectTreeItem = invoke(mws,'SelectTreeItem','1D Results\S-Parameters\SZmax(2),Zmax(2)');
        plot1D = invoke(mws, 'Plot1D');
        pause(100/1000);
        
        % 幅度数据
        invoke(plot1D, 'PlotView', 'magnitudedb');
        pause(50/1000);
        
        amp_file = fullfile(exportpath, sprintf('s11_%s_amp.txt', lower(state)));
        ASCIIExport = invoke(mws,'ASCIIExport'); 
        invoke(ASCIIExport,'Reset'); 
        invoke(ASCIIExport,'FileName', amp_file); 
        invoke(ASCIIExport,'Execute');
        pause(50/1000);
        
        % 相位数据
        plot1D = invoke(mws, 'Plot1D');
        invoke(plot1D, 'PlotView', 'phase');
        pause(50/1000);
        
        ph_file = fullfile(exportpath, sprintf('s11_%s_ph.txt', lower(state)));
        ASCIIExport = invoke(mws,'ASCIIExport'); 
        invoke(ASCIIExport,'Reset'); 
        invoke(ASCIIExport,'FileName', ph_file); 
        invoke(ASCIIExport,'Execute');
        pause(50/1000);
        
        if exist(amp_file, 'file') && exist(ph_file, 'file')
            success = true;
            fprintf('    -> %s状态S参数提取成功\n', state);
        else
            fprintf('    -> %s状态文件创建失败\n', state);
        end
        
    catch ME
        fprintf('    提取%s状态S参数失败: %s\n', state, ME.message);
        success = false;
    end
end

function phase_y = process_phase_continuity(phase_y)
    % 处理相位连续性,消除360度跳变
    phase_y_diff = diff(phase_y);
    change_point = find(abs(phase_y_diff) > 180);
    
    if ~isempty(change_point)
        for i = 1:length(change_point)
            cp = change_point(i);
            if cp < length(phase_y)
                if phase_y_diff(cp) > 0
                    phase_y(cp+1:end) = phase_y(cp+1:end) - 360;
                else
                    phase_y(cp+1:end) = phase_y(cp+1:end) + 360;
                end
            end
        end
    end
end

function improved_gamma = interpolate_gamma_improved(target_freq_ghz, freq_data_ghz, amp_data_db, phase_data_deg)
    % 改进的gamma插值函数
    freq_data_ghz = freq_data_ghz(:);
    amp_data_db = amp_data_db(:);
    phase_data_deg = phase_data_deg(:);

    % 相位解包裹
    phase_data_rad = deg2rad(phase_data_deg);
    phase_data_rad_unwrapped = unwrap(phase_data_rad);
    phase_data_deg = rad2deg(phase_data_rad_unwrapped);

    % 边界处理
    if target_freq_ghz < min(freq_data_ghz)
        target_freq_ghz = min(freq_data_ghz);
    elseif target_freq_ghz > max(freq_data_ghz)
        target_freq_ghz = max(freq_data_ghz);
    end

    % 插值
    try
        amp_db_interp = interp1(freq_data_ghz, amp_data_db, target_freq_ghz, 'spline');
        phase_deg_interp = interp1(freq_data_ghz, phase_data_deg, target_freq_ghz, 'spline');
    catch
        amp_db_interp = interp1(freq_data_ghz, amp_data_db, target_freq_ghz, 'linear');
        phase_deg_interp = interp1(freq_data_ghz, phase_data_deg, target_freq_ghz, 'linear');
    end

    % 转换为复数gamma
    amp_linear = 10^(amp_db_interp/20);
    phase_rad = deg2rad(phase_deg_interp);
    improved_gamma = amp_linear * exp(1j * phase_rad);

    % 限制幅度不超过1
    if abs(improved_gamma) > 1
        improved_gamma = improved_gamma / abs(improved_gamma) * 0.99;
    end
end

function valid = verify_exported_data(exportpath)
    % 验证导出的数据文件是否有效
    files_to_check = {'s11_on_amp.txt', 's11_on_ph.txt', 's11_off_amp.txt', 's11_off_ph.txt'};
    valid = true;
    
    for i = 1:length(files_to_check)
        file_path = fullfile(exportpath, files_to_check{i});
        if exist(file_path, 'file')
            try
                data = importdata(file_path);
                if ~(isfield(data, 'data') && size(data.data, 1) > 10 && size(data.data, 2) >= 2)
                    valid = false;
                end
            catch
                valid = false;
            end
        else
            valid = false;
        end
    end
end
