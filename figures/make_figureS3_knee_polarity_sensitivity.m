function make_figureS3_knee_polarity_sensitivity(cfg)
%MAKE_FIGURES3_KNEE_POLARITY_SENSITIVITY
% Compare four polarity decisions, stratified by C1/C2/C3.

if nargin < 1
    cfg = rf_resolve_paths(fileparts(fileparts(mfilename('fullpath'))));
end

rules = ["Median 55–75%","Median 60–80%","Median 65–85%","Maximum 50–90%"];
ruleCodes = ["median55-75","median60-80","median65-85","max50-90"];

records = table();
fig = figure('Color','w','Renderer','painters');
tl = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
letters = 'ABC';
axs = gobjects(3,1);

% Plot in manuscript condition order: Slow (C2), Normal (C1), Fast (C3).
for c = 1:3
    S = load(cfg.normFiles{c},'Normatives');
    Y = double(S.Normatives.Kinematics.FE3.data);
    subjects = string(S.Normatives.Kinematics.sujets(:));
    n = size(Y,2);
    decisions = false(n,4);

    trialWithinSubject = zeros(n,1);
    u = unique(subjects,'stable');
    for s = 1:numel(u)
        ids = find(subjects==u(s));
        trialWithinSubject(ids) = 1:numel(ids);
    end

    for r = 1:4
        [~,decisions(:,r),scores] = rf_apply_knee_rule(Y,ruleCodes(r));
        temp = table(repmat(cfg.conditions(c),n,1),repmat(cfg.conditionLabels(c),n,1), ...
            subjects,trialWithinSubject,repmat(rules(r),n,1),decisions(:,r),scores(:), ...
            'VariableNames',{'Condition','ConditionLabel','Participant','TrialWithinCondition', ...
            'Rule','ReversedRelativeToInput','RuleScore'});
        records = [records; temp]; %#ok<AGROW>
    end

    % Sort rows by participant then trial; display reverse=1, retain=0.
    ax = nexttile(tl);
    axs(c) = ax;
    imagesc(ax,decisions');
    colormap(ax,[0.92 0.92 0.92; 0.20 0.45 0.70]);
    caxis(ax,[0 1]);
    yticks(ax,1:4); yticklabels(ax,cellstr(rules));
    xlabel(ax,'Participant-condition trials');
    title(ax,sprintf('%s (%s)',cfg.conditionLabels(c),cfg.conditions(c)), ...
        'FontWeight','normal');
    text(ax,0.01,0.99,letters(c),'Units','normalized','FontWeight','bold', ...
        'FontSize',10,'VerticalAlignment','top','Color','k','BackgroundColor','w');
    rf_style_axes(ax,cfg);
end

cb = colorbar(axs(3),'Location','eastoutside');
cb.Ticks = [0 1]; cb.TickLabels = {'Retain input sign','Reverse input sign'};
cb.FontName = cfg.fontName; cb.FontSize = 7;

outBase = fullfile(cfg.outputDir,'Figure_S3_knee_polarity_sensitivity');
rf_export_figure(fig,outBase,190,76);
close(fig);

writetable(records,fullfile(cfg.outputDir,'Knee_Polarity_Sensitivity_Trial_Level.csv'));

% Compact count and agreement table.
summary = table();
for c = 1:3
    for r = 1:4
        rows = records.Condition==cfg.conditions(c) & records.Rule==rules(r);
        nTotal = sum(rows);
        nRev = sum(records.ReversedRelativeToInput(rows));
        refRows = records.Condition==cfg.conditions(c) & records.Rule==rules(2);
        ref = records.ReversedRelativeToInput(refRows);
        this = records.ReversedRelativeToInput(rows);
        agreement = mean(this==ref);
        summary = [summary; table(cfg.conditions(c),cfg.conditionLabels(c),rules(r), ...
            nTotal,nRev,agreement,'VariableNames', ...
            {'Condition','ConditionLabel','Rule','NTrials','NReversed','AgreementWith60_80'})]; %#ok<AGROW>
    end
end
writetable(summary,fullfile(cfg.outputDir,'Knee_Polarity_Sensitivity_Summary.csv'));
end
