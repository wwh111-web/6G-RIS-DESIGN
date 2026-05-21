%% ========== 幅相对比图：纯颜色区分算法，ON/OFF 用线型区分 ==========
clear; clc; close all;

%% ========== 参数配置区 ==========
canvas_width  = 20;   % cm
canvas_height = 22;   % cm
font_name = 'Times New Roman';
axis_fs   = 30;       % 坐标轴刻度
label_fs  = 30;       % 轴标签
legend_fs = 30;       % 图例字号
line_width = 3.0;     % 核心线宽

% 目标频段与带宽计算配置
target_fmin = 6.425; 
target_fmax = 7.125; 
phase_tol   = 10;    

% 颜色配置
color_initial = [0.49, 0.18, 0.56]; % 紫色
color_pso     = [0.85, 0.33, 0.10]; % 橙红
color_ipm     = [0.47, 0.67, 0.19]; % 绿色
color_opt     = [0, 0.45, 0.74];    % 蓝色

filepath = fullfile('E:', '新RIS建模', '新建文件夹', ''); 

%% ========== 2. 数据读取与处理 ==========
read_data = @(prefix, suffix) readmatrix(fullfile(filepath, [prefix, suffix]));

off_init = read_data('chuoff', 'ph.txt'); 
on_init  = read_data('chuon',  'ph.txt');
off_init_amp = read_data('chuoff', 'amp.txt'); 
on_init_amp  = read_data('chuon',  'amp.txt');

off_pso = read_data('dboff', 'ph1.txt'); 
on_pso  = read_data('dbon',  'ph1.txt');
off_pso_amp = read_data('dboff', 'amp1.txt'); 
on_pso_amp  = read_data('dbon',  'amp1.txt');

off_ipm = read_data('ipmoff', 'ph1.txt'); 
on_ipm  = read_data('ipmon',  'ph1.txt');
off_ipm_amp = read_data('ipmoff', 'amp1.txt'); 
on_ipm_amp  = read_data('ipmon',  'amp1.txt');

off_final = read_data('off', 'ph4.txt'); 
on_final  = read_data('on',  'ph4.txt');
off_final_amp = read_data('off', 'amp4.txt'); 
on_final_amp  = read_data('on',  'amp4.txt');

freq = off_init(:, 1);

unwrap_deg = @(p) rad2deg(unwrap(deg2rad(p)));
calc_pd = @(on, off) (on(:, 2) - off(:, 2));

pd_init  = calc_pd(on_init, off_init);
pd_pso   = calc_pd(on_pso, off_pso);
pd_ipm   = unwrap_deg(calc_pd(unwrap_deg(on_ipm), unwrap_deg(off_ipm))); 
pd_final = calc_pd(on_final, off_final);

%% ========== 3. 绘图 1：幅度响应全对比 ==========
figure('Units', 'centimeters', 'Position', [2, 2, canvas_width, canvas_height], 'Color', 'w');
hold on; grid on;

% 背景目标频段
patch([target_fmin, target_fmax, target_fmax, target_fmin], ...
      [-2, -2, 0.1, 0.1], [0.8, 0.8, 0.8], ...
      'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% 实际曲线：算法只用颜色区分，ON/OFF 用实线/虚线区分
plot(freq, on_init_amp(:,2),  '-',  'Color', color_initial, 'LineWidth', line_width, 'HandleVisibility', 'off');
plot(freq, off_init_amp(:,2), '--',  'Color', color_initial, 'LineWidth', line_width, 'HandleVisibility', 'off');

plot(freq, on_final_amp(:,2), '-',   'Color', color_opt,     'LineWidth', line_width, 'HandleVisibility', 'off');
plot(freq, off_final_amp(:,2), '--', 'Color', color_opt,     'LineWidth', line_width, 'HandleVisibility', 'off');

plot(freq, on_pso_amp(:,2),   '-',   'Color', color_pso,     'LineWidth', line_width, 'HandleVisibility', 'off');
plot(freq, off_pso_amp(:,2),  '--',  'Color', color_pso,     'LineWidth', line_width, 'HandleVisibility', 'off');

plot(freq, on_ipm_amp(:,2),   '-',   'Color', color_ipm,     'LineWidth', line_width, 'HandleVisibility', 'off');
plot(freq, off_ipm_amp(:,2),  '--',  'Color', color_ipm,     'LineWidth', line_width, 'HandleVisibility', 'off');

% 图例句柄：纯颜色线
h_init = plot(NaN, NaN, '-', 'Color', color_initial, 'LineWidth', line_width, ...
    'DisplayName', 'PSO-IPM (Initial)');
h_opt  = plot(NaN, NaN, '-', 'Color', color_opt, 'LineWidth', line_width, ...
    'DisplayName', 'PSO-IPM (Optimized)');
h_pso  = plot(NaN, NaN, '-', 'Color', color_pso, 'LineWidth', line_width, ...
    'DisplayName', 'PSO');
h_ipm  = plot(NaN, NaN, '-', 'Color', color_ipm, 'LineWidth', line_width, ...
    'DisplayName', 'IPM');

% 目标频段图例（可选）
h_band = plot(NaN, NaN, 's', 'MarkerSize', 14, ...
    'MarkerFaceColor', [0.8, 0.8, 0.8], ...
    'MarkerEdgeColor', 'none', ...
    'LineStyle', 'none', ...
    'DisplayName', 'Target band');

% 线型说明：只保留 ON/OFF
h_on  = plot(NaN, NaN, 'k-',  'LineWidth', line_width, 'DisplayName', 'ON state');
h_off = plot(NaN, NaN, 'k--', 'LineWidth', line_width, 'DisplayName', 'OFF state');

% 坐标轴设置
set(gca, 'FontName', font_name, 'FontSize', axis_fs, 'LineWidth', 1.5, 'Box', 'on');
xlabel('Frequency (GHz)', 'FontSize', label_fs);
ylabel('Magnitude (dB)', 'FontSize', label_fs);
ylim([-0.5, 0]);

% 图例：只保留你想要的项
handle_order = [h_init, h_opt, h_pso, h_ipm, h_on, h_off];
lgd = legend(handle_order, ...
    'Location', 'southwest', ...
    'FontSize', 24, ...
    'NumColumns', 2);
lgd.ItemTokenSize = [25, 12];
lgd.Box = 'on';

%% ========== 4. 绘图 2：相位差对比 ==========
figure('Units', 'centimeters', 'Position', [24, 2, canvas_width, canvas_height], 'Color', 'w');
hold on; grid on;

patch([target_fmin, target_fmax, target_fmax, target_fmin], ...
      [0, 0, 240, 240], [0.8, 0.8, 0.8], ...
      'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
yline(180, 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% 相位曲线：纯颜色线，不加 marker
h1 = plot(freq, pd_init,  '-', 'Color', color_initial, 'LineWidth', line_width, ...
    'DisplayName', 'PSO-IPM (Initial)');
h2 = plot(freq, pd_final, '-', 'Color', color_opt, 'LineWidth', line_width, ...
    'DisplayName', 'PSO-IPM (Optimized)');
h3 = plot(freq, pd_pso,   '-', 'Color', color_pso, 'LineWidth', line_width, ...
    'DisplayName', 'PSO');
h4 = plot(freq, pd_ipm,   '-', 'Color', color_ipm, 'LineWidth', line_width, ...
    'DisplayName', 'IPM');

set(gca, 'FontName', font_name, 'FontSize', axis_fs, 'LineWidth', 1.5, 'Box', 'on');
xlabel('Frequency (GHz)', 'FontSize', label_fs);
ylabel('Phase Difference (deg)', 'FontSize', label_fs);
ylim([40, 240]); yticks(40:40:240);

% 图例：与幅度图统一风格
lgd2 = legend([h1, h2, h3, h4], ...
    'Location', 'northwest', ...
    'FontSize', 24, ...
    'NumColumns', 2);
lgd2.ItemTokenSize = [25, 12];
lgd2.Box = 'on';

%% ========== 5. 带宽统计输出 ==========
idx_target = (freq >= target_fmin) & (freq <= target_fmax);
df = mean(diff(freq)); 
calc_eff_bw = @(pd) sum(abs(pd(idx_target) - 180) <= phase_tol) * df;

fprintf('\n--- 目标频段内有效带宽统计 ---\n');
fprintf(' * PSO-IPM (Initial)   有效带宽 : %.3f GHz\n', calc_eff_bw(pd_init));
fprintf(' * PSO                 有效带宽 : %.3f GHz\n', calc_eff_bw(pd_pso));
fprintf(' * IPM                 有效带宽 : %.3f GHz\n', calc_eff_bw(pd_ipm));
fprintf(' * PSO-IPM (Optimized) 有效带宽 : %.3f GHz\n', calc_eff_bw(pd_final));