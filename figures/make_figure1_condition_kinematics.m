function make_figure1_condition_kinematics(cfg)
%MAKE_FIGURE1_CONDITION_KINEMATICS
% Participant-level mean ± 1 between-participant SD for C2/C1/C3.

if nargin < 1
    cfg = rf_resolve_paths(fileparts(fileparts(mfilename('fullpath'))));
end

gc = (0:100)';
means = cell(3,3);
sds = cell(3,3);
counts = zeros(3,3);

for c = 1:3
    S = load(cfg.normFiles{c},'Normatives');
    subjects = string(S.Normatives.Kinematics.sujets(:));

    for j = 1:3
        Y = double(S.Normatives.Kinematics.(cfg.jointCodes(j)).data);
        if size(Y,1) ~= 101
            error('%s %s data are not 101 x N.',cfg.conditions(c),cfg.joints(j));
        end

        if cfg.joints(j) == "Knee"
            Y = rf_apply_knee_rule(Y,'median60-80');
        end

        u = unique(subjects,'stable');
        participantCurves = nan(101,numel(u));
        for s = 1:numel(u)
            participantCurves(:,s) = mean(Y(:,subjects==u(s)),2,'omitnan');
        end

        means{j,c} = mean(participantCurves,2,'omitnan');
        sds{j,c} = std(participantCurves,0,2,'omitnan');
        counts(j,c) = size(participantCurves,2);
    end
end

fig = figure('Color','w','Renderer','painters');
tl = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
letters = 'ABC';

for j = 1:3
    ax = nexttile(tl); hold(ax,'on');
    handles = gobjects(3,1);

    % Determine common limits from all mean ± SD bands.
    vals = [];
    for c = 1:3
        vals = [vals; means{j,c}-sds{j,c}; means{j,c}+sds{j,c}]; %#ok<AGROW>
    end
    vals = vals(isfinite(vals));
    span = max(vals)-min(vals);
    if span <= 0; span = 10; end
    ylims = [min(vals)-0.05*span max(vals)+0.05*span];

    for c = 1:3
        mu = means{j,c}; sd = sds{j,c};
        xPoly = [gc; flipud(gc)];
        yPoly = [mu-sd; flipud(mu+sd)];
        patch(ax,xPoly,yPoly,cfg.conditionColours(c,:), ...
            'FaceAlpha',cfg.bandAlpha,'EdgeColor','none', ...
            'HandleVisibility','off');
        handles(c) = plot(ax,gc,mu,'Color',cfg.conditionColours(c,:), ...
            'LineStyle',cfg.conditionLineStyles{c}, ...
            'LineWidth',cfg.meanLineWidth, ...
            'DisplayName',sprintf('%s (%s)',cfg.conditionLabels(c),cfg.conditions(c)));
    end

    xlim(ax,[0 100]); ylim(ax,ylims); xticks(ax,0:20:100);
    xlabel(ax,'Gait cycle (%)');
    ylabel(ax,cfg.jointYLabels(j));
    title(ax,cfg.joints(j),'FontWeight','normal');
    text(ax,0.01,0.99,letters(j),'Units','normalized','FontWeight','bold', ...
        'FontSize',10,'VerticalAlignment','top','HorizontalAlignment','left');
    rf_style_axes(ax,cfg);
    hold(ax,'off');

    if j == 1
        legend(ax,handles,'Location','northoutside','Orientation','horizontal', ...
            'Box','off','FontName',cfg.fontName,'FontSize',7);
    end
end

% Keep the graphic itself free of a manuscript-style title; caption belongs in text.
outBase = fullfile(cfg.outputDir,'Figure_1_condition_kinematics');
rf_export_figure(fig,outBase,190,72);
close(fig);

fprintf('Saved Figure 1. Participant counts by panel/condition:\n');
disp(array2table(counts,'VariableNames',cellstr(cfg.conditionLabels), ...
    'RowNames',cellstr(cfg.joints)));
end
