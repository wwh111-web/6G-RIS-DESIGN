%%% ========================================
%% 两阶段优化：PSO全局搜索 + IPM局部细化
%% 目标：min Σ|γ_on(fk)·γ*_off(fk)+1|²
%% 频段：6.425 - 7.125 GHz
%% PSO停滞检测：连续3次迭代相对改进 < 1e-1
%% IPM收敛条件：|Δx| 或 |ΔG| < 1e-3
%% ========================================

clear;
clc;
close all;
total_tic = tic;
start_wall_time = datetime('now');
seed=3;
rng(seed);
fprintf('=== 基于宽带相位一致性的RIS优化程序 ===\n');
fprintf('=== 优化算法: PSO + IPM 两阶段优化 ===\n');
fprintf('=== 优化目标: min Σ|γ_on(fk)·γ*_off(fk)+1|² ===\n');
fprintf('=== 目标频段: 6.425-7.125 GHz (700 MHz) ===\n');

%% 全局变量声明
global Res
global cst mws app ver fullfilename exportpath original_fullfilename  
global function_evaluation_history

%% 初始化函数评估历史记录 
if exist('function_evaluation_log.mat', 'file')
    delete('function_evaluation_log.mat');
    fprintf('已清除旧的评估日志文件\n');
end
function_evaluation_history = [];

%% 目标频段设置
target_freq_start = 6.425;
target_freq_end = 7.125;
freq_step = 0.010;
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
fprintf('=== 四参数映射和约束设置 ===\n')

% 初始参数:A0, B0, C0, D0, h1
x0 = [2; 5; 1; 10; 1.524];
%h1是固定值，仅作为接口传递

% 约束条件矩阵
A_paper = [0, 1, 1, 0, 0];  % B0 + C0 ≤ 8
b_paper = 8;

% 变量边界
lb = [1.0; 0.1; 0.1; 1.0; 1.524];
ub = [17.0; 8.0; 8.0; 17.0; 1.524];

%% 边界条件检查和修正
fprintf('=== 初始参数边界条件检查 ===\n');
x0_original = x0;
x0_modified = false;

for i = 1:length(x0)
    if x0(i) < lb(i)
        fprintf('警告: 参数%d (%.3f) 小于下边界 (%.3f),自动修正\n', i, x0(i), lb(i));
        x0(i) = lb(i);
        x0_modified = true;
    end
end

for i = 1:length(x0)
    if x0(i) > ub(i)
        fprintf('警告: 参数%d (%.3f) 大于上边界 (%.3f),自动修正\n', i, x0(i), ub(i));
        x0(i) = ub(i);
        x0_modified = true;
    end
end

constraint_violation = A_paper * x0 - b_paper;
if constraint_violation > 0
    fprintf('警告: 初始参数违反线性约束 B0+C0≤8\n');
    current_sum = x0(2) + x0(3);
    if current_sum > b_paper
        scale_factor = b_paper / current_sum * 0.95;
        x0(2) = x0(2) * scale_factor;
        x0(3) = x0(3) * scale_factor;
        fprintf('自动修正: B0=%.3f, C0=%.3f\n', x0(2), x0(3));
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

%% ========================================
%% 第一阶段: PSO全局优化
%% ========================================

fprintf('\n============================================================\n');
fprintf('         第一阶段: PSO粒子群优化 (全局搜索)\n');
fprintf('============================================================\n');

nvars = 5;
SwarmSize = 20;
MaxIterations = 25;
MaxStallIterations = 25;

fprintf('粒子群大小: %d\n', SwarmSize);
fprintf('最大迭代次数: %d\n', MaxIterations);
fprintf('最大停滞迭代次数: %d\n', MaxStallIterations);

% 清除可能存在的PSO历史文件
if exist('optimization_history_pso_wideband_phase.mat', 'file')
    delete('optimization_history_pso_wideband_phase.mat');
end

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
%c1=c2=1.49,w从1.1渐变到0.1，这些在matlab内置PSO里已有初始设定，所以不表达

fprintf('\n=== 开始宽带相位优化 (PSO算法) ===\n');
fprintf('优化指标: Σ|γ_on(fk)·γ*_off(fk)+1|²\n');

% 定义包含约束的目标函数(PSO版本)
objective_func = @(x) ValueFun_WidebanPhase_PSO(x, target_freqs, A_paper, b_paper);

% 运行PSO优化
[best_x_pso, best_fval_pso] = particleswarm(objective_func, nvars, lb, ub, options);

fprintf('\n=== PSO优化完成 ===\n');
fprintf('PSO最优解:\n');
fprintf('  A0 = %.4f, B0 = %.4f, C0 = %.4f, D0 = %.4f, h1 = %.4f\n', best_x_pso);
fprintf('PSO最优指标值: %.6f\n', best_fval_pso);

%% ========================================
%% PSO停滞检测与结果准备
%% ========================================

fprintf('\n=== PSO终止条件检查 ===\n');

% 加载PSO迭代历史
if exist('optimization_history_pso_wideband_phase.mat', 'file')
    load('optimization_history_pso_wideband_phase.mat', 'iteration_history');
    
    if length(iteration_history) >= 4
        % 检查最近3次迭代的相对改进
        recent_fvals = [iteration_history(end).bestfval, ...
                        iteration_history(end-1).bestfval, ...
                        iteration_history(end-2).bestfval, ...
                        iteration_history(end-3).bestfval];
        
        delta_0 = 1e-1;  % 停滞阈值
        stagnation_count = 0;
        
        for i = 2:4
            if recent_fvals(1) > 0
                relative_improvement = abs(recent_fvals(i) - recent_fvals(1)) / recent_fvals(1);
            else
                relative_improvement = abs(recent_fvals(i) - recent_fvals(1));
            end
            
            if relative_improvement < delta_0
                stagnation_count = stagnation_count + 1;
            end
        end
        
        if stagnation_count >= 3
            fprintf('PSO停滞检测: 连续3次迭代相对改进<%.1e\n', delta_0);
            fprintf('PSO因停滞终止\n');
        else
            fprintf('PSO达到最大迭代次数终止\n');
        end
    else
        fprintf('PSO达到最大迭代次数终止\n');
    end
else
    fprintf('PSO达到最大迭代次数终止\n');
end

% PSO最优解作为IPM初始点
x0_ipm = best_x_pso(:);

% 验证约束
fprintf('\nPSO结果约束验证:\n');
fprintf('  B0 + C0 = %.4f (约束: ≤ %.1f)\n', x0_ipm(2) + x0_ipm(3), b_paper);
if x0_ipm(2) + x0_ipm(3) <= b_paper
    fprintf('  约束满足 ✓\n');
else
    fprintf('  警告: 自动修正约束\n');
    current_sum = x0_ipm(2) + x0_ipm(3);
    scale_factor = b_paper / current_sum * 0.95;
    x0_ipm(2) = x0_ipm(2) * scale_factor;
    x0_ipm(3) = x0_ipm(3) * scale_factor;
    fprintf('  修正后: B0=%.4f, C0=%.4f\n', x0_ipm(2), x0_ipm(3));
end

%% ========================================
%% 第二阶段: IPM局部优化
%% ========================================

fprintf('\n============================================================\n');
fprintf('         第二阶段: IPM内点法优化 (局部细化)\n');
fprintf('============================================================\n');

fprintf('IPM初始点 (来自PSO):\n');
fprintf('  A0 = %.4f, B0 = %.4f, C0 = %.4f, D0 = %.4f, h1 = %.4f\n', x0_ipm);
fprintf('初始目标函数值: %.6f\n', best_fval_pso);

% IPM参数设置
fprintf('\n=== IPM参数设置 ===\n');
fprintf('梯度计算: 中心差分 (step size = 0.05)\n');
fprintf('障碍函数: 对数障碍法\n');
fprintf('收敛阈值 δ₁ = 10⁻³\n');

% 清除可能存在的IPM历史文件
if exist('optimization_history_ipm.mat', 'file')
    delete('optimization_history_ipm.mat');
end

% 使用fmincon作为IPM框架
options_ipm = optimoptions('fmincon', ...
    'Display', 'iter', ...
    'PlotFcns', 'optimplotfval', ...
    'OutputFcn', @ipm_optimization_logger, ...
    'Algorithm', 'interior-point', ...
    'MaxIterations', 200, ...
    'MaxFunctionEvaluations', 2400, ...
    'FunctionTolerance', 1e-6, ...
    'StepTolerance', 1e-6, ...
    'OptimalityTolerance', 1e-3, ...
    'FiniteDifferenceStepSize', 0.05, ...
    'FiniteDifferenceType', 'central');

% 定义IPM目标函数(无惩罚项,因为用约束)
objective_ipm = @(x) ValueFun_IPM_Objective(x, target_freqs);

% 运行IPM优化
fprintf('\n=== 开始IPM局部细化 ===\n');

try
    [x_opt, fval_opt] = fmincon(objective_ipm, x0_ipm, ...
        A_paper, b_paper, [], [], lb, ub, [], options_ipm);
    
    fprintf('\n=== IPM优化完成 ===\n');
    fprintf('IPM最优解:\n');
    fprintf('  A0 = %.4f\n', x_opt(1));
    fprintf('  B0 = %.4f\n', x_opt(2));
    fprintf('  C0 = %.4f\n', x_opt(3));
    fprintf('  D0 = %.4f\n', x_opt(4));
    fprintf('  h1 = %.4f\n', x_opt(5));
    fprintf('\nIPM最优指标值: %.6f\n', fval_opt);
    
    % 改进量
    improvement = best_fval_pso - fval_opt;
    improvement_pct = improvement / best_fval_pso * 100;
    fprintf('相对PSO改进: %.6f (%.2f%%)\n', improvement, improvement_pct);
    
catch ME
    fprintf('IPM优化过程中出现错误: %s\n', ME.message);
    x_opt = x0_ipm;
    fval_opt = best_fval_pso;
end

%% 约束最终验证
fprintf('\n最终约束验证:\n');
fprintf('  B0 + C0 = %.4f (约束: ≤ %.1f)\n', x_opt(2) + x_opt(3), b_paper);
if x_opt(2) + x_opt(3) <= b_paper
    fprintf('  约束满足 ✓\n');
else
    fprintf('  警告: 约束可能未完全满足!\n');
end

%% 清理资源
fprintf('正在清理资源...\n');
try
    invoke(mws, 'Quit');
    fprintf('CST Studio已关闭\n');
catch
    fprintf('关闭CST Studio时出现警告\n');
end

%% 总耗时统计
total_duration_seconds = toc(total_tic);
hours = floor(total_duration_seconds / 3600);
minutes = floor(mod(total_duration_seconds, 3600) / 60);
seconds_rem = mod(total_duration_seconds, 60);

fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('          两阶段优化完成总结\n');
fprintf('%s\n', repmat('=', 1, 60));
fprintf('开始时间: %s\n', datestr(start_wall_time));
fprintf('结束时间: %s\n', datestr(datetime('now')));
fprintf('总计耗时: %d 小时 %d 分 %0.2f 秒\n', hours, minutes, seconds_rem);
fprintf('\n--- PSO阶段结果 ---\n');
fprintf('  最优解: A0=%.4f, B0=%.4f, C0=%.4f, D0=%.4f, h1=%.4f\n', best_x_pso);
fprintf('  Metric值: %.6f\n', best_fval_pso);
fprintf('\n--- IPM阶段结果 ---\n');
fprintf('  最优解: A0=%.4f, B0=%.4f, C0=%.4f, D0=%.4f, h1=%.4f\n', x_opt);
fprintf('  Metric值: %.6f\n', fval_opt);
fprintf('  改进量: %.6f (%.2f%%)\n', improvement, improvement_pct);
fprintf('%s\n', repmat('=', 1, 60));
fprintf('=== 程序结束 ===\n');

%% ========================================
%% PSO目标函数 (带惩罚项)
%% ========================================

function modeValue = ValueFun_WidebanPhase_PSO(x, target_freqs, A_paper, b_paper)
    
    global mws exportpath fullfilename
    global function_evaluation_history
    
    eval_start_time = datetime('now');
    x = x(:);
    
    A0 = x(1); B0 = x(2); C0 = x(3); D0 = x(4); h1 = x(5);
    
    fprintf('PSO评估参数: A0=%.4f, B0=%.4f, C0=%.4f, D0=%.4f, h1=%.4f\n', A0, B0, C0, D0, h1);
    
    %% 约束检查
    lb = [1.0; 0.1; 0.1; 1.0; 1.524];
    ub = [17.0; 8.0; 8.0; 17.0; 1.524];
    
    constraint_violated = false;
    violation_reason = '';
    
    for i = 1:length(x)
        if x(i) < lb(i) || x(i) > ub(i)
            constraint_violated = true;
            violation_reason = sprintf('%s参数%d越界 ', violation_reason, i);
        end
    end
    
    constraint_value = A_paper * x - b_paper;
    if constraint_value > 0
        constraint_violated = true;
        violation_reason = sprintf('%s线性约束违反[B0+C0=%.3f>8.0]', violation_reason, B0+C0);
        penalty = 1e4 * constraint_value;
    else
        penalty = 0;
    end
    
    ROFF = 10; COFF = 100e-15; LOFF = 450e-12;
    RON = 1; CON = 0; LON = 450e-12;
    
    if constraint_violated
        modeValue = 1e6 + penalty;
        record_failed_evaluation_pso(x, modeValue, eval_start_time, violation_reason);
        fprintf('  PSO约束违反 → 惩罚值=%.6f\n', modeValue);
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
        
        invoke(mws, 'StoreParameter', 'A0', A0);
        invoke(mws, 'StoreParameter', 'B0', B0);
        invoke(mws, 'StoreParameter', 'C0', C0);
        invoke(mws, 'StoreParameter', 'D0', D0);
        invoke(mws, 'StoreParameter', 'h1', h1);
        invoke(mws, 'Rebuild');
        
        %% ON状态仿真
        fprintf('  PSO:开始ON状态仿真...\n');
        invoke(mws, 'DeleteResults');
        
        invoke(mws, 'StoreParameter','Rpin',RON); 
        invoke(mws, 'StoreParameter','Cpin',CON); 
        invoke(mws, 'StoreParameter','Lpin',LON); 
        
        invoke(mws,'Rebuild');
        invoke(mws, 'Save');
        
        if ~run_simulation('ON')
            modeValue = 1e6 + penalty;
            record_failed_evaluation_pso(x, modeValue, eval_start_time, 'ON状态仿真失败');
            return;
        end
        
        if ~extract_s_parameters('ON')
            modeValue = 1e6 + penalty;
            record_failed_evaluation_pso(x, modeValue, eval_start_time, 'ON状态S参数提取失败');
            return;
        end
        
        %% OFF状态仿真
        fprintf('  PSO:开始OFF状态仿真...\n');
        
        invoke(mws, 'StoreParameter','Rpin',ROFF); 
        invoke(mws, 'StoreParameter','Cpin',COFF); 
        invoke(mws, 'StoreParameter','Lpin',LOFF); 
        
        invoke(mws,'Rebuild');
        invoke(mws, 'Save');
        
        if ~run_simulation('OFF')
            modeValue = 1e6 + penalty;
            record_failed_evaluation_pso(x, modeValue, eval_start_time, 'OFF状态仿真失败');
            return;
        end
        
        if ~extract_s_parameters('OFF')
            modeValue = 1e6 + penalty;
            record_failed_evaluation_pso(x, modeValue, eval_start_time, 'OFF状态S参数提取失败');
            return;
        end
        
        [modeValue, additional_metrics] = calculate_wideband_phase_metric_enhanced(target_freqs);
        modeValue = modeValue + penalty;
        
        eval_end_time = datetime('now');
        eval_duration = seconds(eval_end_time - eval_start_time);

        eval_record = struct();
        eval_record.evaluation_id = length(function_evaluation_history) + 1;
        eval_record.timestamp = eval_start_time;
        eval_record.parameters = x;
        eval_record.function_value = modeValue;
        eval_record.stage = 'PSO';
        eval_record.success = true;
        eval_record.evaluation_duration = eval_duration;
        eval_record.failure_reason = '';  % 空白字段，保持一致性
        
        eval_record.effective_bandwidth_mhz = additional_metrics.effective_bandwidth_mhz;
        eval_record.effective_bandwidth_ratio = additional_metrics.effective_bandwidth_ratio;
        eval_record.son_avg_db = additional_metrics.son_avg_db;
        eval_record.soff_avg_db = additional_metrics.soff_avg_db;
        eval_record.avg_phase_diff = additional_metrics.avg_phase_diff;

        function_evaluation_history = [function_evaluation_history; eval_record];
        save('function_evaluation_log.mat', 'function_evaluation_history');
        
    catch ME
        fprintf('PSO仿真过程出现错误: %s\n', ME.message);
        modeValue = 1e6 + penalty;
        record_failed_evaluation_pso(x, modeValue, eval_start_time, sprintf('仿真异常: %s', ME.message));
    end
    
    fprintf('  PSO评估结果: %.6f\n', modeValue);
end

%% ========================================
%% IPM目标函数 (无惩罚项,使用约束)
%% ========================================

function modeValue = ValueFun_IPM_Objective(x, target_freqs)
    
    global mws exportpath fullfilename
    global function_evaluation_history
    
    eval_start_time = datetime('now');
    x = x(:);
    
    A0 = x(1); B0 = x(2); C0 = x(3); D0 = x(4); h1 = x(5);
    
    fprintf('IPM评估参数: A0=%.4f, B0=%.4f, C0=%.4f, D0=%.4f, h1=%.4f\n', A0, B0, C0, D0, h1);
    
    ROFF = 10; COFF = 100e-15; LOFF = 450e-12;
    RON = 1; CON = 0; LON = 450e-12;
    
    try
        pause(20/1000);
        
        try
            invoke(mws, 'SaveAs', fullfilename, 'True');
            invoke(mws, 'DeleteResults');
        catch
            fprintf('警告: 保存或删除结果时出现问题\n');
        end
        
        invoke(mws, 'StoreParameter', 'A0', A0);
        invoke(mws, 'StoreParameter', 'B0', B0);
        invoke(mws, 'StoreParameter', 'C0', C0);
        invoke(mws, 'StoreParameter', 'D0', D0);
        invoke(mws, 'StoreParameter', 'h1', h1);
        invoke(mws, 'Rebuild');
        
        %% ON状态仿真
        fprintf('  IPM:开始ON状态仿真...\n');
        invoke(mws, 'DeleteResults');
        
        invoke(mws, 'StoreParameter','Rpin',RON); 
        invoke(mws, 'StoreParameter','Cpin',CON); 
        invoke(mws, 'StoreParameter','Lpin',LON); 
        
        invoke(mws,'Rebuild');
        invoke(mws, 'Save');
        
        if ~run_simulation('ON')
            modeValue = 1e6;
            record_failed_evaluation_ipm(x, modeValue, eval_start_time, 'ON状态仿真失败');
            return;
        end
        
        if ~extract_s_parameters('ON')
            modeValue = 1e6;
            record_failed_evaluation_ipm(x, modeValue, eval_start_time, 'ON状态S参数提取失败');
            return;
        end
        
        %% OFF状态仿真
        fprintf('  IPM:开始OFF状态仿真...\n');
        
        invoke(mws, 'StoreParameter','Rpin',ROFF); 
        invoke(mws, 'StoreParameter','Cpin',COFF); 
        invoke(mws, 'StoreParameter','Lpin',LOFF); 
        
        invoke(mws,'Rebuild');
        invoke(mws, 'Save');
        
        if ~run_simulation('OFF')
            modeValue = 1e6;
            record_failed_evaluation_ipm(x, modeValue, eval_start_time, 'OFF状态仿真失败');
            return;
        end
        
        if ~extract_s_parameters('OFF')
            modeValue = 1e6;
            record_failed_evaluation_ipm(x, modeValue, eval_start_time, 'OFF状态S参数提取失败');
            return;
        end
        
        [modeValue, additional_metrics] = calculate_wideband_phase_metric_enhanced(target_freqs);
        
        eval_end_time = datetime('now');
        eval_duration = seconds(eval_end_time - eval_start_time);

        eval_record = struct();
        eval_record.evaluation_id = length(function_evaluation_history) + 1;
        eval_record.timestamp = eval_start_time;
        eval_record.parameters = x;
        eval_record.function_value = modeValue;
        eval_record.stage = 'IPM';
        eval_record.success = true;
        eval_record.evaluation_duration = eval_duration;
        eval_record.failure_reason = '';  % 空白字段
        
        eval_record.effective_bandwidth_mhz = additional_metrics.effective_bandwidth_mhz;
        eval_record.effective_bandwidth_ratio = additional_metrics.effective_bandwidth_ratio;
        eval_record.son_avg_db = additional_metrics.son_avg_db;
        eval_record.soff_avg_db = additional_metrics.soff_avg_db;
        eval_record.avg_phase_diff = additional_metrics.avg_phase_diff;

        function_evaluation_history = [function_evaluation_history; eval_record];
        save('function_evaluation_log.mat', 'function_evaluation_history');
        
    catch ME
        fprintf('IPM仿真过程出现错误: %s\n', ME.message);
        modeValue = 1e6;
        record_failed_evaluation_ipm(x, modeValue, eval_start_time, sprintf('仿真异常: %s', ME.message));
    end
    
    fprintf('  IPM评估结果: %.6f\n', modeValue);
end

%% ========================================
%% 增强版宽带相位指标计算 (与原文件一致)
%% ========================================

function [metric, additional_metrics] = calculate_wideband_phase_metric_enhanced(target_freqs)
    
    global exportpath
    
    additional_metrics = struct();
    additional_metrics.effective_bandwidth_mhz = 0;
    additional_metrics.effective_bandwidth_ratio = 0;
    additional_metrics.son_avg_db = 0;
    additional_metrics.soff_avg_db = 0;
    additional_metrics.avg_phase_diff = 0;
    
    if ~verify_exported_data(exportpath)
        fprintf('    数据文件验证失败\n');
        metric = 1e6;
        return;
    end
    
    try
        off_ph = importdata(fullfile(exportpath, 's11_off_ph.txt'));
        off_ph_x = off_ph.data(:,1);
        off_ph_y = off_ph.data(:,2);
        
        off_amp = importdata(fullfile(exportpath, 's11_off_amp.txt'));
        off_amp_x = off_amp.data(:,1);
        off_amp_y = off_amp.data(:,2);
        
        on_ph = importdata(fullfile(exportpath, 's11_on_ph.txt'));
        on_ph_x = on_ph.data(:,1);
        on_ph_y = on_ph.data(:,2);
        
        on_amp = importdata(fullfile(exportpath, 's11_on_amp.txt'));
        on_amp_x = on_amp.data(:,1);
        on_amp_y = on_amp.data(:,2);
        
        off_ph_y = process_phase_continuity(off_ph_y);
        on_ph_y = process_phase_continuity(on_ph_y);
        
        metric = 0;
        
        phase_diff_details = zeros(length(target_freqs), 1);
        son_amp_details = zeros(length(target_freqs), 1);
        soff_amp_details = zeros(length(target_freqs), 1);
        
        for i = 1:length(target_freqs)
            fk = target_freqs(i);
            
            gamma_off = interpolate_gamma_improved(fk, off_ph_x, off_amp_y, off_ph_y);
            gamma_on = interpolate_gamma_improved(fk, on_ph_x, on_amp_y, on_ph_y);
            
            son_amp_db = interp1(on_amp_x, on_amp_y, fk, 'spline');
            soff_amp_db = interp1(off_amp_x, off_amp_y, fk, 'spline');
            
            gamma_product = gamma_on * conj(gamma_off);
            metric_value = abs(gamma_product + 1)^2;
            
            metric = metric + metric_value;
            
            phase_diff_details(i) = angle(gamma_product) * 180/pi;
            son_amp_details(i) = son_amp_db;
            soff_amp_details(i) = soff_amp_db;
        end
        
        %% 有效带宽计算
        phase_diff_normalized = abs(phase_diff_details);
        phase_diff_normalized(phase_diff_normalized > 180) = 360 - phase_diff_normalized(phase_diff_normalized > 180);
        
        phase_threshold_low = 170;
        phase_threshold_high = 190;
        valid_phase_indices = find(phase_diff_normalized >= phase_threshold_low & ...
                                   phase_diff_normalized <= phase_threshold_high);
        
        if ~isempty(valid_phase_indices)
            freq_step = target_freqs(2) - target_freqs(1);
            
            continuous_segments = [];
            current_segment_start = valid_phase_indices(1);
            current_segment_end = valid_phase_indices(1);
            
            for i = 2:length(valid_phase_indices)
                if valid_phase_indices(i) == valid_phase_indices(i-1) + 1
                    current_segment_end = valid_phase_indices(i);
                else
                    continuous_segments = [continuous_segments; current_segment_start, current_segment_end];
                    current_segment_start = valid_phase_indices(i);
                    current_segment_end = valid_phase_indices(i);
                end
            end
            continuous_segments = [continuous_segments; current_segment_start, current_segment_end];
            
            segment_lengths = continuous_segments(:,2) - continuous_segments(:,1) + 1;
            [max_length, max_idx] = max(segment_lengths);
            longest_segment = continuous_segments(max_idx, :);
            
            effective_bandwidth_ghz = max_length * freq_step;
            effective_bandwidth_mhz = effective_bandwidth_ghz * 1000;
            
            total_bandwidth_ghz = target_freqs(end) - target_freqs(1);
            effective_bandwidth_ratio = effective_bandwidth_ghz / total_bandwidth_ghz * 100;
            
            additional_metrics.effective_bandwidth_mhz = effective_bandwidth_mhz;
            additional_metrics.effective_bandwidth_ratio = effective_bandwidth_ratio;
        end
        
        %% 平均幅度统计
        son_avg_db = mean(son_amp_details);
        soff_avg_db = mean(soff_amp_details);
        
        additional_metrics.son_avg_db = son_avg_db;
        additional_metrics.soff_avg_db = soff_avg_db;
        
        avg_phase_diff = mean(phase_diff_details);
        additional_metrics.avg_phase_diff = avg_phase_diff;
        
        if ~isfinite(metric) || metric < 0
            metric = 1e6;
        end
        
    catch ME
        fprintf('    计算失败: %s\n', ME.message);
        metric = 1e6;
    end
end

%% ========================================
%% 辅助函数 - 修复字段不匹配问题
%% ========================================

function record_failed_evaluation_pso(x, modeValue, eval_start_time, failure_reason)
    global function_evaluation_history
    
    eval_end_time = datetime('now');
    eval_duration = seconds(eval_end_time - eval_start_time);
    
    eval_record = struct();
    eval_record.evaluation_id = length(function_evaluation_history) + 1;
    eval_record.timestamp = eval_start_time;
    eval_record.parameters = x;
    eval_record.function_value = modeValue;
    eval_record.stage = 'PSO';
    eval_record.success = false;
    eval_record.evaluation_duration = eval_duration;
    eval_record.failure_reason = failure_reason;
    
    % 失败时的指标设为0(保持字段一致性)
    eval_record.effective_bandwidth_mhz = 0;
    eval_record.effective_bandwidth_ratio = 0;
    eval_record.son_avg_db = 0;
    eval_record.soff_avg_db = 0;
    eval_record.avg_phase_diff = 0;
    
    function_evaluation_history = [function_evaluation_history; eval_record];
    save('function_evaluation_log.mat', 'function_evaluation_history');
end

function record_failed_evaluation_ipm(x, modeValue, eval_start_time, failure_reason)
    global function_evaluation_history
    
    eval_end_time = datetime('now');
    eval_duration = seconds(eval_end_time - eval_start_time);
    
    eval_record = struct();
    eval_record.evaluation_id = length(function_evaluation_history) + 1;
    eval_record.timestamp = eval_start_time;
    eval_record.parameters = x;
    eval_record.function_value = modeValue;
    eval_record.stage = 'IPM';
    eval_record.success = false;
    eval_record.evaluation_duration = eval_duration;
    eval_record.failure_reason = failure_reason;
    
    % 失败时的指标设为0(保持字段一致性)
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
    persistent best_fval_history;   % 存储每次迭代的最优值
    global function_evaluation_history;
    stop = false;
    
    delta_0 = 1e-1;      % 相对变化阈值 10%
    
    switch state
        case 'init'
            iteration_history = [];
            best_fval_history = [];
            fprintf('\n=== PSO优化开始 (含停滞检测) ===\n');
            fprintf('停滞检测: 连续3次迭代最优值相对变化 < %.1e 时终止\n', delta_0);
            
        case 'iter'
            current_fval = optimValues.bestfval;
            current_bestx = optimValues.bestx;
            
            % 记录最优值
            best_fval_history = [best_fval_history, current_fval];
            
            % ===== 核心：检查最近三次最优值的变化是否小于阈值 =====
            if length(best_fval_history) >= 3
                last_three = best_fval_history(end-2:end);
                max_val = max(last_three);
                min_val = min(last_three);
                if max_val > 0
                    rel_change = (max_val - min_val) / max_val;
                else
                    rel_change = abs(max_val - min_val); % 值为0时用绝对差
                end
                
                if rel_change < delta_0
                    fprintf('\n*** 停滞检测触发: 最近3次迭代最优值相对变化 = %.2e (< %.1e) ***\n', rel_change, delta_0);
                    fprintf('*** 提前终止 PSO，将最优解传递给 IPM ***\n');
                    stop = true;
                end
            end
            % =======================================================
            
            % 记录迭代历史（保持不变）
            current_iter = struct();
            current_iter.iteration = optimValues.iteration;
            current_iter.funccount = optimValues.funccount;
            current_iter.bestfval = current_fval;
            current_iter.bestx = current_bestx;
            current_iter.timestamp = datetime('now');
            
            if ~isempty(function_evaluation_history)
                latest_eval = function_evaluation_history(end);
                current_iter.effective_bandwidth_mhz = latest_eval.effective_bandwidth_mhz;
                current_iter.effective_bandwidth_ratio = latest_eval.effective_bandwidth_ratio;
                current_iter.son_avg_db = latest_eval.son_avg_db;
                current_iter.soff_avg_db = latest_eval.soff_avg_db;
                current_iter.avg_phase_diff = latest_eval.avg_phase_diff;
            end
            
            iteration_history = [iteration_history; current_iter];
            save('optimization_history_pso_wideband_phase.mat', 'iteration_history');
            
            fprintf('\n--- PSO迭代 %d --- 函数评估: %d次, 最佳Metric: %.6f\n', ...
                    optimValues.iteration, optimValues.funccount, optimValues.bestfval);
            
        case 'done'
            fprintf('\n=== PSO优化完成 ===\n');
            if stop
                fprintf('终止原因: 连续3次迭代最优值相对变化 < %.1e\n', delta_0);
            else
                fprintf('终止原因: 达到最大迭代次数\n');
            end
            fprintf('总迭代次数: %d, 总函数评估: %d\n', ...
                    length(iteration_history), optimValues.funccount);
            
            if ~isempty(iteration_history)
                save('pso_final_result.mat', 'iteration_history');
            end
    end
end

function stop = ipm_optimization_logger(x, optimValues, state)
    persistent iteration_history;
    global function_evaluation_history;
    stop = false;
    
    switch state
        case 'init'
            iteration_history = [];
            fprintf('\n=== IPM优化开始 ===\n');
            
        case 'iter'
            current_iter = struct();
            current_iter.iteration = optimValues.iteration;
            current_iter.funccount = optimValues.funccount;
            current_iter.fval = optimValues.fval;
            current_iter.stepsize = optimValues.stepsize;
            current_iter.iteration_parameters = x;
            current_iter.timestamp = datetime('now');
            
            if ~isempty(function_evaluation_history)
                latest_eval = function_evaluation_history(end);
                if isfield(latest_eval, 'effective_bandwidth_mhz')
                    current_iter.effective_bandwidth_mhz = latest_eval.effective_bandwidth_mhz;
                else
                    current_iter.effective_bandwidth_mhz = 0;
                end
                if isfield(latest_eval, 'effective_bandwidth_ratio')
                    current_iter.effective_bandwidth_ratio = latest_eval.effective_bandwidth_ratio;
                else
                    current_iter.effective_bandwidth_ratio = 0;
                end
                if isfield(latest_eval, 'son_avg_db')
                    current_iter.son_avg_db = latest_eval.son_avg_db;
                else
                    current_iter.son_avg_db = 0;
                end
                if isfield(latest_eval, 'soff_avg_db')
                    current_iter.soff_avg_db = latest_eval.soff_avg_db;
                else
                    current_iter.soff_avg_db = 0;
                end
                if isfield(latest_eval, 'avg_phase_diff')
                    current_iter.avg_phase_diff = latest_eval.avg_phase_diff;
                else
                    current_iter.avg_phase_diff = 0;
                end
                
                % 收敛判断: ||Δx|| < δ₁ 或 |ΔG(x)| < δ₁
                delta_1 = 1e-3;
                if ~isempty(iteration_history)
                    prev_x = iteration_history(end).iteration_parameters;
                    delta_x = norm(x - prev_x);
                    delta_G = abs(optimValues.fval - iteration_history(end).fval);
                    
                    if delta_x < delta_1 || delta_G < delta_1
                        fprintf('\n*** IPM收敛! (||Δx||=%.2e, |ΔG|=%.2e) ***\n', delta_x, delta_G);
                    end
                end
            end
            
            iteration_history = [iteration_history; current_iter];
            save('optimization_history_ipm.mat', 'iteration_history');
            
            fprintf('\n--- IPM迭代 %d ---\n', optimValues.iteration);
            fprintf('函数评估: %d次, Metric: %.6f, 步长: %.2e\n', ...
                    optimValues.funccount, optimValues.fval, optimValues.stepsize);
            
        case 'done'
            fprintf('\n=== IPM优化完成 ===\n');
            fprintf('总迭代次数: %d\n', length(iteration_history));
            
            if ~isempty(iteration_history)
                best_iter = iteration_history(end);
                fprintf('\n最优性能指标:\n');
                fprintf('  • 有效带宽: %.1f MHz (%.1f%%)\n', ...
                        best_iter.effective_bandwidth_mhz, best_iter.effective_bandwidth_ratio);
                fprintf('  • Son平均幅度: %.2f dB\n', best_iter.son_avg_db);
                fprintf('  • Soff平均幅度: %.2f dB\n', best_iter.soff_avg_db);
                fprintf('  • 平均相位差: %.1f°\n', best_iter.avg_phase_diff);
                
                save('ipm_final_result.mat', 'iteration_history');
            end
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
                TryN = TryN + 1;
                if TryN > NumberOfTries
                    fprintf('    %s状态仿真失败\n', state);
                    return;
                end
                pause(2);
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
        
        invoke(plot1D, 'PlotView', 'magnitudedb');
        pause(50/1000);
        
        amp_file = fullfile(exportpath, sprintf('s11_%s_amp.txt', lower(state)));
        ASCIIExport = invoke(mws,'ASCIIExport'); 
        invoke(ASCIIExport,'Reset'); 
        invoke(ASCIIExport,'FileName', amp_file); 
        invoke(ASCIIExport,'Execute');
        pause(50/1000);
        
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
        end
        
    catch ME
        fprintf('    提取%s状态S参数失败: %s\n', state, ME.message);
    end
end

function phase_y = process_phase_continuity(phase_y)
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
    freq_data_ghz = freq_data_ghz(:);
    amp_data_db = amp_data_db(:);
    phase_data_deg = phase_data_deg(:);

    phase_data_rad = deg2rad(phase_data_deg);
    phase_data_rad_unwrapped = unwrap(phase_data_rad);
    phase_data_deg = rad2deg(phase_data_rad_unwrapped);

    if target_freq_ghz < min(freq_data_ghz)
        target_freq_ghz = min(freq_data_ghz);
    elseif target_freq_ghz > max(freq_data_ghz)
        target_freq_ghz = max(freq_data_ghz);
    end

    try
        amp_db_interp = interp1(freq_data_ghz, amp_data_db, target_freq_ghz, 'spline');
        phase_deg_interp = interp1(freq_data_ghz, phase_data_deg, target_freq_ghz, 'spline');
    catch
        amp_db_interp = interp1(freq_data_ghz, amp_data_db, target_freq_ghz, 'linear');
        phase_deg_interp = interp1(freq_data_ghz, phase_data_deg, target_freq_ghz, 'linear');
    end

    amp_linear = 10^(amp_db_interp/20);
    phase_rad = deg2rad(phase_deg_interp);
    improved_gamma = amp_linear * exp(1j * phase_rad);

    if abs(improved_gamma) > 1
        improved_gamma = improved_gamma / abs(improved_gamma) * 0.99;
    end
end

function valid = verify_exported_data(exportpath)
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