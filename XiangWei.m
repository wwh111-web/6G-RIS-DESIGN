clc;
clear;
close all;

%% --- Manual Font Settings ---
font_name = 'Times New Roman';
axis_fs   = 30;  % Font size for axis tick labels
label_fs  = 30;  % Font size for X/Y labels
title_fs  = 30;  % Font size for Plot titles
legend_fs = 30;  % Font size for Legends

%% --- File Path Configuration ---
filepath = 'E:\新RIS建模\结果2\'; % Directory for .txt files

%% --- 定义静态目标带宽 ---
target_freq_low = 6.425;   % GHz
target_freq_high = 7.125;  % GHz

%% --- Read S-Parameter Files ---

% 1. Read OFF-state Magnitude
filename_off_am = 'offamp4.txt';%s22_off_amp
full_filepath = fullfile(filepath, filename_off_am);
if ~exist(full_filepath, 'file'), error('File %s not found.', full_filepath); end
fprintf('Reading file: %s\n', filename_off_am);
data_off_am = readmatrix(full_filepath);
freqOFF = data_off_am(:, 1);
s11OFFAm = data_off_am(:, 2);

% 2. Read ON-state Magnitude
filename_on_am = 'onamp4.txt';
full_filepath = fullfile(filepath, filename_on_am);
if ~exist(full_filepath, 'file'), error('File %s not found.', full_filepath); end
fprintf('Reading file: %s\n', filename_on_am);
data_on_am = readmatrix(full_filepath);
freqON = data_on_am(:, 1);
s11ONAm = data_on_am(:, 2);
freq = data_on_am(:, 1); % Frequency base for calculation

% 3. Read OFF-state Phase
filename_off_phase = 'offph4.txt';
full_filepath = fullfile(filepath, filename_off_phase);
if ~exist(full_filepath, 'file'), error('File %s not found.', full_filepath); end
fprintf('Reading file: %s\n', filename_off_phase);
data_off_phase = readmatrix(full_filepath);
s11OFFPhase = data_off_phase(:, 2);

% 4. Read ON-state Phase
filename_on_phase = 'onph4.txt';
full_filepath = fullfile(filepath, filename_on_phase);
if ~exist(full_filepath, 'file'), error('File %s not found.', full_filepath); end
fprintf('Reading file: %s\n', filename_on_phase);
data_on_phase = readmatrix(full_filepath);
s11ONPhase = data_on_phase(:, 2);

%% --- Calculations ---
s11Phase = s11ONPhase - s11OFFPhase;
fprintf('Phase difference calculation complete. Range: %.3f to %.3f deg\n', ...
    min(s11Phase), max(s11Phase));

%% --- Figure 1: General S-Parameter Results ---
figure('Position', [100, 100, 1200, 800], 'Color', 'w');

% Subplot 1: OFF Magnitude
subplot(2,3,1);
plot(freqOFF, s11OFFAm, 'b-', 'linewidth', 2); grid on;
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency (GHz)', 'FontSize', label_fs);
ylabel('S11 Magnitude (dB)', 'FontSize', label_fs);
title('S11 OFF Magnitude', 'FontSize', title_fs, 'FontName', font_name);

% Subplot 2: ON Magnitude
subplot(2,3,2);
plot(freqON, s11ONAm, 'r-', 'linewidth', 2); grid on;
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency (GHz)', 'FontSize', label_fs);
ylabel('S11 Magnitude (dB)', 'FontSize', label_fs);
title('S11 ON Magnitude', 'FontSize', title_fs, 'FontName', font_name);

% Subplot 3: Magnitude Difference
subplot(2,3,3);
s11AmDiff = s11ONAm - s11OFFAm;
plot(freq, s11AmDiff, 'g-', 'linewidth', 2); grid on;
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency(GHz)', 'FontSize', label_fs);
ylabel('Mag. Diff / dB', 'FontSize', label_fs);
title('Mag. Diff (ON - OFF)', 'FontSize', title_fs, 'FontName', font_name);

% Subplot 4: OFF Phase
subplot(2,3,4);
plot(freqOFF, s11OFFPhase, 'b-', 'linewidth', 2); grid on;
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency (GHz)', 'FontSize', label_fs);
ylabel('Phase (deg)', 'FontSize', label_fs);
title('S11 OFF Phase', 'FontSize', title_fs, 'FontName', font_name);

% Subplot 5: ON Phase
subplot(2,3,5);
plot(freqON, s11ONPhase, 'r-', 'linewidth', 2); grid on;
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency (GHz)', 'FontSize', label_fs);
ylabel('Phase (deg)', 'FontSize', label_fs);
title('S11 ON Phase', 'FontSize', title_fs, 'FontName', font_name);

% Subplot 6: Phase Difference
subplot(2,3,6);
plot(freq, s11Phase, 'm-', 'linewidth', 2); grid on;
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency / GHz', 'FontSize', label_fs);
ylabel('Phase Diff (deg)', 'FontSize', label_fs);
title('Phase Diff |ON - OFF|', 'FontSize', title_fs, 'FontName', font_name);

%% --- Data Analysis: Bandwidth and Stability ---
fprintf('\n=== Starting Data Analysis ===\n');
threshold1 = 9;  
threshold2 = 10; 

idx_near_180 = find(s11Phase > (180-threshold1) & s11Phase < (180+threshold1));
if isempty(idx_near_180)
    fprintf('Warning: No phase difference points found near 180 deg!\n');
    fl = 0; fh = 0; BW = 0; center_idx = 0;
else
    center_idx = idx_near_180(1);
    left_idx = center_idx;
    while left_idx > 1 && s11Phase(left_idx-1) > 180-threshold2  && s11Phase(left_idx-1) <180+threshold2 
        left_idx = left_idx - 1;
    end
    right_idx = center_idx;
    while right_idx < length(s11Phase) && s11Phase(right_idx+1) > 180-threshold2  && s11Phase(right_idx+1) <180+threshold2 
        right_idx = right_idx + 1;
    end
    fl = freq(left_idx); fh = freq(right_idx); BW = fh - fl;
    fprintf('Bandwidth Results:\n  Lower: %.3f GHz, Upper: %.3f GHz, BW: %.3f GHz\n', fl, fh, BW);
end

% Stability calculation
if BW > 0 && length(left_idx:right_idx) > 1
    diff_s11Phase = mean(abs(diff(s11Phase(left_idx:right_idx))));
else
    diff_s11Phase = 0;
end

% Magnitude at 180 shift
if center_idx > 0
    Am_OFF = s11OFFAm(center_idx); Am_ON = s11ONAm(center_idx);
else
    Am_OFF = 0; Am_ON = 0;
end


%% --- Figure 2: Detailed Analysis Plot - Part 1 (Magnitude) ---
% 创建第一个独立窗口：幅度对比
figure('Position', [100, 100, 850, 750], 'Color', 'w', 'Name', 'Magnitude Analysis');

% --- 绘图内容 ---
ylim_mag = [-0.4, 0]; 
% 绘制浅灰色目标带宽区域，透明度设为 0.5
h_band_mag = fill([target_freq_low, target_freq_high, target_freq_high, target_freq_low], ...
     [ylim_mag(1), ylim_mag(1), ylim_mag(2), ylim_mag(2)], ...
     [0.85 0.85 0.85], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
hold on;
% 绘制曲线并赋予句柄
h_off_mag = plot(freq, s11OFFAm, 'b-', 'linewidth', 2);
h_on_mag = plot(freq, s11ONAm, 'r-', 'linewidth', 2);

% --- 通用设置 ---
grid on;
ylim(ylim_mag);
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency (GHz)', 'FontSize', label_fs);
ylabel('Magnitude (dB)', 'FontSize', label_fs);
set(gca, 'ycolor', 'k');

% --- 图例 ---
% 将阴影区域和两条曲线加入图例
lgd2 = legend([h_band_mag, h_off_mag, h_on_mag], 'Target Band', 'OFF State', 'ON State', 'Location', 'best');
set(lgd2, 'FontSize', legend_fs, 'FontName', font_name);


%% --- Figure 3: Detailed Analysis Plot - Part 2 (Phase) ---
% 创建第二个独立窗口：相位分析
figure('Position', [150, 150, 850, 750], 'Color', 'w', 'Name', 'Phase Analysis');

% --- 左轴 (Left Axis) ---
yyaxis left
ylim_phase = [min(s11Phase)-10, max(s11Phase)+10]; 
% 绘制浅灰色目标带宽区域，透明度设为 0.5
h_band_phase = fill([target_freq_low, target_freq_high, target_freq_high, target_freq_low], ...
      [ylim_phase(1), ylim_phase(1), ylim_phase(2), ylim_phase(2)], ...
      [0.85 0.85 0.85], 'FaceAlpha', 0.5, 'EdgeColor', 'none'); 
hold on;
h_diff = plot(freq, s11Phase, 'k-', 'linewidth', 2); 
ylabel('Phase Diff (deg)', 'FontSize', label_fs, 'FontWeight', 'normal');

ylim(ylim_phase);
set(gca, 'ycolor', 'k');

% --- 右轴 (Right Axis) ---
yyaxis right
h_off = plot(freq, s11OFFPhase, 'b-', 'linewidth', 2); 
hold on;
h_on  = plot(freq, s11ONPhase, 'r-', 'linewidth', 2); 
ylabel('Phase (deg)', 'FontSize', label_fs, 'FontWeight', 'normal');
set(gca, 'ycolor', 'k'); 
ylim([-180, 180]);

% --- 通用设置 ---
grid on;
set(gca, 'FontName', font_name, 'FontSize', axis_fs);
xlabel('Frequency (GHz)', 'FontSize', label_fs);

% --- 图例 ---
% 将阴影区域和三条曲线加入图例
lgd1 = legend([h_band_phase, h_diff, h_off, h_on], 'Target Band', 'Phase Diff', 'OFF Phase', 'ON Phase', 'Location', 'best');
set(lgd1, 'FontSize', legend_fs, 'FontName', font_name);


fprintf('\nAnalysis Complete!\n');
fprintf('Target Bandwidth: %.3f - %.3f GHz (%.0f MHz)\n', ...
    target_freq_low, target_freq_high, (target_freq_high-target_freq_low)*1000);

%% ==========================
%% 新增：目标带宽内幅度损耗平均值计算
%% ==========================
%% 1. 目标带宽内幅度平均值计算 (固定频段: 6.425 - 7.125 GHz)
%% ==========================
fprintf('\n=== 目标带宽内幅度平均值计算 (Static Target Band) ===\n');
idx_target = freq >= target_freq_low & freq <= target_freq_high;

if sum(idx_target) > 0
    % 提取数据
    target_OFF_amp = s11OFFAm(idx_target);
    target_ON_amp  = s11ONAm(idx_target);
    
    % 计算 dB 均值
    mean_OFF_target = mean(target_OFF_amp);
    mean_ON_target  = mean(target_ON_amp);
    
    % 计算反射效率 (dB 转 线性百分比: 10^(dB/10)*100)
    eff_OFF_target = mean(10.^(target_OFF_amp/10)) * 100;
    eff_ON_target  = mean(10.^(target_ON_amp/10)) * 100;
    
    % 输出结果
    fprintf('目标频段: %.3f - %.3f GHz\n', target_freq_low, target_freq_high);
    fprintf('OFF状态 平均幅度: %.4f dB (效率: %.2f%%)\n', mean_OFF_target, eff_OFF_target);
    fprintf('ON 状态 平均幅度: %.4f dB (效率: %.2f%%)\n', mean_ON_target, eff_ON_target);
    fprintf('目标带宽内总平均损耗: %.4f dB\n', (mean_OFF_target + mean_ON_target)/2);
else
    fprintf('未找到目标带宽内的数据！\n');
end
%% ==========================
%% 新增：有效带宽内（180+/-10 deg）幅度平均值计算
%% ==========================
fprintf('\n=== 有效带宽内（180°±10°）幅度平均值计算 ===\n');

% 利用之前分析出的有效带宽索引范围 [left_idx, right_idx]
if exist('left_idx', 'var') && exist('right_idx', 'var') && left_idx > 0
    % 提取有效带宽内的数据
    valid_OFF_amp = s11OFFAm(left_idx:right_idx);
    valid_ON_amp  = s11ONAm(left_idx:right_idx);
    
    % 计算平均值
    mean_valid_OFF = mean(valid_OFF_amp);
    mean_valid_ON  = mean(valid_ON_amp);
    
    % 计算反射效率 (将 dB 转换为线性效率的百分比: 10^(dB/10) * 100%)
    efficiency_OFF = mean(10.^(valid_OFF_amp/10)) * 100;
    efficiency_ON  = mean(10.^(valid_ON_amp/10)) * 100;
    
    % 输出结果
    fprintf('有效带宽范围: %.3f - %.3f GHz (相位差 180°±10°)\n', fl, fh);
    fprintf('OFF状态 平均幅度: %.4f dB (效率: %.2f%%)\n', mean_valid_OFF, efficiency_OFF);
    fprintf('ON 状态 平均幅度: %.4f dB (效率: %.2f%%)\n', mean_valid_ON, efficiency_ON);
    fprintf('有效带宽内总平均损耗: %.4f dB\n', (mean_valid_OFF + mean_valid_ON)/2);
else
    fprintf('未找到满足 180°±10° 条件的有效带宽，无法计算平均值。\n');
end
