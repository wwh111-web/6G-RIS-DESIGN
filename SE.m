clear; clc; close all;

%% 1. 环境与路径配置
global exportpath
exportpath = 'E:\新RIS建模';   % 请确保 s22_xxx.txt 文件在此路径下

% 评估参数 A0~h1（仅用于传递，不影响配置计算）
x0 = [8.27; 3.23; 3.00; 13.82; 5.00];
target_f_start = 6.425;
target_f_end = 7.125;

fprintf('=== 计算中心子带 RIS 编码配置 ===\n');
fprintf('数据源路径: %s\n', exportpath);

%% 2. 执行配置计算（仅中心子带）
try
    % 仅获取中心子带的配置矩阵
    config_center = compute_center_subband_config(x0);
    
    fprintf('\n=== 配置计算完成 ===\n');
    fprintf('中心子带 RIS 配置矩阵（20x20）已计算完成。\n');
    
    % 保存配置到 .mat 文件
    save('ris_coding_config_center.mat', 'config_center');
    fprintf('配置矩阵已保存至 ris_coding_config_center.mat\n');
    
    % 显示配置矩阵的前5行5列（示例）
    fprintf('\n中心子带 RIS 配置矩阵（前5行5列）:\n');
    disp(config_center(1:5, 1:5));
    
    %% ========================================
    %% 3. 绘制中心子带的编码配置图
    %% ========================================
    custom_font_size = 30;
    fig_size = [100, 100, 800, 700];
    
    figure('Name', 'Center Subband RIS Coding Configuration', ...
           'Color', 'w', 'Position', fig_size);
    imagesc([1 20], [1 20], config_center);
    set(gca, 'YDir', 'normal');
    colormap([0 0 1; 0 1 0]);   % 蓝色: OFF, 绿色: ON
    
    xlabel('Column Index', 'FontName', 'Times New Roman', 'FontSize', custom_font_size);
    ylabel('Row Index', 'FontName', 'Times New Roman', 'FontSize', custom_font_size);
    axis equal tight;
    xticks(0:5:20);
    xticklabels({'', '5', '10', '15', '20'});
    yticks(0:5:20);
    yticklabels({'', '5', '10', '15', '20'});
    
    c = colorbar;
    c.Ticks = [0.25, 0.75];
    c.TickLabels = {'OFF', 'ON'};
    c.FontSize = custom_font_size;
    c.FontName = 'Times New Roman';
    
    set(gca, 'FontName', 'Times New Roman', 'FontSize', custom_font_size);
    title('RIS Coding Matrix (Center Subband)', 'FontSize', custom_font_size);
    
    % 保存图像
    saveas(gcf, 'CenterSubband_RIS_Config.png');
    fprintf('配置图已保存为 CenterSubband_RIS_Config.png\n');
    
catch ME
    fprintf('错误: %s\n', ME.message);
    rethrow(ME);
end

%% ========================================
%% 核心计算函数（仅提取中心子带配置）
%% ========================================

function config_center = compute_center_subband_config(parm)
    global exportpath
    % 读取 S 参数数据
    prefix = 's22';
    off_ph  = importdata(fullfile(exportpath, [prefix, '_off_ph.txt']));
    off_amp = importdata(fullfile(exportpath, [prefix, '_off_amp.txt']));
    on_ph   = importdata(fullfile(exportpath, [prefix, '_on_ph.txt']));
    on_amp  = importdata(fullfile(exportpath, [prefix, '_on_amp.txt']));
    
    freq = off_ph.data(:,1);
    off_p = process_phase_continuity(off_ph.data(:,2));
    on_p  = process_phase_continuity(on_ph.data(:,2));
    
    s11_data = struct('freq', freq, ...
                      'off_amp', off_amp.data(:,2), ...
                      'off_phase', off_p, ...
                      'on_amp', on_amp.data(:,2), ...
                      'on_phase', on_p);
    
    target_range = struct('freq_start', 6.425, 'freq_end', 7.125, ...
                          'bandwidth', 0.7, 'valid', true);
    
    % 调用子函数生成中心子带配置
    config_center = compute_center_config(s11_data, target_range);
end

function config_center = compute_center_config(s11_data, freq_range)
    N = 20; M = 20; spacing = 18e-3;          % RIS 单元数及间距
    num_subbands = 7;                         % 子带总数
    center_subband_idx = 4;                   % 中心子带索引（第4个）
    total_bw = freq_range.bandwidth * 1e9;    % 总带宽 (Hz)
    subband_bw = total_bw / num_subbands;
    f_start = freq_range.freq_start * 1e9;    % 起始频率 (Hz)
    f_end   = freq_range.freq_end   * 1e9;    % 终止频率 (Hz)
    
    subband_centers = linspace(f_start + subband_bw/2, f_end - subband_bw/2, num_subbands);
    freq_c = subband_centers(center_subband_idx);   % 中心子带中心频率 (Hz)
    
    tx_params = struct('Gain', 100, 'pos', [0.4; 0; 6.18]);
    rx_pos = [9; 0; 2];   % 接收点位置（用于计算相位对齐）
    
    % 获取 ON/OFF 状态下的反射系数
    g_off = interpolate_gamma_improved(freq_c/1e9, s11_data.freq, s11_data.off_amp, s11_data.off_phase);
    g_on  = interpolate_gamma_improved(freq_c/1e9, s11_data.freq, s11_data.on_amp,  s11_data.on_phase);
    
    % RIS 参数结构体
    ris_p = ris_parameters(freq_c, N, M, spacing, spacing, 0, 0, [g_off g_on]);
    
    % 计算入射与出射路径的相位延迟
    [~, ~, ~, phas] = ris_pathgain(tx_params, struct('Gain', 1, 'pos', rx_pos), ris_p, 'FF');
    ph = phas.stage1(:) .* phas.stage2(:);   % 各单元的双程相位
    
    % 优化配置：选择每个单元使 |ph * exp(j*angle([g_off g_on])) - 1|^2 最小
    target_phase_opt = exp(1j * angle([g_off g_on]));   % [e^(jθ_off), e^(jθ_on)]
    [~, R] = min(abs(ph * target_phase_opt - 1).^2, [], 2);
    
    % 转换为 0/1 配置（0=OFF, 1=ON）
    config_center = reshape(R-1, [N, M]);
    
    fprintf('中心子带中心频率 = %.3f GHz, 配置矩阵已生成\n', freq_c/1e9);
end

%% ========================================
%% 基础辅助函数（与原代码完全一致）
%% ========================================

function [gain, delay, PL, ph] = ris_pathgain(tx_p, rx_p, ris_p, ~)
    wavelength = 299792458 / ris_p.freq;
    pos_ris = ris_p.pos_center + ris_p.pos_element;
    d_tx = sqrt(sum((pos_ris - tx_p.pos).^2));
    d_rx = sqrt(sum((rx_p.pos - pos_ris).^2));
    ph.stage1 = exp(-1j*2*pi/wavelength*d_tx);
    ph.stage2 = exp(-1j*2*pi/wavelength*d_rx);
    cos_in = abs(pos_ris(1,:)-tx_p.pos(1))./d_tx;
    cos_out = abs(rx_p.pos(1)-pos_ris(1,:))./d_rx;
    s = (ris_p.state(:) + 1)';
    gamma = ris_p.gamma(s);
    gain = sqrt(tx_p.Gain*rx_p.Gain) * ris_p.dN * ris_p.dM .* sqrt(cos_in .* cos_out) .* gamma ./ (4*pi*d_tx.*d_rx) .* ph.stage1 .* ph.stage2;
    delay = 0; PL = 0;
end

function [ris_params] = ris_parameters(freq, N, M, dN, dM, gN, gM, gamma)
    ris_params = struct('freq',freq,'N',N,'M',M,'dN',dN,'dM',dM,'gN',gN,'gM',gM,'gamma',gamma);
    ris_params.pos_center = [0 0 6]';
    pos_z = ((0:N-1) - (N-1)/2) * (dN+gN);
    pos_y = ((0:M-1) - (M-1)/2) * (dM+gM);
    [Y, Z] = meshgrid(pos_y, pos_z);
    ris_params.pos_element = [zeros(N*M,1) Y(:) Z(:)]';
    ris_params.state = zeros(N,M);
end

function g = interpolate_gamma_improved(f, f_d, a, p)
    g = 10^(interp1(f_d, a, f, 'spline')/20) * exp(1j*deg2rad(interp1(f_d, p, f, 'spline')));
end

function py = process_phase_continuity(py)
    for i = 2:length(py)
        while (py(i)-py(i-1))>180, py(i)=py(i)-360; end
        while (py(i)-py(i-1))<-180, py(i)=py(i)+360; end
    end
end