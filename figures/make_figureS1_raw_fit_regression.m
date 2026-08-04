function make_figureS1_raw_fit_regression(cfg,nCurves)
%MAKE_FIGURES1_RAW_FIT_REGRESSION 3 joints x 3 modelling stages.

if nargin < 2; nCurves = 20; end
if nargin < 1
    cfg = rf_resolve_paths(fileparts(fileparts(mfilename('fullpath'))));
end

joints = cfg.joints;
stageTitles = ["Source-normalised waveforms","Quintic-spline fits", ...
    "Regression reconstructions"];
D = cell(3,3);
nCycles = nan(3,1);

for j = 1:3
    paths = {
        fullfile(cfg.matDir,"Sort_"+joints(j)+".mat")
        fullfile(cfg.matDir,"Fitting_"+joints(j)+".mat")
        fullfile(cfg.matDir,"Regression_"+joints(j)+".mat")
        };
    for p = 1:3
        if ~isfile(paths{p})
            error('Missing model output: %s. Run MAIN_fitGait_TRACEABLE first.',paths{p});
        end
    end
    A = load(paths{1},'Sort'); B = load(paths{2},'Fit'); C = load(paths{3},'Reg');
    D{j,1} = double(A.Sort.kinematics);
    D{j,2} = double(B.Fit.kinematics);
    D{j,3} = double(C.Reg.kinematics);
    nCycles(j) = min(cellfun(@(x)size(x,2),D(j,:)));
end

nCommon = min(nCycles);
idx = unique(round(linspace(1,nCommon,min(nCurves,nCommon))),'stable');
gc = 0:100;

kneeMedian = median(D{2,1}(61:81,:),'all','omitnan');
if kneeMedian < 0
    warning(['Loaded knee output is flexion-negative in the 60-80%% window. ' ...
        'Rerun the corrected modelling pipeline before publication.']);
end

fig = figure('Color','w','Renderer','painters');
tl = tiledlayout(fig,3,3,'TileSpacing','compact','Padding','compact');
letters = reshape('A':'I',3,3).';

% MATLAB does not allow indexing an expression in older releases; compute row limits separately.
for j = 1:3
    rowValues = [];
    for s = 1:3
        temp = D{j,s}(:,idx);
        rowValues = [rowValues; temp(:)]; %#ok<AGROW>
    end
    rowValues = rowValues(isfinite(rowValues));
    span = max(rowValues)-min(rowValues);
    if span <= 0; span = 10; end
    rowLim = [min(rowValues)-0.05*span max(rowValues)+0.05*span];

    for s = 1:3
        ax = nexttile(tl); hold(ax,'on');
        Y = D{j,s}(:,idx);
        plot(ax,gc,Y,'Color',[0.75 0.75 0.75],'LineWidth',0.55);
        plot(ax,gc,mean(Y,2,'omitnan'),'Color',[0.05 0.05 0.05],'LineWidth',1.7);
        xlim(ax,[0 100]); ylim(ax,rowLim); xticks(ax,0:20:100);
        if j == 1; title(ax,stageTitles(s),'FontWeight','normal'); end
        if s == 1; ylabel(ax,cfg.jointYLabels(j)); end
        if j == 3; xlabel(ax,'Gait cycle (%)'); end
        text(ax,0.01,0.99,letters(j,s),'Units','normalized','FontWeight','bold', ...
            'FontSize',9,'VerticalAlignment','top');
        rf_style_axes(ax,cfg);
        hold(ax,'off');
    end
end

outBase = fullfile(cfg.outputDir,'Figure_S1_raw_fit_regression_diagnostic');
rf_export_figure(fig,outBase,190,150);
close(fig);
end
