%% ========== 三算法迭代收敛对比图（26点适配版） ==========
clear; clc; close all;

%% ========== 参数配置区 ==========
canvas_width = 20;
canvas_height = 20;
font_name = 'Times New Roman';
font_size_axis = 30;        
font_size_label = 30;       
font_size_legend = 30;      
line_width = 2.5;           
marker_size = 6;            
color_pso = [0.85, 0.33, 0.10];      
color_pso_ipm = [0, 0.45, 0.74];     
color_ipm = [0.47, 0.67, 0.19];      
use_log_scale = true;       
x_label_text = 'Iteration';
y_label_text = 'G(x)';

%% ========== 数据准备 ==========
% === PSO 数据增加到 26 个点 (索引 0-25) ===
% 在原数据基础上补充了一些平稳值以达到 26 个元素
PSO_1 = [117.7, 60.68, 60.68, 47.07, 7.65, 7.65, 7.65, 4.55, 4.55, 4.55, ...
         4.55, 4.55, 4.55, 4.55, 4.55, 1.24, 0.73, 0.72, 0.72, 0.70, ...
         0.70, 0.70, 0.70, 0.70, 0.70, 0.70]; 

% PSO-IPM 和 IPM 保持原样
PSO_IPM_1 = [117.7, 60.68, 60.68, 47.07, 7.65, 7.65, 7.65, 3.89, 2.41, 1.88, 1.34, 0.60, 0.33, 0.33,0.33,0.33,0.33,0.33,0.33,0.33,0.33,0.33,0.33,0.33,0.33,0.33];
IPM_1 = [207.0, 104.5, 43.3, 32.6, 29.4,  27.63, 27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14,27.14];

iter_PSO_1 = 0:length(PSO_1)-1;
iter_PSO_IPM_1 = 0:length(PSO_IPM_1)-1;
iter_IPM_1 = 0:length(IPM_1)-1;

%% ========== 创建图形 ==========
figure('Units', 'centimeters', ...
       'Position', [5, 5, canvas_width, canvas_height], ...
       'Color', 'w');
hold on;

%% ========== 绘制曲线 ==========
h1=plot(iter_PSO_1, PSO_1, '-o', ...
    'Color', color_pso, ...
    'LineWidth', line_width, ...
    'MarkerSize', marker_size, ...
    'MarkerEdgeColor', color_pso, ...
    'MarkerFaceColor', 'w', ...
    'DisplayName', 'PSO');

h2=plot(iter_PSO_IPM_1, PSO_IPM_1, '-s', ...
    'Color', color_pso_ipm, ...
    'LineWidth', line_width, ...
    'MarkerSize', marker_size + 2, ...
    'MarkerEdgeColor', color_pso_ipm, ...
    'MarkerFaceColor', 'w', ...
    'DisplayName', 'PSO-IPM');

h3=plot(iter_IPM_1, IPM_1, '-^', ...
    'Color', color_ipm, ...
    'LineWidth', line_width, ...
    'MarkerSize', marker_size + 2, ...
    'MarkerEdgeColor', color_ipm, ...
    'MarkerFaceColor', 'w', ...
    'DisplayName', 'IPM');

%% ========== 坐标轴美化 (优化均匀度) ==========
ax = gca;
set(ax, 'LineWidth', 1.5, 'Box', 'on');
set(ax, 'FontName', font_name, 'FontSize', font_size_axis);

% X轴保持 0-25 均匀分布
set(ax, 'XLim', [0, 25]);
set(ax, 'XTick', 0:5:25);
set(ax, 'YScale', 'log');
ylim([0.1, 300]);

yticks_manual = [0.1, 1, 10, 100, 300];
set(ax, 'YTick', yticks_manual);
set(ax, 'YTickLabel', {'0.1', '1', '10', '100', '300'});
% Y轴：解决网格不均匀感
if use_log_scale
    set(ax, 'YScale', 'log');
    ylim([0.1, 500]); 
    
    % 方法：手动定义稀疏且对称的刻度，避免自动生成的刻度太乱
    % 这里我们选择 10 的幂次作为主线，视觉上会整齐很多
    yticks_manual = [0.1, 1, 10, 100, 500]; 
    set(ax, 'YTick', yticks_manual);
    
    % 关键：强制关闭次网格（MinorGrid），防止出现那些密密麻麻、不均匀的细线
    ax.YMinorGrid = 'off'; 
    ax.YMinorTick = 'off';
else
    ylim([0, 250]);
    set(ax, 'YTick', 0:50:250);
end

%% ========== 标签与图例 ==========
xlabel(x_label_text, 'FontSize', font_size_label, 'FontName', font_name);
ylabel(y_label_text, 'FontSize', font_size_label, 'FontName', font_name);

leg = legend([h3, h1, h2], 'Location', 'northeast');
leg.ItemTokenSize = [45, 16];  
set(leg, 'FontSize', font_size_legend, 'FontName', font_name);

%% ========== 网格线美化 (关键) ==========
% 移除自带的 MinorGrid 设置，确保只有我们定义的 YTick 产生网格线
grid off; % 先重置
grid on;  % 仅开启主网格
set(ax, ...
    'GridAlpha', 0.4, ...      % 稍微加深一点颜色以便观察
    'GridLineStyle', ':', ...  % 使用虚线
    'Layer', 'bottom');        % 网格线放在曲线下方

%% ========== 导出与打印 ==========
exportgraphics(ax, 'Algorithm_Comparison_26Points.png', 'Resolution', 600);
fprintf('✓ 26点对比图已保存！\n');














% 
% %% ========== 三算法迭代收敛对比图（26点 + LaTeX + 均匀网格） ==========
% clear; clc; close all;
% 
% %% ========== 1. 参数配置区 ==========
% % 画布尺寸 (单位: cm)
% canvas_width = 20;
% canvas_height = 20;
% 
% % 字体大小设置
% font_size_axis = 22;        % 坐标轴刻度字号
% font_size_label = 32;       % 轴标签字号 (G(x) 和 Iteration)
% font_size_legend = 22;      % 图例字号
% 
% % 线条与颜色
% line_width = 2.5;           
% marker_size = 7;            
% color_pso = [0.85, 0.33, 0.10];      % 橙红
% color_pso_ipm = [0, 0.45, 0.74];     % 蓝色
% color_ipm = [0.47, 0.67, 0.19];      % 绿色
% 
% %% ========== 2. 数据准备 ==========
% % PSO 数据：增加至 26 个点 (索引 0-25)
% PSO_1 = [117.7, 60.68, 60.68, 47.07, 7.65, 7.65, 7.65, 4.55, 4.55, 4.55, ...
%          4.55, 4.55, 4.55, 4.55, 4.55, 1.24, 0.73, 0.72, 0.72, 0.70, ...
%          0.70, 0.70, 0.70, 0.70, 0.70, 0.70]; 
% 
% % PSO-IPM 数据
% PSO_IPM_1 = [117.7, 60.68, 60.68, 47.07, 7.65, 7.65, 7.65, 3.89, 2.41, 1.88, 1.34, 0.60, 0.33, 0.33];
% 
% % IPM 数据
% IPM_1 = [207.0, 104.5, 72.8, 66.4, 65.1, 63.63, 63.14];
% 
% % 生成迭代次数向量
% iter_PSO_1 = 0:length(PSO_1)-1;
% iter_PSO_IPM_1 = 0:length(PSO_IPM_1)-1;
% iter_IPM_1 = 0:length(IPM_1)-1;
% 
% %% ========== 3. 创建图形与绘制 ==========
% figure('Units', 'centimeters', ...
%        'Position', [5, 5, canvas_width, canvas_height], ...
%        'Color', 'w');
% hold on;
% 
% % 绘制曲线
% p1 = plot(iter_PSO_1, PSO_1, '-o', ...
%     'Color', color_pso, 'LineWidth', line_width, ...
%     'MarkerSize', marker_size, 'MarkerFaceColor', 'w', ...
%     'DisplayName', 'PSO');
% 
% p2 = plot(iter_PSO_IPM_1, PSO_IPM_1, '-s', ...
%     'Color', color_pso_ipm, 'LineWidth', line_width, ...
%     'MarkerSize', marker_size + 2, 'MarkerFaceColor', 'w', ...
%     'DisplayName', 'PSO-IPM');
% 
% p3 = plot(iter_IPM_1, IPM_1, '-^', ...
%     'Color', color_ipm, 'LineWidth', line_width, ...
%     'MarkerSize', marker_size + 2, 'MarkerFaceColor', 'w', ...
%     'DisplayName', 'IPM');
% 
% %% ========== 4. 坐标轴美化 (核心修正区) ==========
% ax = gca; % 必须先获取句柄
% 
% % 设置基础属性与 LaTeX 渲染引擎
% set(ax, 'LineWidth', 1.5, 'Box', 'on');
% set(ax, 'FontName', 'Times New Roman', 'FontSize', font_size_axis);
% set(ax, 'TickLabelInterpreter', 'latex'); % 使轴上的数字也符合 LaTeX 字体
% 
% % X 轴设置 (适配 26 点)
% set(ax, 'XLim', [0, 25]);
% set(ax, 'XTick', 0:5:25); % 每隔 5 个迭代显示一个刻度，整齐美观
% 
% % Y 轴设置 (对数轴 + 解决不均匀网格)
% set(ax, 'YScale', 'log');
% ylim([0.1, 500]); 
% % 手动设置刻度，确保网格线在视觉上是等间距的
% yticks_manual = [0.1, 1, 10, 100, 500]; 
% set(ax, 'YTick', yticks_manual);
% 
% % 彻底关闭对数坐标自动生成的密集“次网格”
% set(ax, 'YMinorTick', 'off');
% set(ax, 'YMinorGrid', 'off');
% 
% %% ========== 5. LaTeX 标签与图例 ==========
% % 轴标签使用标准的 LaTeX 数学斜体渲染
% xlabel('$\rm{Iteration}$', 'FontSize', font_size_label, 'Interpreter', 'latex');
% ylabel('$G({x})$', 'FontSize', font_size_label, 'Interpreter', 'latex');
% 
% % 图例设置
% leg = legend([p1, p2, p3], 'Location', 'northeast');
% set(leg, 'Interpreter', 'latex', 'FontSize', font_size_legend, 'ItemTokenSize', [45, 16]);
% 
% %% ========== 6. 网格线控制 ==========
% grid off; % 重置网格
% grid on;  % 仅开启主网格
% set(ax, ...
%     'GridAlpha', 0.35, ...     % 网格透明度
%     'GridLineStyle', ':', ...  % 虚线样式
%     'Layer', 'bottom');        % 网格线放在曲线下方
% 
% %% ========== 7. 导出图像 ==========
% % 建议导出为矢量图 EPS 以获得最高的论文打印质量
% exportgraphics(ax, 'Convergence_Comparison.png', 'Resolution', 600);
% fprintf('✓ 绘图完成！26点 LaTeX 高清图已保存。\n');