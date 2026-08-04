function make_figureS2_model_performance(cfg)
%MAKE_FIGURES2_MODEL_PERFORMANCE Trial-level model performance summary.

if nargin < 1
    cfg = rf_resolve_paths(fileparts(fileparts(mfilename('fullpath'))));
end
T = rf_load_validation_table(cfg);
metrics = {'RMSE','R2','VAF'};
yLabels = {'Mean RMSE (°)','Mean R^2','Mean VAF (%)'};
letters = 'ABC';

mu = nan(3,3); sd = nan(3,3);
for j = 1:3
    sub = T(T.Joint==cfg.joints(j),:);
    for m = 1:3
        mu(j,m) = mean(sub.(metrics{m}),'omitnan');
        sd(j,m) = std(sub.(metrics{m}),0,'omitnan');
    end
end

fig = figure('Color','w','Renderer','painters');
tl = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
for m = 1:3
    ax = nexttile(tl); hold(ax,'on');
    b = bar(ax,1:3,mu(:,m),0.68,'FaceColor','flat','EdgeColor','none');
    b.CData = cfg.jointColours;
    errorbar(ax,1:3,mu(:,m),sd(:,m),'k','LineStyle','none', ...
        'LineWidth',0.8,'CapSize',5);
    xlim(ax,[0.5 3.5]); xticks(ax,1:3); xticklabels(ax,cellstr(cfg.joints));
    ylabel(ax,yLabels{m});
    if m == 2 || m == 3; yline(ax,0,'--','Color',[0.35 0.35 0.35]); end
    text(ax,0.01,0.99,letters(m),'Units','normalized','FontWeight','bold', ...
        'FontSize',10,'VerticalAlignment','top');
    rf_style_axes(ax,cfg);
    hold(ax,'off');
end

outBase = fullfile(cfg.outputDir,'Figure_S2_model_performance_summary');
rf_export_figure(fig,outBase,176,62);
close(fig);

summary = table(cfg.joints',mu(:,1),sd(:,1),mu(:,2),sd(:,2),mu(:,3),sd(:,3), ...
    'VariableNames',{'Joint','RMSE_mean','RMSE_SD','R2_mean','R2_SD','VAF_mean','VAF_SD'});
writetable(summary,fullfile(cfg.outputDir,'Figure_S2_model_performance_values.csv'));
end
