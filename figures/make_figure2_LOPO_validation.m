function make_figure2_LOPO_validation(cfg)
%MAKE_FIGURE2_LOPO_VALIDATION Participant-level median validation metrics.

if nargin < 1
    cfg = rf_resolve_paths(fileparts(fileparts(mfilename('fullpath'))));
end

T = rf_load_validation_table(cfg);
metrics = {'RMSE','R2','VAF','MAX'};
yLabels = {'RMSE (°)','R^2','VAF (%)','Maximum absolute error (°)'};
letters = 'ABCD';

fig = figure('Color','w','Renderer','painters');
tl = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');

for m = 1:4
    ax = nexttile(tl); hold(ax,'on');
    allVals = [];

    for j = 1:3
        sub = T(T.Joint==cfg.joints(j),:);
        ids = unique(sub.SubjectRemoved,'stable');
        vals = nan(numel(ids),1);
        for s = 1:numel(ids)
            vals(s) = median(sub.(metrics{m})(sub.SubjectRemoved==ids(s)),'omitnan');
        end

        allVals = [allVals; vals]; %#ok<AGROW>
        x = repmat(j,numel(vals),1);
        boxchart(ax,x,vals,'BoxFaceColor',cfg.jointColours(j,:), ...
            'BoxFaceAlpha',0.24,'MarkerStyle','none');
        jitter = linspace(-0.16,0.16,numel(vals))';
        scatter(ax,x+jitter,vals,18,cfg.jointColours(j,:),'filled', ...
            'MarkerFaceAlpha',0.72,'MarkerEdgeColor','none');
    end

    xlim(ax,[0.5 3.5]); xticks(ax,1:3); xticklabels(ax,cellstr(cfg.joints));
    ylabel(ax,yLabels{m});
    text(ax,0.01,0.99,letters(m),'Units','normalized','FontWeight','bold', ...
        'FontSize',10,'VerticalAlignment','top');
    if m == 2 || m == 3
        yline(ax,0,'--','Color',[0.35 0.35 0.35],'LineWidth',0.8);
    end
    if m == 2
        ylim(ax,expandLimits(allVals,0.08));
    end
    rf_style_axes(ax,cfg);
    hold(ax,'off');
end

outBase = fullfile(cfg.outputDir,'Figure_2_LOPO_validation');
rf_export_figure(fig,outBase,176,126);
close(fig);
end

function lim = expandLimits(x,f)
x = x(isfinite(x));
if isempty(x); lim = [-1 1]; return; end
lo = min(x); hi = max(x); span = hi-lo;
if span == 0; span = max(1,abs(hi)); end
lim = [lo-f*span hi+f*span];
end
